#!/usr/bin/env python3
"""hard-wo78: three real loopback pages and one headless Chrome profile."""
import http.server
import json
import socket
import sys
import threading
import time

SOCKET = sys.argv[1]
PAGES = {
    '/load': "<title>load</title><script>window.addEventListener('load', () => alert('loaded'))</script>",
    '/late': '''<title>late</title><button onclick="setTimeout(() => alert('late'), 10)">Late alert</button>''',
    '/confirm': '''<title>confirm</title><button onclick="confirm('proceed?')">Confirm</button>''',
}

class Page(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        data = PAGES.get(self.path, '').encode()
        self.send_response(200 if data else 404)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *_):
        pass


def request(command, **args):
    wire = json.dumps({'v': 1, 'cmd': command, 'args': args}) + '\n'
    with socket.socket(socket.AF_UNIX) as peer:
        peer.settimeout(20)
        peer.connect(SOCKET)
        peer.sendall(wire.encode())
        with peer.makefile('r') as stream:
            reply = json.loads(stream.readline())
    if not reply.get('ok'):
        raise AssertionError(f"{command}: {reply.get('code')} {reply.get('message')}")
    return reply['result']


def dialog(result, kind):
    found = result.get('dialog')
    assert found and found['kind'] == kind, f'expected {kind} dialog, got {found}'
    print(f"{kind}: tab={result['tab']} message={found['message']!r}", flush=True)


def click_button(tab, label):
    snap = request('snap', tab=tab)
    row = next(row for row in snap['rows'] if row['role'] == 'button' and row['name'] == label)
    return request('click', tab=tab, snapshot=snap['snapshot'], index=row['index'])

server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Page)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    base = f"http://127.0.0.1:{server.server_port}"
    for _ in range(100):
        try:
            request('status')
            break
        except (OSError, TimeoutError):
            time.sleep(.1)
    opened = request('new', url=base + '/load')
    dialog(opened, 'alert')
    assert opened['title'] == '' or opened['tab'], 'new omitted its handle'
    request('dialog', tab=opened['tab'], answer='accept')
    request('close', tab=opened['tab'])

    late = request('new', url=base + '/late')
    clicked = click_button(late['tab'], 'Late alert')
    dialog(clicked, 'alert')
    request('dialog', tab=late['tab'], answer='accept')
    request('close', tab=late['tab'])

    confirm = request('new', url=base + '/confirm')
    clicked = click_button(confirm['tab'], 'Confirm')
    dialog(clicked, 'confirm')
    request('dialog', tab=confirm['tab'], answer='dismiss')
    request('close', tab=confirm['tab'])
    print('hard-wo78: three local pages passed', flush=True)
finally:
    server.shutdown()
    server.server_close()
