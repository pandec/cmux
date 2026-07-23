---
name: cmux
description: End-user control of cmux topology and routing, plus Bartosz fork maintenance and upstream-sync workflow. Use for deterministic cmux placement/navigation or when aligning, testing, rebuilding, or cleaning the dev/bdec personal build.
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

The intended shape of `dev/bdec` is a small personal stack on top of current `upstream/main`. Preserve the currently merged fork work, including:

1. `Support Home/End/PageUp/PageDown as shortcut keys`
2. `Lower minimum sidebar width from 180 to 120`
3. Compact narrow-sidebar titlebar controls
4. Configurable MRU surface cycling
5. This project-local cmux skill

### Upstream sync

Keep the running `dev-bdec` app and main checkout untouched while preparing an update:

1. Fetch `upstream/main` and `origin/dev/bdec` without recursively fetching submodules. Record the old and new upstream SHAs.
2. Create the next `dev/bdecN` sibling worktree from `dev/bdec`, then rebase with `--rebase-merges` onto `upstream/main`.
3. Preserve all current personal commits and merged PR behavior. Drop a fork commit only when the upstream range contains an equivalent or newer change, and report it.
4. Verify with `git range-diff`, the ahead count, a clean status, exact submodule revisions, an isolated tagged app build, and the `cmux-unit` scheme when app/package/test APIs changed.
5. Push the test branch before dogfood.

For a test build, copy only preferences from the real `dev-bdec` bundle. Never copy its session/workspace JSON. Remove or archive any stale test session before launch so the test app starts with a fresh workspace while retaining shortcuts and settings.

```bash
SRC_BUNDLE="com.cmuxterm.app.debug.dev.bdec"
DST_BUNDLE="com.cmuxterm.app.debug.dev.bdecN"
TMP_PREF="$(mktemp /tmp/cmux-dev-bdecN-prefs.XXXXXX.plist)"
defaults export "$SRC_BUNDLE" "$TMP_PREF"
defaults import "$DST_BUNDLE" "$TMP_PREF"

TEST_SESSION="$HOME/Library/Application Support/cmux/session-${DST_BUNDLE}.json"
# Archive TMP_PREF and TEST_SESSION instead of deleting them when present.
```

Build the candidate with its numbered tag and launch the app bundle through LaunchServices:

```bash
CMUX_SKIP_ZIG_BUILD=1 PATH="/opt/homebrew/opt/zig@0.15/bin:$PATH" \
  ./scripts/reload.sh --tag dev-bdecN
open -n "$HOME/Library/Developer/Xcode/DerivedData/cmux-dev-bdecN/Build/Products/Debug/cmux DEV dev-bdecN.app"
```

After the user approves the candidate:

1. Back up the real `dev-bdec` plist and session JSON beside the originals with a timestamp; verify byte-identical checksums.
2. Promote the exact tested commit to `dev/bdec` and push with an exact `--force-with-lease`.
3. Build tag `dev-bdec`, launch its `.app` with `open -n`, and verify its process, socket, and restored workspace list.
4. Never copy the test session or test preferences back to the real bundle.

### Required cleanup

Every completed upstream sync must remove all test leftovers after the real app is verified:

- Stop the numbered test app.
- Remove its sibling worktree and local/remote test branch.
- Archive/remove its preferences, session JSON, tagged DerivedData, `/tmp/cmux-<tag>` and unit-build directories, debug socket/log, and `cmuxd-dev-<tag>.sock`.
- Reinitialize the main checkout's submodules after removing a worktree with initialized submodules.
- Confirm no test refs, paths, processes, sockets, or logs remain.
- Preserve unrelated main-checkout changes and the real `dev-bdec` backups.

Move filesystem artifacts into one timestamped Trash folder when practical so cleanup is recoverable.

### Required final summary

End every upstream sync with:

1. The old and new upstream SHAs and the resulting `dev/bdec` ahead count.
2. A concise, user-facing summary of what changed in the pulled upstream range, grouped by meaningful cmux areas rather than a raw commit list. Use the recorded upstream range with `git log` and `git diff --stat`.
3. A separate note for fork commits preserved, changed during conflict resolution, or dropped because upstream superseded them.
4. Build/test verification, real app/session verification, backup paths, and explicit confirmation that all test artifacts were cleaned.

Do not omit the upstream-change summary even when the rebase is conflict-free.

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
