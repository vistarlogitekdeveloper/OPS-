#!/usr/bin/env bash
# Cloudflare Workers build script for the OpsApp Flutter web frontend.
#
# Cloudflare's build image has no Flutter SDK, so we download a pinned
# release, then build the web bundle with the backend URL injected.
#
# The Cloudflare project is a Worker (Workers Builds), not a Pages site, so
# the published directory is declared in wrangler.jsonc (assets.directory)
# rather than a dashboard field. Project settings must match:
#   Build command  -> bash tool/cloudflare-build.sh
#   Deploy command -> npx wrangler versions upload
#
# Build variable (Settings → Variables and Secrets → *Build* variables — NOT the
# runtime "Variables and Secrets" section, which the build command never sees):
#   API_BASE_URL  -> the deployed backend base URL, NO trailing slash and NO
#                    /api suffix (ApiConfig appends /api itself).
#
# Optional: if unset, the build falls back to DEFAULT_API_BASE_URL below so a
# missing dashboard variable can't break the deploy. Set it explicitly to point
# a branch build at a different backend.
#
# Optional env vars:
#   FLUTTER_VERSION -> defaults to the version below; override to upgrade.
#   ET_APP_ID + ET_WRITE_KEY -> switch usage analytics on (both, or neither;
#                    see below). ET_BASE_URL optional.

set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.41.7}"
FLUTTER_DIR="$HOME/flutter"
ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
ARCHIVE_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${ARCHIVE}"

# The OpsApp backend is mounted inside the Vistar CRM at /api/v1/ops-backend.
# The CRM runs on more than one host; this is only the STARTING backend — the
# app ships knowing about all of them and lets the user switch in Settings, so
# a wrong default here is recoverable without a rebuild (see ApiConfig).
# Points at the production host, which serves live traffic; the Render instance
# is intermittently disabled.
DEFAULT_API_BASE_URL="https://api.vistarlogitek.com/api/v1/ops-backend"

if [ -z "${API_BASE_URL:-}" ]; then
  API_BASE_URL="$DEFAULT_API_BASE_URL"
  echo "WARN: API_BASE_URL build variable not set; falling back to the default"
  echo "      $API_BASE_URL"
  echo "      Set it under Settings -> Variables and Secrets -> Build variables"
  echo "      to override (note: runtime variables are NOT visible here)."
else
  echo "==> API_BASE_URL from build variable: $API_BASE_URL"
fi

# A trailing slash would produce '//api' once ApiConfig appends its suffix.
API_BASE_URL="${API_BASE_URL%/}"
export API_BASE_URL

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

DART_DEFINES=(--dart-define=API_BASE_URL="${API_BASE_URL}")

# Usage analytics (lib/core/telemetry/telemetry.dart). On only when BOTH build
# variables are set (Settings -> Build -> Variables and secrets): ET_APP_ID
# (ops_app) and ET_WRITE_KEY (as a secret). Either missing: no define is passed
# and the app sends nothing, exactly as before. ET_BASE_URL is optional (events
# go to the API host by default). Never echo the key.
if [ -n "${ET_APP_ID:-}" ] && [ -n "${ET_WRITE_KEY:-}" ]; then
  DART_DEFINES+=(--dart-define=ET_APP_ID="${ET_APP_ID}" --dart-define=ET_WRITE_KEY="${ET_WRITE_KEY}")
  if [ -n "${ET_BASE_URL:-}" ]; then
    DART_DEFINES+=(--dart-define=ET_BASE_URL="${ET_BASE_URL}")
  fi
  echo "==> Usage analytics on, as ${ET_APP_ID}"
else
  echo "==> Usage analytics off (ET_APP_ID / ET_WRITE_KEY not set)"
fi

echo "==> Building web bundle (API_BASE_URL=${API_BASE_URL})"
flutter build web --release "${DART_DEFINES[@]}"

echo "==> Done. Build output directory: build/web"
