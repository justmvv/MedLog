/// Версия приложения, вкомпилированная tool/build_web.sh:
/// название — из `version:` в pubspec.yaml, номер сборки — номер запуска
/// GitHub Actions (локально — из pubspec), коммит — `git rev-parse`.
/// В отладочных сборках (`flutter run`) пусто.
library;

const appVersion = String.fromEnvironment('APP_VERSION');
const buildNumber = String.fromEnvironment('BUILD_NUMBER');
const commit = String.fromEnvironment('COMMIT');

/// «Версия 1.0.0 · сборка 12 (a1b2c3d)» или «Отладочная сборка».
String get versionLabel {
  if (appVersion.isEmpty) return 'Отладочная сборка';
  return [
    'Версия $appVersion',
    if (buildNumber.isNotEmpty) '· сборка $buildNumber',
    if (commit.isNotEmpty)
      '(${commit.length > 7 ? commit.substring(0, 7) : commit})',
  ].join(' ');
}
