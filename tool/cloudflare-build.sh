#!/usr/bin/env bash
# Cloudflare Pages build script for the OpsApp Flutter web frontend.
#
# Cloudflare's build image has no Flutter SDK, so we download a pinned
# release, then build the web bundle with the backend URL injected.
#
# Cloudflare Pages project settings must match:
#   Build command       -> bash tool/cloudflare-build.sh
#   Build output directory -> build/web
#
# Required env var (Pages → Settings → Environment variables):
#   API_BASE_URL  -> the deployed backend base URL, e.g.
#                    https://ops-backend-eqqd.onrender.com   (NO trailing slash)
#
# Optional env var:
#   FLUTTER_VERSION -> defaults to the version below; override to upgrade.

set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.41.7}"
FLUTTER_DIR="$HOME/flutter"
ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
ARCHIVE_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${ARCHIVE}"

if [ -z "${API_BASE_URL:-}" ]; then
  echo "ERROR: API_BASE_URL env var is required. Set it in the Cloudflare Pages"
  echo "       dashboard (Settings -> Environment variables) to your backend"
  echo "       URL, e.g. https://ops-backend-eqqd.onrender.com"
  exit 1
fi

if ! command -v xz >/dev/null 2>&1; then
  echo "ERROR: 'xz' is not available in the build image, so the Flutter archive"
  echo "       cannot be extracted. Install xz-utils or pin a build image that"
  echo "       provides it."
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

# The build runs as a non-root user against a fresh checkout; mark both trees
# safe so Flutter's internal git calls don't abort on dubious ownership.
git config --global --add safe.directory "$FLUTTER_DIR" || true
git config --global --add safe.directory "$PWD" || true

flutter --version
flutter config --enable-web
flutter pub get

echo "==> Building web bundle (API_BASE_URL=${API_BASE_URL})"
flutter build web --release --dart-define=API_BASE_URL="${API_BASE_URL}"

echo "==> Done. Build output directory: build/web"
