// APC EOS Bridge — Service Worker v1
const CACHE = ‘apc-eos-v1’;
const ASSETS = [
‘./eos_apc_editor.html’,
‘./manifest.json’
];

self.addEventListener(‘install’, e => {
e.waitUntil(
caches.open(CACHE).then(cache => cache.addAll(ASSETS))
);
self.skipWaiting();
});

self.addEventListener(‘activate’, e => {
e.waitUntil(
caches.keys().then(keys =>
Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
)
);
self.clients.claim();
});

self.addEventListener(‘fetch’, e => {
// Never intercept status/fire API calls — always go live to the bridge
if (e.request.url.includes(‘127.0.0.1:9002’)) {
return;
}
// For everything else: network first, fall back to cache
e.respondWith(
fetch(e.request).catch(() => caches.match(e.request))
);
});