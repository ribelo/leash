#!/usr/bin/env python3
"""Live-only L9 assertions against the real CLI/service/headless Chrome.

Public: Wikipedia search, W3C form grouping. Local: deterministic overlay, clock,
and focus-sensitive button (no stable public counterpart to these timing/occlusion
conditions). The HTTP server only serves the two fixed fixture pages.
"""
import http.server
import json
import pathlib
import subprocess
import sys
import threading
import time

LEASH, ROOT = sys.argv[1:]
SEARCH = 'https://www.wikipedia.org/'
SELECT = 'https://www.w3.org/WAI/tutorials/forms/grouping/'
PAGES = {
    '/overlay': '''<!doctype html><html><head><title>Overlay gate</title><style>
      body { font: 18px sans-serif; }
      #target { position:absolute; top:80px; left:20px; width:180px; height:52px; }
      #cover { position:absolute; top:70px; left:10px; width:200px; height:72px;
               background:#c33; z-index:10; }
      #dismiss { position:absolute; top:80px; left:260px; }
      #focus { position:absolute; top:170px; left:20px; }
      footer { position:absolute; top:2400px; }
      </style></head><body><h1>Overlay gate</h1>
      <button id="target" onclick="document.title='Overlay clicked'">Covered target</button>
      <div id="cover">Opaque overlay</div>
      <button id="dismiss" onclick="document.querySelector('#cover').remove()">Dismiss overlay</button>
      <button id="focus" onclick="document.title=document.hasFocus() && window.framesSeen > 0 ? 'Background focus passed' : 'Background focus failed'">Focus-sensitive action</button>
      <footer><button>Far footer button</button></footer>
      <script>window.framesSeen = 0; function tick() { framesSeen++; requestAnimationFrame(tick) }; requestAnimationFrame(tick)</script>
      </body></html>''',
    '/clock': '''<!doctype html><html><head><title>Clock gate</title></head><body>
      <h1>Live clock</h1><p id="clock">0</p><button>Clock control</button>
      <script>document.body.insertAdjacentHTML('beforeend', '<div aria-hidden="true">' + '<span>pad</span>'.repeat(4000) + '</div>');
      let count=0; setInterval(() => {
        document.getElementById('clock').textContent=String(++count);
      }, 1)</script></body></html>''',
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

def cli(command, *args, error=None):
    proc = subprocess.run([LEASH, command, *map(str,args)],
                          capture_output=True, text=True, timeout=45)
    try: value = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise AssertionError(f'{command} did not return JSON: {proc.returncode}: {proc.stdout} {proc.stderr}') from exc
    if error:
        assert proc.returncode == 1 and value['code'] == error, (command, proc.returncode, value)
    else:
        assert proc.returncode == 0, (command, proc.returncode, value, proc.stderr)
    return value

def row(snapshot, role, name):
    matches = [r for r in snapshot['rows'] if r['role'] == role and name.lower() in r['name'].lower()]
    assert matches, (role, name, snapshot['rows'])
    return matches[0]['index']

def observed(label, snapshot):
    print(f'{label}: {{url:{snapshot["url"]!r}, title:{snapshot["title"]!r}, settled:{snapshot["settled"]}, total:{snapshot["total"]}, rows:{snapshot["rows"][:8]!r}}}', flush=True)

with http.server.ThreadingHTTPServer(('127.0.0.1', 0), PageHandler) as server:
    threading.Thread(target=server.serve_forever, daemon=True).start()
    local = f'http://127.0.0.1:{server.server_port}'
    print(f'pages: public search={SEARCH}; public native select={SELECT}; local overlay, focus, clock={local} (public overlays and mutation timing drift)', flush=True)

    search = cli('new', SEARCH)['tab']
    s = cli('snap', search)
    observed('public search', s)
    field = next((r for r in s['rows'] if r['role'] in ('searchbox','combobox','textbox') and 'search' in r['name'].lower()), None)
    assert field, ('search form absent', s['rows'])
    print('fill:', cli('fill', search, s['snapshot'], field['index'], 'Ada Lovelace'))
    print('press:', cli('press', search, s['snapshot'], 'Enter', '--index', field['index']))
    print('wait search:', cli('wait', search, '--text', 'Ada Lovelace', '--timeout-ms', 12000))
    print('text search:', str(cli('text', search)['text'])[:160])
    print('nav search:', cli('nav', search, SEARCH)['url'])

    dropdown = cli('new', SELECT)['tab']
    first = cli('snap', dropdown)
    observed('public select, before scroll', first)
    assert not any(r['role'] in ('combobox','listbox') and r['name'] == 'Course:' for r in first['rows']), 'offscreen select leaked into viewport'
    for n in range(25):
        snap = cli('snap', dropdown)
        matches = [r for r in snap['rows'] if r['role'] in ('combobox','listbox') and r['name'].strip(': ') == 'Course']
        if matches: break
        cli('scroll', dropdown, 'down')
        time.sleep(.15)
    else:
        diagnosis = cli('eval', dropdown, 'return ({scrollY, height:document.body.scrollHeight, select:document.querySelector("#course")?.getBoundingClientRect().toJSON(), label:document.querySelector("#course")?.labels?.[0]?.textContent})')['value']
        raise AssertionError(f'public labelled select never became visible after scrolling: {diagnosis}; {snap["rows"]}')
    observed('public select, visible', snap)
    print('select:', cli('select', dropdown, snap['snapshot'], matches[0]['index'], 2))
    value = cli('eval', dropdown, 'return document.querySelector("#course")?.value')['value']
    assert value == '8.01.2', value
    print('select value:', value)

    overlay = cli('new', local+'/overlay')['tab']
    snap = cli('snap', overlay)
    observed('local overlay', snap)
    assert all(r['name'] != 'Far footer button' for r in snap['rows']), 'offscreen footer leaked into viewport'
    covered = row(snap, 'button', 'Covered target')
    dismiss = row(snap, 'button', 'Dismiss overlay')
    refusal = cli('click', overlay, snap['snapshot'], covered, error='row-not-actionable')
    print('covered click:', refusal)
    assert cli('eval', overlay, 'return document.title')['value'] == 'Overlay gate', 'covered click landed'
    print('dismiss click:', cli('click', overlay, snap['snapshot'], dismiss))
    snap = cli('snap', overlay)
    print('uncovered click:', cli('click', overlay, snap['snapshot'], row(snap,'button','Covered target')))
    assert cli('eval', overlay, 'return document.title')['value'] == 'Overlay clicked'
    png = pathlib.Path(ROOT, 'overlay.png')
    shot = cli('shot', overlay, png)
    assert shot['bytes'] > 0 and png.read_bytes()[:8] == b'\x89PNG\r\n\x1a\n'
    print('shot:', {'bytes': shot['bytes'], 'png': True})
    # Creating a later tab puts the overlay tab in the background. Its focused
    # event handler only succeeds if focus emulation and animation frames work.
    clock = cli('new', local+'/clock')['tab']
    time.sleep(.2)
    snap = cli('snap', overlay)
    print('background focus:', cli('click', overlay, snap['snapshot'], row(snap,'button','Focus-sensitive action')))
    focus = cli('eval', overlay, 'return ({focused:document.hasFocus(), frames:window.framesSeen, title:document.title})')['value']
    assert focus['focused'] and focus['frames'] > 0 and focus['title'] == 'Background focus passed', focus
    print('background evidence:', focus)
    # A 1-ms live clock makes the two guarded AX/layout pairs disagree; it is
    # still observable and must be marked unsettled rather than rejected.
    for attempt in range(40):
        clock_snap = cli('snap', clock)
        if clock_snap['settled'] is False: break
    else:
        raise AssertionError(f'live clock never returned settled:false across 40 captures: {clock_snap}')
    observed(f'local live clock (capture {attempt + 1})', clock_snap)
    print('wait clock:', cli('wait', clock, '--text', 'Live clock', '--timeout-ms', 5000))
    for tab in [search, dropdown, overlay, clock]: print('close:', cli('close', tab))
