"""스포츠 대시보드 - 로컬 서버

실행:  python app.py          (브라우저가 자동으로 열립니다)
옵션:  python app.py --no-browser
       PORT 환경변수로 포트 변경 (기본 8765)

하는 일
- static/index.html 화면을 보여줍니다.
- /espn/... 요청을 ESPN 공개 API(site.api.espn.com/apis/...)로 전달하고 잠시 캐시합니다.
  데이터 가공은 모두 화면(index.html)에서 합니다. 서버 없이 파일만 열어도 동작합니다.

표준 라이브러리만 사용합니다.
"""
import json
import os
import re
import sys
import threading
import time
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

PORT = int(os.environ.get("PORT", "8765"))
ESPN = "https://site.api.espn.com/apis/"
STATIC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")
SAFE_PATH = re.compile(r"^[A-Za-z0-9._/-]+$")
SAFE_QUERY = re.compile(r"^[A-Za-z0-9._=&,-]*$")

TYPES = {  # 화면 폴더(static)에서 보내 줄 파일 종류
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".webmanifest": "application/manifest+json; charset=utf-8",
    ".png": "image/png",
}

_cache = {}
_lock = threading.Lock()


def ttl_for(path):
    if "/schedule" in path:
        return 600   # 팀별 일정
    if "/scoreboard" in path or "/summary" in path:
        return 15    # 실시간 점수 (LIVE 탭은 20초마다 갱신)
    return 60        # 순위표


def fetch(url, ttl):
    now = time.time()
    with _lock:
        hit = _cache.get(url)
    if hit and now - hit[0] < ttl:
        return hit[1]
    req = urllib.request.Request(url, headers={"User-Agent": "SportsDashboard/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            body = r.read()
        json.loads(body)  # JSON인지 확인
    except Exception:
        if hit:  # 네트워크 오류 시 이전 데이터라도 보여줌
            return hit[1]
        raise
    with _lock:
        _cache[url] = (now, body)
        if len(_cache) > 2000:
            _cache.clear()
    return body


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        u = urlparse(self.path)
        try:
            if u.path.startswith("/espn/"):
                rest = u.path[len("/espn/"):]
                if not SAFE_PATH.match(rest) or ".." in rest or not SAFE_QUERY.match(u.query):
                    return self._send(400, b'{"error":"bad path"}', "application/json")
                url = ESPN + rest + ("?" + u.query if u.query else "")
                return self._send(200, fetch(url, ttl_for(rest)), "application/json; charset=utf-8")
            if u.path in ("/", "/static/"):
                rel = "index.html"
            else:
                rel = u.path[len("/static/"):] if u.path.startswith("/static/") else u.path.lstrip("/")
            ext = os.path.splitext(rel)[1].lower()
            if SAFE_PATH.match(rel) and ".." not in rel and ext in TYPES:
                full = os.path.join(STATIC, *rel.split("/"))
                if os.path.isfile(full):
                    with open(full, "rb") as f:
                        return self._send(200, f.read(), TYPES[ext])
            self.send_error(404)
        except Exception as e:
            msg = json.dumps({"error": f"데이터를 불러오지 못했습니다: {e}"}, ensure_ascii=False).encode("utf-8")
            self._send(502, msg, "application/json; charset=utf-8")

    def _send(self, code, body, ctype):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


def main():
    srv = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    url = f"http://127.0.0.1:{PORT}/"
    print(f"스포츠 대시보드 실행 중: {url}")
    print("종료하려면 Ctrl+C")
    if "--no-browser" not in sys.argv:
        threading.Timer(0.8, lambda: webbrowser.open(url)).start()
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
