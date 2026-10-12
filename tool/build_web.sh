#!/usr/bin/env bash
# Релизная сборка PWA.
#   tool/build_web.sh [аргументы flutter build web, например --base-href /MedLog/]
#
# Версия: название — из pubspec.yaml (version: X.Y.Z+N), номер сборки — из
# $BUILD_NUMBER (в CI — номер запуска GitHub Actions), иначе из pubspec;
# коммит — $COMMIT или текущий HEAD. Всё вкомпилировано в приложение
# (виден внизу экрана «Схема») и записано в version.json.
#
# BUILD — хеш содержимого сборки. Он попадает в sw.js (вместе со списком файлов
# для офлайн-кэша), поэтому браузер видит новую версию только когда код
# действительно изменился. Скрипты получают уникальные URL (?v=BUILD), чтобы
# memory-cache браузера не подмешал файл из прошлой версии.
#
# id манифеста = base href: id разрешается относительно корня домена, и
# относительный "./" на <user>.github.io/<repo>/ занял бы весь домен.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=build/web

BASE_HREF=/
for ((i = 1; i <= $#; i++)); do
  case "${!i}" in
    --base-href) j=$((i + 1)); BASE_HREF="${!j}" ;;
    --base-href=*) BASE_HREF="${!i#--base-href=}" ;;
  esac
done

PUBSPEC_VERSION=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')
VERSION_NAME=${PUBSPEC_VERSION%%+*}
BUILD_NUMBER=${BUILD_NUMBER:-${PUBSPEC_VERSION##*+}}
COMMIT=${COMMIT:-$(git rev-parse HEAD 2>/dev/null || true)}

flutter build web --release --no-web-resources-cdn \
  --build-name="$VERSION_NAME" --build-number="$BUILD_NUMBER" \
  --dart-define=APP_VERSION="$VERSION_NAME" \
  --dart-define=BUILD_NUMBER="$BUILD_NUMBER" \
  --dart-define=COMMIT="$COMMIT" \
  "$@"

rm -f "$OUT/flutter_service_worker.js"   # используется собственный web/sw.js

BUILD=$( (cat "$OUT/main.dart.js" "$OUT/flutter_bootstrap.js" "$OUT/index.html" "$OUT/manifest.json"
          find "$OUT/assets" "$OUT/icons" -type f | LC_ALL=C sort | xargs cat) | shasum -a 256 | cut -c1-12)

sed -i.bak "s/^const buildVersion = '';/const buildVersion = '$BUILD';/" "$OUT/flutter_bootstrap.js"
sed -i.bak "s#src=\"flutter_bootstrap.js\"#src=\"flutter_bootstrap.js?v=$BUILD\"#" "$OUT/index.html"
sed -i.bak "s#\"id\": \"[^\"]*\"#\"id\": \"$BASE_HREF\"#" "$OUT/manifest.json"
rm -f "$OUT"/*.bak

python3 - "$OUT" "$BUILD" "$VERSION_NAME+$BUILD_NUMBER" "$COMMIT" <<'PY'
import json, os, sys
out, build, version, commit = sys.argv[1:]
skip_dirs = {'canvaskit'}    # нужный браузеру вариант CanvasKit докэшируется по факту загрузки
skip_files = {'sw.js', 'version.json', '.last_build_id', 'NOTICES'}
files = ['./']
for d, dirs, names in os.walk(out):
    rel = os.path.relpath(d, out)
    dirs[:] = [x for x in dirs if not (rel == '.' and x in skip_dirs)]
    for n in names:
        if n in skip_files or n.endswith('.symbols'):
            continue
        files.append(os.path.normpath(os.path.join(rel, n)).replace(os.sep, '/'))
files.sort()

sw_path = os.path.join(out, 'sw.js')
sw = open(sw_path, encoding='utf-8').read()
sw = sw.replace("'__BUILD__'", json.dumps(build)).replace("'__VERSION__'", json.dumps(version))
start = sw.index('/*__PRECACHE__*/')
sw = sw[:start] + json.dumps(files, ensure_ascii=False) + sw[sw.index(';', start):]
open(sw_path, 'w', encoding='utf-8').write(sw)

v_path = os.path.join(out, 'version.json')
meta = json.load(open(v_path))
meta.update(build=build, commit=commit)
json.dump(meta, open(v_path, 'w'), ensure_ascii=False)
print(f'precache: {len(files)} файлов')
PY

grep -q "buildVersion = '$BUILD'" "$OUT/flutter_bootstrap.js"
grep -q "flutter_bootstrap.js?v=$BUILD" "$OUT/index.html"
grep -q "\"id\": \"$BASE_HREF\"" "$OUT/manifest.json"
grep -q "const BUILD = \"$BUILD\"" "$OUT/sw.js"
echo "Версия $VERSION_NAME+$BUILD_NUMBER, коммит ${COMMIT:0:7}, сборка $BUILD, base href $BASE_HREF"
