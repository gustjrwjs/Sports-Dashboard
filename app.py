"""UEFA 네이션스리그 대시보드 - 로컬 서버

실행:  python app.py          (브라우저가 자동으로 열립니다)
옵션:  python app.py --no-browser
       PORT 환경변수로 포트 변경 (기본 8765)

데이터 출처: ESPN 공개 API (API 키 불필요). 표준 라이브러리만 사용합니다.
"""
import json
import os
import sys
import threading
import time
import urllib.request
import webbrowser
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

PORT = int(os.environ.get("PORT", "8765"))
LEAGUE = "uefa.nations"
SITE = "https://site.api.espn.com/apis/site/v2/sports/soccer"
V2 = "https://site.api.espn.com/apis/v2/sports/soccer"
STATIC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")

# 캐시 유지 시간(초)
TTL_LIVE = 60        # 순위표·경기 목록
TTL_TEAM = 600       # 팀별 지난 경기
TTL_FIXTURE = 300    # 팀별 다음 경기

_cache = {}
_lock = threading.Lock()


def fetch(url, ttl):
    now = time.time()
    with _lock:
        hit = _cache.get(url)
    if hit and now - hit[0] < ttl:
        return hit[1]
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (NationsLeagueDashboard)"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            data = json.loads(r.read().decode("utf-8"))
    except Exception:
        if hit:  # 네트워크 오류 시 이전 데이터라도 보여줌
            return hit[1]
        raise
    with _lock:
        _cache[url] = (now, data)
    return data


# ---------------------------------------------------------------- 정규화

def _int(v):
    if isinstance(v, dict):
        v = v.get("displayValue", v.get("value"))
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return None


def _team(c):
    t = c.get("team") or {}
    logo = t.get("logo") or ((t.get("logos") or [{}])[0].get("href"))
    return {
        "id": str(t.get("id")),
        "name": t.get("displayName") or t.get("name"),
        "abbr": t.get("abbreviation"),
        "logo": logo,
        "score": _int(c.get("score")),
        "shootout": _int(c.get("shootoutScore")),
        "winner": c.get("winner"),
    }


def norm_event(ev):
    comp = (ev.get("competitions") or [{}])[0]
    status = comp.get("status") or ev.get("status") or {}
    st = status.get("type") or {}
    home = away = None
    for c in comp.get("competitors", []):
        if c.get("homeAway") == "home":
            home = _team(c)
        else:
            away = _team(c)
    league = ev.get("league") or {}
    return {
        "id": str(ev.get("id")),
        "date": ev.get("date"),
        "state": st.get("state"),          # pre / in / post
        "completed": bool(st.get("completed")),
        "status": st.get("name"),
        "detail": st.get("shortDetail") or st.get("detail"),
        "clock": status.get("displayClock"),
        "home": home,
        "away": away,
        "venue": (comp.get("venue") or {}).get("fullName"),
        "neutral": bool(comp.get("neutralSite")),
        "competition": league.get("name") or "UEFA Nations League",
    }


# ---------------------------------------------------------------- 데이터

def standings():
    d = fetch(f"{V2}/{LEAGUE}/standings", TTL_LIVE)
    season = (d.get("seasons") or [{}])[0]
    groups = []
    for ch in d.get("children", []):
        rows = []
        for e in (ch.get("standings") or {}).get("entries", []):
            s = {x.get("name"): x.get("value") for x in e.get("stats", [])}
            t = e.get("team") or {}
            note = e.get("note") or {}
            rows.append({
                "id": str(t.get("id")),
                "name": t.get("displayName"),
                "abbr": t.get("abbreviation"),
                "logo": ((t.get("logos") or [{}])[0]).get("href"),
                "rank": _int(s.get("rank")) or 0,
                "p": _int(s.get("gamesPlayed")) or 0,
                "w": _int(s.get("wins")) or 0,
                "d": _int(s.get("ties")) or 0,
                "l": _int(s.get("losses")) or 0,
                "gf": _int(s.get("pointsFor")) or 0,
                "ga": _int(s.get("pointsAgainst")) or 0,
                "gd": _int(s.get("pointDifferential")) or 0,
                "pts": _int(s.get("points")) or 0,
                "note": note.get("description"),
                "noteColor": note.get("color"),
            })
        rows.sort(key=lambda r: r["rank"] or 99)
        groups.append({"name": ch.get("name"), "rows": rows})
    return {"season": season.get("displayName"), "year": season.get("year"), "groups": groups}


def season_year():
    try:
        y = standings().get("year")
        if y:
            return int(y)
    except Exception:
        pass
    now = datetime.now()
    return now.year if now.month >= 7 else now.year - 1


def matches():
    y = season_year()
    # 리그 페이즈(9~11월), 8강·플레이오프(3월), 파이널(6월)
    months = [f"{y}09", f"{y}10", f"{y}11", f"{y + 1}03", f"{y + 1}06"]

    def one(m):
        try:
            return fetch(f"{SITE}/{LEAGUE}/scoreboard?dates={m}&limit=300", TTL_LIVE).get("events", [])
        except Exception:
            return []

    with ThreadPoolExecutor(5) as ex:
        evs = [e for lst in ex.map(one, months) for e in lst]
    seen, out = set(), []
    for e in evs:
        n = norm_event(e)
        if n["id"] in seen or not n["home"] or not n["away"]:
            continue
        seen.add(n["id"])
        out.append(n)
    out.sort(key=lambda e: e["date"] or "")
    return {"matches": out}


def team(tid):
    past = fetch(f"{SITE}/all/teams/{tid}/schedule", TTL_TEAM)
    try:
        fut = fetch(f"{SITE}/all/teams/{tid}/schedule?fixture=true", TTL_FIXTURE)
    except Exception:
        fut = {}
    p = [norm_event(e) for e in past.get("events", [])]
    p = [e for e in p if e["completed"] and e["home"] and e["away"]]
    p.sort(key=lambda e: e["date"] or "", reverse=True)
    u = [norm_event(e) for e in fut.get("events", [])]
    u = [e for e in u if not e["completed"] and e["home"] and e["away"]]
    u.sort(key=lambda e: e["date"] or "")
    info = past.get("team") or {}
    return {"id": tid, "name": info.get("displayName"), "logo": info.get("logo"), "past": p, "upcoming": u}


def forms():
    ids = [r["id"] for g in standings()["groups"] for r in g["rows"]]

    def one(tid):
        try:
            return tid, team(tid)["past"][:5]
        except Exception:
            return tid, []

    with ThreadPoolExecutor(8) as ex:
        return dict(ex.map(one, ids))


# ---------------------------------------------------------------- 서버

ROUTES = {"/api/standings": standings, "/api/matches": matches, "/api/forms": forms}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlparse(self.path).path
        try:
            if path in ROUTES:
                return self._json(ROUTES[path]())
            if path.startswith("/api/team/"):
                tid = path.rsplit("/", 1)[-1]
                if not tid.isdigit():
                    return self._json({"error": "잘못된 팀 ID"}, 400)
                return self._json(team(tid))
            if path in ("/", "/index.html"):
                return self._file("index.html")
            self.send_error(404)
        except Exception as e:  # 외부 API 오류
            self._json({"error": f"데이터를 불러오지 못했습니다: {e}"}, 502)

    def _json(self, obj, code=200):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _file(self, name):
        with open(os.path.join(STATIC, name), "rb") as f:
            body = f.read()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


def main():
    srv = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    url = f"http://127.0.0.1:{PORT}/"
    print(f"네이션스리그 대시보드 실행 중: {url}")
    print("종료하려면 Ctrl+C")
    if "--no-browser" not in sys.argv:
        threading.Timer(0.8, lambda: webbrowser.open(url)).start()
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
