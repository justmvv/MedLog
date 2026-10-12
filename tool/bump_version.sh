#!/usr/bin/env bash
# Повышает версию в pubspec.yaml и переносит раздел «Не выпущено» в CHANGELOG.md.
#   tool/bump_version.sh patch|minor|major
# После проверки: git commit -am "Версия X.Y.Z" && git tag vX.Y.Z && git push --follow-tags
set -euo pipefail
cd "$(dirname "$0")/.."

part=${1:-}
case "$part" in patch|minor|major) ;; *) echo "Использование: $0 patch|minor|major" >&2; exit 1 ;; esac

current=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')
name=${current%%+*}
build=${current##*+}
IFS=. read -r major minor patch <<<"$name"
case "$part" in
  major) major=$((major + 1)); minor=0; patch=0 ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
esac
next="$major.$minor.$patch"

sed -i.bak "s/^version: .*/version: $next+$((build + 1))/" pubspec.yaml && rm pubspec.yaml.bak

python3 - "$name" "$next" "$(date +%Y-%m-%d)" <<'PY'
import re, sys
prev, nxt, date = sys.argv[1:]
p = 'CHANGELOG.md'
s = open(p, encoding='utf-8').read()
s = s.replace('## [Не выпущено]\n', f'## [Не выпущено]\n\n## [{nxt}] — {date}\n', 1)
s = re.sub(r'\[Не выпущено\]: (.*)/compare/v[\d.]+\.\.\.HEAD',
           lambda m: f'[Не выпущено]: {m.group(1)}/compare/v{nxt}...HEAD\n'
                     f'[{nxt}]: {m.group(1)}/compare/v{prev}...v{nxt}', s, count=1)
open(p, 'w', encoding='utf-8').write(s)
PY
echo "$name → $next. Допишите изменения в CHANGELOG.md, затем:"
echo "  git commit -am \"Версия $next\" && git tag v$next && git push --follow-tags"
