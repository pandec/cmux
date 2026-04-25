#!/usr/bin/env bash
# Snapshot/apply UserDefaults + session + settings for a tagged dev build.
# Use `snapshot` on the source Mac (commit + push dev/local), `apply` on the target.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SYNC_DIR="$PROJECT_DIR/tmp-sync"
TAG="${CMUX_SYNC_TAG:-local}"
DOMAIN="com.cmuxterm.app.debug.${TAG}"

PLIST_FILE="$SYNC_DIR/${DOMAIN}.plist"
SESSION_FILE="$SYNC_DIR/session-${DOMAIN}.json"
SETTINGS_FILE="$SYNC_DIR/settings.json"

LIVE_SESSION="$HOME/Library/Application Support/cmux/session-${DOMAIN}.json"
LIVE_SETTINGS="$HOME/.config/cmux/settings.json"

usage() {
  cat <<EOF
Usage: $(basename "$0") <snapshot|apply>

  snapshot   Export current ${TAG}-tag config to tmp-sync/ (commit + push after)
  apply      Restore config from tmp-sync/ onto this machine

Tag: ${TAG} (override with CMUX_SYNC_TAG=<tag>)
EOF
  exit 1
}

cmd="${1:-}"
case "$cmd" in
  snapshot)
    mkdir -p "$SYNC_DIR"
    echo "==> Exporting UserDefaults from ${DOMAIN}"
    defaults export "$DOMAIN" "$PLIST_FILE"

    if [[ -f "$LIVE_SESSION" ]]; then
      echo "==> Copying session file"
      cp "$LIVE_SESSION" "$SESSION_FILE"
    else
      echo "warn: no session file at $LIVE_SESSION"
    fi

    if [[ -f "$LIVE_SETTINGS" ]]; then
      echo "==> Copying settings.json"
      cp "$LIVE_SETTINGS" "$SETTINGS_FILE"
    else
      echo "warn: no settings.json at $LIVE_SETTINGS"
    fi

    echo "==> Done. Files in tmp-sync/:"
    ls -1 "$SYNC_DIR"
    echo ""
    echo "Next: git add tmp-sync/ && git commit && git push origin dev/local"
    ;;

  apply)
    [[ -d "$SYNC_DIR" ]] || { echo "error: $SYNC_DIR missing — run 'snapshot' first or pull dev/local"; exit 1; }

    if pgrep -f "cmux DEV ${TAG}.app" >/dev/null 2>&1; then
      echo "error: cmux DEV ${TAG} is running. Quit it first (it overwrites session on quit)."
      exit 1
    fi

    if [[ -f "$PLIST_FILE" ]]; then
      echo "==> Importing UserDefaults to ${DOMAIN}"
      defaults import "$DOMAIN" "$PLIST_FILE"
    else
      echo "warn: no plist at $PLIST_FILE"
    fi

    if [[ -f "$SESSION_FILE" ]]; then
      echo "==> Restoring session file"
      mkdir -p "$(dirname "$LIVE_SESSION")"
      cp "$SESSION_FILE" "$LIVE_SESSION"
    fi

    if [[ -f "$SETTINGS_FILE" ]]; then
      echo "==> Restoring settings.json"
      mkdir -p "$(dirname "$LIVE_SETTINGS")"
      cp "$SETTINGS_FILE" "$LIVE_SETTINGS"
    fi

    echo "==> Done. Now build + launch:"
    echo "  ./scripts/reload.sh --tag ${TAG} --launch"
    ;;

  *)
    usage
    ;;
esac
