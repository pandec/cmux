---
name: cmux-dev
description: |
  Manage the personal dev/local branch of cmux — sync with upstream, rebuild tagged builds, migrate settings and workspaces between tags. Use when the user mentions syncing cmux with upstream, rebuilding their local dev build, migrating settings between tagged builds, fixing GhosttyKit build issues, or managing the dev/local branch. Also trigger when they say "update my local build", "sync with upstream", "migrate my workspaces", or reference tagged cmux builds.
---

# cmux Local Dev Branch Management

This skill covers maintaining a personal `dev/local` branch with custom changes on top of upstream cmux, syncing, building, and migrating settings between tagged builds.

## Branch & Build Strategy

- `dev/local` branch holds personal changes rebased on top of `main`
- `main` tracks `origin` (pandec/cmux fork), which tracks `upstream` (manaflow-ai/cmux)
- Build and optionally launch with: `./scripts/reload.sh --tag local --launch`
- Tagged builds get isolated bundle ID: `com.cmuxterm.app.debug.local`
- Hide DEV BUILD banner: `defaults write com.cmuxterm.app.debug.local showSidebarDevBuildBanner -bool false`

## Syncing with Upstream

Run these steps in order:

```bash
# 1. Fetch upstream
git fetch upstream main

# 2. Fast-forward local main and push to fork
git checkout main && git merge --ff-only upstream/main && git push origin main

# 3. Rebase dev/local onto updated main
git checkout dev/local && git rebase main

# 4. Update submodules (ghostty + bonsplit pointers may have changed)
git submodule update --init --recursive
```

When resolving rebase conflicts, check if upstream already merged equivalent changes before manually resolving. If a cherry-picked commit conflicts because the feature was merged upstream differently, use `git rebase --skip`.

## GhosttyKit Build Issues

### "tagged releases must be in vX.Y.Z format" crash

The ghostty submodule may have `xcframework-*` or `tip` tags (fetched from the manaflow fork remote) that confuse `zig build` — it uses `git describe --tags` and chokes on non-semver tags.

**Fix:** delete offending tags locally from the submodule:

```bash
git -C ghostty tag -l 'xcframework-*' | xargs git -C ghostty tag -d
git -C ghostty tag -l 'tip*' | xargs git -C ghostty tag -d
```

**Verify:** `git -C ghostty describe --tags` should return something like `v1.2.0-3704-g3b684a085`

These tags may reappear after `git fetch` in the submodule, so you may need to re-delete after submodule updates.

### No pre-built download

`scripts/ensure-ghosttykit.sh` only builds from source (no remote download). `scripts/ghosttykit-checksums.txt` is for CI verification only. There is a local cache at `~/.cache/cmux/ghosttykit/<sha>/` — if the ghostty SHA matches a cached build, it reuses it.

## Settings & Workspace Migration Between Tagged Builds

Each tagged build is isolated — separate UserDefaults domain, separate session file. To migrate from one tag to another, you need to copy both.

### Gotcha: hyphen-to-dot conversion

macOS converts hyphens in bundle IDs to dots in the defaults domain name:
- Tag `my-dev` -> bundle ID `com.cmuxterm.app.debug.my-dev` -> defaults domain `com.cmuxterm.app.debug.my.dev`
- Tag `local` -> defaults domain `com.cmuxterm.app.debug.local` (no hyphens, no conversion)

To find the right domain: `defaults domains 2>&1 | tr ',' '\n' | grep cmux`

### UserDefaults (shortcuts, appearance, app settings)

Contains: keyboard shortcuts, sidebar appearance (preset, colors, blend mode, material, tint), app behavior flags (telemetry, pane click focus, close-on-last-surface), window geometry, Sparkle update state.

```bash
# Export from source tag
defaults export com.cmuxterm.app.debug.<source.domain> /tmp/defaults.plist

# Import to target tag
defaults import com.cmuxterm.app.debug.<target.domain> /tmp/defaults.plist
```

No need to kill the source app — `defaults export` reads the cached plist.

### Session/Workspace Data

Workspace names, open tabs, terminal state, and layout are stored in session JSON files:

```
~/Library/Application Support/cmux/session-<safeBundleId>.json
```

Where `safeBundleId` = `Bundle.main.bundleIdentifier` with non-`[A-Za-z0-9._-]` replaced by `_`.

**Kill the target build before copying** — it overwrites the session file on quit.

```bash
# Kill target build first
pkill -f "cmux DEV local.app/Contents/MacOS/cmux DEV"
sleep 1

# Copy session
cp ~/Library/Application\ Support/cmux/session-com.cmuxterm.app.debug.my.dev.json \
   ~/Library/Application\ Support/cmux/session-com.cmuxterm.app.debug.local.json
```

### settings.json (shared file-managed overrides)

- Primary: `~/.config/cmux/settings.json`
- Fallback: `~/Library/Application Support/com.cmuxterm.app/settings.json`
- **Shared across ALL builds** — uses hardcoded `com.cmuxterm.app`, not the running bundle ID
- Only uncommented entries override; everything else falls back to UserDefaults
- Useful for settings you want consistent across all builds (e.g., shortcuts)
- The file is a template with all settings commented out by default

## Full Migration Checklist

When migrating from one tagged build to another (e.g., `my-dev` -> `local`):

1. Kill the target build if running
2. Export+import UserDefaults (remember hyphen->dot domain conversion)
3. Copy the session JSON file
4. Set `showSidebarDevBuildBanner` to false for the target domain
5. Launch the target build: `./scripts/reload.sh --tag local --launch`

## Cross-machine Sync

For moving the `local`-tag config (UserDefaults + open workspaces + settings.json) between machines, use `scripts/sync-local-config.sh`. The snapshot is committed to `tmp-sync/` on `dev/local`.

**Source machine (capture state):**

```bash
./scripts/sync-local-config.sh snapshot
git add tmp-sync/ && git commit -m "Sync local tag config" && git push origin dev/local
```

**Target machine (restore state):**

```bash
git fetch && git checkout dev/local && git pull
# Quit cmux DEV local first if running — overwrites session on quit
./scripts/sync-local-config.sh apply
./scripts/reload.sh --tag local --launch
```

**First-time setup on a new Mac:**

```bash
brew install zig git              # + Xcode from App Store
./scripts/setup.sh                # submodules + GhosttyKit (5–10 min, watch for the zig tag issue above)
./scripts/sync-local-config.sh apply
./scripts/reload.sh --tag local --launch
```

Script defaults to tag `local`. Override with `CMUX_SYNC_TAG=<tag>`.

## Current Custom Changes on dev/local

As of 2026-04-10, dev/local carries these changes on top of main:

- **Lower minimum sidebar width** from 180 to 120 (`SessionPersistence.swift`)
- **Fix sidebar header buttons clipped at narrow widths** — right-align with trailing inset + intrinsic sizing instead of fixed 124pt width + 72pt leading inset (`ContentView.swift`, `UpdateTitlebarAccessory.swift`)
- **Home/End/PageUp/PageDown as shortcut keys** — keyCode matching, shortcut recording, settings file parsing (`AppDelegate.swift`, `KeyboardShortcutSettings.swift`, `KeyboardShortcutSettingsFileStore.swift`)
