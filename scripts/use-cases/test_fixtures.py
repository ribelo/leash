#!/usr/bin/env python3
"""urllib proofs for pilot-7boq: no browser, third-party packages, or Leash needed."""

import hashlib
from html.parser import HTMLParser
from http.cookiejar import CookieJar
import json
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import unittest
from urllib.error import HTTPError
from urllib.parse import urlencode, urlsplit
from urllib.request import build_opener, HTTPCookieProcessor, ProxyHandler, Request


class Links(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.links = []
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            self.links.extend(value for key, value in attrs if key == "href")


def multipart(name, data):
    boundary = "fixture-test-boundary-49182"
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; '
            f'filename="{name}"\r\nContent-Type: application/octet-stream\r\n\r\n').encode()
    return body + data + f"\r\n--{boundary}--\r\n".encode(), {
        "Content-Type": f"multipart/form-data; boundary={boundary}"}


class FixturesTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="leash-fixtures-")
        self.addCleanup(temporary.cleanup)
        self.state_path = Path(temporary.name) / "state.json"
        self.username = "portal-test-user"
        self.password = "portal-private-password-8192"
        environment = dict(os.environ, FIXTURE_USERNAME=self.username,
                           FIXTURE_PASSWORD=self.password)
        self.process = subprocess.Popen(
            [sys.executable, str(Path(__file__).with_name("fixtures.py")), "0", str(self.state_path)],
            env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.addCleanup(self.stop_server)
        ready, _, _ = select.select([self.process.stdout], [], [], 10)
        self.assertTrue(ready, "server did not announce its port within 10 seconds")
        self.base = self.process.stdout.readline().strip()
        self.assertTrue(self.base.startswith("http://127.0.0.1:"), "missing startup URL")
        self.assertGreater(urlsplit(self.base).port, 0)
        self.client = build_opener(ProxyHandler({}), HTTPCookieProcessor(CookieJar()))
        self.assertEqual(self.state()["registrations"], 0)
        self.assertEqual(self.state()["uploads"], [])

    def stop_server(self):
        if self.process.poll() is None:
            self.process.terminate()
        try:
            stdout, stderr = self.process.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
            stdout, stderr = self.process.communicate()
        self.assertEqual(stdout, "", "only the startup URL should be printed")
        self.assertEqual(stderr, "", "server should not log requests or credentials")

    def state(self):
        return json.loads(self.state_path.read_text(encoding="utf-8"))

    def request(self, path, form=None, body=None, headers=None):
        if form is not None:
            body = urlencode(form).encode()
            headers = {"Content-Type": "application/x-www-form-urlencoded"}
        request = Request(self.base + path, data=body, headers=headers or {})
        with self.client.open(request, timeout=5) as response:
            return response.read()

    def text(self, path, **kwargs):
        return self.request(path, **kwargs).decode("utf-8")

    def link(self, text, prefix):
        return next(link for link in Links(text).links if link.startswith(prefix))

    def assert_rejected(self, code, path, **kwargs):
        with self.assertRaises(HTTPError) as caught:
            self.request(path, **kwargs)
        self.assertEqual(caught.exception.code, code)
        caught.exception.close()

    def test_u7_register_mail_confirm(self):
        self.assertIn('name="confirm_password"', self.text("/register"))
        email, password = "operator@example.test", "registration-secret-7139"
        form = {"email": email, "password": password, "confirm_password": password}
        self.assertIn("Check your email", self.text("/register", form=form))
        initial = self.state()
        self.assertEqual(initial["registrations"], 1)
        self.assertFalse(initial["accounts"][0]["confirmed"])
        account = initial["accounts"][0]
        self.assertEqual(set(account), {"email", "confirmed", "password_hash"})
        algorithm, rounds, salt, digest = account["password_hash"].split("$")
        self.assertEqual(algorithm, "pbkdf2_sha256")
        expected = hashlib.pbkdf2_hmac("sha256", password.encode(), bytes.fromhex(salt), int(rounds)).hex()
        self.assertEqual(digest, expected)
        inbox = self.text("/mail")
        self.assertIn(email, inbox)
        message = self.text(self.link(inbox, "/mail/"))
        confirmation = self.link(message, "/confirm?")
        self.assertIn("Email confirmed", self.text(confirmation))
        final = self.state()
        self.assertEqual(final["registrations"], 1)
        self.assertEqual(len(final["accounts"]), 1)
        self.assertTrue(final["accounts"][0]["confirmed"])
        self.assertEqual(final["accounts"][0]["email"], email)
        self.assertEqual(final["mail"][0]["to"], email)
        self.assertNotIn(password, self.state_path.read_text())
        # Opening the same link again is safe, unlike re-submitting registration.
        self.text(confirmation)
        self.assert_rejected(409, "/register", form=form)
        self.assertEqual(self.state(), final)

    def test_u9_one_upload(self):
        self.assertIn('type="file"', self.text("/upload"))
        data = b"fixture upload\r\n\x00\xff\x80binary contents\n"
        body, headers = multipart("report.bin", data)
        receipt = self.text("/upload", body=body, headers=headers)
        link = self.link(receipt, "/files/")
        self.assertEqual(self.request(link), data)
        self.assertEqual(self.state()["uploads"], [{"id": "1", "name": "report.bin",
                         "size": len(data), "sha256": hashlib.sha256(data).hexdigest(), "link": link}])
        # Re-reading the receipt/link must not perform another upload.
        self.text("/upload/1")
        self.request(link)
        self.assertEqual(len(self.state()["uploads"]), 1)

    def test_u10_login_read_unread_message(self):
        login = self.text("/portal")
        self.assertIn('autocomplete="username"', login)
        self.assertNotIn("REF-2048", self.text("/portal/messages/new"))
        self.assertEqual(self.state()["portal"]["opened_messages"], [])
        inbox = self.text("/portal/login", form={"username": self.username, "password": self.password})
        self.assertIn("Unread", inbox)
        self.assertIn("Welcome to your member portal", inbox)
        before = self.state()["portal"]
        self.assertEqual(before["logins"], 1)
        self.assertEqual(before["opened_messages"], [])
        self.assertEqual([m["id"] for m in before["messages"] if not m["read"]], ["new"])
        message = self.text(self.link(inbox, "/portal/messages/new"))
        self.assertIn("Your appointment is confirmed", message)
        self.assertIn("Tuesday at 10:30", message)
        self.assertIn("REF-2048", message)
        after = self.state()["portal"]
        self.assertEqual(after["logins"], 1)
        self.assertEqual(after["opened_messages"], ["new"])
        self.assertTrue(all(m["read"] for m in after["messages"]))
        self.assertIn(after["messages"][0]["body"], message)
        self.assertNotIn("Unread", self.text("/portal/inbox"))
        self.assertNotIn(self.username, self.state_path.read_text())
        self.assertNotIn(self.password, self.state_path.read_text())

    def test_invalid_submissions_do_not_mutate_state(self):
        initial = self.state()
        self.assert_rejected(400, "/register", form={"email": "operator@example.test",
                             "password": "private", "confirm_password": "different"})
        self.assert_rejected(400, "/confirm?token=wrong")
        self.assert_rejected(400, "/upload", body=b"not multipart")
        self.assert_rejected(401, "/portal/login", form={"username": self.username, "password": "wrong"})
        self.assertEqual(self.state(), initial)

    def test_repeated_uploads_are_recorded_not_deduplicated(self):
        body, headers = multipart("same.txt", b"same contents")
        self.text("/upload", body=body, headers=headers)
        self.text("/upload", body=body, headers=headers)
        uploads = self.state()["uploads"]
        self.assertEqual(len(uploads), 2, "independent gate must be able to detect retries")
        self.assertEqual(uploads[0]["sha256"], uploads[1]["sha256"])
        self.assertNotEqual(uploads[0]["link"], uploads[1]["link"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
