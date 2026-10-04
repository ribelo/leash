# Local action-with-result fixtures

Implements U7, U9 and U10 for pilot story `pilot-7boq` ([use cases](../../docs/use-cases.md), [pilot spec](../../docs/issues/pilot/01-pilot.md)). Python 3 standard library only; no browser, JavaScript, external assets, network services, or package installation.

## Start

From the repository root:

```sh
FIXTURE_USERNAME=fixture-user FIXTURE_PASSWORD=fixture-password \
  python3 scripts/use-cases/fixtures.py 0 /tmp/leash-fixture-state.json
```

The first and only stdout line is the base URL, for example `http://127.0.0.1:43127`. `0` selects a free port; substitute a fixed port if needed. It binds only to `127.0.0.1`. Append `/register`, `/upload`, or `/portal` to that URL. Stop with Ctrl-C. Credentials may instead be supplied with `--username USER --password PASSWORD`; environment variables avoid putting them in process arguments. Supply these portal credentials to the operator/Leash separately, not in the mission. Registration uses its own operator-supplied email and password, unrelated to the portal credentials.

**Each startup resets the specified state file and all app data.** Use a fresh process/state path for each independent acceptance run. The JSON file is created before the startup URL is printed and replaced atomically before each successful action response; read it directly after the mission, without trusting the browser or Leash reply. Concurrent requests are serialized when updating state. Passwords, portal usernames, and session cookies are never recorded in state or request logs. Accounts retain only a salted PBKDF2-SHA256 password hash (`pbkdf2_sha256$100000$SALT_HEX$HASH_HEX`). The mailbox is a deliberately public local stub, not real email. Uploaded bytes live in memory and are downloadable until the process stops; their metadata persists in the JSON state. Requests are limited to 32 MiB including multipart overhead.

## Missions and independent pass checks

Use the missions exactly as written. Set the initial page to the corresponding path and supply the email, password, or local file separately. A complete Leash gate also needs a nonempty `result` and page/link `evidence` matching these independent observations; these fixtures do not run the pilot themselves.

### U7 — registration and confirmation

> Register an account on the fixture site with my email and confirm it from the mailbox

Start at `/register`. Submit email, password and matching confirmation, open `/mail`, open the confirmation message, then follow its confirmation link.

Pass on a fresh run:

- `registrations == 1`, and `accounts` contains exactly one account whose `email` equals the supplied email and `confirmed == true`. Merely submitting the form leaves `confirmed == false`.
- The account has only `email`, `confirmed`, and `password_hash`; the supplied password must not occur anywhere in the JSON.
- `mail` has one message addressed to that email with subject `Confirm your Northstar account` and a `confirmation_link`. The returned account login is the email.

Mismatched/empty passwords are rejected without registration. Re-submitting an existing email is rejected; reopening a valid confirmation link is harmless.

### U9 — upload once and return the link

> Upload <file> to the fixture upload service and tell me the resulting link

Start at `/upload`. Select the supplied file, click Upload once, and read the link on the upload-complete page.

Pass on a fresh run:

- `len(uploads) == 1`. Each accepted POST adds a record, even if the bytes/name are identical: retries must fail the one-upload gate.
- The record contains `id`, `name` (basename), `size` (bytes), `sha256` (hex digest), and `link` (`/files/<id>`). Check name, size and digest against the original local file.
- Resolve `link` against the printed base URL; the pilot result must name that URL, and fetching it must return the original bytes. Reading the receipt or file link adds no upload.

### U10 — login and read the new message

> Is there a new message in my fixture portal inbox, and what does it say

Start at `/portal`. Sign in with the configured credentials. The inbox starts with one **Unread** message (`new`) and one **Read** message (`old`). Open the unread message.

Pass on a fresh run:

- `portal.logins == 1` for the single-login flow; this counts successful logins, not attempts. `portal.opened_messages` contains `new`. For the minimal flow it equals `["new"]`; opening other messages is recorded too, and repeat opens append repeated IDs.
- `portal.messages` contains `new` with `read == true` after opening it; simply listing the inbox never marks it read. `old` starts with `read == true`.
- The pilot result reports subject **Your appointment is confirmed** and the text: **Your appointment is confirmed for Tuesday at 10:30. Please bring your reference number REF-2048.** Compare with `portal.messages` directly.
- No configured username/password is present in the JSON. Anonymous message requests return the login page and do not record an open; incorrect credentials do not increment logins.

On a subsequent mission in the same session, there are no unread messages; the expected answer becomes “no new messages”. Restart to restore the original unread message for another independent run.

## Test

```sh
python3 scripts/use-cases/test_fixtures.py
```

Five stdlib `unittest` cases start isolated server subprocesses on free loopback ports, exercise all three flows through `urllib` and cookie handling, and assert the JSON file. They additionally check rejected actions leave state unchanged, binary downloads match, page refreshes do not repeat uploads, duplicate upload POSTs remain visible, and server stdout/stderr contain no request logs. Temporary state is cleaned up and server processes stopped after each case. No browser or Leash service is launched.
