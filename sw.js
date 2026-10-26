/* Service worker aplikasi Lomba Layangan (PWA).
   - Halaman (index.html): selalu ambil versi terbaru dari internet; kalau offline pakai salinan terakhir.
   - Ikon & manifest: disimpan di HP supaya cepat.
   - Data Supabase, foto, dan font tidak disentuh (selalu langsung ke internet). */
const VERSI = 'lomba-pwa-v1';
const INTI = ['/', '/manifest.webmanifest', '/ikon/ikon-192.png', '/ikon/ikon-512.png'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSI).then((c) => c.addAll(INTI)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys()
    .then((ks) => Promise.all(ks.filter((k) => k !== VERSI).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;
  const halaman = req.mode === 'navigate' || url.pathname === '/' || url.pathname === '/index.html';
  if (halaman) {
    e.respondWith(fetch(req, { cache: 'no-store' })
      .then((res) => { if (res.ok) { const salin = res.clone(); caches.open(VERSI).then((c) => c.put('/', salin)); } return res; })
      .catch(() => caches.match('/')));
    return;
  }
  if (url.pathname.startsWith('/ikon/') || url.pathname === '/manifest.webmanifest') {
    e.respondWith(caches.match(req).then((ada) => ada || fetch(req).then((res) => {
      if (res.ok) { const salin = res.clone(); caches.open(VERSI).then((c) => c.put(req, salin)); }
      return res;
    })));
  }
});
