// App-shell cache. Firestore data is cached separately by the Firebase SDK.
const CACHE = "fast-v1";
const SHELL = ["/", "/index.html", "/styles.css", "/app.js", "/manifest.webmanifest", "/icons/icon-192.png", "/icons/icon-512.png"];
self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", (e) => {
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener("fetch", (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== "GET") return;
  const sameOrigin = url.origin === location.origin;
  const isFont = /fonts\.(googleapis|gstatic)\.com$/.test(url.hostname);
  const isSdk = url.hostname === "www.gstatic.com" && url.pathname.startsWith("/firebasejs/");
  if (sameOrigin && url.pathname.startsWith("/__/")) {
    // init.json: network first, cached fallback for offline launches; never cache the auth handler
    if (url.pathname !== "/__/firebase/init.json") return;
  } else if (!sameOrigin && !isFont && !isSdk) return;
  // Network first for our own files (fresh deploys), cache first for versioned SDK + fonts.
  if (sameOrigin) {
    e.respondWith(
      fetch(e.request)
        .then((r) => { const copy = r.clone(); if (r.ok) caches.open(CACHE).then((c) => c.put(e.request, copy)); return r; })
        .catch(() => caches.match(e.request).then((r) => r || (e.request.mode === "navigate" ? caches.match("/index.html") : undefined)))
    );
  } else {
    e.respondWith(
      caches.match(e.request).then((hit) => hit || fetch(e.request).then((r) => { const copy = r.clone(); caches.open(CACHE).then((c) => c.put(e.request, copy)); return r; }))
    );
  }
});
