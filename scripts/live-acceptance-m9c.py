#!/usr/bin/env python3
"""L40 real headless Leash gate (extr-uhnc): collection through drive on books.toscrape.com.

Run only via secret-env ai -- scripts/live-acceptance-m9c (LEASH_M9C_PHASE=test needs no key). The shell owns the isolated
Chrome profile and checks SIGTERM/Chrome cleanup after this script. Ground truth is fetched here, independently of Leash,
straight from the category's pages; nothing is written to the site.
"""
import html
import json
import os
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request

LEASH, ROOT, LOG = sys.argv[1:]
KEY = os.environ.get("OPENROUTER_API_KEY", "")
PHASE = os.environ.get("LEASH_M9C_PHASE", "all")
assert PHASE in ("all", "test", "missions"), "invalid phase"
if PHASE != "test":
    assert KEY, "run under secret-env ai -- scripts/live-acceptance-m9c"
OUTPUTS = []
OWNER = "live-m9c"
SITE = "https://books.toscrape.com"
CATEGORY = SITE + "/catalogue/category/books/mystery_3/index.html"
SHAPE = {"title": str, "price": (int, float), "url": str, "category": str, "rating": int, "availability": str}
LIMIT = 20


def leaked(text):
    return bool(KEY) and KEY in text


def cli(*args, timeout=60, expect=0):
    p = subprocess.run([LEASH, *map(str, args), "--owner", OWNER],
                       text=True, capture_output=True, timeout=timeout)
    OUTPUTS.extend((p.stdout, p.stderr))
    assert not leaked(p.stdout) and not leaked(p.stderr), "API key leaked in CLI output"
    try:
        value = json.loads(p.stdout)
    except json.JSONDecodeError as e:
        raise AssertionError(f"{args[0]} did not return JSON (exit {p.returncode}): {p.stderr[:200]}") from e
    if p.returncode != expect and args[0] == "drive":
        detail = value.get("detail") or {}
        print(f"  drive error {value.get('code')}: {str(value.get('message'))[:200]} detail.code={detail.get('code')}", flush=True)
        for proc in detail.get("procedures", []):
            print(f"  trace {proc.get('slug')}: {proc.get('outcome')} reason={str(proc.get('reason'))[:200]}", flush=True)
            for drive in proc.get("drives", []):
                print(f"    drive {drive.get('status')} reason={str(drive.get('reason'))[:200]}", flush=True)
                for step in drive.get("steps", [])[:14]:
                    print(f"      step {step.get('n')} {step.get('operation')} index={step.get('index')} target={step.get('target')} top={sorted((step.get('probabilities') or {}).get('target', {}).items(), key=lambda kv: -kv[1])[:3]} after={json.dumps(step.get('after'))[:260]}", flush=True)
    assert p.returncode == expect, f"leash {' '.join(map(str, args))[:120]}: exit {p.returncode}, wanted {expect}: {json.dumps(value)[:400]}"
    return value


def truth(category_url=CATEGORY):
    """Every book of the category, read straight from its pages: (title, price, url) per product card."""
    books, url, visited = [], category_url, set()
    while url:
        assert url not in visited, "category pagination cycle"
        visited.add(url)
        with urllib.request.urlopen(url, timeout=30) as response:
            page = response.read().decode("utf-8")
        heading = re.search(r"<h1>([^<]+)</h1>", page)
        assert heading, "missing category heading"
        category = html.unescape(heading.group(1))
        for card in page.split('<article class="product_pod">')[1:]:
            link = re.search(r'<h3><a href="([^"]+)" title="([^"]*)"', card)
            price = re.search(r'class="price_color">[^0-9]*([0-9.]+)<', card)
            rating = re.search(r'star-rating (\w+)', card)
            assert link and price and rating, "unparsed card"
            href = urllib.parse.urljoin(url, html.unescape(link.group(1)))
            availability = re.search(r'class="instock availability">(.*?)</p>', card, re.S)
            assert availability, "missing availability"
            stock = html.unescape(re.sub(r"<[^>]+>", "", availability.group(1))).strip()
            books.append({"title": html.unescape(link.group(2)), "price": float(price.group(1)), "url": href, "rating": ["Zero", "One", "Two", "Three", "Four", "Five"].index(rating.group(1)), "category": category, "availability": stock})
        nxt = re.search(r'<li class="next"><a href="([^"]+)"', page)
        url = urllib.parse.urljoin(url, nxt.group(1)) if nxt else None
    return books, len(visited)


def check_shape(record, category="Mystery"):
    assert set(record) == set(SHAPE), f"fields {sorted(record)}"
    for field, kind in SHAPE.items():
        assert isinstance(record[field], kind) and not isinstance(record[field], bool), f"{field}: {record[field]!r}"
    assert record["url"].startswith(SITE + "/catalogue/") and record["title"] and record["category"] == category
    assert 1 <= record["rating"] <= 5 and record["price"] > 0 and record["availability"] == "In stock", record


def read_jsonl(path):
    with open(path, encoding="utf8") as f:
        return [json.loads(line) for line in f if line.strip()]


def usage_rows(offset):
    counts = {"systemone usage": [], "text helper usage": [], "planner usage": []}
    with open(LOG, encoding="utf8", errors="replace") as f:
        f.seek(offset)
        for line in f:
            assert not leaked(line), "API key leaked into service log"
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("msg") in counts:
                counts[row["msg"]].append(row.get("fields") or {})
    return counts


def mission(name, text, expected, tab_out, category="Mystery"):
    """One paid drive with --out; asserts the count against the independently fetched truth."""
    out = os.path.join(ROOT, tab_out)
    offset = os.path.getsize(LOG)
    tab = cli("new", "about:blank" if os.environ.get("LEASH_M9C_BLANK") == "1" else SITE)["tab"]
    started = time.monotonic()
    try:
        reply = cli("drive", text, "--tab", tab, "--out", out, "--deadline-s", 400, "--max-procedures", int(os.environ.get("LEASH_M9C_MAXPROC", 30)), timeout=440)
    except (AssertionError, subprocess.TimeoutExpired) as error:
        usage = usage_rows(offset)
        print(f"{name}: FAILED after {time.monotonic() - started:.1f}s: {str(error)[:600]}", flush=True)
        print(f"  service log usage rows: JEV={len(usage['systemone usage'])} text={len(usage['text helper usage'])} planner={len(usage['planner usage'])}", flush=True)
        raise
    elapsed = time.monotonic() - started
    evidence = os.environ.get("LEASH_M9C_EVIDENCE")
    if evidence:
        os.makedirs(evidence, mode=0o700, exist_ok=True)
        payload = json.dumps({"mission": text, "elapsed_s": elapsed, "reply": reply}, indent=2)
        assert not leaked(payload), "key in trace"
        with open(os.path.join(evidence, name + ".json"), "w") as f:
            f.write(payload)
    usage = usage_rows(offset)
    data = reply.get("data") or {}
    by_kind = data.get("model_calls_by_kind", {})
    print(f"{name}: mission={text!r} status={reply.get('status')} records={reply.get('collected')} (truth {len(expected)}) elapsed={elapsed:.1f}s", flush=True)
    print(f"  model calls={reply.get('model_calls')} by kind={json.dumps(by_kind)} cost USD={reply.get('model_cost')} "
          f"cost_unreported={data.get('cost_unreported')}; service log rows JEV={len(usage['systemone usage'])} "
          f"text helper={len(usage['text helper usage'])} planner={len(usage['planner usage'])}", flush=True)
    print(f"  pages={data.get('pages')} scripts={json.dumps(data.get('scripts'))} procedures="
          f"{[(p.get('slug'), p.get('outcome')) for p in reply.get('procedures', [])]} final={reply.get('final', {}).get('url')}", flush=True)
    print(f"  playbook choices={json.dumps(reply.get('playbook_choices', []))}", flush=True)
    print(f"  first record={json.dumps((data.get('first') or [None])[0])}", flush=True)
    if reply.get("status") != "done" or os.environ.get("LEASH_M9C_TRACE"):
        for proc in reply.get("procedures", []):
            print(f"  trace {proc.get('slug')}: {proc.get('outcome')} scripts={[(x.get('url', '')[-40:], x.get('records'), x.get('error')) for x in proc.get('scripts', [])]} "
                  f"checks={[(e.get('sentence'), e.get('passed')) for e in proc.get('expectations', [])]} choice={sorted((proc.get('choice', {}).get('probabilities') or {}).items(), key=lambda kv: -kv[1])[:3]} "
                  f"steps={[(st.get('operation'), (st.get('after') or {}).get('url', '')[-22:]) for d in proc.get('drives', []) for st in d.get('steps', [])]}", flush=True)
    assert reply.get("status") == "done", f"{name}: drive ended {reply.get('status')}: {reply.get('reason')}"
    if os.environ.get("LEASH_M9C_BLANK") == "1":
        assert reply.get("site") == "books.toscrape.com", "blank-tab mission did not select playbook"
        assert reply.get("playbook_choices"), "playbook selection trace missing"
    if os.environ.get("LEASH_M9C_REPEAT") == "1":
        assert data.get("pages") == 8, data
        scripts = {s["name"]: s for s in data.get("scripts", [])}
        assert scripts["list-page"]["calls"] == 8
        assert scripts["next-url"]["calls"] == 7
        assert scripts["last-page"]["calls"] == 8
        assert all(scripts[n]["records"] == 0 for n in ("next-url", "last-page", "category-url"))
        assert reply["final"]["url"].endswith("/default_15/page-8.html")
    records = read_jsonl(out)
    assert len(records) == reply["collected"] == data.get("count") == len(expected), \
        f"{name}: JSONL {len(records)}, collected {reply['collected']}, count {data.get('count')}, truth {len(expected)}"
    for record in records:
        check_shape(record, category)
    assert len({r["url"] for r in records}) == len(records), "duplicate records"
    assert {(r["title"], r["price"], r["url"]) for r in records} == {(b["title"], b["price"], b["url"]) for b in expected}, "records differ from the site"
    assert {r["url"]: r for r in records} == {b["url"]: b for b in expected}, "record fields differ from independently fetched site"
    assert len(data.get("first", [])) <= 5
    assert by_kind.get("text_helper", 0) >= 1 or name == "mission A", "the text helper was never asked"
    assert reply.get("model_calls") == sum(by_kind.values()), (reply.get("model_calls"), by_kind)
    # extr-b3u0: the records bypass every model - the model calls do not grow with the record count.
    assert reply["model_calls"] < 40, reply["model_calls"]
    print(f"  {name} OK: {len(records)} records in JSONL match the site; every record passes the shape", flush=True)
    return reply


def main():
    status = cli("status")
    if PHASE != "test":
        assert status.get("models", {}).get("configured"), "model configuration absent"
    print(f"phase {PHASE}; Chrome headless verified by shell", flush=True)
    checked = cli("playbook", "check", "books.toscrape.com")
    assert all(v["ok"] for v in checked["syntax"]), checked["syntax"]
    cases = [("Travel", "travel_2", 1, 1), ("Fiction", "fiction_10", 3, 5), ("Default", "default_15", 8, 60)]
    if os.environ.get("LEASH_M9C_REPEAT") == "1":
        cases = [cases[-1]]
    for category, slug, low, high in cases:
        books, pages = truth(SITE + "/catalogue/category/books/" + slug + "/index.html")
        assert low <= pages <= high, (category, pages)
        print(f"Independent {category}: {len(books)} books on {pages} pages", flush=True)
        if PHASE in ("all", "missions"):
            mission(category, f"collect every book in the {category} category", books, slug + ".jsonl", category)

    with open(LOG, encoding="utf8", errors="replace") as f:
        logged = f.read()
    assert not leaked(logged) and not any(leaked(v) for v in OUTPUTS), "key leaked"
    print(f"API key absent from {len(OUTPUTS)} CLI stdout/stderr and {len(logged)} service-log bytes" if KEY else "no key in this phase", flush=True)
    print(f"L40 live phase {PHASE} complete; shell will SIGTERM Leash and verify Chrome is gone", flush=True)


if __name__ == "__main__":
    main()
