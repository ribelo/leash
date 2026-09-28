#!/usr/bin/env python3
"""hard-wk6q (L36): one live check per addition of hardening 2, headless Chrome, loopback pages.

Stories: hard-xg6y hard-ovbx hard-vq5s (net), hard-sr9v (a wait longer than 30 s),
hard-sckn (changed-since), hard-2gnf hard-o3za (file inputs, upload), hard-v1gs (hover),
hard-b20d (eval --index), hard-ufb7 (cookies, storage), hard-b1na (ten agents at once).
"""
import http.server
import json
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time

SOCKET = sys.argv[1]
LEASH = os.environ['LEASH_BIN']
SLOW_SECONDS = 32  # longer than the old 30 s bound on wait

INDEX = '''<!doctype html><title>h2</title>
<style>.wrap{position:relative;display:inline-block}.menu{display:none;position:absolute;left:0;top:100%}.wrap:hover .menu{display:block}</style>
<body>
<h1>Hardening two</h1>
<button onclick="document.getElementById('f').click()">Styled upload</button>
<input type=file id=f multiple style="display:none">
<div class=wrap><button>Hover me</button><div class=menu><a href="#secret">Secret item</a></div></div>
<button onclick="setTimeout(() => document.body.append(' changed'), 1500)">Change soon</button>
<script>
localStorage.setItem('token', 'local-token');
sessionStorage.setItem('draft', 'session-draft');
window.picked = null;
document.getElementById('f').addEventListener('change', e => { window.picked = e.target.files.length; });
fetch('/api/items?n=1').then(r => r.json()).then(j => { window.items = j; });
fetch('/api/save', {method: 'POST', headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({name: 'Ada'})});
</script>
</body>'''
SLOW = '''<!doctype html><title>slow</title><body><p>waiting</p>
<script>setTimeout(() => { document.body.append('SLOW-DONE'); }, %d)</script></body>''' % (SLOW_SECONDS * 1000)


class Page(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split('?')[0]
        if path == '/api/items':
            body, kind = json.dumps({'items': [1, 2, 3], 'name': 'live'}).encode(), 'application/json'
        elif path == '/slow':
            body, kind = SLOW.encode(), 'text/html; charset=utf-8'
        else:
            body, kind = INDEX.encode(), 'text/html; charset=utf-8'
        self.send_response(200)
        self.send_header('Content-Type', kind)
        self.send_header('Content-Length', str(len(body)))
        if path == '/':
            self.send_header('Set-Cookie', 'sid=live-secret; HttpOnly; Path=/')
            self.send_header('Set-Cookie', 'theme=dark; Path=/')
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        self.rfile.read(length)
        body = b'{"saved":true}'
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


def wire(owner, command, timeout=120, **args):
    line = json.dumps({'v': 1, 'owner': owner, 'cmd': command, 'args': args}) + '\n'
    with socket.socket(socket.AF_UNIX) as peer:
        peer.settimeout(timeout)
        peer.connect(SOCKET)
        peer.sendall(line.encode())
        with peer.makefile('r') as stream:
            reply = json.loads(stream.readline())
    return reply


def ok(reply, what):
    assert reply.get('ok'), f"{what}: {reply.get('error')}"
    return reply['result']


def request(command, owner='live-h2', **args):
    return ok(wire(owner, command, **args), command)


def cli(*argv, owner='live-h2', expect_ok=True):
    run = subprocess.run([LEASH, *argv, '--socket', SOCKET, '--owner', owner],
                         capture_output=True, text=True, timeout=120)
    body = json.loads(run.stdout) if run.stdout.strip() else None
    if expect_ok:
        assert run.returncode == 0, f"leash {' '.join(argv)}: {run.returncode} {run.stdout} {run.stderr}"
    return body


def row(snap, role, name):
    return next(r for r in snap['rows'] if r['role'] == role and r['name'] == name)


def eventually(what, probe, seconds=15):
    end = time.time() + seconds
    while time.time() < end:
        value = probe()
        if value:
            return value
        time.sleep(0.2)
    raise AssertionError(f'never happened: {what}')


def section(text):
    print(f'\n== {text}', flush=True)


server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Page)
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    base = f'http://127.0.0.1:{server.server_port}'
    for _ in range(100):
        try:
            request('status')
            break
        except (OSError, TimeoutError):
            time.sleep(0.1)

    tab = request('new', url=base + '/')['tab']
    other = request('new', url=base + '/slow')['tab']
    snap = request('snap', tab=tab)
    sid = snap['snapshot']

    section('hard-2gnf: the hidden file input is a row')
    file_row = next(r for r in snap['rows'] if r['role'] == 'file-input')
    print('file-input row:', json.dumps(file_row))
    assert file_row['index'] > 0
    clicked = cli('click', tab, sid, str(file_row['index']), expect_ok=False)
    assert clicked and clicked['code'] == 'row-not-actionable', clicked
    print('click on it: row-not-actionable')

    section('hard-o3za: upload two files through the CLI')
    with tempfile.TemporaryDirectory() as tmp:
        paths = []
        for name, size in (('one.txt', 11), ('two.bin', 2048)):
            path = os.path.join(tmp, name)
            with open(path, 'wb') as out:
                out.write(b'x' * size)
            paths.append(path)
        result = cli('upload', tab, sid, str(file_row['index']), *paths)
        print('upload:', json.dumps(result))
        seen = request('eval', tab=tab, expression=(
            "return [window.picked, Array.from(document.getElementById('f').files)"
            ".map(f => f.name + ':' + f.size)]"))['value']
        print('the page saw:', seen)
        assert seen == [2, ['one.txt:11', 'two.bin:2048']], seen
        relative = cli('upload', tab, sid, str(file_row['index']), 'relative.txt', expect_ok=False)
        assert relative['code'] == 'invalid-request', relative
        print('a relative path: invalid-request')

    section('hard-v1gs: hover opens the menu')
    hover_row = row(snap, 'button', 'Hover me')
    assert not any(r['name'] == 'Secret item' for r in snap['rows'])
    cli('hover', tab, sid, str(hover_row['index']))
    after = request('snap', tab=tab)
    item = row(after, 'link', 'Secret item')
    print('after the hover the menu item is a row:', json.dumps(item))
    sid2 = after['snapshot']

    section('hard-b20d: eval --index')
    tag = cli('eval', tab, 'return [argument, element.tagName, element.textContent]',
              '--argument', '"arg"', '--snapshot', sid2, '--index', str(row(after, 'button', 'Hover me')['index']))
    print('eval --index:', json.dumps(tag))
    assert tag['value'] == ['arg', 'BUTTON', 'Hover me'], tag

    section('hard-xg6y hard-ovbx hard-vq5s: net, body, request (CLI)')
    listed = eventually('both API calls in the ring',
                        lambda: (lambda r: r if len(r['requests']) >= 2 else None)(
                            cli('net', tab, '--match', '/api/')))
    for entry in listed['requests']:
        print('net:', json.dumps(entry))
    items = next(e for e in listed['requests'] if '/api/items' in e['url'])
    save = next(e for e in listed['requests'] if '/api/save' in e['url'])
    assert items['method'] == 'GET' and items['status'] == 200 and items['type'] == 'fetch', items
    assert items['mime'] == 'application/json' and items['size'] and items['from_cache'] is False, items
    assert save['method'] == 'POST' and save['status'] == 200, save
    only_fetch = cli('net', tab, '--type', 'fetch')['requests']
    assert all(e['type'] == 'fetch' for e in only_fetch) and len(only_fetch) >= 2
    body = cli('net', tab, 'body', items['id'])
    print('body:', json.dumps(body))
    assert json.loads(body['body']) == {'items': [1, 2, 3], 'name': 'live'} and body['base64'] is False, body
    data = cli('net', tab, 'request', save['id'])
    print('request:', json.dumps({k: data[k] for k in ('method', 'url', 'post_data', 'truncated')}))
    assert data['post_data'] == '{"name":"Ada"}', data
    assert data['headers'].get('Content-Type') == 'application/json', data['headers']
    missing = cli('net', tab, 'body', 'no-such-id', expect_ok=False)
    assert missing['code'] == 'unknown-request', missing
    slow_ring = request('net', tab=other)['requests']
    assert not any('/api/' in e['url'] for e in slow_ring), slow_ring
    print('the other tab\'s ring holds', len(slow_ring), 'requests, none of the first tab\'s')
    stranger = wire('somebody-else', 'net', tab=tab)
    assert not stranger['ok'] and stranger['error']['code'] == 'not-owner', stranger

    section('hard-ufb7: cookies and storage (CLI)')
    jar = cli('cookies', tab)['cookies']
    sid_cookie = next(c for c in jar if c['name'] == 'sid')
    print('cookie:', json.dumps(sid_cookie))
    assert sid_cookie['value'] == 'live-secret' and sid_cookie['http_only'] is True
    assert next(c for c in jar if c['name'] == 'theme')['http_only'] is False
    visible = request('eval', tab=tab, expression='return document.cookie')['value']
    assert 'sid=' not in visible and 'theme=dark' in visible, visible
    print('document.cookie (no httpOnly):', visible)
    local = cli('storage', tab, 'local')
    session = cli('storage', tab, 'session')
    print('local:', json.dumps(local), 'session:', json.dumps(session))
    assert local['items'] == {'token': 'local-token'} and session['items'] == {'draft': 'session-draft'}
    assert local['origin'] == base

    section('hard-sckn: wait --changed-since (CLI)')
    fresh = request('snap', tab=tab)
    change = row(fresh, 'button', 'Change soon')
    request('click', tab=tab, snapshot=fresh['snapshot'], index=change['index'])
    started = time.time()
    changed = cli('wait', tab, '--changed-since', fresh['snapshot'], '--timeout-ms', '20000')
    print('changed after %.1f s:' % (time.time() - started), json.dumps(changed))
    assert 1.0 <= time.time() - started < 10
    still = request('snap', tab=tab)
    quiet = cli('wait', tab, '--changed-since', still['snapshot'], '--timeout-ms', '1500', expect_ok=False)
    assert quiet['code'] == 'timeout', quiet
    print('a page that does not change: timeout')

    section('hard-sr9v hard-b1na: ten agents at once, five in a wait longer than 30 s')
    waiters = [request('new', owner=f'agent-{n}', url=base + '/slow')['tab'] for n in range(1, 6)]
    actors = [request('new', owner=f'agent-{n}', url=base + '/')['tab'] for n in range(6, 11)]
    results = {}
    slowest = []
    lock = threading.Lock()

    def waiting(n, handle):
        started = time.time()
        reply = wire(f'agent-{n}', 'wait', timeout=120, tab=handle,
                     until={'text': 'SLOW-DONE'}, timeout_ms=3_600_000)
        results[n] = (reply, time.time() - started)

    def acting(n, handle):
        worst = 0.0
        count = 0
        end = time.time() + 12
        while time.time() < end:
            for command, args in (('snap', {}), ('net', {'limit': 5}), ('cookies', {}),
                                  ('eval', {'expression': 'return 1'})):
                started = time.time()
                ok(wire(f'agent-{n}', command, tab=handle, **args), command)
                worst = max(worst, time.time() - started)
                count += 1
            page = request('snap', owner=f'agent-{n}', tab=handle)
            button = row(page, 'button', 'Hover me')
            started = time.time()
            request('hover', owner=f'agent-{n}', tab=handle, snapshot=page['snapshot'], index=button['index'])
            worst = max(worst, time.time() - started)
            count += 2
        with lock:
            slowest.append((n, count, worst))

    threads = [threading.Thread(target=waiting, args=(n, h)) for n, h in enumerate(waiters, 1)]
    threads += [threading.Thread(target=acting, args=(n, h)) for n, h in enumerate(actors, 6)]
    begin = time.time()
    for thread in threads:
        thread.start()
    for thread in threads[5:]:
        thread.join()
    acted_for = time.time() - begin
    assert all(thread.is_alive() for thread in threads[:5]), 'the waits ended before the actors did'
    print('the five actors finished after %.1f s while five waits were still blocked' % acted_for)
    for n, count, worst in sorted(slowest):
        print(f'  agent-{n}: {count} requests, slowest {worst:.2f} s')
        assert worst < 8, f'agent-{n} was queued: {worst:.2f} s'
    for thread in threads[:5]:
        thread.join()
    for n in range(1, 6):
        reply, elapsed = results[n]
        result = ok(reply, 'wait')
        print(f'  agent-{n}: wait returned after %.1f s' % elapsed)
        assert SLOW_SECONDS - 2 <= elapsed <= SLOW_SECONDS + 15, elapsed
    print('all five long waits returned after more than 30 s')
finally:
    server.shutdown()
print('hardening 2: live checks passed')
