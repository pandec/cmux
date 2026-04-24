# Emoji Input Bug — Command Palette Rename & Search

Upstream issue: **manaflow-ai/cmux#2161** ("Emoji can't be used in workspace name")

## Problem

Emoji cannot be inserted into the command palette text fields (both rename and search). All input methods fail:
- Emoji picker (Ctrl+Cmd+Space / fn)
- Cmd+V paste of emoji (regular text paste works)
- Third-party emoji pickers (Raycast, etc.)

The right-click rename dialog (NSAlert + NSTextField) works fine for emoji.

## Root Causes

Three layers of the command palette's focus management fight emoji input:

### 1. Focus lock timer clears first responder on window resign

`WindowCommandPaletteOverlayController.updateFocusLockForWindowState()` (`Sources/ContentView.swift:~1171`) calls `window.makeFirstResponder(nil)` whenever the window loses key status. The emoji picker panel causes a brief key-window change, so the field editor is killed before the picker's `insertText:` arrives.

### 2. Focus lock timer steals keyboard focus from the picker

`startFocusLockTimer()` (`Sources/ContentView.swift:~1198`) fires every 80ms and calls `focusIntoPalette()` which does `window.makeFirstResponder(textField)`. This pulls keyboard focus back to the palette text field, preventing the emoji picker from receiving arrow keys, enter, or search input.

### 3. AppKit ends editing when window resigns key

Even without the timer interference, AppKit's default behavior ends the field editor's editing session when a window resigns key. This disconnects the `NSTextInputContext`, so the emoji picker's `insertText:replacementRange:` has no target. The `updateNSView` re-focus logic in the `NSViewRepresentable` then cycles editing (end → restart → end) every SwiftUI view update, creating a rapid attach/detach loop visible in debug logs.

### Secondary: SwiftUI TextField + .onKeyPress

The rename field originally used a SwiftUI `TextField` with `.backport.onKeyPress(.delete)`. SwiftUI's `NSTextInputClient` handling with `.onKeyPress` has known edge cases on macOS 14+ where external `insertText:` (emoji picker, special paste) is dropped. This is independent of the focus lock issues above.

## Why Right-Click Rename Works

The right-click rename uses `NSAlert.runModal()` with a plain NSTextField:
- Runs in its own modal event loop
- `handleCustomShortcut` bails at `NSApp.modalWindow != nil` (AppDelegate.swift:~8956)
- Focus lock timer is irrelevant
- No SwiftUI binding or `.onKeyPress` modifiers

## Why Search Field Appeared to Work

Initial testing suggested the search field handled emoji. On closer inspection, the same bug exists there — the search field uses the same `CommandPaletteNativeTextField` + `CommandPaletteSearchFieldRepresentable` and is subject to the same focus lock timer. The difference was likely in testing conditions (e.g., the picker not taking key in some scenarios).

## Affected Code

- `Sources/ContentView.swift` — focus lock timer (~1185-1215), `updateFocusLockForWindowState` (~1161), rename TextField (~3783), `CommandPaletteNativeTextField` (~3865), `CommandPaletteSearchFieldRepresentable` (~3924), `handleCommandPaletteRenameDeleteBackward` (~6578)
- `Sources/Backport.swift` — `.onKeyPress` implementation (~44-60)
- `Sources/AppDelegate.swift` — local event monitor (~8609), `shouldConsumeShortcutWhileCommandPaletteVisible` (~1632, explicitly allows Cmd+V)

## References

- [docs/01-emoji-input-command-palette.md](../../docs/01-emoji-input-command-palette.md) — initial investigation and root cause analysis
- [docs/00-pr-contribution-guide.md](../../docs/00-pr-contribution-guide.md) — PR patterns for upstream submission
- [docs/04-pr-submission-learnings.md](../../docs/04-pr-submission-learnings.md) — learnings from Option+Delete PR
