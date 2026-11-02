// Service worker for Breathing Dark.
// Keeps the page and the face and pose models on this computer so the installed app opens offline.
// The page itself is fetched fresh whenever there is a connection, so pushes to GitHub Pages show up
// on the next launch. The CDN files are pinned versions that never change, so they are served from
// the cache once stored.

const SHELL_CACHE = 'breathing-dark-shell-v5';
const CDN_CACHE = 'breathing-dark-cdn-v2';
const MP = 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.35';

const SHELL = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icon-192.png',
  './icon-512.png',
  './icon-maskable-512.png',
  './apple-touch-icon.png',
  './favicon-32.png',
];
const CDN = [
  `${MP}/vision_bundle.mjs`,
  `${MP}/wasm/vision_wasm_internal.js`,
  `${MP}/wasm/vision_wasm_internal.wasm`,
  'https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task',
  'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/1/pose_landmarker_full.task',
];
// tfhub.dev serves the MoveNet models (through a redirect); they are stored the first time they are used.
const CDN_HOSTS = new Set(['cdn.jsdelivr.net', 'storage.googleapis.com', 'fonts.googleapis.com', 'fonts.gstatic.com', 'tfhub.dev']);

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const shell = await caches.open(SHELL_CACHE);
    await shell.addAll(SHELL.map(url => new Request(url, { cache: 'reload' }))); // skip the browser's 10-minute copy
    // The models are large; store them in the background and don't fail the install over them.
    const cdn = await caches.open(CDN_CACHE);
    await Promise.all(CDN.map(async url => {
      if (await cdn.match(url)) return;
      try { await cdn.add(url); } catch (err) { console.warn('Not cached yet:', url, err); }
    }));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const keep = new Set([SHELL_CACHE, CDN_CACHE]);
    for (const key of await caches.keys()) {
      if (key.startsWith('breathing-dark-') && !keep.has(key)) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin === self.location.origin) event.respondWith(networkFirst(req));
  else if (CDN_HOSTS.has(url.hostname)) event.respondWith(cacheFirst(req));
});

async function networkFirst(req) {
  const cache = await caches.open(SHELL_CACHE);
  const cached = await cache.match(req, { ignoreSearch: true });
  // GitHub Pages tells browsers to reuse files for 10 minutes; 'no-cache' asks the server every time
  // instead (a quick "not modified" when nothing changed), so a new version shows on the next load.
  const fresh = req.mode === 'navigate'
    ? fetch(req.url, { cache: 'no-cache', credentials: 'same-origin' })
    : fetch(req, { cache: 'no-cache' });
  const network = fresh.then(res => {
    if (res.ok) cache.put(req, res.clone());
    return res;
  });
  if (!cached) return network;
  network.catch(() => {}); // offline: the stored copy answers below
  // With a stored copy, wait at most 3 s for the network, then fall back to the copy.
  const timeout = new Promise(resolve => setTimeout(() => resolve(cached), 3000));
  try {
    return await Promise.race([network, timeout]);
  } catch {
    return cached;
  }
}

async function cacheFirst(req) {
  const cache = await caches.open(CDN_CACHE);
  const hit = await cache.match(req);
  if (hit) return hit;
  const res = await fetch(req);
  if (res.ok || res.type === 'opaque') cache.put(req, res.clone());
  return res;
}
