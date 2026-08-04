#!/usr/bin/env bash
set -euo pipefail

# Local nightly build: Release build carrying the nightly channel identity
# ("cmux NIGHTLY", com.cmuxterm.app.nightly, AppIcon-Nightly, cmux-nightly URL
# scheme), installed to a persistent location and launched.
#
# This is the local counterpart of the identity injection in
# .github/workflows/nightly.yml. It deliberately does NOT sign with Developer ID
# or notarize; a local nightly is ad-hoc signed, which is enough to launch it.
#
# Derived data stays in /tmp (build cache, disposable). The installed app does
# not: it lands in ~/Applications so it survives reboots and /tmp cleanup.
#
# Sparkle: the feed points at the nightly appcast for channel parity, but
# automatic checks are disabled so a local build never silently replaces itself
# with a downloaded nightly.

APP_NAME="cmux NIGHTLY"
BUNDLE_ID="com.cmuxterm.app.nightly"
BASE_APP_NAME="cmux"
ICON_NAME="AppIcon-Nightly"
FEED_URL="https://files.cmux.com/nightly/appcast.xml"
URL_SCHEME="cmux-nightly"
SOCKET_PATH="/tmp/cmux-nightly.sock"
LOCAL_ENTITLEMENTS="cmux.local-nightly.entitlements"

TAG=""
DERIVED_DATA=""
DERIVED_SET=0
INSTALL_DIR="$HOME/Applications"
DO_INSTALL=1
DO_LAUNCH=1

usage() {
  cat <<'EOF'
Usage: ./scripts/reloadn.sh [options]

Release build with the nightly channel identity ("cmux NIGHTLY"). Runs
side-by-side with the production cmux app and with dev/staging builds.

Options:
  --tag <name>           Short tag for parallel builds. Only scopes the derived
                         data path; the app identity stays on the nightly channel
                         so it matches what ships.
  --derived-data <path>  Override derived data path.
  --install-dir <path>   Where to install the built app (default ~/Applications).
  --no-install           Leave the app in derived data; do not install it.
  --no-launch            Build and install without launching.
  -h, --help             Show this help.
EOF
}

sanitize_path() {
  local raw="$1"
  echo "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      TAG="${2:-}"
      if [[ -z "$TAG" ]]; then
        echo "error: --tag requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    --derived-data)
      DERIVED_DATA="${2:-}"
      if [[ -z "$DERIVED_DATA" ]]; then
        echo "error: --derived-data requires a value" >&2
        exit 1
      fi
      DERIVED_SET=1
      shift 2
      ;;
    --install-dir)
      INSTALL_DIR="${2:-}"
      if [[ -z "$INSTALL_DIR" ]]; then
        echo "error: --install-dir requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    --no-install)
      DO_INSTALL=0
      shift
      ;;
    --no-launch)
      DO_LAUNCH=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$DERIVED_SET" -eq 0 ]]; then
  if [[ -n "$TAG" ]]; then
    TAG_SLUG="$(sanitize_path "$TAG")"
    if [[ -z "$TAG_SLUG" ]]; then
      echo "error: --tag must contain at least one alphanumeric character" >&2
      exit 1
    fi
    DERIVED_DATA="/tmp/cmux-nightly-${TAG_SLUG}"
  else
    DERIVED_DATA="/tmp/cmux-nightly"
  fi
fi

# Ad-hoc sign during the build. The Release entitlements are scoped to the
# Manaflow team (see cmux.nightly.entitlements), so a contributor signing with
# their own certificate cannot satisfy them and the build fails with
# "has entitlements that require signing with a development certificate".
# Drop the team-scoped entitlements for the Xcode build so nested code is signed
# successfully; the compatible local app entitlements are applied after staging.
# Developer ID signing and notarization stay in CI.
xcodebuild \
  -project cmux.xcodeproj \
  -scheme "$BASE_APP_NAME" \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  ASSETCATALOG_COMPILER_APPICON_NAME="$ICON_NAME" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_ENTITLEMENTS="" \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  build

PRODUCTS_DIR="${DERIVED_DATA}/Build/Products/Release"
BUILT_APP="${PRODUCTS_DIR}/${BASE_APP_NAME}.app"
if [[ ! -d "$BUILT_APP" ]]; then
  echo "error: ${BASE_APP_NAME}.app not found at ${BUILT_APP}" >&2
  exit 1
fi

# Stage a copy so the raw build product keeps its stable identity and repeated
# runs are idempotent.
STAGED_APP="${PRODUCTS_DIR}/${APP_NAME}.app"
rm -rf "$STAGED_APP"
cp -R "$BUILT_APP" "$STAGED_APP"
INFO_PLIST="${STAGED_APP}/Contents/Info.plist"

plist_set() {
  local key="$1"
  local type="$2"
  local value="$3"
  /usr/libexec/PlistBuddy -c "Set :${key} ${value}" "$INFO_PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :${key} ${type} ${value}" "$INFO_PLIST"
}

BASE_MARKETING="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")"
# Prefix the second-resolution UTC timestamp with a reserved high digit. Current
# CI nightlies use the substantially shorter GITHUB_RUN_ID + two-digit attempt,
# so Sparkle does not immediately offer an official nightly over this local one.
NIGHTLY_BUILD="9$(date -u +%Y%m%d%H%M%S)"
NIGHTLY_MARKETING_VERSION="${BASE_MARKETING}-nightly.local.${NIGHTLY_BUILD}"
SHORT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

plist_set CFBundleName string "$APP_NAME"
plist_set CFBundleDisplayName string "$APP_NAME"
plist_set CFBundleIdentifier string "$BUNDLE_ID"
plist_set CFBundleShortVersionString string "$NIGHTLY_MARKETING_VERSION"
plist_set CFBundleVersion string "$NIGHTLY_BUILD"
plist_set CMUXCommit string "$SHORT_SHA"

# Same guard CI uses: index 1 must be the auth URL type before its scheme is
# rewritten, so a plist reorder fails loudly instead of silently renaming the
# wrong scheme.
URL_TYPE_NAME="$(/usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes:1:CFBundleURLName" "$INFO_PLIST")"
if [[ "$URL_TYPE_NAME" != *.auth ]]; then
  echo "error: expected CFBundleURLTypes[1] to be the auth URL type, found: ${URL_TYPE_NAME}" >&2
  exit 1
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:1:CFBundleURLSchemes:0 ${URL_SCHEME}" "$INFO_PLIST"

plist_set SUFeedURL string "$FEED_URL"
plist_set SUEnableAutomaticChecks bool false
plist_set SUAutomaticallyUpdate bool false

if [[ -d "$PWD/cmuxd" ]]; then
  (cd "$PWD/cmuxd" && zig build -Doptimize=ReleaseFast)
  CMUXD_SRC="$PWD/cmuxd/zig-out/bin/cmuxd"
  if [[ -x "$CMUXD_SRC" ]]; then
    BIN_DIR="${STAGED_APP}/Contents/Resources/bin"
    mkdir -p "$BIN_DIR"
    cp "$CMUXD_SRC" "$BIN_DIR/cmuxd"
    chmod +x "$BIN_DIR/cmuxd"
  fi
fi

# Patching the bundle invalidates the build's signature, so re-sign ad-hoc last.
# Keep the unrestricted runtime/TCC capabilities used by cmux. Team-scoped
# Keychain and WebAuthn entitlements require Manaflow's profile and intentionally
# remain CI-only; local auth uses the repository's file-store fallback.
/usr/bin/codesign \
  --force \
  --options runtime \
  --sign - \
  --timestamp=none \
  --entitlements "$LOCAL_ENTITLEMENTS" \
  --generate-entitlement-der \
  "$STAGED_APP"

./scripts/verify-app-bundle-channel-metadata.sh "$STAGED_APP" nightly

APP_PATH="$STAGED_APP"
INSTALL_STAGE_ROOT=""
INSTALL_BACKUP_ROOT=""

cleanup_install_artifacts() {
  if [[ -n "$INSTALL_STAGE_ROOT" && -d "$INSTALL_STAGE_ROOT" ]]; then
    rm -rf -- "$INSTALL_STAGE_ROOT"
  fi
  if [[ -n "$INSTALL_BACKUP_ROOT" && -d "$INSTALL_BACKUP_ROOT" ]]; then
    rm -rf -- "$INSTALL_BACKUP_ROOT"
  fi
}
trap cleanup_install_artifacts EXIT

app_path_is_running() {
  local app_path="$1"
  pgrep -f "${app_path}/Contents/MacOS/${BASE_APP_NAME}" >/dev/null 2>&1
}

stop_running_nightly() {
  if ! pgrep -f "${APP_NAME}.app/Contents/MacOS/${BASE_APP_NAME}" >/dev/null 2>&1; then
    return 0
  fi

  echo "Requesting the running Nightly to quit; confirm its close dialog if one appears..."
  /usr/bin/osascript -e "with timeout of 5 seconds
tell application id \"${BUNDLE_ID}\" to quit
end timeout" >/dev/null 2>&1 || true

  local attempt=0
  local max_attempts=120
  while [[ "$attempt" -lt "$max_attempts" ]]; do
    if ! pgrep -f "${APP_NAME}.app/Contents/MacOS/${BASE_APP_NAME}" >/dev/null 2>&1; then
      break
    fi
    attempt=$((attempt + 1))
    sleep 0.25
  done

  if pgrep -f "${APP_NAME}.app/Contents/MacOS/${BASE_APP_NAME}" >/dev/null 2>&1; then
    echo "error: cmux NIGHTLY is still running; the installed bundle was not replaced" >&2
    echo "hint: confirm the app's close dialog, then rerun this command" >&2
    return 1
  fi

  if [[ -S "$SOCKET_PATH" ]]; then
    rm -f "$SOCKET_PATH"
  fi
}

if [[ "$DO_INSTALL" -eq 1 ]]; then
  mkdir -p "$INSTALL_DIR"
  INSTALLED_APP="${INSTALL_DIR}/${APP_NAME}.app"

  if [[ "$DO_LAUNCH" -eq 0 ]] && app_path_is_running "$INSTALLED_APP"; then
    echo "error: refusing to replace the running app while --no-launch is set:" >&2
    echo "  ${INSTALLED_APP}" >&2
    echo "hint: add --no-install to validate without touching it, or omit --no-launch to replace and relaunch it." >&2
    exit 1
  fi

  # Fully copy and verify the candidate before touching the current install.
  # Both temporary roots live beside the destination, so the final renames stay
  # on one filesystem and a failed swap can restore the previous bundle.
  INSTALL_STAGE_ROOT="$(mktemp -d "${INSTALL_DIR}/.cmux-nightly-install.XXXXXX")"
  INSTALL_CANDIDATE="${INSTALL_STAGE_ROOT}/${APP_NAME}.app"
  /usr/bin/ditto "$STAGED_APP" "$INSTALL_CANDIDATE"
  xattr -dr com.apple.quarantine "$INSTALL_CANDIDATE" 2>/dev/null || true
  ./scripts/verify-app-bundle-channel-metadata.sh "$INSTALL_CANDIDATE" nightly

  if [[ "$DO_LAUNCH" -eq 1 ]]; then
    stop_running_nightly
  fi

  if [[ -e "$INSTALLED_APP" ]]; then
    INSTALL_BACKUP_ROOT="$(mktemp -d "${INSTALL_DIR}/.cmux-nightly-backup.XXXXXX")"
    mv "$INSTALLED_APP" "${INSTALL_BACKUP_ROOT}/${APP_NAME}.app"
  fi

  if ! mv "$INSTALL_CANDIDATE" "$INSTALLED_APP"; then
    ROLLBACK_RESULT="no previous bundle needed restoration"
    if [[ -n "$INSTALL_BACKUP_ROOT" && -e "${INSTALL_BACKUP_ROOT}/${APP_NAME}.app" ]]; then
      if mv "${INSTALL_BACKUP_ROOT}/${APP_NAME}.app" "$INSTALLED_APP"; then
        ROLLBACK_RESULT="restored the previous bundle"
        INSTALL_BACKUP_ROOT=""
      else
        ROLLBACK_RESULT="automatic rollback failed; manual recovery is required"
        echo "error: automatic rollback also failed; the previous bundle remains at:" >&2
        echo "  ${INSTALL_BACKUP_ROOT}/${APP_NAME}.app" >&2
        # Preserve the backup for manual recovery instead of deleting it in the
        # EXIT trap.
        INSTALL_BACKUP_ROOT=""
      fi
    fi
    echo "error: failed to install the new Nightly app; ${ROLLBACK_RESULT}" >&2
    exit 1
  fi

  cleanup_install_artifacts
  INSTALL_STAGE_ROOT=""
  INSTALL_BACKUP_ROOT=""
  APP_PATH="$INSTALLED_APP"
fi

echo "Nightly app:"
echo "  ${APP_PATH}"
echo "  ${NIGHTLY_MARKETING_VERSION} (${NIGHTLY_BUILD}), commit ${SHORT_SHA}"

if [[ "$DO_LAUNCH" -eq 0 ]]; then
  exit 0
fi

APP_PROCESS_PATH="${APP_PATH}/Contents/MacOS/${BASE_APP_NAME}"

# Installation already stopped the old app immediately before the swap. A
# no-install launch still needs the same bounded shutdown before opening the
# staged bundle.
if [[ "$DO_INSTALL" -eq 0 ]]; then
  stop_running_nightly
fi

# Avoid inheriting cmux/ghostty environment variables from the terminal that
# runs this script (often inside another cmux instance), which can cause socket
# and resource-path conflicts.
OPEN_CLEAN_ENV=(
  env
  -u CMUX_SOCKET_PATH
  -u CMUX_SOCKET_PASSWORD
  -u CMUX_TAB_ID
  -u CMUX_PANEL_ID
  -u CMUXD_UNIX_PATH
  -u CMUX_TAG
  -u CMUX_BUNDLE_ID
  -u CMUX_SHELL_INTEGRATION
  -u GHOSTTY_BIN_DIR
  -u GHOSTTY_RESOURCES_DIR
  -u GHOSTTY_SHELL_FEATURES
  # Dev shells (including CI/Codex) often force-disable paging by exporting these.
  # Don't leak that into cmux, otherwise `git diff` won't page even with PAGER=less.
  -u GIT_PAGER
  -u GH_PAGER
  -u TERMINFO
  -u XDG_DATA_DIRS
)

"${OPEN_CLEAN_ENV[@]}" open -g "$APP_PATH"

# `open` reports success as soon as LaunchServices accepts the request, so
# confirm the process actually came up rather than trusting the exit code.
ATTEMPT=0
MAX_ATTEMPTS=40
while [[ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]]; do
  if pgrep -f "$APP_PROCESS_PATH" >/dev/null 2>&1; then
    echo "Nightly launch status:"
    echo "  running: ${APP_PROCESS_PATH}"
    exit 0
  fi
  ATTEMPT=$((ATTEMPT + 1))
  sleep 0.25
done

echo "error: launch was requested, but no running process was observed for:" >&2
echo "  ${APP_PROCESS_PATH}" >&2
echo "hint: check Gatekeeper with: spctl -a -vv \"${APP_PATH}\"" >&2
echo "hint: launch directly to see startup output: \"${APP_PROCESS_PATH}\"" >&2
exit 1
