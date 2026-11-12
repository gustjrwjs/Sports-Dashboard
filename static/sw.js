// 스포츠 대시보드 - 서비스 워커
// 화면 파일(앱 껍데기)만 저장해 두고, 항상 인터넷에서 최신 버전을 먼저 받습니다.
// 인터넷이 안 될 때만 저장해 둔 화면을 보여줍니다. 경기 데이터는 저장하지 않습니다.
const CACHE = "shell-v1";
const SHELL = ["./", "manifest.webmanifest", "icons/icon-192.png", "icons/icon-512.png", "icons/apple-touch-icon.png"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", e => {
  e.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.origin !== location.origin || url.pathname.includes("/espn/")) return; // 데이터 요청은 그대로 통과

  const isPage = req.mode === "navigate";
  e.respondWith((async () => {
    try {
      const res = await fetch(req, { cache: "no-cache" }); // 브라우저 캐시를 건너뛰고 최신 확인
      if (res.ok) {
        const c = await caches.open(CACHE);
        c.put(isPage ? "./" : req, res.clone());
      }
      return res;
    } catch (err) {
      const hit = await caches.match(isPage ? "./" : req);
      if (hit) return hit;
      throw err;
    }
  })());
});
