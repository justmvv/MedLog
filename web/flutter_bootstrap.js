{{flutter_js}}
{{flutter_build_config}}

// tool/build_web.sh fills in the build hash: main.dart.js gets a unique URL,
// so no cache can mix files from different versions. Empty in debug builds.
const buildVersion = '';
if (buildVersion) {
  for (const b of _flutter.buildConfig.builds) {
    if (b.mainJsPath) b.mainJsPath += '?v=' + buildVersion;
  }
}

// No serviceWorkerSettings: offline caching is done by our own web/sw.js,
// registered in index.html.
_flutter.loader.load();
