#!/usr/bin/env python3
"""Capture five shop page states using an isolated, verified-headless Leash Chrome.

Run explicitly via nix develop -c python3 .scratch/research/state-measurement/capture.py.
No model credentials, account actions, checkout, or payment are used.
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
CLI = ROOT / "_build/default/packages/leash/bin/main.exe"
OWNER = "state-measurement-l30"


def chrome_cmdlines(profile):
    for proc in Path('/proc').iterdir():
        if not proc.name.isdigit():
            continue
        try:
            argv = (proc / 'cmdline').read_bytes().split(b'\0')
        except (OSError, PermissionError):
            continue
        if any(b'--user-data-dir=' + os.fsencode(profile) in arg for arg in argv):
            yield proc.name, argv


with tempfile.TemporaryDirectory(prefix='leash-l30-') as temp:
    temp = Path(temp)
    runtime = temp / 'runtime'
    runtime.mkdir(mode=0o700)
    profile = temp / 'profile'
    config = temp / 'leash.toml'
    config.write_text(f'''[chrome]
binary = "/etc/profiles/per-user/ribelo/bin/google-chrome-stable"
profile_dir = "{profile}"
workspace = "state-measurement"
headless = true
[tabs]
cap = 8
''')
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime))
    log = (temp / 'service.log').open('w')
    service = subprocess.Popen([str(CLI), 'run', '--config', str(config)], env=env,
                               stdout=log, stderr=subprocess.STDOUT)
    tab = None
    try:
        socket = runtime / 'leash/control.sock'
        for _ in range(120):
            if socket.is_socket():
                break
            if service.poll() is not None:
                raise RuntimeError('Leash service exited before opening control socket')
            time.sleep(.1)
        else:
            raise RuntimeError('Leash service socket did not appear')

        def command(*args):
            proc = subprocess.run([str(CLI), args[0], '--config', str(config),
                                   '--owner', OWNER, *args[1:]], env=env,
                                  capture_output=True, text=True, timeout=45)
            if proc.returncode:
                raise RuntimeError(f'{args[0]} failed ({proc.returncode}): {proc.stdout[:500]} {proc.stderr[:300]}')
            return json.loads(proc.stdout)

        command('status')
        tab = command('new', 'https://automationexercise.com/')['tab']
        running = list(chrome_cmdlines(profile))
        primary = [(pid, argv) for pid, argv in running if b'--remote-debugging-pipe' in b' '.join(argv) and b'--type=renderer' not in b' '.join(argv)]
        assert primary and all(b'--headless=new' in b' '.join(argv) for _, argv in primary), 'Chrome not verified headless'
        print('verified --headless=new Chrome', flush=True)
        time.sleep(2)

        def evaluate(script):
            return command('eval', tab, script)['value']

        def capture(name, kind, expected, recent):
            observed = command('text', tab, '--max-chars', '8000')
            meta = evaluate('return {title:document.title,url:location.href,visibleChars:document.body?.innerText?.length||0}')
            assert observed['text'] and meta['visibleChars'], f'{name} was empty'
            assert meta['url'] == observed['url'], f'{name}: metadata/text navigation mismatch'
            fixture = {'label':name,'site':'automationexercise.com','title':meta['title'],
                       'url':meta['url'],'page_kind':kind,'recent_procedures':recent,
                       'page_text':observed['text'],'page_text_truncated':observed['truncated'],
                       'correct_choice':expected,'visible_chars':meta['visibleChars']}
            (OUT / f'{name}.json').write_text(json.dumps(fixture,ensure_ascii=False,indent=2)+'\n')
            print(name, kind, expected, meta['url'], len(observed['text']), flush=True)

        def snapshot(match, limit=20):
            return command('snap', tab, '--match', match, '--limit', str(limit))

        def accept_consent():
            consent = snapshot('Consent')
            buttons = [r for r in consent['rows'] if r['role']=='button' and r['name']=='Consent']
            if buttons:
                command('press',tab,consent['snapshot'],'Enter','--index',str(buttons[0]['index']))
                print('accepted visible consent dialog',flush=True)
                time.sleep(.3)

        capture('home','home','find-product',[])
        command('nav', tab, 'https://automationexercise.com/products')
        time.sleep(2)
        accept_consent()
        search = snapshot('Search Product')
        field = next(row for row in search['rows'] if row['role']=='textbox')
        command('fill',tab,search['snapshot'],str(field['index']),'Blue Top')
        # Search submit is a visible button adjacent to Search Product, but carries only an icon.
        nearby = command('snap',tab,'--offset',str(field['index']),'--limit','5')
        command('press',tab,nearby['snapshot'],'Enter','--index',str(next(row for row in nearby['rows'] if row['role']=='button')['index']))
        time.sleep(2)
        assert 'SEARCHED PRODUCTS' in command('text',tab,'--max-chars','2000')['text'], 'search did not submit'
        capture('search','search','open-offer',[{'slug':'find-product','outcome':'passed'}])
        links = evaluate("return Array.from(document.querySelectorAll('a[href*=\"/product_details/\"]')).map(a=>a.href).slice(0,4)")
        assert links, 'no product-detail links on actual search results'
        command('nav',tab,links[0])
        time.sleep(2)
        capture('offer','offer','add-to-cart',[{'slug':'find-product','outcome':'passed'},{'slug':'open-offer','outcome':'passed'}])
        accept_consent()
        add = snapshot('Add to cart')
        row = next(row for row in add['rows'] if row['role']=='button')
        command('press',tab,add['snapshot'],'Enter','--index',str(row['index']))
        time.sleep(2)
        modal = evaluate("return Array.from(document.querySelectorAll('.modal.show,.modal.in')).map(e=>e.innerText.slice(0,250))")
        assert any('Added!' in text and 'View Cart' in text for text in modal), 'no successful add modal'
        capture('post-add','post-add','go-to-cart',[{'slug':'find-product','outcome':'passed'},{'slug':'open-offer','outcome':'passed'},{'slug':'add-to-cart','outcome':'passed'}])
        command('nav',tab,'https://automationexercise.com/view_cart')
        time.sleep(2)
        cart_text = command('text',tab,'--max-chars','8000')['text']
        cart_has_product = 'Blue Top' in cart_text and 'Cart is empty!' not in cart_text
        assert cart_has_product, 'Blue Top absent from cart'
        capture('cart','cart','DONE',[{'slug':'find-product','outcome':'passed'},{'slug':'open-offer','outcome':'passed'},{'slug':'add-to-cart','outcome':'passed'},{'slug':'go-to-cart','outcome':'passed'}])
    finally:
        if tab is not None:
            try:
                command('close', tab)
            except Exception as err:
                print('close failed:', err, flush=True)
        service.terminate()  # SIGTERM to Leash itself, not a shell wrapper.
        try:
            service.wait(timeout=15)
        except subprocess.TimeoutExpired:
            service.kill()
            service.wait(timeout=10)
            raise RuntimeError('Leash service did not stop after SIGTERM')
        assert not list(chrome_cmdlines(profile)), 'Chrome child remains after service stopped'
        log.close()
        print('Leash stopped, managed Chrome gone', flush=True)
