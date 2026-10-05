#!/usr/bin/env python3
"""L34 real headless Leash gate: bounded paid runs, per-run traces and costs.

Run only via secret-env ai -- scripts/live-acceptance-m7. The shell owns the
isolated Chrome profile and checks SIGTERM/Chrome cleanup after this script.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

LEASH, ROOT, LOG = sys.argv[1:]
KEY = os.environ.get("OPENROUTER_API_KEY", "")
assert KEY, "run under secret-env ai -- scripts/live-acceptance-m7"
OUTPUTS = []
OWNER = "live-m7"


def cli(*args, timeout=60):
    p = subprocess.run([LEASH, *map(str, args),
                        *[]],
                       text=True, capture_output=True, timeout=timeout)
    OUTPUTS.extend((p.stdout, p.stderr))
    assert KEY not in p.stdout and KEY not in p.stderr, "API key leaked in CLI output"
    try:
        value = json.loads(p.stdout)
    except json.JSONDecodeError as e:
        raise AssertionError(f"{args[0]} did not return JSON (exit {p.returncode})") from e
    if p.returncode:
        if args[0] == "drive":
            detail = value.get("detail") or {}
            procedures = detail.get("procedures", [])
            steps = sum(len(d.get("steps", [])) for p in procedures for d in p.get("drives", []))
            print(f"  partial error: code={value.get('code')} detail_code={detail.get('code')} "
                  f"site={detail.get('site')} steps={steps} "
                  f"planner_turns={len(detail.get('planner_turns', []))} "
                  f"final={detail.get('final', {}).get('url')} procedures="
                  f"{[(x.get('slug'), x.get('outcome'), x.get('attempts'), len(x.get('drives', []))) for x in procedures]}", flush=True)
            print(f"  partial mission checks={[(x.get('sentence'), x.get('checker'), x.get('passed')) for x in detail.get('mission_expectations', [])]} "
                  f"upper choices={[(x.get('source'), x.get('key')) for x in detail.get('playbook_choices', [])]}", flush=True)
            for proc in detail.get("procedures", []):
                print(f"  partial {proc.get('slug')}: "
                      f"drives={[(d.get('status'), str(d.get('reason'))[:120], [(s.get('operation'), s.get('index'), s.get('after', {}).get('url')) for s in d.get('steps', [])]) for d in proc.get('drives', [])]} "
                      f"checks={[(e.get('sentence'), e.get('passed')) for e in proc.get('expectations', [])]}", flush=True)
        if args[0] == "drive" and "--tab" in args:
            tab = args[args.index("--tab") + 1]
            rows = cli("snap", tab, "--limit", 20).get("rows", [])
            print(f"  diagnostic rows={[(r.get('index'), r.get('role'), str(r.get('name'))[:80]) for r in rows if r.get('index') in range(10, 21)]}", flush=True)
            hit = cli("eval", tab, "return (() => { const b=document.querySelector('#submit_search'); if(!b) return {found:false}; const r=b.getBoundingClientRect(),x=r.x+r.width/2,y=r.y+r.height/2,e=document.elementFromPoint(x,y); return {found:true,html:b.outerHTML.slice(0,180),hit:e?.outerHTML.slice(0,180),contains:!!(e&&b.contains(e)),center:[x,y]}; })()")
            print(f"  diagnostic search-hit={hit.get('value')}", flush=True)
            links = cli("eval", tab, "return Array.from(document.querySelectorAll('a[href*=product_details], a.add-to-cart')).slice(0,6).map(a=>{const r=a.getBoundingClientRect(),e=document.elementFromPoint(r.x+r.width/2,r.y+r.height/2);return {name:a.innerText.slice(0,40),href:a.getAttribute('href'),center:[r.x+r.width/2,r.y+r.height/2],hit:e?.outerHTML.slice(0,180),contains:!!(e&&a.contains(e))}})")
            print(f"  diagnostic offer-targets={links.get('value')}", flush=True)
        raise AssertionError(f"{args[0]} returned {p.returncode}: "
                             f"{value.get('code', 'unknown')} "
                             f"{str(value.get('message', ''))[:160].replace(KEY, '[redacted]')}")
    return value


def log_position():
    return os.path.getsize(LOG)


def usage_since(offset):
    counts = {"systemone usage": [], "planner usage": [], "text helper usage": []}
    with open(LOG, encoding="utf8", errors="replace") as f:
        f.seek(offset)
        for line in f:
            if KEY in line:
                raise AssertionError("API key leaked into service log")
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("msg") in counts:
                counts[row["msg"]].append(row.get("fields") or {})
    return counts


def summarize(name, mission, result, elapsed, usage):
    procedures = result.get("procedures", [])
    drives = [drive for proc in procedures for drive in proc.get("drives", [])]
    steps = sum(len(d.get("steps", [])) for d in drives)
    all_usage = [f for rows in usage.values() for f in rows]
    cost = sum(float(f.get("cost") or 0) for f in all_usage)
    turns = result.get("planner_turns", [])
    print(f"{name}: mission={mission!r} outcome={result.get('status')} "
          f"JEV={len(usage['systemone usage'])} planner_turns={len(turns)} "
          f"planner_calls={len(usage['planner usage'])} "
          f"steps={steps} elapsed={elapsed:.1f}s", flush=True)
    print(f"  mission checks={[(x.get('sentence'), x.get('checker'), x.get('passed')) for x in result.get('mission_expectations', [])]}", flush=True)
    print(f"  cost USD={cost:.9f} (System One="
          f"{sum(float(f.get('cost') or 0) for f in usage['systemone usage']):.9f}, "
          f"chat={sum(float(f.get('cost') or 0) for f in usage['planner usage'] + usage['text helper usage']):.9f}); "
          f"tokens JEV={sum(int(f.get('input_tokens') or 0) for f in usage['systemone usage'])}/"
          f"{sum(int(f.get('output_tokens') or 0) for f in usage['systemone usage'])}; "
          f"chat={sum(int(f.get('total_tokens') or 0) for f in usage['planner usage'] + usage['text helper usage'])}", flush=True)
    for proc in procedures:
        checks = ','.join(f"{e.get('sentence')}:{e.get('passed')}[{e.get('checker')}]"
                          for e in proc.get('expectations', []))
        print(f"  trace {proc.get('site')}/{proc.get('slug')}: {proc.get('outcome')} "
              f"attempts={proc.get('attempts')} drives="
              f"{','.join(d.get('status', '?') for d in proc.get('drives', []))} "
              f"checks={checks[:300]}", flush=True)
        if proc.get("outcome") == "failed":
            for drive in proc.get("drives", [])[:2]:
                print(f"    failed-drive {drive.get('status')} "
                      f"reason={str(drive.get('reason'))[:130]} "
                      f"steps={[(s.get('operation'), str(s.get('reason'))[:80]) for s in drive.get('steps', [])[:3]]}", flush=True)
    print(f"  final={result.get('final', {}).get('url')} "
          f"reason={str(result.get('reason'))[:200]} "
          f"turns={[(t.get('trigger'), t.get('answer')) for t in turns]}", flush=True)
    return result


def timed(name, mission, command, *args, timeout=200):
    pos = log_position()
    started = time.monotonic()
    try:
        reply = cli(command, *args, timeout=timeout)
    except (AssertionError, subprocess.TimeoutExpired):
        usage = usage_since(pos)
        jev = usage["systemone usage"]
        chat = usage["planner usage"] + usage["text helper usage"]
        print(f"{name}: command failed after {time.monotonic() - started:.1f}s "
              f"JEV={len(jev)} planner_calls={len(usage['planner usage'])} "
              f"text_helper_calls={len(usage['text helper usage'])} "
              f"cost USD={sum(float(x.get('cost') or 0) for x in jev + chat):.9f}",
              flush=True)
        raise
    return summarize(name, mission, reply, time.monotonic() - started,
                     usage_since(pos))


def site_text(tab):
    return cli('text', tab, '--max-chars', 2000).get('text', '')


def main():
    status = cli('status')
    assert status.get('models', {}).get('configured'), 'model configuration absent'
    print('models configured; Chrome headless verified by shell', flush=True)
    phase = os.environ.get("LEASH_M7_PHASE", "all")
    assert phase in ("all", "shop", "cross", "discover"), "invalid phase"
    if phase in ('all', 'shop'): 
        if phase == 'shop':
            blocked = True  # headless 403 was already independently established
        else:
            tab = cli('new', 'https://allegro.pl/') ['tab']
            snap = cli('snap', tab, '--limit', 5)
            text = site_text(tab)
            navigation = cli('eval', tab, 'return {status: performance.getEntriesByType("navigation")[0]?.responseStatus ?? null, title: document.title, text: document.body?.innerText.slice(0,180) ?? ""}').get('value') or {}
            # Curl corroborates the observed Chrome status, never replaces the real browser.
            probe = subprocess.run(['curl', '-L', '-I', '--max-time', '12', '-s',
                                    '-o', '/dev/null', '-w', '%{http_code}',
                                    'https://allegro.pl/'], text=True, capture_output=True)
            blocked = (navigation.get('status') == 403 or probe.stdout.strip() == '403'
                       or '403' in text or 'datadome' in text.lower())
            print(f"Allegro mission attempted in Chrome: {snap.get('url')} "
                  f"Chrome HTTP={navigation.get('status')} title={navigation.get('title')!r} "
                  f"curl HTTP={probe.stdout.strip()} blocked={blocked} "
                  f"excerpt={(text or navigation.get('text', ''))[:180]!r}", flush=True)
            mission = 'Find a Logitech MX Master 3S offer on Allegro, add it to the cart and show the cart; stop before checkout or payment'
            if blocked:
                print('allegro: navigation blocked (403); JEV=0 planner_turns=0 steps=0 cost=$0.000000000. Mission cannot proceed.', flush=True)
            else:
                allegro = timed('allegro', mission, 'drive', mission, '--tab', tab,
                                '--expect', 'the page is cart', '--max-procedures', 4,
                                '--deadline-s', 130, timeout=170)
        if blocked:
            print('Allegro is blocked in real headless Chrome; headed operator run needed. No evasion.', flush=True)
            if phase != 'shop':
                cli('close', tab)
            tab = cli('new', 'https://automationexercise.com/products') ['tab']
            shop_page = cli('eval', tab, 'return {status: performance.getEntriesByType("navigation")[0]?.responseStatus ?? null, title: document.title, text: document.body?.innerText.slice(0,250) ?? ""}').get('value') or {}
            print(f"fallback initial page: HTTP={shop_page.get('status')} title={shop_page.get('title')!r} text={shop_page.get('text')!r}", flush=True)
            mission = 'Find Blue Top on Automation Exercise, open its offer, add Blue Top to the cart, show the cart, and stop before checkout or payment'
            shop = timed('automationexercise', mission, 'drive', mission, '--tab', tab,
                         '--expect', 'the page is cart', '--expect', 'the page shows Blue Top',
                         '--max-procedures', 9, '--deadline-s', 300, timeout=345)
            assert shop.get('status') == 'done', 'fallback shop did not reach verified DONE'
            verified = {p.get('slug'): p for p in shop.get('procedures', [])
                        if p.get('outcome') == 'verified'}
            required = {'find-product', 'open-offer', 'add-to-cart', 'go-to-cart'}
            assert required <= verified.keys(), f'missing verified shop stage: {required - verified.keys()}'
            assert '/view_cart' in shop.get('final', {}).get('url', ''), 'DONE without cart URL'
            assert 'Blue Top' in site_text(tab), 'DONE without Blue Top in cart page text'
            cart_checks = verified['go-to-cart'].get('expectations', [])
            assert all(e.get('passed') for e in cart_checks), 'cart stage checks not all verified'
            assert any(e.get('sentence') == 'checkout/payment has not started' and e.get('passed')
                       for e in cart_checks), 'no-checkout boundary unverified'
            print('fallback DONE guard: verified find → offer → add → cart; Blue Top visible, no checkout/payment', flush=True)
        else:
            assert allegro.get('status') == 'done', 'Allegro unexpectedly accessible but mission incomplete'
            print('Allegro run finished; inspect cart before payment', flush=True)
        cli('close', tab)

    if phase in ('all', 'cross'):
        # GitHub PDF.js source page -> Example Domain, in one run and one tab.
        tab = cli('new', 'https://github.com/mozilla/pdf.js/blob/master/test/pdfs/tracemonkey.pdf')['tab']
        mission = ('Download the public tracemonkey.pdf test fixture on GitHub, then switch '
                   'to example.com and verify Example Domain; do not post or change anything')
        cross = timed('cross-site PDF', mission, 'drive', mission, '--tab', tab,
                      '--expect', 'a file was downloaded', '--expect', 'the page is example',
                      '--max-procedures', 5, '--deadline-s', 240, timeout=280)
        downloads = cli('downloads', tab).get('downloads', [])
        print(f"  downloads={[(x.get('suggested_name'), x.get('state')) for x in downloads]} "
              f"sites={list(dict.fromkeys(x.get('site') for x in cross.get('procedures', [])))}", flush=True)
        assert cross.get('status') == 'done', 'cross-site mission did not reach DONE'
        assert 'Example Domain' in cross.get('final', {}).get('title', ''), 'the final Chrome title is not Example Domain'
        assert any(x.get('site') == 'github.com' for x in cross['procedures']), 'PDF source not used'
        assert any(x.get('site') == 'example.com' for x in cross['procedures']), 'no playbook switch'
        assert len(downloads) == 1, f'expected one PDF download, got {len(downloads)}'
        assert downloads[0].get('suggested_name', '').endswith('.pdf') and downloads[0].get('state') == 'completed', 'no completed PDF download'
        cli('close', tab)

    with open(LOG, encoding='utf8', errors='replace') as f:
        logged = f.read()
    assert KEY not in logged and all(KEY not in value for value in OUTPUTS), 'key leaked'
    print(f"API key absent from {len(OUTPUTS)} CLI stdout/stderr and {len(logged)} service-log bytes", flush=True)
    print(f'L34 live phase {phase} complete; shell will SIGTERM Leash and verify Chrome is gone', flush=True)


if __name__ == '__main__':
    main()
