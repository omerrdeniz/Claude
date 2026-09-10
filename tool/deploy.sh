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
