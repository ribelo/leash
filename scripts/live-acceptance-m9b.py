#!/usr/bin/env python3
"""L39 real headless Leash gate (extr-tkco extr-oaci extr-8ubt): collection through drive on books.toscrape.com.

Run only via secret-env ai -- scripts/live-acceptance-m9b (LEASH_M9B_PHASE=test needs no key). The shell owns the isolated
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
PHASE = os.environ.get("LEASH_M9B_PHASE", "all")
assert PHASE in ("all", "test", "missions"), "invalid phase"
if PHASE != "test":
    assert KEY, "run under secret-env ai -- scripts/live-acceptance-m9b"
OUTPUTS = []
OWNER = "live-m9b"
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


def truth():
    """Every book of the category, read straight from its pages: (title, price, url) per product card."""
    books, url = [], CATEGORY
    while url:
        with urllib.request.urlopen(url, timeout=30) as response:
            page = response.read().decode("utf-8")
        for card in page.split('<article class="product_pod">')[1:]:
            link = re.search(r'<h3><a href="([^"]+)" title="([^"]*)"', card)
            price = re.search(r'class="price_color">[^0-9]*([0-9.]+)<', card)
            rating = re.search(r'star-rating (\w+)', card)
            assert link and price and rating, "unparsed card"
            href = urllib.parse.urljoin(url, html.unescape(link.group(1)))
            books.append({"title": html.unescape(link.group(2)), "price": float(price.group(1)), "url": href, "rating": rating.group(1)})
        nxt = re.search(r'<li class="next"><a href="([^"]+)"', page)
        url = urllib.parse.urljoin(url, nxt.group(1)) if nxt else None
    return books


def check_shape(record):
    assert set(record) == set(SHAPE), f"fields {sorted(record)}"
    for field, kind in SHAPE.items():
        assert isinstance(record[field], kind) and not isinstance(record[field], bool), f"{field}: {record[field]!r}"
    assert record["url"].startswith(SITE + "/catalogue/") and record["title"] and record["category"] == "Mystery"
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


def mission(name, text, expected, tab_out):
    """One paid drive with --out; asserts the count against the independently fetched truth."""
    out = os.path.join(ROOT, tab_out)
    offset = os.path.getsize(LOG)
    started = time.monotonic()
    try:
        reply = cli("drive", text, "--out", out, "--deadline-s", 400, "--max-procedures", int(os.environ.get("LEASH_M9B_MAXPROC", 30)), timeout=440)
    except (AssertionError, subprocess.TimeoutExpired) as error:
        usage = usage_rows(offset)
        print(f"{name}: FAILED after {time.monotonic() - started:.1f}s: {str(error)[:600]}", flush=True)
        print(f"  service log usage rows: JEV={len(usage['systemone usage'])} text={len(usage['text helper usage'])} planner={len(usage['planner usage'])}", flush=True)
        raise
    elapsed = time.monotonic() - started
    usage = usage_rows(offset)
    data = reply.get("data") or {}
    by_kind = data.get("model_calls_by_kind", {})
    print(f"{name}: mission={text!r} status={reply.get('status')} records={reply.get('collected')} (truth {len(expected)}) elapsed={elapsed:.1f}s", flush=True)
    print(f"  model calls={reply.get('model_calls')} by kind={json.dumps(by_kind)} cost USD={reply.get('model_cost')} "
          f"cost_unreported={data.get('cost_unreported')}; service log rows JEV={len(usage['systemone usage'])} "
          f"text helper={len(usage['text helper usage'])} planner={len(usage['planner usage'])}", flush=True)
    print(f"  pages={data.get('pages')} scripts={json.dumps(data.get('scripts'))} procedures="
          f"{[(p.get('slug'), p.get('outcome')) for p in reply.get('procedures', [])]} final={reply.get('final', {}).get('url')}", flush=True)
    print(f"  first record={json.dumps((data.get('first') or [None])[0])}", flush=True)
    if reply.get("status") != "done" or os.environ.get("LEASH_M9B_TRACE"):
        for proc in reply.get("procedures", []):
            print(f"  trace {proc.get('slug')}: {proc.get('outcome')} scripts={[(x.get('url', '')[-40:], x.get('records'), x.get('error')) for x in proc.get('scripts', [])]} "
                  f"checks={[(e.get('sentence'), e.get('passed')) for e in proc.get('expectations', [])]} choice={sorted((proc.get('choice', {}).get('probabilities') or {}).items(), key=lambda kv: -kv[1])[:3]} "
                  f"steps={[(st.get('operation'), (st.get('after') or {}).get('url', '')[-22:]) for d in proc.get('drives', []) for st in d.get('steps', [])]}", flush=True)
    assert reply.get("status") == "done", f"{name}: drive ended {reply.get('status')}: {reply.get('reason')}"
    records = read_jsonl(out)
    assert len(records) == reply["collected"] == data.get("count") == len(expected), \
        f"{name}: JSONL {len(records)}, collected {reply['collected']}, count {data.get('count')}, truth {len(expected)}"
    for record in records:
        check_shape(record)
    assert len({r["url"] for r in records}) == len(records), "duplicate records"
    assert {(r["title"], r["price"], r["url"]) for r in records} == {(b["title"], b["price"], b["url"]) for b in expected}, "records differ from the site"
    assert {r["title"]: r["rating"] for r in records} == {b["title"]: ["Zero", "One", "Two", "Three", "Four", "Five"].index(b["rating"]) for b in expected}
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
    books = truth()
    cheap = [b for b in books if b["price"] < LIMIT]
    print(f"independent truth from the category pages: {len(books)} books, {len(cheap)} under GBP {LIMIT}", flush=True)
    assert len(books) > 20 and 0 < len(cheap) < len(books), "the site changed shape"

    if PHASE in ("all", "test"):
        checked = cli("playbook", "check", "books.toscrape.com")
        assert all(v["ok"] for v in checked["syntax"]) and len(checked["syntax"]) == 2, checked["syntax"]
        print("playbook check: both scripts compile in a blank tab", flush=True)
        tab = cli("new", CATEGORY)["tab"]
        listed = cli("playbook", "test", "books.toscrape.com/list-page", "--tab", tab)
        assert listed["records"] == 20, listed
        for record in listed["value"]:
            check_shape(record)
        print(f"playbook test list-page: {listed['records']} records in {listed['elapsed_ms']} ms, first={json.dumps(listed['value'][0])}", flush=True)
        under = cli("playbook", "test", "books.toscrape.com/list-page", "--tab", tab, "--arg", f"max_price={LIMIT}")
        assert under["records"] == len([b for b in books[:20] if b["price"] < LIMIT]) and all(r["price"] < LIMIT for r in under["value"]), under
        crawl = cli("playbook", "test", "books.toscrape.com/crawl-category", "--tab", tab, timeout=120)
        assert crawl["records"] == len(books), (crawl["records"], len(books))  # the fetch-based script, all pages in one call
        assert {(r["title"], r["price"]) for r in crawl["value"]} == {(b["title"], b["price"]) for b in books}
        print(f"playbook test crawl-category (fetch): {crawl['records']} records in {crawl['elapsed_ms']} ms; matches the site", flush=True)
        cli("close", tab)

    if PHASE in ("all", "missions"):
        a = mission("mission A", "collect every book title and price in the Mystery category", books, "mystery.jsonl")
        b = mission("mission B", f"collect Mystery books cheaper than \u00a3{LIMIT}", cheap, "mystery-cheap.jsonl")
        assert any(p.get("slug", "").startswith("collect-category") for p in a["procedures"])
        assert any(p.get("slug") == "collect-category-under" for p in b["procedures"]), "the filtered procedure did not run"
        assert all(r["price"] < LIMIT for r in read_jsonl(os.path.join(ROOT, "mystery-cheap.jsonl")))
        for tab in cli("list").get("tabs", []):
            cli("close", tab["tab"])

    with open(LOG, encoding="utf8", errors="replace") as f:
        logged = f.read()
    assert not leaked(logged) and not any(leaked(v) for v in OUTPUTS), "key leaked"
    print(f"API key absent from {len(OUTPUTS)} CLI stdout/stderr and {len(logged)} service-log bytes" if KEY else "no key in this phase", flush=True)
    print(f"L39 live phase {PHASE} complete; shell will SIGTERM Leash and verify Chrome is gone", flush=True)


if __name__ == "__main__":
    main()
