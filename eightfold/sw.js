// Service worker for Eightfold: keeps the app on this computer so the installed app opens offline.
// Page files are checked with the server on every load (GitHub Pages otherwise lets browsers reuse
// them for 10 minutes), so a new version shows up straight away; fonts are kept once fetched.

const SHELL_CACHE = 'eightfold-shell-v1';
const FONT_CACHE = 'eightfold-fonts-v1';
const SHELL = [
  './', './index.html', './looper-worklet.js', './manifest.webmanifest',
  './icon-192.png', './icon-512.png', './icon-maskable-512.png', './apple-touch-icon.png', './favicon-32.png',
];
const FONT_HOSTS = new Set(['fonts.googleapis.com', 'fonts.gstatic.com']);

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(SHELL_CACHE);
    await cache.addAll(SHELL.map(url => new Request(url, { cache: 'reload' })));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key.startsWith('eightfold-') && key !== SHELL_CACHE && key !== FONT_CACHE) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin === self.location.origin) event.respondWith(networkFirst(req));
  else if (FONT_HOSTS.has(url.hostname)) event.respondWith(cacheFirst(req));
});

async function networkFirst(req) {
  const cache = await caches.open(SHELL_CACHE);
  const cached = await cache.match(req, { ignoreSearch: true });
  const fresh = req.mode === 'navigate'
    ? fetch(req.url, { cache: 'no-cache', credentials: 'same-origin' })
    : fetch(req, { cache: 'no-cache' });
  const network = fresh.then(res => { if (res.ok) cache.put(req, res.clone()); return res; });
  if (!cached) return network;
  network.catch(() => {});
  const timeout = new Promise(resolve => setTimeout(() => resolve(cached), 3000));
  try { return await Promise.race([network, timeout]); } catch { return cached; }
}

async function cacheFirst(req) {
  const cache = await caches.open(FONT_CACHE);
  const hit = await cache.match(req);
  if (hit) return hit;
  const res = await fetch(req);
  if (res.ok || res.type === 'opaque') cache.put(req, res.clone());
  return res;
}
