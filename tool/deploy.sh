#!/usr/bin/env bash
# Builds the web release, stamps it with a version, and publishes it to
# GitHub Pages — which is how the player actually gets to play.
#
#     tool/deploy.sh
#
# The version is the branch's commit count, so it goes up by one every time
# and can be compared at a glance; the build id is the commit itself. Both
# are printed at the end and shown at the top of the song list, so "is this
# the build with the fix in it" has an answer that does not need guessing.
set -euo pipefail

BRANCH=$(git rev-parse --abbrev-ref HEAD)
SHA=$(git rev-parse --short HEAD)
VERSION=$(git rev-list --count HEAD)
WORKTREE=${PAGES_WORKTREE:-/tmp/pages}

if [ -n "$(git status --porcelain)" ]; then
  echo "Çalışma dizini temiz değil — önce commit edin." >&2
  exit 1
fi

flutter build web --release --base-href /Claude/ \
  --pwa-strategy=none \
  --dart-define=BUILD_ID="$SHA" \
  --dart-define=APP_VERSION="$VERSION"

# Cache-busting. A phone that has the game on its home screen keeps its own
# copy of the page and of the code, and will happily go on running a build
# from hours ago — which is indistinguishable, from the player's side, from a
# fix that did not work. The page carries its build number; version.json says
# what the current one is; the script in index.html compares them. Not
# version.json — Flutter writes its own there, from pubspec.
sed -i "s|BUILD_STAMP|$VERSION|" build/web/index.html
sed -i "s|flutter_bootstrap.js|flutter_bootstrap.js?v=$VERSION|" build/web/index.html
sed -i "s|\"mainJsPath\":\"main.dart.js\"|\"mainJsPath\":\"main.dart.js?v=$VERSION\"|" \
  build/web/flutter_bootstrap.js
printf '{"version":"%s","build":"%s"}\n' "$VERSION" "$SHA" > build/web/build.json

# The published branch is a worktree so the source checkout is never touched.
if [ ! -d "$WORKTREE" ]; then
  git worktree add "$WORKTREE" gh-pages
fi
git -C "$WORKTREE" fetch origin gh-pages
git -C "$WORKTREE" reset --hard origin/gh-pages

rm -rf "${WORKTREE:?}"/*
cp -r build/web/* "$WORKTREE"/
echo "v$VERSION $SHA" > "$WORKTREE/.last_build_id"

git -C "$WORKTREE" add -A
git -C "$WORKTREE" commit -q -m "Piano Flow v$VERSION ($SHA)"
git -C "$WORKTREE" push -q origin gh-pages
git push -q -u origin "$BRANCH"

echo
echo "v$VERSION · $SHA  →  https://omerrdeniz.github.io/Claude/"
