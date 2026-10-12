/// App version, compiled in by tool/build_web.sh: the name comes from
/// `version:` in pubspec.yaml, the build number is the GitHub Actions run
/// number (from pubspec when built locally), the commit is `git rev-parse`.
/// Empty in debug builds (`flutter run`).
library;

const appVersion = String.fromEnvironment('APP_VERSION');
const buildNumber = String.fromEnvironment('BUILD_NUMBER');
const commit = String.fromEnvironment('COMMIT');

/// "Версия 1.0.0 · сборка 12 (a1b2c3d)" or "Отладочная сборка" (debug build).
String get versionLabel {
  if (appVersion.isEmpty) return 'Отладочная сборка';
  return [
    'Версия $appVersion',
    if (buildNumber.isNotEmpty) '· сборка $buildNumber',
    if (commit.isNotEmpty)
      '(${commit.length > 7 ? commit.substring(0, 7) : commit})',
  ].join(' ');
}
