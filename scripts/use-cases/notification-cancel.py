#!/usr/bin/env python3
"""pilot-9u3q: real notify-send + private D-Bus + Chrome + pilot/trace check.

Run only under dbus-run-session, with Python dbus-next available:
  dbus-run-session --config-file=notification-bus.conf -- python3 notification-cancel.py LEASH_BINARY EVIDENCE_DIR
No operator bus, profile, credentials or model provider is used. The local model
fixture makes exactly one handoff decision (and Done only after resume).
"""
import asyncio
import json
import os
from pathlib import Path
import signal
import sys
import time
from dbus_next import DBusError, NameFlag, RequestNameReply
from dbus_next.aio import MessageBus
from dbus_next.service import ServiceInterface, method, signal as dbus_signal


class Notifications(ServiceInterface):
    def __init__(self):
        super().__init__("org.freedesktop.Notifications")
        self.mode = "dismissed"
        self.events = []
        self.ident = 0

    @method()
    def GetCapabilities(self) -> 'as':
        return ["actions", "body"]

    @method()
    def GetServerInformation(self) -> 'ssss':
        return ["Leash isolated cancellation fixture", "Leash", "1", "1.2"]

    @dbus_signal()
    def NotificationClosed(self, ident: 'u', reason: 'u') -> 'uu':
        return [ident, reason]

    @dbus_signal()
    def ActionInvoked(self, ident: 'u', action: 's') -> 'us':
        return [ident, action]

    @method()
    def CloseNotification(self, ident: 'u'):
        self.NotificationClosed(ident, 3)

    @method()
    def Notify(self, app: 's', replace: 'u', icon: 's', summary: 's',
               body: 's', actions: 'as', hints: 'a{sv}', expire: 'i') -> 'u':
        self.ident += 1
        ident = self.ident
        self.events.append({"id": ident, "summary": summary,
                            "actions": actions, "expire": expire})
        if summary != "Leash needs you":
            return ident
        assert expire == 0, "handoff notification must not expire independently"
        assert actions == ["done", "Done", "cancel", "Cancel"], actions
        if self.mode == "delivery-failure":
            raise DBusError("org.freedesktop.Notifications.Error", "fixture delivery failure")
        mode = self.mode
        def respond():
            if mode in ("cancel", "done"):
                self.ActionInvoked(ident, mode)
            if mode in ("dismissed", "cancel", "done"):
                # Standard reason 2 means dismissed by the user, not expired (1).
                self.NotificationClosed(ident, 2)
        asyncio.get_running_loop().call_later(0.15, respond)
        return ident


async def main():
    binary = str(Path(sys.argv[1]).resolve(strict=True))
    root = Path(sys.argv[2]).resolve()
    root.mkdir(mode=0o700)  # refuse to overwrite an earlier recorded run
    if "/tmp/dbus-" not in os.environ.get("DBUS_SESSION_BUS_ADDRESS", ""):
        raise RuntimeError("Run under dbus-run-session: refusing the operator session bus")
    bus = await MessageBus().connect()
    daemon = Notifications()
    bus.export("/org/freedesktop/Notifications", daemon)
    ownership = await bus.request_name("org.freedesktop.Notifications", NameFlag.DO_NOT_QUEUE)
    assert ownership == RequestNameReply.PRIMARY_OWNER, "refusing an existing daemon"
    calls = 0

    async def http(reader, writer):
        nonlocal calls
        try:
            try:
                header = await reader.readuntil(b"\r\n\r\n")
            except asyncio.IncompleteReadError as error:
                if error.partial:
                    raise
                return
            lines = header.decode().split("\r\n")
            length = next((int(s.split(":", 1)[1]) for s in lines
                           if s.lower().startswith("content-length:")), 0)
            if length:
                await reader.readexactly(length)
            if lines[0].startswith("POST "):
                calls += 1
                answer = {"answer": "handoff", "reason": "operator decision"}
                if calls > 1:
                    assert daemon.mode == "done", "pilot retried after cancellation"
                    answer = {"answer": "done", "result": "Resumed", "evidence": []}
                payload = json.dumps({"id": "fixture", "object": "chat.completion", "created": 0,
                                      "model": "openai/gpt-6-luna",
                                      "choices": [{"index": 0, "finish_reason": "stop",
                                                   "message": {"role": "assistant", "content": json.dumps(answer)}}],
                                      "usage": {"prompt_tokens": 1, "completion_tokens": 1,
                                                "total_tokens": 2, "cost": 0}}).encode()
                content_type = "application/json"
            else:
                payload = b"<!doctype html><title>Cancellation fixture</title><p>Ready</p>"
                content_type = "text/html"
            writer.write((f"HTTP/1.1 200 OK\r\nContent-Type: {content_type}\r\n"
                          f"Content-Length: {len(payload)}\r\nConnection: close\r\n\r\n").encode() + payload)
            await writer.drain()
        finally:
            writer.close()
            await writer.wait_closed()

    server = await asyncio.start_server(http, "127.0.0.1", 0)
    port = server.sockets[0].getsockname()[1]
    env = dict(os.environ)
    env.pop("OPENROUTER_API_KEY", None)
    for key, directory in [("XDG_CONFIG_HOME", "config"), ("XDG_DATA_HOME", "data"),
                           ("XDG_STATE_HOME", "state"), ("XDG_RUNTIME_DIR", "runtime")]:
        path = root / directory
        path.mkdir(mode=0o700)
        env[key] = str(path)
    config_dir = root / "config/leash"
    config_dir.mkdir()
    (config_dir / "config.toml").write_text(
        '[chrome]\nheadless = true\n[models]\napi_key = "local-fixture"\n'
        f'chat_base_url = "http://127.0.0.1:{port}"\n'
        '[handoff]\ntimeout_s = 2\n[learning]\nmode = "off"\n')

    async def cli(*args, timeout=75):
        process = await asyncio.create_subprocess_exec(binary, *args, env=env,
                    stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        try:
            stdout, stderr = await asyncio.wait_for(process.communicate(), timeout)
        except BaseException:
            process.kill()
            await process.wait()
            raise
        return process.returncode, stdout.decode(), stderr.decode()

    log = (root / "service.log").open("wb")
    service = await asyncio.create_subprocess_exec(binary, "serve", env=env,
                stdout=log, stderr=log, start_new_session=True)
    summary = []
    try:
        socket = root / "runtime/leash/control.sock"
        for _ in range(100):
            if service.returncode is not None:
                raise RuntimeError("private service exited; read service.log")
            if socket.exists():
                break
            await asyncio.sleep(0.1)
        else:
            raise RuntimeError("private socket was not ready")
        for mode in ["dismissed", "cancel", "done", "timeout", "delivery-failure"]:
            daemon.mode = mode
            daemon.events = []
            calls = 0
            started = time.monotonic()
            rc, stdout, stderr = await cli("drive", "Ask the operator for a decision, then stop",
                                "--url", f"http://127.0.0.1:{port}/", "--deadline-s", "60")
            (root / f"{mode}-reply.json").write_text(stdout)
            (root / f"{mode}-stderr.json").write_text(stderr)
            assert rc == 0, (mode, rc, stderr)
            reply = json.loads(stdout)
            expected = ("canceled-by-operator" if mode in ("dismissed", "cancel") else
                        "done" if mode == "done" else "handoff-expired")
            assert reply["status"] == expected, (mode, reply)
            event = next(e for e in reply["unattended"] if e["kind"] == "handoff")
            expected_event = ("canceled-by-operator" if expected == "canceled-by-operator" else
                              "resumed" if mode == "done" else "expired")
            assert event["outcome"] == expected_event, event
            assert calls == (2 if mode == "done" else 1), (mode, calls)
            if mode in ("dismissed", "cancel"):
                assert event["elapsed_ms"] < 1500, event
                assert not any(e["kind"] == "notify" for e in reply["unattended"]), reply
                rc2, listing, _ = await cli("list")
                assert rc2 == 0 and any(t["url"].startswith(f"http://127.0.0.1:{port}")
                                       and not t["with_human"] for t in json.loads(listing)["tabs"])
            trace = json.loads(Path(reply["trace_path"]).read_text())
            assert trace["outcome"] == expected, trace
            assert next(e for e in trace["unattended"] if e["kind"] == "handoff")["outcome"] == expected_event
            row = {"mode": mode, "status": reply["status"], "handoff_ms": event["elapsed_ms"],
                   "pilot_calls": calls, "wall_s": round(time.monotonic() - started, 3),
                   "notifications": daemon.events}
            summary.append(row)
            print(json.dumps(row), flush=True)
        (root / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    finally:
        service.terminate()
        try:
            await asyncio.wait_for(service.wait(), 10)
        except asyncio.TimeoutError:
            os.killpg(service.pid, signal.SIGKILL)
            await service.wait()
        log.close()
        server.close()
        await server.wait_closed()
        bus.disconnect()


if __name__ == "__main__":
    asyncio.run(main())
