# cy-review: PR 5 - configurable MRU surface cycling

- Date: 2026-07-23
- Round: 3
- Target: `bdec/ctrl-tab-mru`
- Base: `origin/dev/bdec`
- PR: https://github.com/pandec/cmux/pull/5
- Reviewed commit: `587f626007`

## Fleet

| Reviewer | Primary responsibility |
| --- | --- |
| Focus correctness | Verify interruption, commit, and AppKit focus lifecycle |
| Hot-path safety | Inspect responder and event-monitor changes for regressions |
| Adversarial solution | Challenge hibernation, detach, and lifecycle edge cases |

Three focused reviewers were sufficient because the first two rounds had already covered the configuration, localization, navigation model, and broad coordinator behavior.

## Summary

- Raw findings: 6
- Kept after deduplication: 4
- Fix now: 4
- Deferred: 0 new items
- Discarded: 0

## Combined findings

| Finding | Location | Sources | Severity | Disposition | Rationale |
| --- | --- | --- | --- | --- | --- |
| Delayed terminal focus must not interrupt the cycle that initiated it | `Sources/AppDelegate.swift:16766` | RH-1, RA-1 | High | Fix now | A synchronous suppression flag ends before scheduled first-responder work, causing the preview to cancel itself. |
| Dock detach must remove the transferred panel from its MRU ledger | `Sources/DockSplitStore+SurfaceTransfer.swift:153` | RF-1 | Medium | Fix now | Ownership mappings are removed before reconciliation, so ordinary close cleanup cannot forget the panel. |
| App deactivation must commit regardless of key-window callback order | `Sources/CmuxLifecycleEventPublishing.swift:275` | RH-2, RA-2 | High | Fix now | A resign-key interruption can otherwise clear the session before `applicationWillResignActive` commits it. |
| Previewing a hibernated terminal must not trigger its focus-driven resume path | `Sources/Workspace.swift:11363` | RA-3 | High | Fix now | Suppressing the direct resume call is insufficient while activation still invokes terminal focus behavior. |

## Deferred candidates

No new items deferred this round. The round-1 shortcut-catalog cleanup remains deferred.

## Discarded summary

No candidate findings were discarded after verification.
