#!/usr/bin/env python3
"""L58 pic-iomj: the pilot operates a button that exists only as canvas pixels.

A loopback page draws a "Launch" button at a random point of a canvas; no DOM
control names it. The private headless service drives one mission with the real
pilot. The page records every canvas click in its own state and posts it to the
harness server, so the outcome is verified without trusting the pilot's reply.
Evidence (replies, image metadata, hit evidence and PNGs) is saved redacted.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import re
import shutil
import signal
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REPO = Path(__file__).resolve().parent.parent
MISSION = (
    "This is a harmless local test page. A button labelled Launch is drawn on the "
    "canvas; it is a picture, not a page control. Click the drawn Launch button exactly "
    "once and finish when the canvas shows Launched. Do not click anything else and "
    "never repeat an uncertain click."
)
PAGE = """<!doctype html><html><head><title>Canvas launch test</title>
<style>body{margin:0;background:#20232a}canvas{display:block}</style></head><body>
<canvas id="c" width="900" height="560"></canvas>
<script>
const button = %(button)s;
const c = document.getElementById('c'), g = c.getContext('2d');
window.__hits = []; window.__state = 'ready';
function draw() {
  g.fillStyle = '#20232a'; g.fillRect(0, 0, c.width, c.height);
  const launched = window.__state === 'launched';
  g.fillStyle = launched ? '#2e9d4f' : '#3b6fd8';
  g.beginPath(); g.roundRect(button.x, button.y, button.w, button.h, 12); g.fill();
  g.fillStyle = '#ffffff'; g.font = 'bold 26px sans-serif';
  g.textAlign = 'center'; g.textBaseline = 'middle';
  g.fillText(launched ? 'Launched' : 'Launch', button.x + button.w / 2, button.y + button.h / 2);
}
c.addEventListener('click', (e) => {
  const r = c.getBoundingClientRect(), x = e.clientX - r.left, y = e.clientY - r.top;
  const inside = x >= button.x && x < button.x + button.w && y >= button.y && y < button.y + button.h;
  window.__hits.push({x, y, inside});
  if (inside) window.__state = 'launched';
  draw();
  fetch('/hit', {method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({x, y, inside})});
});
draw();
</script></body></html>"""


class Gate:
    def __init__(self, args):
        self.args = args
        self.evidence = Path(args.evidence).resolve()
        self.evidence.mkdir(parents=True, exist_ok=False, mode=0o755)
        self.root = Path(tempfile.mkdtemp(prefix="leash-l58-"))
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
        self.hits = []
        self.failures = []
        self.checks = []
        rng = random.SystemRandom()
        self.button = {"x": rng.randrange(60, 900 - 220), "y": rng.randrange(60, 560 - 110), "w": 180, "h": 64}

    def redact(self, value):
        if isinstance(value, dict):
            return {k: ("[redacted capability]" if k in ("tab", "snapshot", "handle") and isinstance(v, str) else self.redact(v)) for k, v in value.items()}
        if isinstance(value, list):
            return [self.redact(v) for v in value]
        if isinstance(value, str):
            for secret in self.secrets:
                value = value.replace(secret, "[redacted]")
            value = re.sub(r"\b(?:t_[0-9a-f]{16,}|s_[0-9A-Za-z_-]{16,})\b", "[redacted capability]", value)
            return value.replace(str(self.root), "<PRIVATE_ROOT>")
        return value

    def save(self, name, value):
        text = value if isinstance(value, str) else json.dumps(self.redact(value), indent=2, ensure_ascii=False) + "\n"
        text = self.redact(text)
        assert not self.key or self.key not in text, "key leak prevented"
        (self.evidence / name).write_text(text)

    def keep_png(self, path, name):
        source = Path(path) if path else None
        # Leash writes picture PNGs as /tmp/leash-picture-*.png (Reading.shot), outside XDG.
        if source and source.is_file() and (self.root in source.resolve().parents or re.fullmatch(r"leash-picture-[0-9a-f]+.png", source.name)):
            shutil.copyfile(source, self.evidence / name)
            return name
        return None

    def check(self, condition, detail):
        self.checks.append({"passed": bool(condition), "check": detail})
        if not condition:
            self.failures.append(detail)
        return condition

    def cli(self, label, *args, timeout=90):
        command = [str(self.binary), *map(str, args)]
        try:
            p = subprocess.run(command, env=self.env, text=True, capture_output=True, timeout=timeout)
            stdout, stderr, code = p.stdout, p.stderr, p.returncode
        except subprocess.TimeoutExpired:
            stdout, stderr, code = "", "harness CLI timeout; no retry", 124
        payload = None
        for stream in (stdout, stderr):
            try:
                payload = json.loads(stream.strip())
                break
            except (ValueError, TypeError):
                pass
        self.save(label + ".json", {"command": command[1:], "exit_code": code, "reply": payload, "raw": None if payload is not None else (stdout + stderr)[:4000]})
        return payload or {}, code

    def browsers(self):
        found = []
        for entry in Path("/proc").iterdir():
            if not entry.name.isdigit():
                continue
            try:
                argv = (entry / "cmdline").read_bytes().split(b"\0")
            except (OSError, PermissionError):
                continue
            if any(str(self.root / "profile").encode() in x for x in argv):
                found.append({"pid": int(entry.name), "headless": any(b"--headless=new" in x for x in argv), "pipe": any(b"--remote-debugging-pipe" in x for x in argv), "main": not any(b"--type=" in x for x in argv)})
        return found

    def serve_page(self):
        outer = self
        page = (PAGE % {"button": json.dumps(self.button)}).encode()

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_GET(self):
                if self.path != "/":
                    self.send_response(404)
                    self.end_headers()
                    return
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(page)))
                self.end_headers()
                self.wfile.write(page)

            def do_POST(self):
                size = int(self.headers.get("Content-Length", "0"))
                try:
                    hit = json.loads(self.rfile.read(size))
                    outer.hits.append({"x": float(hit["x"]), "y": float(hit["y"]), "inside": bool(hit["inside"]), "time_unix": time.time()})
                except (ValueError, KeyError, TypeError):
                    pass
                self.send_response(204)
                self.end_headers()

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        return f"http://127.0.0.1:{self.server.server_port}/"

    def start(self):
        if not self.key:
            raise RuntimeError("OPENROUTER_API_KEY missing; use secret-env ai --")
        chrome = shutil.which("google-chrome-stable") or shutil.which("chromium")
        if not chrome:
            raise RuntimeError("Chrome executable missing")
        config = self.root / "config" / "leash" / "config.toml"
        config.parent.mkdir(mode=0o700)
        text = f'''[chrome]
binary = "{chrome}"
profile_dir = "{self.root / 'profile'}"
workspace = "test"
headless = true
[models]
planner_model = "{self.args.planner_model}"
planner_reasoning = "{self.args.planner_reasoning}"
[handoff]
focus_command = []
notify_command = []
'''
        config.write_text(text)
        self.save("config.toml", text)
        head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip()
        self.save("identity.json", {"gate": "pic-iomj", "git_head": head, "binary_sha256": hashlib.sha256(self.binary.read_bytes()).hexdigest(), "headless": True, "private_xdg": True, "button_css": self.button, "model_key_source": "secret-env ai --"})
        self.log_stream = self.log.open("w")
        self.service = subprocess.Popen([str(self.binary), "serve", "--config", str(config)], env=self.env, stdout=self.log_stream, stderr=subprocess.STDOUT, start_new_session=True)
        socket = self.root / "runtime" / "leash" / "control.sock"
        end = time.monotonic() + 25
        while not socket.exists():
            if self.service.poll() is not None or time.monotonic() > end:
                raise RuntimeError("Private Leash did not open its control socket")
            time.sleep(0.1)
        time.sleep(5)  # cold private Chrome settles before the first tab (as in L53)
        _, code = self.cli("startup-status", "status")
        if code:
            raise RuntimeError("Private status failed")

    def run(self):
        url = self.serve_page()
        tab_reply, code = self.cli("new", "new", url)
        tab = tab_reply.get("tab")
        if code or not tab:
            raise RuntimeError("New private tab failed")
        self.secrets.append(tab)
        browsers = [b for b in self.browsers() if b["pipe"] and b["main"]]
        self.check(bool(browsers) and all(b["headless"] for b in browsers), "Private Chrome runs headless over the pipe")
        try:
            snap, _ = self.cli("before-snap-with-image", "snap", tab, "--with-image")
            rows = snap.get("rows") or []
            image = snap.get("image") or {}
            actionable = [r for r in rows if str(r.get("role", "")).lower() in ("button", "link", "textbox", "checkbox", "radio", "combobox", "menuitem", "tab")]
            self.check(not actionable, "No DOM action row names the drawn button")
            self.check(bool(image) and abs(image.get("width", 0) / image["viewport"]["width"] - image["scale"]) < 0.01, "Snapshot PNG width equals CSS viewport width times the reported scale")
            alignment = {"image": {k: image.get(k) for k in ("width", "height", "viewport", "scale")}, "button_css": self.button, "button_png": {k: round(v * image.get("scale", 1), 2) for k, v in self.button.items()}, "png": self.keep_png(image.get("path", ""), "before.png")}
            self.save("alignment.json", alignment)
            reply, code = self.cli("drive", "drive", MISSION, "--tab", tab, "--deadline-s", self.args.deadline, "--max-steps", 15, timeout=self.args.deadline + 120)
            turns = reply.get("planner_turns") or []
            answers = [t.get("answer") for t in turns]
            steps = [s for t in turns for s in t.get("steps") or []]
            clicks = [s for s in steps if s.get("command") == "click_at"]
            evidence = []
            for n, step in enumerate(clicks, 1):
                shots = [self.keep_png(s.get("path", ""), f"click-{n}-{i}.png") for i, s in enumerate(step.get("shots") or [])]
                evidence.append({"hits": step.get("hits"), "shots": [{k: s.get(k) for k in ("width", "height", "viewport", "scale")} for s in step.get("shots") or []], "pngs": shots, "error": step.get("error")})
            self.save("pilot-clicks.json", {"answers": answers, "click_at": evidence, "status": reply.get("status"), "result": reply.get("result"), "evidence": reply.get("evidence"), "model_calls": reply.get("model_calls"), "model_cost": reply.get("model_cost"), "pilot_turns": reply.get("pilot_turns"), "navigator_steps": reply.get("navigator_steps")})
            state, _ = self.cli("after-page-state", "eval", tab, "return {state: window.__state, hits: window.__hits}")
            after, _ = self.cli("after-snap-with-image", "snap", tab, "--with-image")
            self.keep_png((after.get("image") or {}).get("path", ""), "after.png")
            self.save("server-hits.json", self.hits)
            page = json.dumps(state)
            inside = [h for h in self.hits if h["inside"]]
            self.check(code == 0 and reply.get("status") == "done", f"Drive ended done (exit {code}, status {reply.get('status')})")
            self.check(len(clicks) >= 1, "The pilot acted with click_at")
            self.check(len(self.hits) == 1 and len(inside) == 1, f"The canvas recorded exactly one click, inside the drawn button ({len(self.hits)} clicks, {len(inside)} inside)")
            self.check('"state": "launched"' in page, "The page's own state is launched")
            self.check(all(not row.get("error") for row in evidence) and all(row["hits"] for row in evidence), "Every click_at retained hit evidence without error")
        finally:
            self.cli("close", "close", tab)

    def cleanup(self):
        if self.service and self.service.poll() is None:
            self.service.terminate()
            try:
                self.service.wait(timeout=25)
            except subprocess.TimeoutExpired:
                os.killpg(self.service.pid, signal.SIGKILL)
                self.service.wait(timeout=10)
        remaining = self.browsers()
        for b in remaining:
            try:
                os.kill(b["pid"], signal.SIGKILL)
            except ProcessLookupError:
                pass
        self.check(not remaining, "No private Chrome process survived the service")
        if self.server:
            self.server.shutdown()
            self.server.server_close()
        if self.log.exists():
            self.save("service.redacted.jsonl", self.log.read_text(errors="replace"))
        self.save("result.json", {"gate": "pic-iomj", "passed": not self.failures, "checks": self.checks, "failures": self.failures, "service_exit": self.service.returncode if self.service else None})
        if self.root.parent == Path(tempfile.gettempdir()).resolve() and self.root.name.startswith("leash-l58-"):
            shutil.rmtree(self.root)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence")
    parser.add_argument("--leash", default=str(REPO / "_build/default/packages/leash/bin/main.exe"))
    parser.add_argument("--deadline", type=int, default=240)
    parser.add_argument("--planner-model", default="openai/gpt-6-luna")
    parser.add_argument("--planner-reasoning", default="max")
    args = parser.parse_args()
    gate = Gate(args)

    def interrupted(signum, frame):
        raise RuntimeError(f"interrupted by signal {signum}")

    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        gate.start()
        gate.run()
    except Exception as error:
        gate.failures.append(type(error).__name__ + ": " + str(error))
    finally:
        gate.cleanup()
    print(json.dumps({"gate": "pic-iomj", "passed": not gate.failures, "failures": gate.failures}), flush=True)
    return 0 if not gate.failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
