---
name: cmux
description: End-user control of cmux topology and routing (windows, workspaces, panes/surfaces, focus, moves, reorder, identify, trigger flash). Use when automation needs deterministic placement and navigation in a multi-pane cmux layout.
---

# cmux Core Control

Use this skill to control non-browser cmux topology and routing.

## Core Concepts

- Window: top-level macOS cmux window.
- Workspace: tab-like group within a window.
- Pane: split container in a workspace.
- Surface: a tab within a pane (terminal or browser panel).

## Fast Start

```bash
# identify current caller context
cmux identify --json

# list topology
cmux list-windows
cmux list-workspaces
cmux list-panes
cmux list-pane-surfaces --pane pane:1

# create/focus/move
cmux new-workspace
cmux new-split right --panel pane:1
cmux move-surface --surface surface:7 --pane pane:2 --focus true
cmux split-off --surface surface:7 right
cmux reorder-surface --surface surface:7 --before surface:3

# attention cue
cmux trigger-flash --surface surface:7
```

## Settings and Docs

Use `cmux docs settings` before changing cmux-owned settings. It prints the docs URL, schema URL, raw GitHub resources, cmux.json paths, and reload command.

```bash
cmux docs settings
cmux settings path
```

cmux-owned settings live in `~/.config/cmux/cmux.json`. Legacy `~/.config/cmux/settings.json` and `~/Library/Application Support/com.cmuxterm.app/settings.json` files are read only as fallback for missing keys. Before editing, copy any existing `cmux.json` file to a timestamped `.bak` next to it so the user can revert. Edit the user file, then reload:

```bash
cmux reload-config
```

`cmux reload-config` reloads BOTH `cmux.json` and Ghostty config (`~/.config/ghostty/config`) and refreshes terminals in place. No app restart needed.

Use cmux settings for app behavior, sidebar, notifications, browser behavior, automation, workspace colors, and cmux-owned shortcuts. Terminal rendering settings such as font, cursor style, theme, scrollback, background transparency (`background-opacity`), and blur (`background-blur`) belong in Ghostty config at `~/.config/ghostty/config`.

Open the UI when useful:

```bash
cmux settings
cmux settings cmux-json
cmux settings shortcuts
```

## Bartosz Fork Maintenance

This checkout is a fork used for Bartosz's personal cmux build. The clean personal branch is now:

```bash
dev/bdec
```

Treat `dev/bdec` as the fork main for future updates. Do not base new personal-fork work on the old `dev/local` branch unless the user explicitly asks; `dev/local` contains older local experiments and extra mess.

The intended shape of `dev/bdec` is a small stack on top of current `upstream/main`:

1. `Support Home/End/PageUp/PageDown as shortcut keys`
2. `Lower minimum sidebar width from 180 to 120`

When updating to a newer upstream, create or refresh a worktree from `upstream/main`, then replay only those personal commits unless the user asks for more. Verify the resulting branch is only the expected number of commits ahead:

```bash
git fetch upstream main
git checkout dev/bdec
git rev-list --count upstream/main..HEAD
git diff --stat upstream/main..HEAD
```

For isolated builds of this branch, use tag `dev-bdec`:

```bash
./scripts/reload.sh --tag dev-bdec
```

On this machine, the full Ghostty CLI helper build may fail if Xcode's Metal Toolchain is missing. It is acceptable for Swift/app verification to use the repo-supported skip:

```bash
CMUX_SKIP_ZIG_BUILD=1 PATH="/opt/homebrew/opt/zig@0.15/bin:$PATH" ./scripts/reload.sh --tag dev-bdec
```

The previous working personal app was `cmux DEV local`, bundle id `com.cmuxterm.app.debug.local`. The new personal app is `cmux DEV dev-bdec`, bundle id `com.cmuxterm.app.debug.dev.bdec`. When preparing a fresh `dev-bdec` build, copy preferences and session state from the old local build so shortcuts and layout carry over:

```bash
SRC_BUNDLE="com.cmuxterm.app.debug.local"
DST_BUNDLE="com.cmuxterm.app.debug.dev.bdec"
TMP_PREF="$(mktemp /tmp/cmux-local-prefs.XXXXXX.plist)"
defaults export "$SRC_BUNDLE" "$TMP_PREF"
defaults import "$DST_BUNDLE" "$TMP_PREF"
rm -f "$TMP_PREF"

SRC_SESSION="$HOME/Library/Application Support/cmux/session-${SRC_BUNDLE}.json"
DST_SESSION="$HOME/Library/Application Support/cmux/session-${DST_BUNDLE}.json"
if [ -f "$SRC_SESSION" ]; then
  cp -p "$SRC_SESSION" "$DST_SESSION"
fi
```

Important launch note: on this machine, `reload.sh --launch` may start a tagged app by directly running `Contents/MacOS/cmux DEV`, which can exit immediately. If the tagged app closes right away with no crash, launch the app bundle through LaunchServices instead:

```bash
APP_PATH="$HOME/Library/Developer/Xcode/DerivedData/cmux-dev-bdec/Build/Products/Debug/cmux DEV dev-bdec.app"
/usr/bin/osascript -e 'tell application id "com.cmuxterm.app.debug.dev.bdec" to quit' >/dev/null 2>&1 || true
open -n "$APP_PATH"
```

The expected tagged socket and debug log are:

```bash
/tmp/cmux-debug-dev-bdec.sock
/tmp/cmux-debug-dev-bdec.log
```

## Handle Model

- Default output uses short refs: `window:N`, `workspace:N`, `pane:N`, `surface:N`.
- UUIDs are still accepted as inputs.
- Request UUID output only when needed: `--id-format uuids|both`.

## Deep-Dive References

| Reference | When to Use |
|-----------|-------------|
| [references/handles-and-identify.md](references/handles-and-identify.md) | Handle syntax, self-identify, caller targeting |
| [references/windows-workspaces.md](references/windows-workspaces.md) | Window/workspace lifecycle and reorder/move |
| [references/panes-surfaces.md](references/panes-surfaces.md) | Splits, surfaces, move/reorder, focus routing |
| [references/trigger-flash-and-health.md](references/trigger-flash-and-health.md) | Flash cue and surface health checks |
| [../cmux-workspace/SKILL.md](../cmux-workspace/SKILL.md) | Current caller workspace rules and non-disruptive automation |
| [../cmux-settings/SKILL.md](../cmux-settings/SKILL.md) | Safe cmux.json settings edits and validation |
| [../cmux-browser/SKILL.md](../cmux-browser/SKILL.md) | Browser automation on surface-backed webviews |
| [../cmux-markdown/SKILL.md](../cmux-markdown/SKILL.md) | Markdown viewer panel with live file watching |
