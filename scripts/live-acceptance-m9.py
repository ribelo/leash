#!/usr/bin/env python3
"""extr-plaz extr-8o1h extr-vgir extr-mp5z extr-lslp (L37): playbook scripts, headless Chrome, one loopback page.

The page sets a cookie; its endpoint answers 403 without it. The playbook's file script fetches that endpoint
from inside the page — the page's own cookies, no token extracted — and its result is validated against the
script's declared shape. Also: a wrong shape, a throw, a result over its bound, syntax checking in a blank page,
show, and the refusals of the loader (an escaping symlink, a bare file, the old flat layout).
"""
import http.server
import json
import os
import subprocess
import sys
import threading

SOCKET = sys.argv[1]
LEASH = os.environ['LEASH_BIN']
CONFIG = os.environ['XDG_CONFIG_HOME']

PAGE = b'<!doctype html><title>Shelf</title><body><h1>Shelf</h1></body>'
BOOKS = [
    {'title': 'A Light in the Attic', 'price': 51.77, 'href': '/catalogue/a-light'},
    {'title': 'Tipping the Velvet', 'price': 53, 'href': '/catalogue/tipping'},
    {'title': 'Soumission', 'price': 50.1, 'href': '/catalogue/soumission'},
]


class Site(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        path, _, query = self.path.partition('?')
        if path == '/api/books.json':
            if 'sid=live' not in self.headers.get('Cookie', ''):
                self.send_response(403)
                self.end_headers()
                return
            minimum = float(dict(q.split('=') for q in query.split('&') if q).get('min', '0'))
            body, kind = json.dumps([b for b in BOOKS if b['price'] >= minimum]).encode(), 'application/json'
        else:
            body, kind = PAGE, 'text/html; charset=utf-8'
        self.send_response(200)
        self.send_header('Content-Type', kind)
        self.send_header('Content-Length', str(len(body)))
        if path == '/':
            self.send_header('Set-Cookie', 'sid=live; Path=/')
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        f.write(text)


def playbook(name, base, scripts, files=()):
    directory = os.path.join(CONFIG, 'leash', 'playbooks', name)
    write(os.path.join(directory, 'playbook.json'), json.dumps({
        'site': '127.0.0.1', 'entry': base + '/', 'description': 'Live shelf ' + name,
        'pages': [{'name': 'shelf', 'description': 'The shelf', 'url_pattern': base + '/*'}],
        'scripts': scripts,
        'procedures': [{'slug': 'collect', 'description': 'Collect the books', 'args': ['min'],
                        'steps': [{'script': next(iter(scripts)), 'args': {'min': '{min}'}}],
                        'expect': ['the page is shelf']}],
    }, indent=2))
    for path, text in files:
        write(os.path.join(directory, path), text)
    return directory


def cli(*argv, expect=0, service=True):
    flags = ['--socket', SOCKET] if service else []
    run = subprocess.run([LEASH, *argv, *flags], capture_output=True, text=True, timeout=120)
    assert run.returncode == expect, f"leash {' '.join(argv)}: exit {run.returncode}, wanted {expect}: {run.stdout} {run.stderr}"
    return json.loads(run.stdout) if run.stdout.strip() else None


def section(text):
    print(f'\n== {text}', flush=True)


LIST_JS = """const response = await fetch('/api/books.json?min=' + encodeURIComponent(args.min || '0'));
if (!response.ok) throw new Error('books endpoint answered ' + response.status);
const rows = await response.json();
return rows.map(r => ({title: r.title, price: r.price, url: new URL(r.href, location.href).href}));
"""
RETURNS = [{'title': 'string', 'price': 'number', 'url': 'url'}]

server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Site)
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    base = f'http://127.0.0.1:{server.server_port}'
    tab = cli('new', base + '/')['tab']

    playbook('shelf', base, {
        'list': {'file': 'scripts/list.js', 'returns': RETURNS},
        'wrong': {'source': "return [{title: 'x', price: '9', url: 'https://x.example/'}]", 'returns': RETURNS},
        'boom': {'source': "throw new Error('boom from the script')", 'returns': RETURNS},
        'big': {'source': "return [{title: 'x'.repeat(100), price: 1, url: 'https://x.example/'}]",
                'returns': RETURNS, 'max_bytes': 50},
        'flat': {'source': "return () => 1", 'returns': RETURNS},
    }, files=[('scripts/list.js', LIST_JS)])

    section('extr-mp5z extr-vgir: the file script fetches the page own endpoint behind its cookie')
    out = cli('playbook', 'test', 'shelf/list', '--tab', tab, '--arg', 'min=51')
    print(json.dumps(out)[:300])
    assert out['records'] == 2 and [b['title'] for b in out['value']] == ['A Light in the Attic', 'Tipping the Velvet'], out
    assert out['value'][0]['url'] == base + '/catalogue/a-light', out
    out = cli('playbook', 'test', 'shelf/list', '--tab', tab)
    assert out['records'] == 3, out

    section('extr-8o1h: a result that does not fit, a throw, an oversize result, a non-JSON value')
    for script, code, needle in [
        ('wrong', 'script-invalid', '$[0].price: expected number, got string'),
        ('boom', 'script-failed', 'boom from the script'),
        ('big', 'too-large', 'over its bound of 50'),
        ('flat', 'script-invalid', '$: expected an array, got object'),
    ]:
        err = cli('playbook', 'test', 'shelf/' + script, '--tab', tab, expect=1)
        print(script, '->', err['code'], err['message'])
        assert err['code'] == code and needle in err['message'], err
    err = cli('playbook', 'test', 'shelf/absent', '--tab', tab, expect=1)
    assert err['code'] == 'invalid-request', err

    section('extr-lslp: show prints the script, check compiles every script in a blank tab')
    shown = cli('playbook', 'show', 'shelf', service=False)
    assert any('fetch(' in s.get('code', '') for s in shown['scripts']), shown['scripts']
    checked = cli('playbook', 'check', 'shelf')
    assert all(v['ok'] for v in checked['syntax']) and len(checked['syntax']) == 5, checked['syntax']
    tabs = cli('list')['tabs']
    assert len(tabs) == 1, tabs  # the check's blank tab is gone

    playbook('broken', base, {'oops': {'source': 'return [SYNTAX', 'returns': RETURNS}})
    checked = cli('playbook', 'check', 'broken', expect=1)
    print(json.dumps(checked['syntax']))
    assert checked['syntax'][0]['ok'] is False and 'Unexpected token' in checked['syntax'][0]['error'], checked

    section('extr-plaz: the loader refuses what leaves the playbook directory, and the old layouts')
    escape = playbook('escape', base, {'list': {'file': 'scripts/list.js', 'returns': RETURNS}})
    write(os.path.join(CONFIG, 'outside.js'), 'return [];')
    os.makedirs(os.path.join(escape, 'scripts'), exist_ok=True)
    os.symlink(os.path.join(CONFIG, 'outside.js'), os.path.join(escape, 'scripts', 'list.js'))
    run = subprocess.run([LEASH, 'playbook', 'check', escape], capture_output=True, text=True)
    assert run.returncode == 1 and 'outside the playbook directory' in run.stderr, (run.returncode, run.stderr)
    dotdot = playbook('dotdot', base, {'list': {'file': '../outside.js', 'returns': RETURNS}})
    run = subprocess.run([LEASH, 'playbook', 'check', dotdot], capture_output=True, text=True)
    assert run.returncode == 1 and 'must not contain ..' in run.stderr, (run.returncode, run.stderr)
    run = subprocess.run([LEASH, 'playbook', 'check', os.path.join(dotdot, 'playbook.json')], capture_output=True, text=True)
    assert run.returncode == 1 and 'not a single file' in run.stderr, (run.returncode, run.stderr)
    print('refused: symlink out, .. in a path, a bare playbook.json')
finally:
    server.shutdown()
print('extr-plaz extr-8o1h extr-vgir extr-mp5z extr-lslp: live playbook scripts OK')
