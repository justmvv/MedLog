# MedLog: medication log (Flutter → PWA)

An offline app for a regular medication schedule with approximate times:
check off each dose, see a monthly heatmap of how doses were taken and drill
down into any day. The UI is in Russian.

[Open the app](https://justmvv.github.io/MedLog/) · [Changelog](CHANGELOG.md) · [MIT License](LICENSE)

> This is a personal log, not a medical device: it doesn't send reminders and
> doesn't replace a doctor's prescriptions.

## Scenarios

1. **Take a dose**: open the app → "Сегодня" (Today) tab → tap a medication
   row. The actual time is recorded; long-press or ✎ corrects it.
2. **Review the month**: the "Месяц" (Month) tab shows a heatmap of doses
   taken, with month totals: share of doses taken, missed doses, days without
   misses and the average offset from the planned time. Tap a day to see its
   timeline of doses with planned and actual times.

## Data

- Everything is stored on the device (in the PWA, `localStorage` via
  `shared_preferences`); there is no server.
- Changing dose times doesn't rewrite history: the old version of the schedule
  is closed as of today and the new one starts today. "Завершить" (Stop)
  removes a medication from the daily list while keeping past days.

## Building the PWA

```bash
tool/build_web.sh
```

The script runs `flutter build web --release --no-web-resources-cdn`, compiles
in the version (see [Versions](#versions)), writes the build content hash and the
file list into `build/web/sw.js`, gives scripts unique URLs and sets the
manifest `id`. Extra flags are passed through, e.g.
`tool/build_web.sh --base-href /MedLog/`.

The result is `build/web/`: deploy it to any static HTTPS host **as a whole**,
replacing the previous version.

Preview a build locally:

```bash
python3 -m http.server 8765 --directory build/web
```

### Installing

- Chrome / Edge / Android: the "Установить" (Install) bar (the
  `beforeinstallprompt` event), or "Install app" in the browser menu.
- iOS / iPadOS Safari: a one-time hint to use Share → Add to Home Screen.

### Offline and updates

Offline caching is done by our own service worker, [web/sw.js](web/sw.js); the
built-in `flutter_service_worker.js` is disabled in
[web/flutter_bootstrap.js](web/flutter_bootstrap.js).

- Every build is an atomic version in its own `medlog-<build hash>` cache: a
  page always runs on the files of a single version, starts instantly and
  works offline.
- Everything needed goes into the cache on the very first visit, including the
  CanvasKit variant the browser picked and the Google fonts (Cyrillic).
- A new version is looked for on every launch, when returning to the app and
  every 30 minutes. It downloads in the background, then a "Доступна версия
  X.Y.Z" (Version X.Y.Z available) bar with an "Обновить" (Update) button
  appears. If ignored, the new version takes over on the next cold start.
- User data (`localStorage`) is not touched by updates.

Hosting headers: browsers already check `sw.js` bypassing the HTTP cache
(`updateViaCache: 'none'`), but it's best to serve `sw.js` and `index.html` with
`Cache-Control: no-cache`.

## Versions

The version is the `version: X.Y.Z+N` field in [pubspec.yaml](pubspec.yaml)
and follows [Semantic Versioning](https://semver.org/). `tool/build_web.sh`
compiles into the app:

- the version name: `X.Y.Z` from pubspec;
- the build number: `$BUILD_NUMBER` (in CI, the GitHub Actions run number),
  or `N` from pubspec for local builds;
- the commit: `$COMMIT` or the current `HEAD`.

The version is shown at the bottom of the "Схема" (Schedule) screen, e.g.
"Версия 1.0.0 · сборка 12 (a1b2c3d)", and is written to `version.json` and
`sw.js`; the update bar shows the new version number. Debug builds
(`flutter run`) are labeled "Отладочная сборка".

Releasing a new version:

```bash
tool/bump_version.sh minor    # patch | minor | major; then describe the changes in CHANGELOG.md
git commit -am "Version 1.1.0" && git tag v1.1.0 && git push --follow-tags
```

A push to `main` deploys the site to GitHub Pages; a `vX.Y.Z` tag creates a
GitHub release with the zipped build
([.github/workflows/deploy.yml](.github/workflows/deploy.yml)). To enable
deployment, set Settings → Pages → Source to "GitHub Actions".

## Icon and palette

The icon is a faceted (low-poly) cross: the left half herb green, the right half
saturated blue, with light facet lines and a dark outline, in the style of the
calorie_cam icon. [tool/make_icons.py](tool/make_icons.py) (Pillow) renders all
PWA sizes (including maskable and apple-touch-icon), the splash logo and
`assets/logo.png` used in the screen headers.

The palette comes from calorie_cam too: light herb → green → saturated blue
(`C` in [lib/theme.dart](lib/theme.dart)); the heatmap uses the same scale.

## Project structure

- `lib/models.dart`: medications, intakes, day summaries
- `lib/store.dart`: app state and local storage
- `lib/app_version.dart`: version compiled in at build time
- `lib/theme.dart`: palette, hatching, hand-drawn checkbox, logo
- `lib/screens/`: Today, Month (heatmap), day details, schedule
- `test/app_test.dart`: logic tests and an editor smoke test

## License

[MIT](LICENSE) © 2026 Vasilii Morozov
