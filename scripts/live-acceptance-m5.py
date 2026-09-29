#!/usr/bin/env python3
"""Live-only L23 gate: milestone-5 drive through the real CLI/service/
headless-Chrome with real models (OpenRouter key from the environment).

status     the service reports the models configured with the pinned ids and
           default endpoints, and the key is in no reply (drive-e7oi).
wikipedia  fresh tab on https://www.wikipedia.org/: one --dry-run (a single
           decision, the page untouched, one System One call, no helper call),
           then the real drive. Expects done with the final url/title on the
           Godel incompleteness article, verified by reading the page text
           (drive-y7v8 drive-8zh8).
flights    fresh tab on Google Flights: dry-run, then the one-way search. The
           outcome is recorded honestly — done verified by reading the result
           page, or blocked with its reason (a consent wall counts as the site,
           not Leash). Only a model failure or a drive error fails the gate.
leak       the key is in no CLI reply and no service log line.

Per task the gate prints operator steps, decisions with top probabilities, wall time,
model call counts, token/cost usage from the service log (drive-7tvn), and a
one-line-per-step trace summary. L38 folded the old run command into drive: the
current CLI takes MISSION first, --tab TAB, and --max-procedures.
"""
import json
import os
import subprocess
import sys
import time

LEASH, ROOT, LOG = sys.argv[1:]
KEY = os.environ.get("OPENROUTER_API_KEY", "")
assert KEY, "OPENROUTER_API_KEY is not set; run under secret-env ai -- ..."

JEV_MODEL = "typesafe/jev-1.13-20260917"
TEXT_MODEL = "inception/mercury-2.5"

WIKI_URL = "https://www.wikipedia.org/"
WIKI_GOAL = "Find and open the Wikipedia article about G\u00f6del's incompleteness theorems"
FLIGHTS_URL = "https://www.google.com/travel/flights"
FLIGHTS_GOAL = ("Search Google Flights for a one-way flight from Warsaw (WAW) to "
                "London (LHR) leaving on October 15, 2026.")
MAX_PROCEDURES = 10
DEADLINE_S = 300

TRANSCRIPT = []


def cli(owner, command, *args, error=None, timeout=60):
    proc = subprocess.run([LEASH, command, "--owner", owner, *map(str, args)],
                          capture_output=True, text=True, timeout=timeout)
    TRANSCRIPT.append(proc.stdout)
    try:
        value = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise AssertionError(
            f"{command} did not return JSON: rc={proc.returncode}: "
            f"{proc.stdout!r} {proc.stderr!r}") from exc
    if error:
        assert proc.returncode == 1 and value.get("code") == error, \
            (command, proc.returncode, value)
    else:
        assert proc.returncode == 0, (command, proc.returncode, value, proc.stderr)
    return value


def log_pos():
    return os.path.getsize(LOG)


def usage_since(pos):
    """Service-log usage lines appended after pos: (systemone, helper) fields."""
    systemone, helper = [], []
    with open(LOG, encoding="utf-8", errors="replace") as handle:
        handle.seek(pos)
        for line in handle:
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            if record.get("msg") == "systemone usage":
                systemone.append(record.get("fields", {}))
            elif record.get("msg") == "text helper usage":
                helper.append(record.get("fields", {}))
    return systemone, helper


def top1(dist):
    if isinstance(dist, dict) and dist:
        key = max(dist, key=lambda k: dist[k])
        return key, dist[key]
    return "-", 0.0


def summarize(name, reply, wall_s, systemone, helper):
    steps = reply.get("operator_steps", [])
    print(f"--- {name}: status={reply.get('status')} steps={len(steps)} "
          f"wall={wall_s:.1f}s reason={reply.get('reason', '-')}", flush=True)
    for step in steps:
        probs = step.get("probabilities", {})
        op, p = top1(probs.get("op"))
        target, tp = top1(probs.get("target"))
        typed = step.get("text")
        print(f"  step {step.get('n')}: op={step.get('operation')} ({op} {p:.3f}) "
              f"index={step.get('index')} target=({target} {tp:.3f}) "
              f"typed={typed!r} after={step.get('after', {}).get('url')} "
              f"elapsed_ms={step.get('elapsed_ms')}", flush=True)
    tokens_in = sum(f.get("input_tokens", 0) for f in systemone)
    tokens_out = sum(f.get("output_tokens", 0) for f in systemone)
    cost = sum(f.get("cost", 0.0) for f in systemone)
    help_tokens = sum(f.get("total_tokens", 0) for f in helper)
    print(f"  model calls: {len(systemone)} systemone, {len(helper)} text-helper; "
          f"systemone tokens in/out={tokens_in}/{tokens_out} cost=${cost:.6f}; "
          f"helper tokens={help_tokens}", flush=True)
    final = reply.get("final", {})
    print(f"  final: {final.get('url')} | {final.get('title')!r}", flush=True)
    return {"status": reply.get("status"), "steps": len(steps), "wall_s": wall_s,
            "systemone": len(systemone), "helper": len(helper),
            "cost": cost, "final_url": final.get("url"),
            "final_title": final.get("title"), "reason": reply.get("reason")}


def dry_run(tab, goal, name):
    before = cli("live", "snap", tab)
    pos = log_pos()
    started = time.monotonic()
    reply = cli("live", "drive", goal, "--tab", tab, "--dry-run", timeout=120)
    wall = time.monotonic() - started
    systemone, helper = usage_since(pos)
    steps = reply.get("operator_steps", [])
    assert len(steps) == 1, (name, reply)
    step = steps[0]
    op, prob = top1(step.get("probabilities", {}).get("op"))
    assert op != "-" and prob > 0, (name, step)
    after = cli("live", "snap", tab)
    assert after["url"] == before["url"], (name, before, after)
    assert after["title"] == before["title"], (name, before, after)
    assert len(systemone) == 1, (name, systemone)
    assert helper == [], (name, helper)
    print(f"{name} dry-run: one decision ({step.get('operation')} {op} {prob:.3f}), "
          f"page untouched ({after['url']}, {len(after['rows'])} rows), "
          f"1 systemone call, no helper call, wall={wall:.1f}s", flush=True)


def main():
    status = cli("live", "status")
    models = status.get("models") or {}
    assert models.get("configured") is True, models
    assert models.get("jev_model") == JEV_MODEL, models
    assert models.get("text_model") == TEXT_MODEL, models
    assert models["systemone_endpoint"].endswith("/systemone"), models
    assert models["chat_base_url"].endswith("/api/v1"), models
    print(f"status: models configured, {JEV_MODEL} + {TEXT_MODEL}", flush=True)

    # Wikipedia: jev's own article task.
    wiki_tab = cli("live", "new", WIKI_URL)["tab"]
    dry_run(wiki_tab, WIKI_GOAL, "wikipedia")
    pos = log_pos()
    started = time.monotonic()
    wiki = cli("live", "drive", WIKI_GOAL, "--tab", wiki_tab,
               "--max-procedures", MAX_PROCEDURES, "--deadline-s", DEADLINE_S, timeout=360)
    wiki_wall = time.monotonic() - started
    wiki_sys, wiki_help = usage_since(pos)
    wiki_summary = summarize("wikipedia drive", wiki, wiki_wall, wiki_sys, wiki_help)
    assert wiki["status"] == "done", wiki_summary
    final = wiki.get("final", {})
    assert "wikipedia.org/wiki/" in final.get("url", ""), wiki_summary
    assert "ncompleteness" in final.get("url", ""), wiki_summary
    assert "ncompleteness" in final.get("title", ""), wiki_summary
    text = cli("live", "text", wiki_tab, timeout=120)
    assert "ncompleteness" in text.get("text", ""), text.get("text", "")[:500]
    print("wikipedia: done on the article, page text confirms it", flush=True)

    # Flights: the one-way search, recorded honestly.
    flights_tab = cli("live", "new", FLIGHTS_URL)["tab"]
    opened = cli("live", "snap", flights_tab)
    print(f"flights opened at: {opened['url']} | {opened['title']!r}", flush=True)
    dry_run(flights_tab, FLIGHTS_GOAL, "flights")
    pos = log_pos()
    started = time.monotonic()
    try:
        flights = cli("live", "drive", FLIGHTS_GOAL, "--tab", flights_tab,
                      "--max-procedures", MAX_PROCEDURES, "--deadline-s", DEADLINE_S, timeout=360)
    except AssertionError as exc:
        raise AssertionError(f"flights drive failed at the protocol: {exc}") from exc
    flights_wall = time.monotonic() - started
    flights_sys, flights_help = usage_since(pos)
    flights_summary = summarize("flights drive", flights, flights_wall,
                                flights_sys, flights_help)
    if flights["status"] == "done":
        text = cli("live", "text", flights_tab, timeout=120).get("text", "")
        markers = [m for m in ("Nonstop", "1 stop", "2 stops", "Top departing",
                               "Other flights", "round trip", "one-way", "One-way",
                               "WAW", "LHR", "z\u0142", "$", "\u20ac")
                   if m in text]
        print(f"flights: done; result-page markers seen: {markers}", flush=True)
    elif flights["status"] == "blocked":
        print(f"flights: blocked ({flights.get('reason', 'jev said blocked')}); "
              f"final page: {flights_summary['final_url']} | "
              f"{flights_summary['final_title']!r}", flush=True)
    else:
        raise AssertionError(f"flights drive needs a worker look: {flights_summary}")

    for row in cli("live", "list", "--all")["tabs"]:
        cli("live", "close", row["tab"], "--force")

    with open(LOG, encoding="utf-8", errors="replace") as handle:
        logged = handle.read()
    assert KEY not in logged, "the key reached the service log"
    assert all(KEY not in out for out in TRANSCRIPT), "the key reached a CLI reply"
    print(f"key leak check: clean ({len(TRANSCRIPT)} CLI replies, "
          f"{len(logged)} log bytes scanned)", flush=True)
    print("milestone-5 live acceptance: done", flush=True)


main()
