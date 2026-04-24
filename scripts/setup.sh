#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# shellcheck source=lib/prefer-zig-0.15.sh
source "$SCRIPT_DIR/lib/prefer-zig-0.15.sh"

cd "$PROJECT_DIR"

echo "==> Initializing submodules..."
git submodule update --init --recursive

echo "==> Checking for zig..."
if ! command -v zig &> /dev/null; then
    echo "Error: zig is not installed."
    echo "Install via: brew install zig"
    exit 1
fi

"$SCRIPT_DIR/ensure-ghosttykit.sh"

echo "==> Setup complete!"
echo ""
echo "You can now build and run the app:"
echo "  ./scripts/reload.sh --tag first-run"
