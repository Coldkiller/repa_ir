const staticRepairDocs = "static-repair";
const assets = [ 
"/",
"index.html",
"/css/pure-min.css",
"/js/index.js",
"/js/fb.js",
"/js/qrcode.min.js",
"/icons/cc.png"
]
self.addEventListener("install", installEvent =>{
   installEvent.waitUntil(
      caches.open(staticRepairDocs).then(cache => {
         cache.addAll(assets);
         console.log('cargando elementos... ok');
      })
      )
});

self.addEventListener("fetch", fetchEvent=>{
    fetchEvent.respondWith(
	caches.match(fetchEvent.request)
   .then(res =>{
	    return res || fetch(fetchEvent.request);
       console.log(res);
	})
   .catch(e => {
      console.log("error");//recordar funcion error de promesa incumplida
   })
    );
});
