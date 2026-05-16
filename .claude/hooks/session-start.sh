#!/bin/bash
# Installs the Flutter SDK into the Claude Code on the web sandbox so that
# `flutter analyze`, `flutter test`, and `dart test` work without manual setup.
#
# There is no official Flutter apt repository; the supported install method on
# Linux is to download the SDK tarball from storage.googleapis.com. We extract
# it to /opt/flutter (cached across runs once warm) and export PATH for the
# session via $CLAUDE_ENV_FILE.
set -euo pipefail

# Only run inside Claude Code on the web; locally developers manage their own
# Flutter install per https://docs.flutter.dev/install.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_HOME="/opt/flutter"
FLUTTER_BIN="$FLUTTER_HOME/bin"
PUB_CACHE="${PUB_CACHE:-/root/.pub-cache}"

install_flutter() {
  if [ -x "$FLUTTER_BIN/flutter" ]; then
    echo "[session-start] Flutter already installed at $FLUTTER_HOME"
    return 0
  fi

  echo "[session-start] Resolving latest stable Flutter release..."
  local manifest archive base_url url tmp
  manifest="$(curl -fsSL --max-time 30 \
    https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json)"
  archive="$(echo "$manifest" | python3 -c "
import json, sys
d = json.load(sys.stdin)
stable = d['current_release']['stable']
rel = next(r for r in d['releases'] if r['hash'] == stable)
print(rel['archive'])
")"
  base_url="$(echo "$manifest" | python3 -c "import json,sys;print(json.load(sys.stdin)['base_url'])")"
  url="$base_url/$archive"

  tmp="$(mktemp -d)"
  echo "[session-start] Downloading $url"
  curl -fsSL --max-time 600 -o "$tmp/flutter.tar.xz" "$url"

  echo "[session-start] Extracting to $FLUTTER_HOME"
  mkdir -p "$(dirname "$FLUTTER_HOME")"
  tar -xJf "$tmp/flutter.tar.xz" -C /opt
  rm -rf "$tmp"

  # Flutter refuses to run from a path it considers "dubious" git ownership.
  git config --global --add safe.directory "$FLUTTER_HOME" || true
}

warm_caches() {
  export PATH="$FLUTTER_BIN:$PATH"
  export PUB_CACHE

  # Disable analytics/telemetry in CI-like environments.
  flutter --disable-analytics >/dev/null 2>&1 || true
  flutter config --no-cli-animations >/dev/null 2>&1 || true

  echo "[session-start] flutter --version"
  flutter --version || true

  local engine_dir="$CLAUDE_PROJECT_DIR/pv_calculator_dexus_overlay/packages/pv_engine"
  local app_dir="$CLAUDE_PROJECT_DIR/pv_calculator_dexus_overlay/app/flutter_app"

  if [ -f "$engine_dir/pubspec.yaml" ]; then
    echo "[session-start] dart pub get (pv_engine)"
    (cd "$engine_dir" && dart pub get) || echo "[session-start] WARN: dart pub get failed"
  fi

  if [ -f "$app_dir/pubspec.yaml" ]; then
    echo "[session-start] flutter pub get (flutter_app)"
    (cd "$app_dir" && flutter pub get) || echo "[session-start] WARN: flutter pub get failed"
  fi
}

export_env() {
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    {
      echo "export PATH=\"$FLUTTER_BIN:\$PATH\""
      echo "export PUB_CACHE=\"$PUB_CACHE\""
    } >> "$CLAUDE_ENV_FILE"
  fi
}

install_flutter
warm_caches
export_env

echo "[session-start] done"
