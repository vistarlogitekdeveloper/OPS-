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
#   Deploy command -> npx wrangler deploy
#
# NOTE: use `wrangler deploy`, NOT `wrangler versions upload`. The latter
# uploads a version without activating it, so the live URL keeps serving the
# previous bundle and a "successful" build silently changes nothing.
#
# Optional build variable (Settings -> Variables and Secrets -> Build variables):
#   API_BASE_URL  -> the deployed backend base URL, NO trailing slash, e.g.
#                    https://api.vistarlogitek.com/api/v1/ops-backend
#                    Defaults to DEFAULT_API_BASE_URL below when unset.
#
# Optional env var:
#   FLUTTER_VERSION -> defaults to the version below; override to upgrade.

set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.41.7}"
FLUTTER_DIR="$HOME/flutter"
ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
ARCHIVE_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${ARCHIVE}"

# Cloudflare build variables are dashboard-only — there is no in-repo place to
# declare them the way render.yaml does. Rather than fail the build when the
# dashboard has none set, fall back to the same host ApiConfig defaults to and
# say so loudly, so a wrong backend is visible in the build log. NOTE: do NOT
# copy render.yaml:23 — it still pins ops-backend-eqqd.onrender.com, which is
# decommissioned (/api/health returns 503).
DEFAULT_API_BASE_URL="https://api.vistarlogitek.com/api/v1/ops-backend"

if [ -z "${API_BASE_URL:-}" ]; then
  echo "==> API_BASE_URL build variable not set; falling back to the default:"
  echo "    ${DEFAULT_API_BASE_URL}"
  echo "    To point at a different backend, add an API_BASE_URL build variable"
  echo "    under Settings -> Variables and Secrets -> Build variables."
  API_BASE_URL="$DEFAULT_API_BASE_URL"
else
  echo "==> API_BASE_URL from build variable: ${API_BASE_URL}"
fi

# ApiConfig.apiRoot appends its own '/api', so a trailing slash here would
# produce a double slash in every request URL.
API_BASE_URL="${API_BASE_URL%/}"

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
