#!/usr/bin/env python3
"""L53 live gates: real models, no seeded books, distinct private XDG/Chrome per gate.
Only synthetic loopback form POSTs may mutate; explicit safety approval is required.
Replies, logs, traces, actual proposals and installed books are preserved redacted.
A failed check is evidence, never permission to rewrite a mission or retry a submit.
"""
import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

REPO = Path("/home/ribelo/projects/ribelo/leash")
SAFE = " Do not buy, book, send, upload personal data, log in, or bypass challenges. If cookie consent appears, choose Reject all only. Stop if login or a challenge is needed."
MISSIONS = {
    "books": ("https://books.toscrape.com/", "Open the Mystery category on books.toscrape.com and stop when the page heading is Mystery and books are listed. Do not add anything to the basket." + SAFE),
    "maps": ("https://www.google.com/maps?hl=en", "Search Google Maps for Eiffel Tower in Paris and open its place information. Stop when the place name Eiffel Tower and its Paris address are visible." + SAFE),
    "flights": ("https://www.google.com/travel/flights?hl=en", "On Google Flights, open Explore and stop when the Explore destinations map and destination flight prices are visible." + SAFE),
}
CHALLENGE = re.compile(r"unusual traffic|verify (?:that )?you are human|not a robot|complete the captcha|access denied", re.I)

class Gate:
    def __init__(self, args):
        self.args = args
        self.evidence = Path(args.evidence).resolve()
        self.evidence.mkdir(parents=True, exist_ok=False, mode=0o700)
        self.root = Path(tempfile.mkdtemp(prefix="leash-l53-"))
        os.chmod(self.root, 0o700)
        self.env = dict(os.environ)
        for name, directory in [("XDG_RUNTIME_DIR", "runtime"), ("XDG_CONFIG_HOME", "config"), ("XDG_STATE_HOME", "state"), ("XDG_CACHE_HOME", "cache"), ("XDG_DATA_HOME", "data"), ("XDG_DOWNLOAD_DIR", "downloads")]:
            path = self.root / directory
            path.mkdir(mode=0o700)
            self.env[name] = str(path)
        self.key = self.env.get("OPENROUTER_API_KEY", "")
        self.secrets = [self.key] if self.key else []
        self.binary = Path(args.leash).resolve()
        self.log = self.root / "service.log"
        self.service = None
        self.server = None
        self.server_thread = None
        self.submissions = []
        self.results = []
        self.failures = []
        self.cleanup_data = {}
        self.started = time.time()

    def redact(self, value):
        if isinstance(value, dict):
            return {k: ("[redacted capability]" if k in ("tab", "snapshot", "handle") and isinstance(v, str) else self.redact(v)) for k, v in value.items()}
        if isinstance(value, list):
            return [self.redact(v) for v in value]
        if isinstance(value, str):
            for secret in self.secrets:
                if secret:
                    value = value.replace(secret, "[redacted]")
            value = re.sub(r"\b(?:t_[0-9a-f]{16,}|s_[0-9A-Za-z_-]{16,})\b", "[redacted capability]", value)
            return value.replace(str(self.root), "<PRIVATE_ROOT>")
        return value

    def save(self, name, value):
        path = self.evidence / name
        path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        text = value if isinstance(value, str) else json.dumps(self.redact(value), indent=2, ensure_ascii=False) + "\n"
        text = self.redact(text)
        assert not self.key or self.key not in text, "key leak prevented"
        path.write_text(text)
        path.chmod(0o600)

    def check(self, condition, detail):
        if not condition:
            self.failures.append(detail)
        return condition

    def cli(self, name, *args, timeout=90, label=None):
        start = time.monotonic()
        command = [str(self.binary), name, *map(str, args)]
        try:
            p = subprocess.run(command, env=self.env, text=True, capture_output=True, timeout=timeout)
            stdout, stderr, code = p.stdout, p.stderr, p.returncode
        except subprocess.TimeoutExpired as error:
            def text(v):
                return v.decode(errors="replace") if isinstance(v, bytes) else v or ""
            stdout, stderr, code = text(error.stdout), text(error.stderr), 124
            stderr += "\nHarness CLI timeout; no mission retry."
        payload = None
        for stream in (stdout, stderr):
            try:
                payload = json.loads(stream.strip())
                break
            except (ValueError, TypeError):
                pass
        record = {"command": command[1:], "exit_code": code, "elapsed_s": time.monotonic() - start, "reply": payload, "stdout": stdout if payload is None else None, "stderr": stderr if payload is None or not stderr.strip().startswith("{") else None}
        if label:
            self.save(label + ".json", record)
        if payload is None:
            payload = {"status": "harness-error", "message": stderr[:1000]}
        return payload, code, record

    def processes(self):
        found = []
        for entry in Path("/proc").iterdir():
            if not entry.name.isdigit():
                continue
            try:
                raw = (entry / "cmdline").read_bytes()
                argv = raw.split(b"\0")
                if any(str(self.root / "profile").encode() in x for x in argv):
                    found.append({"pid": int(entry.name), "headless": any(b"--headless=new" in x.split() for x in argv), "pipe": any(b"--remote-debugging-pipe" in x.split() for x in argv), "browser_main": not any(b"--type=" in x for x in argv), "argv": [x.decode(errors="replace") for x in argv if x]})
            except (OSError, PermissionError):
                pass
        return found

    def start(self):
        if not self.key:
            raise RuntimeError("OPENROUTER_API_KEY missing; use secret-env ai --")
        chrome = shutil.which("google-chrome-stable") or shutil.which("chromium")
        if not chrome:
            raise RuntimeError("Chrome executable missing")
        config = self.root / "config" / "leash" / "config.toml"
        config.parent.mkdir(mode=0o700)
        # No copied playbooks, real user config, real service, or user profile.
        text = f'''[chrome]
binary = "{chrome}"
profile_dir = "{self.root / 'profile'}"
workspace = "test"
headless = true
[tabs]
cap = 8
[expiry]
idle_s = 3600
tombstone_s = 3600
[models]
jev_model = "typesafe/jev-1.13-20260917"
text_model = "inception/mercury-2.5"
planner_model = "openai/gpt-6-luna"
planner_reasoning = "max"
systemone_endpoint = "https://openrouter.ai/api/v1/systemone"
chat_base_url = "https://openrouter.ai/api/v1"
[learning]
mode = "auto"
successes = 2
timeout_s = 900
planner_model = "openai/gpt-6-luna"
planner_reasoning = "max"
[handoff]
focus_command = []
notify_command = []
'''
        config.write_text(text)
        self.save("config.toml", text)
        self.save("identity.json", {"gate": self.args.gate, "start_unix": self.started, "binary_sha256": hashlib.sha256(self.binary.read_bytes()).hexdigest(), "seeded_playbooks": 0, "private_xdg": True, "headless": True, "model_key_source": "secret-env ai --", "git_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip()})
        self.log_stream = self.log.open("w")
        self.service = subprocess.Popen([str(self.binary), "serve", "--config", str(config)], env=self.env, stdout=self.log_stream, stderr=subprocess.STDOUT, start_new_session=True)
        socket = self.root / "runtime" / "leash" / "control.sock"
        end = time.monotonic() + 25
        while time.monotonic() < end:
            if self.service.poll() is not None:
                raise RuntimeError("Private Leash exited before startup; see redacted service log")
            if socket.exists():
                break
            time.sleep(0.1)
        else:
            raise RuntimeError("Private control socket startup timeout")
        status, code, _ = self.cli("status", label="startup-status")
        if code:
            raise RuntimeError("Private status failed")
        end = time.monotonic() + 25
        while time.monotonic() < end:
            ready = [p for p in self.processes() if p["pipe"]]
            if ready:
                break
            if self.service.poll() is not None:
                raise RuntimeError("Private service exited while awaiting Chrome readiness")
            time.sleep(0.1)
        self.save("startup-process-diagnostic.json", self.processes())
        # Chrome rewrites argv and advertises a process before its CDP initialization ends.
        # The public new handler has a fixed 1 s budget; let cold private startup settle.
        time.sleep(5)
        warm, warm_code, _ = self.cli("new", "about:blank", label="startup-warm-tab")
        if warm_code or not warm.get("tab"):
            raise RuntimeError("Private Chrome warm-up failed")
        self.secrets.append(warm["tab"])
        browsers = [p for p in self.processes() if p["pipe"] and p["browser_main"]]
        self.save("startup-processes.json", browsers)
        if not browsers or not all(p["headless"] for p in browsers):
            raise RuntimeError("Private Chrome is not verified headless-over-pipe")
        agent, agent_code, _ = self.cli("eval", warm["tab"], "return {userAgent:navigator.userAgent,brands:navigator.userAgentData?.brands,platform:navigator.platform}", label="startup-browser-useragent")
        if agent_code:
            raise RuntimeError("Private browser userAgent cross-check failed")
        self.cli("close", warm["tab"], label="startup-warm-close")
        if list((self.root / "config").rglob("playbook.json")):
            raise RuntimeError("Unexpected seeded playbook")

    def state(self, stage):
        actual = {"proposed": [], "installed": [], "traces": []}
        for directory in ["config", "state"]:
            for path in (self.root / directory).rglob("*.json"):
                if "profile" in path.parts:
                    continue
                try:
                    value = json.loads(path.read_text())
                except (OSError, ValueError):
                    continue
                relative = str(path.relative_to(self.root))
                self.save(stage + "/" + relative, value)
                if "proposed" in path.parts and "retired" not in path.parts:
                    actual["proposed"].append(value)
                elif path.name == "playbook.json":
                    actual["installed"].append(value)
                elif "traces" in path.parts:
                    actual["traces"].append(value)
        status, _, _ = self.cli("status", label=stage + "/status")
        actual["status"] = status
        return actual

    def usage(self, offset):
        rows = []
        with self.log.open(errors="replace") as stream:
            stream.seek(offset)
            for line in stream:
                try:
                    value = json.loads(line)
                    if "usage" in value.get("msg", ""):
                        rows.append(value)
                except ValueError:
                    pass
        return rows

    def observe(self, tab, stage):
        snap, _, _ = self.cli("snap", tab, "--limit", 250, label=stage + "/snapshot")
        text, _, _ = self.cli("eval", tab, "return {url:location.href,title:document.title,text:document.body.innerText.slice(0,50000)}", label=stage + "/visible-page")
        self.cli("shot", tab, str(self.evidence / stage / "page.png"), label=stage + "/screenshot")
        # eval result schema is preserved too; recursively extract visible text.
        def strings(v):
            if isinstance(v, dict):
                return " ".join(strings(x) for x in v.values())
            if isinstance(v, list):
                return " ".join(strings(x) for x in v)
            return v if isinstance(v, str) else ""
        return snap, text, strings(text)

    def goal(self, reply, visible, value=None):
        final = reply.get("final") or {}
        url = final.get("url", "")
        names = " ".join(row.get("name", "") for row in final.get("rows", []))
        observed = visible + " " + names
        if self.args.gate == "books":
            return "/category/books/mystery_3/" in url and "Mystery" in observed and "Add to basket" in observed
        if self.args.gate == "maps":
            return "Eiffel Tower" in observed and bool(re.search(r"Paris|Champ de Mars|75007", observed, re.I)) and "/place/" in url
        if self.args.gate == "flights":
            priced_amount = r"(?:\b(?:PLN|EUR|GBP)|[€$£]|zł)\s*\d[\d,.]*|\d[\d,.]*\s*(?:PLN\b|EUR\b|GBP\b|zł|[€$£])"
            return "/travel/explore" in url and bool(re.search(r"Explore", observed)) and bool(re.search(priced_amount, observed))
        return len(self.submissions) == value and self.submissions[-1]["token"] == ["alpha-test", "beta-test"][value - 1] and "Test message posted" in observed

    def learning_state(self):
        path = self.root / "state" / "leash" / "learning.json"
        if not path.exists():
            return {"mtime_ns": None, "state": {}}
        return {"mtime_ns": path.stat().st_mtime_ns, "state": json.loads(path.read_text())}

    def wait_learning(self, number):
        start = time.monotonic()
        history = []
        final = None
        idle = False
        while True:
            remaining = 900 - (time.monotonic() - start)
            if remaining <= 0:
                self.check(False, f"Mission {number}: pending learning exceeded 900-second wait; no retry")
                break
            reply, code, _ = self.cli("status", timeout=min(10, remaining))
            final = reply
            learning = reply.get("learning") or {}
            pending = learning.get("pending")
            history.append({"elapsed_s": time.monotonic() - start, "pending": pending, "sites": learning.get("sites", [])})
            if code or type(pending) is not int or pending < 0:
                self.check(False, f"Mission {number}: status lacks usable learning.pending; no retry")
                break
            if pending == 0:
                idle = True
                break
            time.sleep(min(5, max(0, 900 - (time.monotonic() - start))))
        after = self.learning_state()
        self.save(f"mission-{number}/learning-wait.json", {"bound_seconds": 900, "completed": idle, "elapsed_s": time.monotonic() - start, "history": history, "final_status": final, "before": self.learning_before, "after": after})
        return idle, final or {}, after

    def accounting(self, reply):
        idle, status, after = self.wait_learning(self.learning_number)
        sites = (status.get("learning") or {}).get("sites", [])
        # This meter is the LAST model-bearing work, not a cumulative counter.
        # record_account writes account:<site> last, moving it to the first key.
        # Distinct mtime plus that key detects even an identical rewritten meter.
        before = self.learning_before
        key = "account:google.com"
        rewritten = after["mtime_ns"] != before["mtime_ns"] and next(iter(after["state"]), None) == key
        account = after["state"].get(key)
        reported = next((s for s in sites if s.get("site") == "google.com"), {})
        learning_calls, learning_cost = (0, 0.0) if idle and not rewritten else (None, None)
        if idle and rewritten:
            self.check(isinstance(account, dict), "Async learning account missing")
            learning_calls = reported.get("learning_calls")
            learning_cost = reported.get("learning_cost")
            self.check(account.get("model_calls") == learning_calls and account.get("model_cost") == learning_cost, "Status and learning.json last-work meter disagree")
        data = reply.get("data") or {}
        run_calls = reply.get("model_calls")
        run_cost = reply.get("model_cost")
        kinds = dict(data.get("model_calls_by_kind") or {})
        self.check(sum(kinds.values()) == run_calls, "Browser reply call-kind accounting mismatch")
        if learning_calls:
            kinds["learning"] = learning_calls
        total_calls = run_calls + learning_calls if run_calls is not None and learning_calls is not None else None
        total_cost = run_cost + learning_cost if idle and run_cost is not None and learning_cost is not None and data.get("cost_unreported") == 0 else None
        return {"scope": "browser reply plus newly completed asynchronous learning work", "total_calls_by_kind": kinds, "run_only_calls": run_calls, "run_only_reported_cost_usd": data.get("reported_cost"), "run_only_cost_unreported": data.get("cost_unreported"), "learning_calls": learning_calls, "learning_cost_usd": learning_cost, "total_calls": total_calls, "total_cost_usd": total_cost, "total_cost_fully_reported": total_cost is not None, "learning_pending_finished": idle, "new_learning_account": rewritten, "last_work_status": reported}

    def mission(self, number, url, mission):
        stage = f"mission-{number}"
        self.learning_number = number
        self.learning_before = self.learning_state()
        tab_reply, code, _ = self.cli("new", url, label=stage + "/new")
        if code or not tab_reply.get("tab"):
            raise RuntimeError("New private tab failed")
        tab = tab_reply["tab"]
        self.secrets.append(tab)
        try:
            _, _, initial = self.observe(tab, stage + "/before")
            if CHALLENGE.search(initial):
                self.failures.append(f"Mission {number}: challenge present before drive; stopped, no bypass")
                return False
            offset = self.log.stat().st_size
            reply, code, record = self.cli("drive", mission, "--tab", tab, "--deadline-s", self.args.deadline, "--max-steps", 50, "--max-procedures", 15, "--out", str(self.root / f"output-{number}.jsonl"), timeout=self.args.deadline + 190, label=stage + "/drive")
            _, _, visible = self.observe(tab, stage + "/after")
            data = reply.get("data") or {}
            # Error details may carry a partial result; preserve original rather than inventing done.
            accounting = self.accounting(reply)
            row = {"number": number, "mission": mission, "exit_code": code, "status": reply.get("status"), "reason": reply.get("reason") or reply.get("message"), "elapsed_s": record["elapsed_s"], "model_calls": reply.get("model_calls"), "model_calls_by_kind": accounting["total_calls_by_kind"], "model_cost_usd": reply.get("model_cost"), "reported_cost_usd": reply.get("model_cost"), "cost_unreported": data.get("cost_unreported") if reply.get("model_cost") is not None else None, "accounting": accounting, "usage_rows": self.usage(offset), "goal_verified": self.goal(reply, visible, number), "reply": reply}
            row.update({"model_calls": accounting["total_calls"], "model_cost_usd": accounting["total_cost_usd"], "reported_cost_usd": accounting["total_cost_usd"], "cost_unreported": 0 if accounting["total_cost_fully_reported"] else None})
            self.check(accounting["total_cost_fully_reported"], f"Mission {number}: total browser-plus-async-learning provider cost is incomplete")
            trace_path = Path(reply.get("trace_path") or "")
            if reply.get("trace_path") and self.root.resolve() in trace_path.resolve().parents and trace_path.exists():
                durable = json.loads(trace_path.read_text())
                row["durable_accounting"] = {"model_calls": durable.get("model_calls"), "cost_usd": durable.get("cost")}
                self.check(durable.get("model_calls") == reply.get("model_calls") and durable.get("cost") == reply.get("model_cost"), f"Mission {number}: durable trace and browser-only reply meter disagree")
            else:
                self.check(False, f"Mission {number}: no private durable trace for browser-run accounting")
            self.check(reply.get("model_cost") is not None, f"Mission {number}: browser-run provider cost is incomplete")
            self.results.append(row)
            self.save("cost-curve.json", self.results)
            self.state(stage + "/durable")
            output = self.root / f"output-{number}.jsonl"
            if output.exists():
                self.save(stage + "/operator-output.jsonl", output.read_text())
            if self.args.gate == "form":
                self.save(stage + "/submissions.json", self.submissions)
            done = code == 0 and reply.get("status") == "done"
            self.check(done, f"Mission {number}: drive not done (exit {code}, status {reply.get('status')}, reason {row['reason']})")
            self.check(row["goal_verified"], f"Mission {number}: independently observed page did not satisfy unchanged mission")
            print(f"{self.args.gate} mission {number}: exit={code} status={reply.get('status')} goal={row['goal_verified']} model_calls={row['model_calls']} cost={row['model_cost_usd']} proposals={len(reply.get('proposals', []))} installed={reply.get('installed', [])}", flush=True)
            return done and row["goal_verified"] and not CHALLENGE.search(visible) and not self.failures
        finally:
            self.cli("close", tab, label=stage + "/close")

    @staticmethod
    def procedures(books):
        for book in books:
            if "procedure" in book:
                yield book["procedure"]
            else:
                yield from book.get("procedures", [])

    def replay(self):
        url, task = MISSIONS[self.args.gate]
        self.save("mission-contract.json", {"url": url, "mission": task, "unchanged_across_four_missions": True})
        for number in range(1, 5):
            if not self.mission(number, url, task):
                break
            state = self.state(f"checkpoint-{number}")
            reply = self.results[-1]["reply"]
            if number <= 2:
                self.check(not any(p.get("slug", "").startswith("draft:") for p in reply.get("procedures", [])), f"Mission {number}: unexpectedly ran a draft before two traces")
                self.check(not state["installed"], f"Mission {number}: replay procedure installed before site verification")
            if number == 2:
                drafts = list(self.procedures(state["proposed"]))
                self.check(bool(drafts), "After two independently successful missions: no actual generated draft in private proposed store")
                self.check(any(len(p.get("provenance", {}).get("traces", [])) >= 2 for p in drafts), "Draft lacks provenance of two successful traces")
                self.check(any(p.get("provenance", {}).get("gate") == "replay" and p.get("provenance", {}).get("repeatable") is True for p in drafts), "Generated draft is not classified repeatable with replay gate")
            if number == 3:
                attempts = [p for p in reply.get("procedures", []) if p.get("slug", "").startswith("draft:") and not p.get("planned")]
                verified = [p for p in attempts if p.get("choice", {}).get("key") == p.get("slug") and p.get("outcome") == "verified" and p.get("expectations") and all(e.get("passed") for e in p["expectations"])]
                self.check(bool(verified), "Third mission: no JEV-selected generated draft with nonempty passing expectations")
                self.check(bool(state["installed"]) and any(p.get("provenance", {}).get("gate") == "replay" for p in self.procedures(state["installed"])), "Third mission: successful replay did not asynchronously install an actual replay-gated playbook")
            if number == 4:
                installed_slugs = {p.get("slug") for p in self.procedures(state["installed"])}
                verified = [p for p in reply.get("procedures", []) if p.get("slug") in installed_slugs and p.get("choice", {}).get("key") == p.get("slug") and not p.get("slug", "").startswith("draft:") and not p.get("planned") and p.get("outcome") == "verified" and p.get("expectations") and all(e.get("passed") for e in p["expectations"])]
                self.check(bool(verified), "Fourth mission: installed procedure was not actually used with passing expectations")
                baseline = [r["model_cost_usd"] for r in self.results[:2]]
                current = self.results[-1]["model_cost_usd"]
                self.check(current is not None and all(x is not None for x in baseline) and all(r.get("cost_unreported") == 0 for r in [*self.results[:2], self.results[-1]]) and current < min(baseline), "Fourth mission: lower fully-reported model cost than both on-the-fly baselines not demonstrated")
                self.check(any(p.get("provenance", {}).get("gate") == "replay" for p in self.procedures(state["installed"])), "Installed playbook lacks replay-gate provenance")
            if self.failures:
                break  # Preserve useful first-failure evidence; do not pay for a doomed campaign.

    def form(self):
        outer = self
        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass
            def page(self, body, status=200):
                content = ("<!doctype html><html><head><title>Harmless message posting acceptance</title></head><body>" + body + "</body></html>").encode()
                self.send_response(status)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(content)))
                self.end_headers()
                self.wfile.write(content)
            def do_GET(self):
                if self.path.startswith("/message-compose"):
                    self.page('<h1>Harmless message posting form</h1><p>Local synthetic test only. Nothing is sent outside this test server.</p><form method="POST" action="/message-posted"><label>Test message<input name="token" required autocomplete="off"></label><button type="submit">Post test message</button></form>')
                elif self.path.startswith("/message-posted"):
                    token = parse_qs(urlparse(self.path).query).get("token", [""])[0]
                    self.page('<h1>Test message posted</h1><p>Recorded synthetic token: ' + html.escape(token) + '</p><p>No external message was sent.</p>')
                else:
                    self.page('<h1>Not found</h1>', 404)
            def do_POST(self):
                size = int(self.headers.get("Content-Length", "0"))
                token = parse_qs(self.rfile.read(size).decode()).get("token", [""])[0]
                if self.path != "/message-posted" or token not in ("alpha-test", "beta-test"):
                    self.page('<h1>Rejected test input</h1>', 400)
                    return
                outer.submissions.append({"n": len(outer.submissions) + 1, "token": token, "time_unix": time.time()})
                self.send_response(303)
                self.send_header("Location", "/message-posted?token=" + token)
                self.end_headers()
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.server_thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.server_thread.start()
        url = f"http://127.0.0.1:{self.server.server_port}/message-compose"
        for number, value in enumerate(("alpha-test", "beta-test"), 1):
            task = f"On this harmless local test server, enter {value} in the Test message field and click Post test message exactly once. Stop when Test message posted and {value} are visible. This synthetic loopback submission is authorized. Never submit a second time or retry an uncertain submission. Do not log in, buy, upload, or send anything outside this local test server."
            if not self.mission(number, url, task):
                break
            state = self.state(f"checkpoint-{number}")
            self.check(len(self.submissions) == number, f"After form mission {number}: expected exactly {number} independently authorized POSTs")
            self.check(not any(p.get("slug", "").startswith("draft:") for p in self.results[-1]["reply"].get("procedures", [])), "Nonrepeatable draft offered/replayed")
            if number == 1:
                self.check(not state["installed"], "Form installed before independent agreement")
            if number == 2:
                installed = list(self.procedures(state["installed"]))
                self.check(bool(installed) and bool(self.results[-1]["reply"].get("installed")), "After two form submissions: no actual installed agreement procedure reported")
                self.check(any(p.get("provenance", {}).get("gate") == "agreement" and p.get("provenance", {}).get("repeatable") is False and len(p.get("provenance", {}).get("traces", [])) == 2 for p in installed), "Installed form procedure lacks nonrepeatable two-trace agreement provenance")
            if self.failures:
                break
        self.save("submissions.json", self.submissions)
        self.check(len(self.submissions) == 2, "Form gate did not finish with exactly two POSTs and no third replay")

    def cleanup(self):
        if self.service and self.service.poll() is None:
            self.service.terminate()
            try:
                self.service.wait(timeout=25)
            except subprocess.TimeoutExpired:
                os.killpg(self.service.pid, signal.SIGTERM)
                try:
                    self.service.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(self.service.pid, signal.SIGKILL)
                    self.service.wait(timeout=10)
        remaining = self.processes()
        self.cleanup_data = {"service_exit": self.service.returncode if self.service else None, "profile_processes_after_service": remaining, "loopback_server_closed": False}
        if remaining:
            self.failures.append("Private profile processes remained after service exit; killed exact owned PIDs")
            for p in remaining:
                try:
                    os.kill(p["pid"], signal.SIGKILL)
                except ProcessLookupError:
                    pass
        if self.server:
            self.server.shutdown()
            self.server.server_close()
            self.server_thread.join(timeout=5)
        self.cleanup_data["loopback_server_closed"] = True
        if self.args.gate == "form" and self.server:
            self.save("submissions.json", self.submissions)
            self.cleanup_data["submissions_after_browser_shutdown"] = len(self.submissions)
            self.check(len(self.submissions) == 2, "Entire form service lifetime included an unexpected or missing POST")
        if self.log.exists():
            self.save("service.redacted.jsonl", self.log.read_text(errors="replace"))
        self.save("cleanup.json", self.cleanup_data)
        self.save("result.json", {"gate": self.args.gate, "passed": not self.failures, "missions_recorded": len(self.results), "failures": self.failures, "elapsed_s": time.time() - self.started, "cleanup": self.cleanup_data})
        # Exact generated target, never caller-provided path.
        if self.root.parent == Path(tempfile.gettempdir()).resolve() and self.root.name.startswith("leash-l53-"):
            shutil.rmtree(self.root)
        else:
            raise RuntimeError("Refusing unexpected cleanup path")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("gate", choices=["books", "maps", "flights", "form"])
    parser.add_argument("evidence")
    parser.add_argument("--leash", default=str(REPO / "_build_l53_live/default/packages/leash/bin/main.exe"))
    parser.add_argument("--deadline", type=int, default=420)
    parser.add_argument("--startup-only", action="store_true", help="Verify isolated headless browser without missions or model calls")
    parser.add_argument("--allow-local-submissions", action="store_true", help="Explicitly authorize the two synthetic loopback form submissions after safety review")
    args = parser.parse_args()
    if args.gate == "form" and not args.startup_only and not args.allow_local_submissions:
        parser.error("Nonrepeatable form gate requires explicit --allow-local-submissions after safety fixes are approved")
    gate = Gate(args)
    def interrupted(signum, frame):
        raise RuntimeError(f"Harness interrupted by signal {signum}; closing owned resources")
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        gate.start()
        if args.startup_only:
            gate.save("diagnostic-only.json", {"startup_only": True, "missions": 0, "model_calls": 0, "not_an_acceptance_pass": True})
        elif args.gate == "form":
            gate.form()
        else:
            gate.replay()
    except Exception as error:
        gate.failures.append(type(error).__name__ + ": " + str(error))
    finally:
        gate.cleanup()
    print(json.dumps({"gate": args.gate, "passed": not gate.failures, "missions_recorded": len(gate.results), "failures": gate.failures}), flush=True)
    return 0 if not gate.failures else 1

if __name__ == "__main__":
    raise SystemExit(main())
