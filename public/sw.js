const CACHE_NAME = 'static-repair';
const ASSETS = [
  "/",
  "index.html",
  "/css/pure-min.css",
  "/js/index.js",
  "/js/sa2.min.js",
  "/js/qrcode.min.js",
  "/icons/cc.webp",
];
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
     return cache.addAll(ASSETS);
      console.log("cargando elementos... ok");
    }),
  );
});

self.addEventListener("fetch", (event) => {
  event.respondWith(
    caches
      .match(event.request)
      .then((cachedResponse) => {
        return cachedResponse || fetch(event.request);
      })
      .catch((e) => {
        console.error("error"); //recordar funcion error de promesa incumplida
      }),
  );
});
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cache) => {
          if (cache !== CACHE_NAME) {
            return caches.delete(cache);
          }
        })
      );
    })
  );
});
