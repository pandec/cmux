# tmp-sync — personal config travel folder

Holds a snapshot of the `local`-tag dev build's UserDefaults, workspace session, and settings.json. Tracked on `dev/local` (personal fork branch only). Never merge into main.

## Files

- `com.cmuxterm.app.debug.local.plist` — UserDefaults export (shortcuts, sidebar appearance, window geometry, etc.)
- `session-com.cmuxterm.app.debug.local.json` — open workspaces, tabs, terminal session state
- `settings.json` — `~/.config/cmux/settings.json` (shared across all builds via the file-managed override layer)

## Snapshot (source machine)

After a session where you've changed shortcuts / opened workspaces / tweaked appearance:

```bash
./scripts/sync-local-config.sh snapshot
git add tmp-sync/
git commit -m "Sync local tag config"
git push origin dev/local
```

Override the tag if needed: `CMUX_SYNC_TAG=other-tag ./scripts/sync-local-config.sh snapshot`

## Apply (target machine)

```bash
git fetch && git checkout dev/local && git pull
# Quit cmux DEV local first if running — it overwrites session on quit
./scripts/sync-local-config.sh apply
./scripts/reload.sh --tag local --launch
```

## Build first time on a new Mac

```bash
brew install zig git           # + Xcode from App Store
./scripts/setup.sh             # submodules + GhosttyKit (5–10 min)
./scripts/sync-local-config.sh apply
./scripts/reload.sh --tag local --launch
```

Or ask Claude Code in this repo: *"use the cmux-dev skill to set up and launch my local build, then apply the tmp-sync snapshot"*.
