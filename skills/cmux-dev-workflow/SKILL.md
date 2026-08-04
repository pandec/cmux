---
name: cmux-dev-workflow
description: "Contributor workflow for native cmux setup, tagged dev builds, Xcode project normalization and sidebar extensions. Use for native build inputs, setup or tagged app verification."
---

# cmux Dev Workflow

## Scope and routing

Run repository commands only from a [trusted checkout](../../docs/contributor-verification.md#trust-boundary);
even `verify-local.py --help` and `--list` load repository code.

[Choose verification for the change](../cmux-testing/references/local-vs-ci-validation.md)
before preparing a native build. Fast feedback starts with
`python3 scripts/verify-local.py`; portable-tooling and documentation changes use
their scoped checks without an unrelated app build.

For native app or build-input changes, build with a tag as below. Setup (`./scripts/setup.sh`) initializes
submodules, builds GhosttyKit and installs the project-normalization hook;
it is not a prerequisite for portable static checks.

## Tagged local development

When local native execution is authorized:

```sh
./scripts/reload.sh --tag <short-tag>
CMUX_TAG=<short-tag> scripts/cmux-debug-cli.sh list-workspaces
```

Reload builds without launching; add `--launch` when live verification is needed.
Never use bare `xcodebuild` or open an untagged `cmux DEV.app`: tags isolate bundle
IDs, sockets and build output from other sessions. Do not use `/tmp/cmux-cli`,
which follows the most recently reloaded app. See [tagged builds](references/tagged-builds.md).
Never quit, kill, relaunch or `xctrace --launch` the user's running cmux
(`com.cmuxterm.app`); it holds their live agent sessions.

An app build does not establish test-target compilation or execution. Follow
[the test guide](../cmux-testing/references/local-vs-ci-validation.md) for those claims.

## Toolchain and project files

`.xcode-version` owns the Xcode major; `cmux.xcodeproj/project.pbxproj` currently
uses objectVersion 60. The Intel/macOS 14 fallback uses Xcode 16.2/Swift 6.0;
keep app-linked code compatible as specified in
[Swift 6.0 compatibility](../cmux-architecture/references/swift-6-0-compatibility.md).

The installed pre-commit hook normalizes staged project files and registers new
Python tests in `tests/test-execution.toml`. Preserve it and
run `python3 scripts/verify-local.py --only project` after project edits. Toolchain
pin changes are deliberate team decisions; see [project normalization](references/xcode-project-normalization.md).

## Local nightly build

```bash
./scripts/reloadn.sh [--tag <short-tag>]
```

Builds Release with the nightly channel identity ("cmux NIGHTLY", `com.cmuxterm.app.nightly`, `AppIcon-Nightly`, `cmux-nightly` URL scheme), mirroring the identity injection in `.github/workflows/nightly.yml`, then ad-hoc signs with the compatible local runtime/TCC entitlements, verifies both the staged and installed bundles, and performs a rollback-safe install to `~/Applications/cmux NIGHTLY.app`. Install elsewhere with `--install-dir`, or use `--no-install --no-launch` to validate without touching or stopping the running Nightly. A normal install requests a graceful quit and waits for the user to confirm cmux's close dialog; it never force-kills the app.

The install step is the point: derived data lives in `/tmp`, so an app left there is lost on reboot or tmp cleanup. Do not hand-patch a Release build's Info.plist to fake the nightly channel — a partial patch (right bundle ID, stable icon, stable Sparkle feed) points the nightly at the stable appcast. `--tag` only scopes the derived data path; the identity stays on the nightly channel so the build matches what ships.

A local nightly is ad-hoc signed and `spctl`-rejected, which does not prevent launching. Team-scoped Keychain and WebAuthn entitlements, Developer ID signing, and notarization stay in CI; local authentication uses the file-store fallback. Sparkle automatic checks are disabled, and the local build number is kept above current CI run-id-based versions so an official nightly is not immediately offered over the build under test.

## Sidebar extension tags

Keep the extension-point ID, bundle-ID suffix and display-name suffix distinct
for each tag. Build extensions through `scripts/reload-extension.sh --tag <tag>`
with the matching host; do not repair a mismatched tag by re-signing. The exact
settings, helper arguments and verification checklist live in
[sidebar extension tagging](references/sidebar-extension-tagging.md).
