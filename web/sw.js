// Service worker of the MedLog PWA.
//
// Every build is a separate, atomic version: tool/build_web.sh fills in BUILD
// and the PRECACHE file list, so sw.js changes from build to build and the
// browser notices the update. The new version is downloaded into its own cache
// as a whole, waits, and is activated by the "Обновить" (Update) button, or on
// the next launch once all tabs are closed. A page always runs on the files of
// a single version.

const BUILD = '__BUILD__';     // hash of the build contents
const VERSION = '__VERSION__'; // version from pubspec.yaml + build number
const PRECACHE = /*__PRECACHE__*/ ['./', 'index.html', 'manifest.json'];

const PREFIX = 'medlog-';
const LEGACY_PREFIX = 'krest-'; // caches of versions before the rename
const CACHE = PREFIX + BUILD;
const FONTS = PREFIX + 'fonts'; // Google fonts don't depend on the build

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE).then((c) =>
      // cache: 'reload' bypasses the HTTP cache so no files of an older build get in.
      c.addAll(PRECACHE.map((u) => new Request(u, { cache: 'reload' })))
    )
  );
  // No skipWaiting: the update is applied when the user asks for it.
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys
          .filter((k) => k.startsWith(LEGACY_PREFIX) ||
            (k.startsWith(PREFIX) && k !== CACHE && k !== FONTS))
          .map((k) => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('message', (e) => {
  const msg = e.data || {};
  if (msg.type === 'SKIP_WAITING') self.skipWaiting();
  if (msg.type === 'GET_BUILD') {
    const reply = { type: 'BUILD', build: BUILD, version: VERSION };
    (e.ports && e.ports[0]) ? e.ports[0].postMessage(reply) : e.source && e.source.postMessage(reply);
  }
  // The page sends files it loaded before the SW took control of it (e.g. the
  // CanvasKit variant the browser picked); add them to the cache.
  if (msg.type === 'CACHE_URLS' && Array.isArray(msg.urls)) {
    e.waitUntil(Promise.all(msg.urls.map(async (u) => {
      const font = new URL(u).hostname === 'fonts.gstatic.com';
      const c = await caches.open(font ? FONTS : CACHE);
      if (await c.match(u)) return;
      await c.add(new Request(u, font ? { mode: 'cors' } : { cache: 'reload' })).catch(() => {});
    })));
  }
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  if (url.hostname === 'fonts.gstatic.com' || url.hostname === 'fonts.googleapis.com') {
    e.respondWith(cacheFirst(req, FONTS));
    return;
  }
  if (url.origin !== self.location.origin) return;

  // sw.js itself and version.json always come from the network.
  if (url.pathname.endsWith('/sw.js') || url.pathname.endsWith('/version.json')) return;

  if (req.mode === 'navigate') {
    // App shell: index.html of the current version, offline too.
    e.respondWith(
      caches.open(CACHE)
        .then((c) => c.match('index.html'))
        .then((hit) => hit || fetch(req))
    );
    return;
  }
  e.respondWith(cacheFirst(req, CACHE));
});

async function cacheFirst(req, name) {
  const cache = await caches.open(name);
  const hit = await cache.match(req, { ignoreSearch: true });
  if (hit) return hit;
  const res = await fetch(req, { cache: 'no-cache' });
  if (res.ok || res.type === 'opaque') cache.put(req, res.clone());
  return res;
}
