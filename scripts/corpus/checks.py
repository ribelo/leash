"""Independent checks for the corpus (corp-667a): each fetches the truth without Leash,
or reads a fixture's own record, and compares it with the reply. A check never trusts
the reply's status alone; a mission marked done but wrong fails."""
import html, json, os, pathlib, random, re, secrets, socket, string, subprocess, sys, threading, time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REPO = pathlib.Path(__file__).resolve().parent.parent.parent
FIXTURES = REPO / "scripts/use-cases/fixtures.py"
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/150 Safari/537.36",
      "Accept-Language": "en-US,en;q=0.9",
      "Cookie": "CONSENT=YES+; SOCS=CAESEwgDEgk0ODE3Nzk3MjQaAmVuIAEaBgiA_LyaBg"}


def fetch(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=45) as r:
        return r.read().decode("utf-8", "ignore")


def norm(s):
    return re.sub(r"\s+", " ", html.unescape(s or "")).strip().lower()


class Context:
    def __init__(self, work, svc):
        self.work, self.svc = work, svc
        self.vars, self.secret_files, self.out = {}, {}, None
        self.fixture = None


class Fixture:
    pass


def start_fixture(mission, ctx):
    kind = mission.get("fixture")
    if not kind:
        return None
    f = Fixture()
    if kind == "fixtures":
        user = "u" + secrets.token_hex(4)
        password = secrets.token_urlsafe(12)
        for name, value in (("portal_user", user), ("portal_password", password)):
            p = ctx.work / f"{name}.txt"
            p.write_text(value)
            os.chmod(p, 0o600)
            if name in mission.get("secrets", []):
                ctx.secret_files[name] = p
        ctx.vars["file"] = str(ctx.work / "upload-sample.txt")
        (ctx.work / "upload-sample.txt").write_text("corpus upload " + secrets.token_hex(8) + "\n")
        f.state = ctx.work / "fixture-state.json"
        f.proc = subprocess.Popen([sys.executable, str(FIXTURES), "0", str(f.state)],
                                  env=dict(os.environ, FIXTURE_USERNAME=user, FIXTURE_PASSWORD=password),
                                  stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        f.base = f.proc.stdout.readline().strip()
    elif kind == "canvas":
        f.hits = []
        bx = random.randint(60, 600); by = random.randint(60, 380)
        f.button = {"x": bx, "y": by, "w": 220, "h": 90}
        page = CANVAS % {"button": json.dumps(f.button)}
        body = page.encode()
        class H(BaseHTTPRequestHandler):
            def log_message(self, *a): pass
            def do_GET(self):
                self.send_response(200); self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
            def do_POST(self):
                n = int(self.headers.get("Content-Length", "0"))
                try:
                    f.hits.append(json.loads(self.rfile.read(n)))
                except ValueError:
                    pass
                self.send_response(204); self.end_headers()
        f.server = ThreadingHTTPServer(("127.0.0.1", 0), H)
        threading.Thread(target=f.server.serve_forever, daemon=True).start()
        f.base = f"http://127.0.0.1:{f.server.server_port}"
    elif kind == "tauron":
        lines = (pathlib.Path.home() / ".config/leash/use-cases/tauron").read_text().splitlines()
        for name, value in (("login", lines[0]), ("password", lines[1])):
            p = ctx.work / f"{name}.txt"; p.write_text(value); os.chmod(p, 0o600)
            ctx.secret_files[name] = p
        f.base = ""
        f.downloads_before = set(downloads(ctx))
    ctx.fixture = f
    return f


def stop_fixture(ctx):
    f = ctx.fixture
    if f is None:
        return
    if hasattr(f, "proc"):
        f.proc.terminate()
        try:
            f.proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            f.proc.kill()
    if hasattr(f, "server"):
        f.server.shutdown()
    for p in ctx.work.glob("*.txt"):
        if p.name.endswith(("user.txt", "password.txt", "login.txt")):
            p.unlink()


def downloads(ctx):
    d = ctx.svc.root / "data/leash/profile/downloads"
    return [p.name for p in d.glob("*")] if d.is_dir() else []


CANVAS = """<!doctype html><html><head><title>Canvas launch test</title>
<style>body{margin:0;background:#20232a}canvas{display:block}</style></head><body>
<canvas id="c" width="900" height="560"></canvas>
<script>
const button = %(button)s;
const c = document.getElementById('c'), g = c.getContext('2d');
let state = 'ready';
function draw() {
  g.fillStyle = '#20232a'; g.fillRect(0, 0, c.width, c.height);
  g.fillStyle = state === 'launched' ? '#2e9d4f' : '#3b6fd8';
  g.beginPath(); g.roundRect(button.x, button.y, button.w, button.h, 12); g.fill();
  g.fillStyle = '#ffffff'; g.font = 'bold 26px sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
  g.fillText(state === 'launched' ? 'Launched' : 'Launch', button.x + button.w / 2, button.y + button.h / 2);
}
c.addEventListener('click', (e) => {
  const r = c.getBoundingClientRect(), x = e.clientX - r.left, y = e.clientY - r.top;
  const inside = x >= button.x && x < button.x + button.w && y >= button.y && y < button.y + button.h;
  if (inside) state = 'launched';
  draw();
  fetch('/hit', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({x, y, inside})});
});
draw();
</script></body></html>"""


def result_text(reply):
    return norm((reply.get("result") or "") + " " + " ".join(reply.get("evidence") or []))


def records(ctx):
    if not ctx.out or not pathlib.Path(ctx.out).is_file():
        return []
    out = []
    for line in pathlib.Path(ctx.out).read_text().splitlines():
        try:
            d = json.loads(line)
        except ValueError:
            continue
        out.append(d.get("record") or {})
    return out


def books_cards(url):
    page = fetch(url)
    titles = [html.unescape(t) for t in re.findall(r'<h3><a [^>]*title="([^"]*)"', page)]
    prices = [html.unescape(p) for p in re.findall(r'<p class="price_color">([^<]*)</p>', page)]
    return list(zip(titles, prices)), page


def check(mission, reply, ctx):
    spec = mission["check"]
    kind = spec["kind"]
    text = result_text(reply)
    f = ctx.fixture
    try:
        if kind == "contains":
            truth = spec["truth"]
            if spec.get("source") == "wikipedia":
                summary = json.loads(fetch("https://en.wikipedia.org/api/rest_v1/page/summary/" + spec["page"]))
                if norm(truth) not in norm(summary.get("extract", "")):
                    return False, f"truth {truth!r} no longer in the Wikipedia summary"
            elif spec.get("source"):
                page = norm(fetch(spec["source"]))
                if norm(truth) not in page:
                    return False, f"truth {truth!r} not on {spec['source']}"
            ok = all(norm(t) in text for t in spec.get("all", [truth]))
            return ok, f"result {'names' if ok else 'lacks'} {truth!r}"
        if kind == "regex_on_source":
            page = fetch(spec["source"])
            m = re.search(spec["pattern"], page)
            if not m:
                return False, "truth pattern not found on the source"
            truth = norm(m.group(1))
            ok = truth in text or truth.replace(",", "") in text.replace(",", "")
            return ok, f"truth {truth!r}; result {'agrees' if ok else 'differs'}"
        if kind == "books_jsonl":
            cards, _ = books_cards(spec["source"])
            # A price is compared as a number: a script returns 51.77, the page shows £51.77.
            def price(v):
                digits = re.sub(r"[^0-9.]", "", str(v))
                return f"{float(digits):.2f}" if digits else ""
            got = [(norm(r.get("title")), price(r.get("price"))) for r in records(ctx)]
            want = [(norm(t), price(p)) for t, p in cards]
            # A card shows a long title cut with "..."; a record copying that visible text
            # matches the full title it starts.
            def same(g, w):
                title, price = g
                cut = title.rstrip(". …").strip()
                return price == w[1] and (title == w[0] or (title.endswith(("...", "…")) and w[0].startswith(cut)))
            missing = [w for w in want if not any(same(g, w) for g in got)]
            extra = [g for g in got if not any(same(g, w) for w in want)]
            ok = not missing and not extra and len(got) == len(want)
            return ok, f"{len(want)} on the page, {len(got)} in the file, {len(missing)} missing, {len(extra)} extra"
        if kind == "maps_place":
            # Maps renders only in a browser, so the truth is a fresh tab read with the
            # service's low-level commands (new, text), never a drive.
            words = re.findall(r"[A-Z][\w'’&.-]+(?:\s+[A-Z][\w'’&.-]+)+", (reply.get("result") or ""))
            st = ctx.svc.cli("new", spec["source"])
            tab = (st or {}).get("tab")
            time.sleep(8)
            page = (ctx.svc.cli("text", tab) or {}).get("text", "") if tab else ""
            if tab:
                ctx.svc.cli("close", tab)
            seen = [w for w in words if w in page]
            ratings = [float(x.replace(",", ".")) for x in re.findall(r"\b([45][.,]\d)\b", reply.get("result") or "")]
            ok = bool(seen) and any(r > 4 for r in ratings)
            return ok, f"names on a fresh Maps search: {seen[:2]}; ratings {ratings[:2]}"
        if kind == "wikidata":
            data = json.loads(fetch(f"https://www.wikidata.org/wiki/Special:EntityData/{spec['entity']}.json"))
            claims = data["entities"][spec["entity"]]["claims"][spec["property"]]
            values = [c["mainsnak"]["datavalue"]["value"] for c in claims if "datavalue" in c["mainsnak"]]
            values = [v if isinstance(v, str) else json.dumps(v) for v in values]
            ok = any(norm(v) in text for v in values)
            return ok, f"Wikidata {spec['property']} {values[:2]}; result {'agrees' if ok else 'differs'}"
        if kind == "fixture_register":
            st = json.loads(f.state.read_text())
            accounts = [a for a in st["accounts"] if a["email"] == spec["email"]]
            ok = st["registrations"] == 1 and len(accounts) == 1 and accounts[0]["confirmed"]
            return ok, f"registrations {st['registrations']}, confirmed {bool(accounts and accounts[0]['confirmed'])}"
        if kind == "fixture_upload":
            st = json.loads(f.state.read_text())
            ups = st.get("uploads", [])
            link = ups[0]["link"] if len(ups) == 1 else None
            ok = link is not None and link in text
            return ok, f"{len(ups)} upload(s); link {link} {'in' if ok else 'not in'} the result"
        if kind == "fixture_message":
            st = json.loads(f.state.read_text())
            msg = next(m for m in st["portal"]["messages"] if m["id"] == spec["message"])
            ok = norm(spec["phrase"]) in text and norm(spec["phrase"]) in norm(msg["body"])
            return ok, f"message {spec['message']!r} {'quoted' if ok else 'not quoted'}"
        if kind == "canvas":
            inside = [h for h in f.hits if h.get("inside")]
            ok = len(f.hits) == 1 and len(inside) == 1
            return ok, f"{len(f.hits)} canvas click(s), {len(inside)} inside the drawn button"
        if kind == "tauron_overdue":
            st = ctx.svc.cli("new", "https://moj.tauron.pl/")
            tab = (st or {}).get("tab")
            time.sleep(8)
            page = (ctx.svc.cli("text", tab) or {}).get("text", "") if tab else ""
            if tab:
                ctx.svc.cli("close", tab)
            i = page.find("Najbliższa płatność")
            amounts = re.findall(r"\d[\d ]*,\d\d zł", page[i:i + 200]) if i >= 0 else []
            ok = bool(amounts) and norm(amounts[0].replace(" zł", "")) in text
            return ok, f"page (fresh tab, low-level text) shows {amounts[:3]}"
        if kind == "tauron_pdf":
            new = [n for n in downloads(ctx) if n not in f.downloads_before and n.lower().endswith(".pdf")]
            return bool(new), f"new PDF(s): {new[:2]}"
    except Exception as e:  # the truth could not be read: the cell cannot pass
        return False, f"check failed: {e}"
    return False, f"unknown check {kind}"
