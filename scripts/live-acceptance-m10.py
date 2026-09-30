#!/usr/bin/env python3
"""L46 live gate (pbk-eyya): JEV drives books.toscrape.com and can choose a script.

Run only via secret-env ai -- scripts/live-acceptance-m10. Ground truth is fetched here,
independently of Leash. Nothing is written to the site. The key is never printed.
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
assert KEY, "run under secret-env ai -- scripts/live-acceptance-m10"
OWNER = "live-m10"
SITE = "https://books.toscrape.com"
SHAPE = {"title": str, "price": (int, float), "url": str, "category": str, "rating": int, "availability": str}
CATEGORIES = {
    "Travel": SITE + "/catalogue/category/books/travel_2/index.html",
    "Mystery": SITE + "/catalogue/category/books/mystery_3/index.html",
    "Default": SITE + "/catalogue/category/books/default_15/index.html",
}
EVIDENCE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs/issues/playbook-scripts/acceptance")


def leaked(text):
    return bool(KEY) and KEY in text


def cli(*args, timeout=60):
    proc = subprocess.run([LEASH, *map(str, args), "--owner", OWNER], text=True, capture_output=True, timeout=timeout)
    assert not leaked(proc.stdout) and not leaked(proc.stderr), "API key leaked in CLI output"
    try:
        value = json.loads(proc.stdout)
    except json.JSONDecodeError as error:
        raise AssertionError(f"{args[0]} did not return JSON (exit {proc.returncode}): {proc.stderr[:300]}") from error
    if proc.returncode != 0:
        raise AssertionError(f"leash {args[0]} exit {proc.returncode}: {json.dumps(value)[:500]}")
    return value


def truth(url, one_page=False):
    books, pages, seen = [], 0, set()
    while url:
        assert url not in seen, "pagination cycle"
        seen.add(url)
        pages += 1
        with urllib.request.urlopen(url, timeout=30) as response:
            page = response.read().decode("utf-8")
        heading = re.search(r"<h1>([^<]+)</h1>", page)
        assert heading, "missing category heading"
        category = html.unescape(heading.group(1))
        for card in page.split('<article class="product_pod">')[1:]:
            link = re.search(r'<h3><a href="([^"]+)" title="([^"]*)"', card)
            price = re.search(r'class="price_color">[^0-9]*([0-9.]+)<', card)
            rating = re.search(r"star-rating (\w+)", card)
            availability = re.search(r'class="instock availability">(.*?)</p>', card, re.S)
            assert link and price and rating and availability, "unparsed card"
            stock = html.unescape(re.sub(r"<[^>]+>", "", availability.group(1))).strip()
            books.append({
                "title": html.unescape(link.group(2)),
                "price": float(price.group(1)),
                "url": urllib.parse.urljoin(url, html.unescape(link.group(1))),
                "rating": ["Zero", "One", "Two", "Three", "Four", "Five"].index(rating.group(1)),
                "category": category,
                "availability": stock,
            })
        nxt = re.search(r'<li class="next"><a href="([^"]+)"', page)
        url = None if one_page or not nxt else urllib.parse.urljoin(url, nxt.group(1))
    return books, pages


def check_shape(record, category):
    assert set(record) == set(SHAPE), sorted(record)
    for field, kind in SHAPE.items():
        assert isinstance(record[field], kind) and not isinstance(record[field], bool), record[field]
    assert record["category"] == category and record["availability"] == "In stock"
    assert record["url"].startswith(SITE + "/catalogue/") and 1 <= record["rating"] <= 5 and record["price"] > 0


def save(name, payload):
    os.makedirs(EVIDENCE, mode=0o700, exist_ok=True)
    text = json.dumps(payload, indent=2)
    assert not leaked(text), "key in transcript"
    with open(os.path.join(EVIDENCE, name + ".json"), "w", encoding="utf8") as handle:
        handle.write(text)


def mission(name, text, expected, category, start):
    out = os.path.join(ROOT, name + ".jsonl")
    tab = cli("new", start)["tab"]
    started = time.monotonic()
    try:
        reply = cli("drive", text, "--tab", tab, "--out", out, "--deadline-s", "700", "--max-procedures", "20", timeout=760)
    finally:
        try:
            cli("close", tab)
        except Exception:
            pass
    elapsed = time.monotonic() - started
    with open(out, encoding="utf8") as handle:
        records = [json.loads(line)["record"] for line in handle if line.strip() and json.loads(line).get("kind") == "script-record"]
    data = reply.get("data") or {}
    procedures = [(item.get("slug"), item.get("outcome")) for item in reply.get("procedures", [])]
    scripts = data.get("scripts") or []
    summary = {
        "mission": text,
        "status": reply.get("status"),
        "reason": reply.get("reason"),
        "elapsed_s": round(elapsed, 1),
        "collected": reply.get("collected"),
        "truth": len(expected),
        "pages": data.get("pages"),
        "model_calls": reply.get("model_calls"),
        "model_calls_by_kind": data.get("model_calls_by_kind"),
        "model_cost": reply.get("model_cost"),
        "cost_unreported": data.get("cost_unreported"),
        "procedures": procedures,
        "scripts": scripts,
        "final": (reply.get("final") or {}).get("url"),
    }
    save(name, {"summary": summary, "reply": reply})
    print(json.dumps(summary), flush=True)
    assert reply.get("status") == "done", summary
    assert len(records) == reply.get("collected") == len(expected), summary
    for record in records:
        check_shape(record, category)
    got = {item["url"]: item for item in records}
    want = {item["url"]: item for item in expected}
    assert got.keys() == want.keys(), "urls differ from the site"
    for url, record in got.items():
        assert record == want[url], (url, record, want[url])
    return summary


def main():
    truths = {}
    for name, url in CATEGORIES.items():
        books, pages = truth(url)
        truths[name] = (books, pages)
        print(f"oracle {name}: {pages} pages, {len(books)} books", flush=True)
    assert truths["Default"][1] >= 8, truths["Default"][1]
    results = []
    for name in ("Travel", "Mystery", "Default"):
        books, _pages = truths[name]
        results.append(mission(name, f"collect every book in the {name} category", books, name, SITE))
    current, current_pages = truth(CATEGORIES["Mystery"], one_page=True)
    assert current_pages == 1 and len(current) == 20, (current_pages, len(current))
    # Already on the category page. The mission names no procedure; the operator must choose run_script:list-page.
    results.append(mission("read-page", "Collect the book titles and prices on this page.", current, "Mystery", CATEGORIES["Mystery"]))
    save("summary", {"results": results, "oracle": {name: {"pages": pages, "books": len(books)} for name, (books, pages) in truths.items()}})
    print("L46 live gate passed", flush=True)


if __name__ == "__main__":
    main()
