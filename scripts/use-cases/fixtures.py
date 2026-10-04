#!/usr/bin/env python3
"""Local U7/U9/U10 fixtures for pilot-7boq; Python standard library only."""

import argparse
from email import policy
from email.parser import BytesParser
import hashlib
import hmac
from html import escape
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import secrets
import tempfile
import threading
from urllib.parse import parse_qs, urlsplit


MESSAGES = [
    {"id": "new", "subject": "Your appointment is confirmed",
     "body": "Your appointment is confirmed for Tuesday at 10:30. Please bring your reference number REF-2048.",
     "read": False},
    {"id": "old", "subject": "Welcome to your member portal",
     "body": "Welcome! You can find updates from our team in this inbox.", "read": True},
]
MAX_BODY = 32 * 1024 * 1024


class FixtureServer(ThreadingHTTPServer):
    def __init__(self, port, state_path, username, password):
        super().__init__(("127.0.0.1", port), Handler)
        self.lock = threading.Lock()
        self.state_path = Path(state_path)
        self.username = username
        self.password = password
        self.sessions = set()
        self.tokens = {}
        self.files = {}
        self.state = {"accounts": [], "registrations": 0, "mail": [], "uploads": [],
                      "portal": {"logins": 0, "opened_messages": [],
                                 "messages": [dict(message) for message in MESSAGES]}}
        self.save()

    def save(self):
        """Called while holding the lock (or before serving); readers see whole JSON."""
        self.state_path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8",
                                         dir=self.state_path.parent, delete=False) as output:
            temporary = output.name
            json.dump(self.state, output, indent=2)
            output.write("\n")
        os.replace(temporary, self.state_path)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Suppress request logs entirely: URLs, form values and credentials stay private.
        pass

    def respond(self, content, status=200, content_type="text/html; charset=utf-8"):
        data = content.encode("utf-8") if isinstance(content, str) else content
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def page(self, title, body, status=200):
        self.respond(f'''<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>{escape(title)} | Northstar</title><meta name="viewport" content="width=device-width">
<style>body{{font:18px system-ui,sans-serif;max-width:760px;margin:40px auto;padding:0 24px;color:#172b3a;background:#f7f9fb}}nav{{padding:18px 0;border-bottom:1px solid #ccd5dd}}nav a{{margin-right:20px}}main{{background:white;padding:24px;margin-top:24px;border:1px solid #dbe2e8;border-radius:8px}}label{{display:block;margin-top:16px}}input{{display:block;margin:6px 0;padding:10px;max-width:90%}}button{{margin-top:20px;padding:10px 22px}}li{{margin:18px 0}}a{{color:#154f95}}</style></head>
<body><header><strong>Northstar · Local fixture services</strong><nav aria-label="Main navigation">
<a href="/register">Create account</a><a href="/mail">Mailbox</a>
<a href="/upload">File sharing</a><a href="/portal">Member portal</a></nav></header>
<main><h1>{escape(title)}</h1>{body}</main><footer><p>Local demonstration site. No external services.</p></footer></body></html>''', status)

    def redirect(self, location, cookie=None):
        self.send_response(303)
        self.send_header("Location", location)
        if cookie:
            self.send_header("Set-Cookie", cookie)
        self.send_header("Content-Length", "0")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()

    def authenticated(self):
        cookie = SimpleCookie()
        try:
            cookie.load(self.headers.get("Cookie", ""))
        except Exception:
            return False
        session = cookie.get("fixture_session")
        return session is not None and session.value in self.server.sessions

    def login_page(self, error="", status=200):
        self.page("Sign in to your member portal", f'''
<p>Sign in to view your private messages.</p><p role="alert">{escape(error)}</p>
<form method="post" action="/portal/login">
<label for="username">Username</label><input id="username" name="username" autocomplete="username" required>
<label for="login-password">Password</label><input id="login-password" name="password" type="password" autocomplete="current-password" required>
<button type="submit">Sign in</button></form>''', status)

    def do_GET(self):
        route = urlsplit(self.path)
        path = route.path
        with self.server.lock:
            if path == "/":
                self.page("Welcome to Northstar", "<p>Create an account, share a file, or check your member inbox using the navigation above.</p>")
            elif path == "/register":
                self.page("Create your Northstar account", '''<p>Register to join Northstar. We will send a confirmation email to the fixture mailbox.</p>
<form method="post" action="/register">
<label for="email">Email address</label><input id="email" name="email" type="email" autocomplete="email" required>
<label for="password">Password</label><input id="password" name="password" type="password" autocomplete="new-password" required>
<label for="confirm-password">Confirm password</label><input id="confirm-password" name="confirm_password" type="password" autocomplete="new-password" required>
<button type="submit">Create account</button></form>''')
            elif path == "/register/sent":
                self.page("Check your email", '<p>Your account has been created. Open the confirmation email in your <a href="/mail">fixture mailbox</a> to confirm your email address.</p>')
            elif path == "/mail":
                items = "".join(f'<li><a href="/mail/{m["id"]}">{escape(m["subject"])}</a> — To: {escape(m["to"])}</li>' for m in self.server.state["mail"])
                self.page("Fixture mailbox · Inbox", f"<p>Messages delivered locally by Northstar.</p><ul>{items}</ul>" if items else "<p>Your inbox is empty.</p>")
            elif path.startswith("/mail/"):
                message = next((m for m in self.server.state["mail"] if path == f'/mail/{m["id"]}'), None)
                if message:
                    self.page(message["subject"], f'<p>To: {escape(message["to"])}</p><p>Please confirm your Northstar account.</p><a href="{escape(message["confirmation_link"])}">Confirm email address</a>')
                else:
                    self.page("Message not found", "<p>Return to the mailbox.</p>", 404)
            elif path == "/confirm":
                token = parse_qs(route.query).get("token", [""])[0]
                email = self.server.tokens.get(token)
                if email:
                    account = next(a for a in self.server.state["accounts"] if a["email"] == email)
                    account["confirmed"] = True
                    self.server.save()
                    self.page("Email confirmed", f'<p>Your account is confirmed. Your login is {escape(email)}.</p>')
                else:
                    self.page("Invalid confirmation link", "<p>Please open the link in your confirmation email.</p>", 400)
            elif path == "/upload":
                self.page("Share a file", '''<p>Select a file to upload. After uploading, you will receive a download link.</p>
<form method="post" action="/upload" enctype="multipart/form-data">
<label for="file">Choose file</label><input id="file" name="file" type="file" required>
<button type="submit">Upload</button></form>''')
            elif path.startswith("/upload/"):
                upload = next((u for u in self.server.state["uploads"] if path == f'/upload/{u["id"]}'), None)
                if upload:
                    self.page("Upload complete", f'<p>{escape(upload["name"])} ({upload["size"]} bytes) is ready to share.</p><p>Resulting link: <a href="{upload["link"]}">{upload["link"]}</a></p>')
                else:
                    self.page("Upload not found", "<p>Return to file sharing.</p>", 404)
            elif path.startswith("/files/"):
                data = self.server.files.get(path[len("/files/"):])
                if data is not None:
                    self.respond(data, content_type="application/octet-stream")
                else:
                    self.page("File not found", "<p>That file does not exist.</p>", 404)
            elif path in ("/portal", "/portal/inbox"):
                if not self.authenticated():
                    self.login_page()
                else:
                    items = "".join(f'<li><strong>{"Read" if m["read"] else "Unread"}</strong>: <a href="/portal/messages/{m["id"]}">{escape(m["subject"])}</a></li>' for m in self.server.state["portal"]["messages"])
                    self.page("Member inbox", f"<p>Messages from the Northstar team.</p><ul>{items}</ul>")
            elif path.startswith("/portal/messages/"):
                if not self.authenticated():
                    self.redirect("/portal")
                    return
                portal = self.server.state["portal"]
                message = next((m for m in portal["messages"] if path == f'/portal/messages/{m["id"]}'), None)
                if message:
                    message["read"] = True
                    portal["opened_messages"].append(message["id"])
                    self.server.save()
                    self.page(message["subject"], f'<article><p>{escape(message["body"])}</p></article><a href="/portal/inbox">Back to inbox</a>')
                else:
                    self.page("Message not found", "<p>Return to your inbox.</p>", 404)
            else:
                self.page("Page not found", "<p>Please use the navigation above.</p>", 404)

    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = -1
        if not 0 <= length <= MAX_BODY:
            self.page("Invalid request size", "<p>The request limit is 32 MiB.</p>", 413)
            return
        body = self.rfile.read(length)
        path = urlsplit(self.path).path
        with self.server.lock:
            if path == "/upload":
                content_type = self.headers.get("Content-Type", "")
                message = BytesParser(policy=policy.default).parsebytes(
                    b"Content-Type: " + content_type.encode("utf-8") + b"\r\nMIME-Version: 1.0\r\n\r\n" + body)
                parts = list(message.iter_parts()) if message.get_content_type() == "multipart/form-data" else []
                files = [p for p in parts if p.get_content_disposition() == "form-data" and p.get_param("name", header="content-disposition") == "file" and p.get_filename()]
                if len(files) != 1 or message.defects or files[0].defects:
                    self.page("Choose one file", "<p>Please select exactly one file and try again.</p>", 400)
                    return
                part = files[0]
                name = part.get_filename().replace("\\", "/").rsplit("/", 1)[-1]
                data = part.get_payload(decode=True)
                if not name or data is None:
                    self.page("Invalid file", "<p>Please choose a file.</p>", 400)
                    return
                file_id = str(len(self.server.state["uploads"]) + 1)
                self.server.files[file_id] = data
                self.server.state["uploads"].append({"id": file_id, "name": name, "size": len(data),
                                                     "sha256": hashlib.sha256(data).hexdigest(),
                                                     "link": f"/files/{file_id}"})
                self.server.save()
                self.redirect(f"/upload/{file_id}")
                return
            if path not in ("/register", "/portal/login"):
                self.page("Page not found", "<p>Unknown form.</p>", 404)
                return
            try:
                form = parse_qs(body.decode("utf-8"), keep_blank_values=True)
            except UnicodeDecodeError:
                self.page("Invalid form", "<p>Please submit a valid form.</p>", 400)
                return
            value = lambda key: form.get(key, [""])[0]
            if path == "/register":
                email, password = value("email").strip(), value("password")
                if "@" not in email or not password or password != value("confirm_password"):
                    self.page("Registration incomplete", '<p>Enter an email and matching passwords. <a href="/register">Try again</a>.</p>', 400)
                    return
                if any(a["email"] == email for a in self.server.state["accounts"]):
                    self.page("Account already exists", '<p>Please check the <a href="/mail">mailbox</a> for your confirmation email.</p>', 409)
                    return
                salt = secrets.token_hex(16)
                digest = hashlib.pbkdf2_hmac("sha256", password.encode(), bytes.fromhex(salt), 100000).hex()
                self.server.state["accounts"].append({"email": email, "confirmed": False,
                                                      "password_hash": f"pbkdf2_sha256$100000${salt}${digest}"})
                self.server.state["registrations"] += 1
                token = secrets.token_urlsafe(24)
                self.server.tokens[token] = email
                self.server.state["mail"].append({"id": str(len(self.server.state["mail"]) + 1),
                                                  "to": email, "subject": "Confirm your Northstar account",
                                                  "confirmation_link": f"/confirm?token={token}"})
                self.server.save()
                self.redirect("/register/sent")
            else:
                if not (hmac.compare_digest(value("username").encode(), self.server.username.encode()) and
                        hmac.compare_digest(value("password").encode(), self.server.password.encode())):
                    self.login_page("The username or password is incorrect.", 401)
                    return
                session = secrets.token_urlsafe(24)
                self.server.sessions.add(session)
                self.server.state["portal"]["logins"] += 1
                self.server.save()
                self.redirect("/portal/inbox", f"fixture_session={session}; Path=/portal; HttpOnly; SameSite=Lax")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("port", type=int, help="loopback port; 0 selects a free port")
    parser.add_argument("state", help="JSON state path; reset on startup")
    parser.add_argument("--username", default=os.environ.get("FIXTURE_USERNAME"))
    parser.add_argument("--password", default=os.environ.get("FIXTURE_PASSWORD"))
    args = parser.parse_args()
    if not 0 <= args.port <= 65535:
        parser.error("port must be between 0 and 65535")
    if not args.username or not args.password:
        parser.error("provide --username/--password or FIXTURE_USERNAME/FIXTURE_PASSWORD")
    with FixtureServer(args.port, args.state, args.username, args.password) as server:
        print(f"http://127.0.0.1:{server.server_port}", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
