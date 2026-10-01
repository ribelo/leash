#!/usr/bin/env python3
"""Live-only L18 gate (headless part): milestone-4 human handoff through the
real CLI/service/headless-Chrome. One service, sequential handoffs, each on a
fresh tab:

handoff-resume  two CLIs: the agent (alice) hands off and blocks, the human
                leash resume HANDLE finishes it, and the agent's handoff answers
                {resumed: true, url, title}. While it waits, commands on the handle
                actions are refused with with-human, and list shows
                with_human with the reason (hand-lz3p hand-0sja hand-nisr
                hand-r4t1).
timeout         handoff --timeout-s 3 with nobody resuming answers timeout and
                the tab is actionable again (hand-lmd5).
disconnect      killing the agent's handoff client clears with_human without
                any resume (client disconnect ends the wait).
no-handoff      resume on a tab nobody waits on answers no-handoff, including
                a tab whose handoff already ended (hand-szz7).
unknown-tab     handoff on a handle that was never minted answers unknown-tab.
auto-done       the stand-in notifier printing "done" resumes the tab with no
                CLI resume (hand-phof: the Done action is a resume).
focus-argv      the stand-in focus command received the substituted tab,
                reason, url and title (hand-04rb).
warnings        a failing focus stand-in and a failing notify stand-in each
                produce warnings, but the handoff still succeeds on resume
                (hand-rg9h).

The human-facing steps never touch the real desktop: the wrapper points
handoff.focus_command/_notify_command at stand-in scripts that record their
argv and branch on the reason text (idle until stopped, print "done", or exit
nonzero). The headed focus/notification run is the separate manual script
scripts/live-acceptance-m4-headed, for the user on the desktop.
"""
import http.server
import json
import os
import signal
import subprocess
import sys
import threading
import time

LEASH, ROOT, SERVICE_LOG = sys.argv[1:]
FOCUS_LOG = os.path.join(ROOT, "focus-argv.log")
NOTIFY_LOG = os.path.join(ROOT, "notify-argv.log")

PAGE = """<!doctype html><html><head><title>M4 gate</title></head><body>
<h1>M4 gate</h1>
</body></html>"""


class PageHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/m4":
            self.send_error(404)
            return
        data = PAGE.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *_args):
        pass


EXITS = {
    "invalid-request": 64, "usage": 64, "no-handoff": 64, "timeout": 75,
    "unknown-tab": 66, "tab-gone": 66, "with-human": 77,
}


HANDLES = []


def cli(command, *args, error=None, timeout=60):
    proc = subprocess.run([LEASH, command, *map(str, args)],
                          capture_output=True, text=True, timeout=timeout)
    raw = proc.stdout if proc.returncode == 0 else proc.stderr
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise AssertionError(
            f"{command} did not return JSON: rc={proc.returncode}: "
            f"{proc.stdout!r} {proc.stderr!r}") from exc
    if error:
        expect = EXITS.get(error)
        assert value.get("code") == error and (expect is None or proc.returncode == expect), \
            (command, proc.returncode, value)
    else:
        assert proc.returncode == 0, (command, proc.returncode, value, proc.stderr)
    if not error and command in ("new", "take"):
        HANDLES.append(value["tab"])
    return value


def handoff_async(tab, reason, timeout_s=None):
    argv = [LEASH, "handoff", tab, reason]
    if timeout_s is not None:
        argv += ["--timeout-s", str(timeout_s)]
    return subprocess.Popen(argv, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True)


def handoff_result(proc, timeout=120):
    stdout, stderr = proc.communicate(timeout=timeout)
    try:
        value = json.loads(stdout)
    except json.JSONDecodeError as exc:
        raise AssertionError(
            f"handoff did not return JSON: rc={proc.returncode}: "
            f"{stdout!r} {stderr!r}") from exc
    return proc.returncode, value


def every_tab(_who="alice"):
    return cli("list")["tabs"]


def held(handle):
    proc = subprocess.run([LEASH, "snap", handle], capture_output=True, text=True, timeout=60)
    if proc.returncode == 0:
        return False
    try:
        return json.loads(proc.stderr).get("code") == "with-human"
    except json.JSONDecodeError:
        return False


def wait_held(handle, want, timeout=20):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if held(handle) == want:
            return
        time.sleep(0.2)
    raise AssertionError(f"tab {handle[:8]} with_human did not become {want}")


def human_row():
    rows = [row for row in every_tab() if row.get("with_human")]
    assert len(rows) == 1, rows
    return rows[0]


def read_log(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except OSError:
        return ""


def wait_warning(tab, step, timeout=5):
    """hand-rg9h: resume only after the async stand-in has actually failed."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        for line in read_log(SERVICE_LOG).splitlines():
            if f"handoff warning: {step}:" in line and tab in line:
                return
        time.sleep(0.05)
    raise AssertionError(f"{step} warning for {tab} did not reach the service log")


def main():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), PageHandler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    local = f"http://127.0.0.1:{server.server_port}"
    print(f"pages: {local}/m4 (title 'M4 gate')", flush=True)

    # handoff-resume: agent blocks, human resumes, reply carries url/title.
    tab = cli("new", local + "/m4")["tab"]
    reason = "please confirm the M4 gate page"
    proc = handoff_async(tab, reason)
    wait_held(tab, True)
    waiting = human_row()
    assert waiting.get("reason") == reason, waiting
    assert "tab" not in waiting, waiting
    cli("snap", tab, error="with-human")
    cli("text", tab, error="with-human")
    assert cli("resume", tab) == {"resumed": True}
    rc, answered = handoff_result(proc)
    assert rc == 0, (rc, answered)
    assert answered.get("resumed") is True, answered
    assert answered.get("url") == local + "/m4", answered
    assert answered.get("title") == "M4 gate", answered
    assert "warnings" not in answered, answered
    assert not any(row.get("with_human") for row in every_tab())
    print(f"handoff-resume: human resumed {tab[:8]}, agent got url/title, "
          "tab actionable again", flush=True)

    # no-handoff: the ended handoff above leaves nothing to resume.
    cli("resume", tab, error="no-handoff")
    print("no-handoff: resume after the handoff ended answers no-handoff",
          flush=True)

    # timeout: short deadline answers timeout, tab actionable again.
    slow = cli("new", local + "/m4")["tab"]
    started = time.monotonic()
    timed_out = cli("handoff", slow, "nobody will answer this",
                    "--timeout-s", 3, error="timeout", timeout=60)
    elapsed = time.monotonic() - started
    assert 2 <= elapsed <= 30, elapsed
    assert not held(slow)
    cli("snap", slow)
    print(f"timeout: --timeout-s 3 answered timeout in {elapsed:.1f}s, "
          "tab actionable again", flush=True)

    # disconnect: killing the waiting client clears the human hold.
    dropped = cli("new", local + "/m4")["tab"]
    proc = handoff_async(dropped, "the agent goes away")
    wait_held(dropped, True)
    proc.send_signal(signal.SIGKILL)
    assert proc.wait(timeout=30) == -signal.SIGKILL, proc.returncode
    wait_held(dropped, False, timeout=20)
    cli("snap", dropped)
    print("disconnect: killed handoff client, tab actionable again, snap works",
          flush=True)

    # no-handoff on a tab never handed off; a missing handle is unknown-tab.
    fresh = cli("new", local + "/m4")["tab"]
    cli("resume", fresh, error="no-handoff")
    cli("handoff", "t_not_a_tab", "missing capability",
        error="unknown-tab")
    print("no-handoff: fresh tab; unknown-tab: a missing handle cannot hand off",
          flush=True)

    # auto-done: the stand-in notifier printing "done" resumes with no CLI.
    auto = cli("new", local + "/m4")["tab"]
    proc = handoff_async(auto, "auto-done: approve from the tray")
    rc, answered = handoff_result(proc, timeout=60)
    assert rc == 0, (rc, answered)
    assert answered.get("resumed") is True, answered
    assert answered.get("title") == "M4 gate", answered
    print("auto-done: notifier printed done, handoff resumed itself", flush=True)

    # focus-argv: the focus stand-in saw the substituted values.
    focus_seen = read_log(FOCUS_LOG)
    for needle in (tab, reason, local + "/m4", "M4 gate"):
        assert needle in focus_seen, (needle, focus_seen[-2000:])
    notify_seen = read_log(NOTIFY_LOG)
    assert "auto-done: approve from the tray" in notify_seen, notify_seen[-2000:]
    print("focus-argv: stand-in focus got tab/reason/url/title; "
          "notify got the reason", flush=True)

    # warnings: each failing stand-in warns but the handoff still succeeds.
    failing_focus = cli("new", local + "/m4")["tab"]
    proc = handoff_async(failing_focus, "fail-focus induction")
    wait_held(failing_focus, True)
    wait_warning(failing_focus, "focus")
    assert cli("resume", failing_focus) == {"resumed": True}
    rc, answered = handoff_result(proc)
    assert rc == 0, (rc, answered)
    assert answered.get("resumed") is True, answered
    assert any("focus" in w for w in answered.get("warnings", [])), answered
    failing_notify = cli("new", local + "/m4")["tab"]
    proc = handoff_async(failing_notify, "fail-notify induction")
    wait_held(failing_notify, True)
    wait_warning(failing_notify, "notify")
    assert cli("resume", failing_notify) == {"resumed": True}
    rc, answered = handoff_result(proc)
    assert rc == 0, (rc, answered)
    assert answered.get("resumed") is True, answered
    assert any("notify" in w for w in answered.get("warnings", [])), answered
    print("warnings: failing focus and notify each warned, handoff succeeded",
          flush=True)

    for handle in HANDLES:
        cli("close", handle)
    leftovers = [t for t in every_tab() if t["url"].startswith(local)]
    assert not leftovers, leftovers
    print("milestone-4 headless live acceptance: done", flush=True)


main()
