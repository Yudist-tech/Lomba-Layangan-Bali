/* Service worker aplikasi Lomba Layangan (PWA).
   - Halaman (index.html): selalu ambil versi terbaru dari internet; kalau offline pakai salinan terakhir.
   - Ikon & manifest: disimpan di HP supaya cepat.
   - Data Supabase, foto, dan font tidak disentuh (selalu langsung ke internet).
   v2: halaman dibaca utuh dulu lalu dikirim sebagai Response baru (tanpa clone/stream bersama),
       karena Safari iPhone kadang gagal membuka halaman ("WebKitBlobResource error 1")
       saat respons yang sama dibagi ke cache sambil ditampilkan, terutama sesaat setelah situs diperbarui. */
const VERSI = 'lomba-pwa-v2';
const INTI = ['/manifest.webmanifest', '/ikon/ikon-192.png', '/ikon/ikon-512.png'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSI).then((c) => c.addAll(INTI)).catch(() => null).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys()
    .then((ks) => Promise.all(ks.filter((k) => k !== VERSI).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

async function halamanTerbaru(req) {
  try {
    const res = await fetch(req, { cache: 'no-store' });
    if (!res.ok || res.redirected || res.type !== 'basic') return res;   // biarkan apa adanya (pengalihan, error)
    const isi = await res.arrayBuffer();
    const init = { status: res.status, statusText: res.statusText, headers: res.headers };
    try { const c = await caches.open(VERSI); await c.put('/', new Response(isi.slice(0), init)); } catch (e) { /* cache penuh: abaikan */ }
    return new Response(isi, init);
  } catch (e) {
    const simpan = await caches.match('/');
    return simpan || Response.error();
  }
}

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;
  const halaman = req.mode === 'navigate' || url.pathname === '/' || url.pathname === '/index.html';
  if (halaman) { e.respondWith(halamanTerbaru(req)); return; }
  if (url.pathname.startsWith('/ikon/') || url.pathname === '/manifest.webmanifest') {
    e.respondWith(caches.match(req).then((ada) => ada || fetch(req).then((res) => {
      if (res.ok) { const salin = res.clone(); caches.open(VERSI).then((c) => c.put(req, salin)); }
      return res;
    })));
  }
});
