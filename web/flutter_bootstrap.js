{{flutter_js}}
{{flutter_build_config}}

// Собственный service worker (web/sw.js) регистрируется в index.html,
// поэтому встроенный flutter_service_worker.js не подключаем.
_flutter.loader.load();
