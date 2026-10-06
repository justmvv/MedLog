#!/usr/bin/env bash
# Сборка PWA. Каждой сборке — уникальный BUILD_ID: он попадает в приложение
# (экран «Схема») и в sw.js вместе со списком файлов для офлайн-кэша,
# поэтому браузер видит новую версию и предлагает обновиться.
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_ID="${BUILD_ID:-$(date +%Y%m%d-%H%M%S)}"
flutter build web --release --no-web-resources-cdn \
  --dart-define=BUILD_ID="$BUILD_ID" "$@"

python3 - "$BUILD_ID" <<'PY'
import json, os, sys
build = sys.argv[1]
root = 'build/web'
# встроенный SW Flutter не используется
for f in ('flutter_service_worker.js',):
    p = os.path.join(root, f)
    if os.path.exists(p):
        os.remove(p)
skip_dirs = {'canvaskit'}        # нужный вариант CanvasKit докэшируется по факту загрузки
skip_files = {'sw.js', 'version.json', '.last_build_id', 'NOTICES'}
files = ['./']
for d, dirs, names in os.walk(root):
    rel = os.path.relpath(d, root)
    dirs[:] = [x for x in dirs if not (rel == '.' and x in skip_dirs)]
    for n in names:
        if n in skip_files or n.endswith('.symbols'):
            continue
        files.append(os.path.normpath(os.path.join(rel, n)).replace(os.sep, '/'))
files.sort()
sw = os.path.join(root, 'sw.js')
s = open(sw, encoding='utf-8').read()
s = s.replace("'__BUILD__'", json.dumps(build))
start = s.index('/*__PRECACHE__*/')
end = s.index(';', start)
s = s[:start] + json.dumps(files, ensure_ascii=False) + s[end:]
open(sw, 'w', encoding='utf-8').write(s)
v = os.path.join(root, 'version.json')
meta = json.load(open(v))
meta['build_id'] = build
json.dump(meta, open(v, 'w'))
print(f'BUILD_ID={build}, precache: {len(files)} файлов')
PY
