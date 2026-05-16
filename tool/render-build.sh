#!/usr/bin/env bash
# Render Static Site build script for the OpsApp Flutter web frontend.
#
# Render's static build image has no Flutter SDK, so we download a pinned
# release, then build the web bundle with the backend URL injected.
#
# Required env var (set in the Render Static Site → Environment):
#   API_BASE_URL  -> the deployed backend base URL, e.g.
#                    https://opsapp-backend.onrender.com   (NO trailing slash)
#
# Optional env var:
#   FLUTTER_VERSION -> defaults to the version below; override to upgrade.

set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.41.7}"
FLUTTER_DIR="$HOME/flutter"
ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
ARCHIVE_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${ARCHIVE}"

if [ -z "${API_BASE_URL:-}" ]; then
  echo "ERROR: API_BASE_URL env var is required (set it in the Render dashboard"
  echo "       to your backend URL, e.g. https://opsapp-backend.onrender.com)."
  exit 1
fi

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "==> Downloading Flutter ${FLUTTER_VERSION}"
  curl -fsSL "$ARCHIVE_URL" -o "/tmp/${ARCHIVE}"
  echo "==> Extracting Flutter"
  mkdir -p "$HOME"
  tar -xf "/tmp/${ARCHIVE}" -C "$HOME"
  rm -f "/tmp/${ARCHIVE}"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

# Render's build runs as a non-root user in a fresh checkout; mark it safe.
git config --global --add safe.directory "$FLUTTER_DIR" || true

flutter --version
flutter config --enable-web
flutter pub get

echo "==> Building web bundle (API_BASE_URL=${API_BASE_URL})"
flutter build web --release --dart-define=API_BASE_URL="${API_BASE_URL}"

echo "==> Done. Publish directory: build/web"
