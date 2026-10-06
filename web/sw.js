// Service worker PWA «Крест».
//
// Каждая сборка — отдельная атомарная версия: tool/build_web.sh подставляет
// BUILD и список файлов PRECACHE, поэтому sw.js меняется от сборки к сборке,
// и браузер видит обновление. Новая версия скачивается целиком в свой кэш,
// ждёт и активируется по кнопке «Обновить» (или при следующем запуске, когда
// все вкладки закрыты). Страница всегда работает на файлах одной версии.

const BUILD = '__BUILD__';
const PRECACHE = /*__PRECACHE__*/ ['./', 'index.html', 'manifest.json'];

const PREFIX = 'krest-';
const CACHE = PREFIX + BUILD;
const FONTS = PREFIX + 'fonts'; // шрифты Google не зависят от сборки

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE).then((c) =>
      // cache: 'reload' — мимо HTTP-кэша, чтобы не захватить файлы старой сборки.
      c.addAll(PRECACHE.map((u) => new Request(u, { cache: 'reload' })))
    )
  );
  // Без skipWaiting: обновление применяется по запросу пользователя.
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys
          .filter((k) => k.startsWith(PREFIX) && k !== CACHE && k !== FONTS)
          .map((k) => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('message', (e) => {
  const msg = e.data || {};
  if (msg.type === 'SKIP_WAITING') self.skipWaiting();
  if (msg.type === 'GET_BUILD') e.source && e.source.postMessage({ type: 'BUILD', build: BUILD });
  // Страница присылает файлы, загруженные до того, как SW начал ею управлять
  // (например, выбранный браузером вариант CanvasKit), — докладываем их в кэш.
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

  // Сам sw.js и version.json всегда из сети.
  if (url.pathname.endsWith('/sw.js') || url.pathname.endsWith('/version.json')) return;

  if (req.mode === 'navigate') {
    // Оболочка приложения: index.html текущей версии, офлайн тоже.
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
