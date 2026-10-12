{{flutter_js}}
{{flutter_build_config}}

// tool/build_web.sh подставляет хеш сборки: main.dart.js получает уникальный
// URL, и никакой кэш не смешает файлы разных версий. В отладке пусто.
const buildVersion = '';
if (buildVersion) {
  for (const b of _flutter.buildConfig.builds) {
    if (b.mainJsPath) b.mainJsPath += '?v=' + buildVersion;
  }
}

// Без serviceWorkerSettings: офлайн-кэш — собственный web/sw.js,
// он регистрируется в index.html.
_flutter.loader.load();
