#!/usr/bin/env bash
# Prepend Homebrew keg-only zig@0.15 to PATH when the system zig isn't 0.15.x.
# Ghostty's build.zig requires zig 0.15.2. This lets us keep a newer system zig
# (e.g. 0.16) without editing the user's shell config.
# Safe to source multiple times; no-op if already satisfied or zig@0.15 is absent.

_cmux_prefer_zig_015() {
  local candidate
  local current

  case ":$PATH:" in
    *":/opt/homebrew/opt/zig@0.15/bin:"*) return 0 ;;
  esac

  current="$(zig version 2>/dev/null || true)"
  case "$current" in
    0.15.*) return 0 ;;
  esac

  for candidate in \
    "/opt/homebrew/opt/zig@0.15/bin" \
    "/usr/local/opt/zig@0.15/bin"; do
    if [[ -x "$candidate/zig" ]]; then
      export PATH="$candidate:$PATH"
      return 0
    fi
  done
}

_cmux_prefer_zig_015
unset -f _cmux_prefer_zig_015
