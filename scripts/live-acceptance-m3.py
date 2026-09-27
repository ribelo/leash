#!/usr/bin/env python3
"""Live-only L14 gate: milestone-3 ownership, claim/release, expiry and disposition
through the real CLI/service/headless-Chrome. Three phases, one service each:

ownership  two CLI owners with cross-owner refusals; the outside tab (Chrome's own
           initial chrome://newtab/ target, discovered through Target.setDiscoverTargets
           and never created by Leash); --force release and close.
popups     an adopted window.open popup (the opening click is answered by the
           popup's own targetCreated despite Chrome withholding the dispatch reply,
           tab-0ohq); a loaded popup that closes itself, reporting closed_externally.
           The opener-holding click can leave late, uncloseable popup debris behind, so
           this phase runs on its own Chrome and SIGTERM reaps it.
expiry     a short idle/unclaimed config with a 1 s sweep proving stage 1 (release)
           then stage 2 (closed_by_ttl) on a real clock, while a claimed-then-released
           human tab survives both stages.

Why the newtab target counts as "opened outside Leash": Leash owns the only CDP pipe,
so no second client can create a target; the initial target reaches Leash exactly the
way a human-opened tab does -- announced on the target stream with no openerId and
adopted as human-origin unowned (own-c0cl). A page's window.open with 'noopener'
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


def cli(owner, command, *args, error=None, timeout=60):
    proc = subprocess.run([LEASH, command, '--owner', owner, *map(str, args)],
                          capture_output=True, text=True, timeout=timeout)
    try:
        value = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise AssertionError(
            f'{command} did not return JSON: rc={proc.returncode}: '
            f'{proc.stdout!r} {proc.stderr!r}') from exc
    if error:
        assert proc.returncode == 1 and value.get('code') == error, \
            (command, proc.returncode, value)
    else:
        assert proc.returncode == 0, (command, proc.returncode, value, proc.stderr)
    return value


def every_tab(owner='alice'):
    return cli(owner, 'list', '--all')['tabs']


def find(tabs, handle):
    return next((t for t in tabs if t['tab'] == handle), None)


def row(snapshot, role, name):
    matches = [r for r in snapshot['rows']
               if r['role'] == role and name.lower() in r['name'].lower()]
    assert matches, (role, name, snapshot['rows'])
    return matches[0]['index']


def is_newtab(tab):
    return tab['url'].startswith('chrome://newtab')


def ownership(local):
    print(f'owner tabs on {local}/m3 (popups run in their own phase)', flush=True)

    def mine(tab):
        return tab['url'].startswith(local)

    alice_tab = cli('alice', 'new', local + '/m3')['tab']
    bob_tab = cli('bob', 'new', local + '/m3')['tab']
    print(f'two owners: alice={alice_tab[:8]} bob={bob_tab[:8]}', flush=True)

    cli('bob', 'snap', alice_tab, error='not-owner')
    cli('bob', 'close', alice_tab, error='not-owner')
    cli('bob', 'release', alice_tab, error='not-owner')
    cli('bob', 'claim', alice_tab, error='already-owned')
    cli('alice', 'claim', bob_tab, error='already-owned')
    bob_list = [t['tab'] for t in cli('bob', 'list')['tabs']]
    assert bob_tab in bob_list and alice_tab not in bob_list, bob_list
    scoped = {t['tab']: t for t in every_tab('bob')}
    assert scoped[alice_tab]['owner'] == 'alice', scoped
    assert scoped[alice_tab]['state'] == 'owned', scoped
    print('cross-owner refusals: snap/close/release not-owner, claim already-owned, '
          'list scoped, list --all shows both', flush=True)

    cli('alice', 'release', alice_tab)
    assert cli('bob', 'claim', alice_tab)['owner'] == 'bob'
    cli('bob', 'release', alice_tab)
    assert cli('alice', 'claim', alice_tab)['owner'] == 'alice'
    print('release/claim cycle across owners: ok', flush=True)

    outside = next(t for t in every_tab() if is_newtab(t))
    assert outside['origin'] == 'human', outside
    assert outside['state'] == 'unowned', outside
    assert outside['owner'] is None, outside
    assert outside['expires'] is None, outside
    print(f"outside tab: {outside['tab'][:8]} human/unowned, expires null", flush=True)

    forced_release = cli('alice', 'new', local + '/m3')['tab']
    cli('bob', 'release', forced_release, '--force')
    assert find(every_tab(), forced_release)['state'] == 'unowned'
    forced_close = cli('alice', 'new', local + '/m3')['tab']
    cli('bob', 'close', forced_close, '--force')
    gone = cli('alice', 'snap', forced_close, error='tab-gone')
    assert gone['detail']['disposition'] == 'closed_by_owner', gone
    print("--force: release and close on another owner's tabs ok; force-close is "
          'closed_by_owner', flush=True)

    for t in every_tab():
        if mine(t) or t['url'] == '':
            p = subprocess.run(
                [LEASH, 'close', '--owner', 'alice', t['tab'], '--force'],
                capture_output=True, text=True, timeout=60)
            print(f"cleanup close {t['tab'][:8]} {t['url'][:40]!r} {t['origin']}/"
                  f"{t['state']}/{t['owner']}: rc={p.returncode} {p.stdout.strip()[:120]}",
                  flush=True)
    leftovers = [t for t in every_tab() if mine(t) or t['url'] == '']
    assert not leftovers, leftovers
    print('ownership phase: done', flush=True)


def popups(local):
    print(f'pages: {local}/m3 (popup opener), {local}/popup (self-closing popup)',
          flush=True)

    def mine(tab):
        return tab['url'].startswith(local)

    # The named open keeps its opener, so Chrome withholds the dispatch reply; the
    # popup's own announcement settles the click (tab-0ohq), which is why it answers
    # before the popup's navigation has gone anywhere.
    opener = cli('alice', 'new', local + '/m3')['tab']
    opened = cli('alice', 'snap', opener)
    pre_adopt = {t['tab'] for t in every_tab()}
    started = time.monotonic()
    clicked = cli('alice', 'click', opener, opened['snapshot'],
                  row(opened, 'button', 'adopted'))
    click_s = time.monotonic() - started
    assert clicked['popups'], clicked
    popup = clicked['popups'][0]
    assert popup['origin'] == 'agent', popup
    assert popup['state'] == 'owned' and popup['owner'] == 'alice', popup
    listed = find(every_tab(), popup['tab'])
    assert listed is not None and listed['owner'] == 'alice', listed
    print(f'adopted popup: click replied in {click_s:.2f}s with '
          f"{popup['tab'][:8]} agent/owned/alice", flush=True)
    for t in every_tab():
        if t['tab'] not in pre_adopt and (t['url'] == '' or mine(t)):
            cli('alice', 'close', t['tab'], '--force')

    # A loaded popup that closes itself reports closed_externally (own-teh1). The
    # opener-holding open above hangs its navigation, so this step uses the noopener
    # button: that popup commits at once with healthy sessions on both sides, and
    # Chrome still reports openerId, so it is adopted like any popup. Candidates stay
    # origin-agnostic (a popup Leash cannot attribute is claimed first), and only an
    # exact /popup URL counts as loaded -- a pending popup reports its opener's URL.
    attempts = 0
    while True:
        attempts += 1
        census = [(t['tab'][:8], t['url'][:44], t['origin'], t['state'],
                   t['owner']) for t in every_tab()]
        print(f'closed_externally attempt {attempts}: {len(census)} tabs: {census}',
              flush=True)
        assert attempts <= 4, f'no loaded popup after 4 attempts: {census}'
        attempt_opener = cli('alice', 'new', local + '/m3')['tab']
        attempt_snap = cli('alice', 'snap', attempt_opener)
        known = {t['tab'] for t in every_tab()}
        cli('alice', 'click', attempt_opener, attempt_snap['snapshot'],
            row(attempt_snap, 'button', 'fast'))

        def candidates():
            return [t for t in every_tab()
                    if t['tab'] not in known
                    and (t['url'] == '' or mine(t))]

        loaded = None
        for _ in range(10):
            time.sleep(1)
            loaded = next((t for t in candidates()
                           if t['url'] == local + '/popup'), None)
            if loaded is not None:
                break
        if loaded is None:
            for t in candidates():
                cli('alice', 'close', t['tab'], '--force')
            cli('alice', 'close', attempt_opener)
            print(f'closed_externally attempt {attempts}: popup never navigated, '
                  'retrying with a fresh opener', flush=True)
            continue
        if loaded['state'] == 'unowned':
            assert cli('alice', 'claim', loaded['tab'])['owner'] == 'alice'
        closing = cli('alice', 'snap', loaded['tab'])
        # The click destroys its own target, so either the reply wins the race (ok)
        # or the death does (tab-gone closed_externally); both prove the point.
        suicide = subprocess.run(
            [LEASH, 'click', '--owner', 'alice', loaded['tab'], closing['snapshot'],
             str(row(closing, 'button', 'Close this popup'))],
            capture_output=True, text=True, timeout=60)
        suicide_body = json.loads(suicide.stdout)
        if suicide.returncode == 0:
            print('self-close click replied before its target died', flush=True)
        else:
            assert suicide.returncode == 1 \
                and suicide_body.get('code') == 'tab-gone', \
                (suicide.returncode, suicide_body)
            assert suicide_body['detail']['disposition'] == 'closed_externally', \
                suicide_body
            print('self-close click reported its own tab-gone closed_externally',
                  flush=True)
        time.sleep(3)
        assert find(every_tab(), loaded['tab']) is None, loaded['tab']
        gone = cli('alice', 'snap', loaded['tab'], error='tab-gone')
        assert gone['detail']['disposition'] == 'closed_externally', gone
        for t in candidates():
            cli('alice', 'close', t['tab'], '--force')
        cli('alice', 'close', attempt_opener)
        print(f'closed_externally: loaded popup closed itself on attempt {attempts}; '
              'tab-gone carries closed_externally', flush=True)
        break
    print('popups phase: done (SIGTERM reaps the wedged-process debris)', flush=True)


def expiry():
    idle_s, unclaimed_s = 5, 12
    created = cli('alice', 'new')
    tab = created['tab']
    assert created['url'] == 'about:blank', created
    assert created['expires']['stage'] == 'release', created
    assert 0 < created['expires']['in_s'] <= idle_s, created
    outside = next(t for t in every_tab() if is_newtab(t))
    assert outside['origin'] == 'human' and outside['state'] == 'unowned', outside
    assert outside['expires'] is None, outside
    assert cli('alice', 'claim', outside['tab'])['owner'] == 'alice'
    cli('alice', 'release', outside['tab'])
    released = find(every_tab(), outside['tab'])
    assert released['state'] == 'unowned' and released['expires'] is None, released
    print(f"expiry watches {tab[:8]} (agent/owned) and {outside['tab'][:8]} "
          '(human, claimed then released)', flush=True)
    time.sleep(9)
    stage1 = find(every_tab(), tab)
    assert stage1 is not None and stage1['state'] == 'unowned', stage1
    assert stage1['expires']['stage'] == 'close', stage1
    assert 0 < stage1['expires']['in_s'] <= unclaimed_s, stage1
    assert find(every_tab(), outside['tab']) is not None
    print('stage 1: owned tab released after idle, still open; human tab untouched',
          flush=True)
    time.sleep(13)
    assert find(every_tab(), tab) is None
    gone = cli('alice', 'snap', tab, error='tab-gone')
    assert gone['detail']['disposition'] == 'closed_by_ttl', gone
    survivor = find(every_tab(), outside['tab'])
    assert survivor is not None and survivor['state'] == 'unowned', survivor
    print('stage 2: unowned agent tab closed_by_ttl; human tab claimed then released '
          'survives both stages', flush=True)
    print('expiry phase: done', flush=True)


if PHASE in ('ownership', 'popups'):
    with http.server.ThreadingHTTPServer(('127.0.0.1', 0), PageHandler) as server:
        threading.Thread(target=server.serve_forever, daemon=True).start()
        run = ownership if PHASE == 'ownership' else popups
        run(f'http://127.0.0.1:{server.server_port}')
elif PHASE == 'expiry':
    expiry()
else:
    raise SystemExit(f'unknown phase {PHASE}')
