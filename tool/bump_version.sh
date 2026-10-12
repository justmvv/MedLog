#!/usr/bin/env bash
# Bumps the version in pubspec.yaml and opens a section for it under
# "[Не выпущено]" (Unreleased) in CHANGELOG.md.
#   tool/bump_version.sh patch|minor|major
# Then: git commit -am "Version X.Y.Z" && git tag -a vX.Y.Z -m "Version X.Y.Z" && git push --follow-tags
set -euo pipefail
cd "$(dirname "$0")/.."

part=${1:-}
case "$part" in patch|minor|major) ;; *) echo "Usage: $0 patch|minor|major" >&2; exit 1 ;; esac

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
echo "$name → $next. Describe the changes in CHANGELOG.md, then:"
echo "  git commit -am \"Version $next\" && git tag -a v$next -m \"Version $next\" && git push --follow-tags"
