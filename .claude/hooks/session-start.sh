#!/bin/bash
# Installs what this project needs before a Claude Code on the web session
# starts. The container is new every time and its image carries no Flutter, so
# without this every session begins by installing it by hand. See
# docs/DURUM.md, "Ortam kurulumu".
set -euo pipefail

# Only the remote container needs this; a local checkout has its own Flutter.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_DIR="/opt/flutter"
FLUTTER_REF="3.35.1"  # what the project is developed against

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 -b "$FLUTTER_REF" \
    https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$PATH:$FLUTTER_DIR/bin"

# The tool refuses to run inside a checkout whose owner it cannot vouch for.
git config --global --get-all safe.directory | grep -qxF "$FLUTTER_DIR" ||
  git config --global --add safe.directory "$FLUTTER_DIR"

# The first run unpacks the Dart SDK. Paying for it here rather than on the
# first `flutter test` is the whole point of the hook.
flutter --version
flutter config --no-analytics > /dev/null 2>&1 || true

cd "${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
flutter pub get

# Leave Flutter on the PATH for the rest of the session.
if [ -n "${CLAUDE_ENV_FILE:-}" ] &&
   ! grep -qF "$FLUTTER_DIR/bin" "$CLAUDE_ENV_FILE" 2> /dev/null; then
  echo "export PATH=\"\$PATH:$FLUTTER_DIR/bin\"" >> "$CLAUDE_ENV_FILE"
fi
