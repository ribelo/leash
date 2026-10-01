#!/usr/bin/env python3
"""Live-only gate: handles, popups, and one-rule expiry through the real CLI.
Three phases, one service each:

capabilities  two new tabs; list shows both and never a handle; a bad handle is
           unknown-tab; a second process that is given the handle can snap it;
           close is closed_by_handle. The initial chrome://newtab stays human.
popups     an adopted window.open popup (the opening click is answered by the
           popup's own targetCreated despite Chrome withholding the dispatch reply,
           tab-0ohq); a loaded popup that closes itself, reporting closed_externally.
           The opener-holding click can leave late, uncloseable popup debris behind, so
           this phase runs on its own Chrome and SIGTERM reaps it.
expiry     a short idle config with a 1 s sweep. An agent tab closes with
           closed_by_idle. A human tab that was never taken stays open.

Why the newtab target counts as "opened outside Leash": Leash owns the only CDP pipe,
so no second client can create a target; the initial target reaches Leash exactly the
way a human-opened tab does -- announced on the target stream with no openerId and
adopted as human origin (own-c0cl). A page's window.open with 'noopener'
was tried for that route and rejected: Chrome 152 still reports openerId, so Leash
correctly adopts the popup. The two popup shapes split live: the opener-holding open
stalls its navigation while Chrome withholds the dispatch reply (the L10 finding; the
popup's own targetCreated settles the adoption click, tab-0ohq), while the
noopener popup commits at once with healthy sessions, so the closed_externally step
uses it (docs/cdp-shapes.md, L14). Stray tabs -- this machine's
force-installed extension opens its installed page about a minute in -- are ignored:
every assertion filters by URL or handle, never by tab count.

The expiry phase shortens the sweep through LEASH_SWEEP_INTERVAL_S (test-only; the
30 s contract default stands in production). A bad value fails fast before Chrome
launches; the wrapper proves that as phase 0.
"""
import http.server
import json
import subprocess
import sys
import threading
import time

LEASH, ROOT, PHASE = sys.argv[1:]

PAGES = {
    '/m3': """<!doctype html><html><head><title>M3 gate</title></head><body>
      <h1>M3 gate</h1>
      <button id="adopt" onclick="window.open('/popup','w'+Date.now())">Open adopted popup</button>
      <button id="noop" onclick="window.open('/popup','n'+Date.now(),'noopener')">Open fast popup</button>
      </body></html>""",
    '/popup': """<!doctype html><html><head><title>M3 popup</title></head><body>
      <h1>M3 popup</h1>
      <button id="selfclose" onclick="window.close()">Close this popup</button>
      </body></html>""",
}


class PageHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        page = PAGES.get(self.path)
        if page is None:
            self.send_error(404)
            return
        data = page.encode()
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *_args):
        pass


EXITS = {
    'invalid-request': 64, 'usage': 64, 'ambiguous': 66, 'no-match': 66,
    'tab-gone': 66, 'unknown-tab': 66, 'taken': 77, 'with-human': 77, 'timeout': 75,
}


def cli(command, *args, error=None, timeout=60):
    proc = subprocess.run([LEASH, command, *map(str, args)],
                          capture_output=True, text=True, timeout=timeout)
    raw = proc.stdout if proc.returncode == 0 else proc.stderr
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise AssertionError(
            f'{command} did not return JSON: rc={proc.returncode}: '
            f'{proc.stdout!r} {proc.stderr!r}') from exc
    if error:
        expect = EXITS.get(error)
        assert value.get('code') == error and (expect is None or proc.returncode == expect), \
            (command, proc.returncode, value)
    else:
        assert proc.returncode == 0, (command, proc.returncode, value, proc.stderr)
    return value


def every_tab(_who='alice'):
    return cli('list')['tabs']


def find(tabs, handle):
    return next((t for t in tabs if t['tab'] == handle), None)


def row(snapshot, role, name):
    matches = [r for r in snapshot['rows']
               if r['role'] == role and name.lower() in r['name'].lower()]
    assert matches, (role, name, snapshot['rows'])
    return matches[0]['index']


def is_newtab(tab):
    return tab['url'].startswith('chrome://newtab')


def capabilities(local):
    print(f'handles on {local}/m3', flush=True)
    alice_tab = cli('new', local + '/m3', '--label', 'alice')['tab']
    bob_tab = cli('new', local + '/m3', '--label', 'bob')['tab']
    print(f'two handles: {alice_tab[:8]} {bob_tab[:8]}', flush=True)
    cli('snap', alice_tab)
    cli('snap', 't_not_a_tab', error='unknown-tab')
    cli('close', 't_not_a_tab', error='unknown-tab')
    listed = every_tab()
    assert all('tab' not in row and 'handle' not in row for row in listed), listed
    assert any(row.get('label') == 'alice' and row.get('origin') == 'agent' for row in listed)
    assert any(row.get('label') == 'bob' and row.get('origin') == 'agent' for row in listed)
    outside = next(t for t in listed if is_newtab(t))
    assert outside['origin'] == 'human', outside
    assert outside.get('closes_in_s') is None, outside
    print('human newtab stays human and is not closed', flush=True)
    cli('close', alice_tab)
    gone = cli('snap', alice_tab, error='tab-gone')
    assert gone['detail']['disposition'] == 'closed_by_handle', gone
    cli('close', bob_tab)
    print('capabilities phase: done', flush=True)


def popups(local):
    print(f'pages: {local}/m3 (popup opener), {local}/popup (self-closing popup)',
          flush=True)
    opener = cli('new', local + '/m3')['tab']
    opened = cli('snap', opener)
    started = time.monotonic()
    clicked = cli('click', opener, opened['snapshot'],
                  row(opened, 'button', 'adopted'))
    click_s = time.monotonic() - started
    assert clicked['popups'], clicked
    popup = clicked['popups'][0]
    assert popup['origin'] == 'human' and 'tab' not in popup, popup
    popup_handle = cli('take', '--url', popup['url'])['tab']
    assert all('tab' not in row for row in every_tab())
    print(f'adopted popup: click replied in {click_s:.2f}s with {popup_handle[:8]}',
          flush=True)
    cli('close', popup_handle)
    cli('close', opener)

    attempts = 0
    while True:
        attempts += 1
        assert attempts <= 4, 'no loaded popup after 4 attempts'
        attempt_opener = cli('new', local + '/m3')['tab']
        attempt_snap = cli('snap', attempt_opener)
        clicked = cli('click', attempt_opener, attempt_snap['snapshot'],
                      row(attempt_snap, 'button', 'fast'))
        assert clicked['popups'], clicked
        popup = clicked['popups'][0]
        assert popup['origin'] == 'human' and 'tab' not in popup, popup
        popup_handle = cli('take', '--url', popup['url'])['tab']
        loaded = None
        for _ in range(10):
            time.sleep(1)
            snap = cli('snap', popup_handle)
            if snap.get('url') == local + '/popup':
                loaded = snap
                break
        if loaded is None:
            cli('close', popup_handle)
            cli('close', attempt_opener)
            print(f'attempt {attempts}: popup never navigated', flush=True)
            continue
        suicide = subprocess.run(
            [LEASH, 'click', popup_handle, loaded['snapshot'],
             str(row(loaded, 'button', 'Close this popup'))],
            capture_output=True, text=True, timeout=60)
        if suicide.returncode == 0:
            print('self-close click replied before its target died', flush=True)
        else:
            body = json.loads(suicide.stderr)
            assert suicide.returncode == 66 and body.get('code') == 'tab-gone', (
                suicide.returncode, body)
            assert body['detail']['disposition'] == 'closed_externally', body
        time.sleep(3)
        gone = cli('snap', popup_handle, error='tab-gone')
        assert gone['detail']['disposition'] == 'closed_externally', gone
        cli('close', attempt_opener)
        print(f'closed_externally on attempt {attempts}', flush=True)
        break
    print('popups phase: done', flush=True)


def expiry():
    idle_s = 5
    created = cli('new')
    tab = created['tab']
    assert created['origin'] == 'agent', created
    assert created.get('closes_in_s') is not None, created
    assert 0 < created['closes_in_s'] <= idle_s, created
    outside = next(t for t in every_tab() if is_newtab(t))
    assert outside['origin'] == 'human' and outside.get('closes_in_s') is None, outside
    print(f"expiry watches {tab[:8]}; human tab stays", flush=True)
    time.sleep(idle_s + 6)
    gone = cli('snap', tab, error='tab-gone')
    assert gone['detail']['disposition'] == 'closed_by_idle', gone
    survivor = next(t for t in every_tab() if is_newtab(t))
    assert survivor['origin'] == 'human' and survivor.get('closes_in_s') is None, survivor
    print('agent tab closed_by_idle; human tab survives', flush=True)


if PHASE in ('capabilities', 'popups'):
    with http.server.ThreadingHTTPServer(('127.0.0.1', 0), PageHandler) as server:
        threading.Thread(target=server.serve_forever, daemon=True).start()
        run = capabilities if PHASE == 'capabilities' else popups
        run(f'http://127.0.0.1:{server.server_port}')
elif PHASE == 'expiry':
    expiry()
else:
    raise SystemExit(f'unknown phase {PHASE}')
