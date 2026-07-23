# cy-review: PR 5 - configurable MRU surface cycling

- Date: 2026-07-23
- Round: 2
- Target: `bdec/ctrl-tab-mru`
- Base: `origin/dev/bdec`
- PR: https://github.com/pandec/cmux/pull/5
- Reviewed commit: `f1540112ed`

## Fleet

| Reviewer | Primary responsibility |
| --- | --- |
| Correctness | Verify the revised coordinator and all host-routing paths |
| State and tests | Stress interruption, modifier, scope, and fake-host evidence |
| Adversarial solution | Challenge the coordinator lifecycle and minimality |

Three focused reviewers were sufficient because settings, schema, docs, and localization were clean in round 1; round 2 targeted the lifecycle fixes that changed.

## Summary

- Raw findings: 6
- Kept after deduplication: 4
- Fix now: 4
- Deferred: 0 new items
- Discarded: 0

## Combined findings

| Finding | Location | Sources | Severity | Disposition | Rationale |
| --- | --- | --- | --- | --- | --- |
| Cross-host external focus must interrupt without reactivating the old preview | `Sources/AppDelegate+SurfaceCycleShortcut.swift:61` | RT-1, RA-1 | High | Fix now | Committing the old host is a focusing operation and can override the newer explicit focus. |
| Key-window and non-surface responder changes must end a held cycle | `Sources/CmuxLifecycleEventPublishing.swift:260` | RC-1, RA-2 | High | Fix now | Titlebar, sidebar, palette, and other responder changes can otherwise leave stale focus to be applied on modifier release. |
| Remove transferred panels from the source workspace MRU ledger | `Sources/Workspace.swift:11964` | RC-2 | Low | Fix now | Detach skips the ordinary close cleanup and leaves dead bounded-history entries. |
| Remove obsolete original-surface state | `SurfaceCycleSession.swift:9` | RA-3 | Low | Fix now | Restoration was removed, so the internal field is dead state. |

## Deferred candidates

No new items deferred this round. The round-1 shortcut-catalog cleanup remains deferred.

## Discarded summary

No candidate findings were discarded after verification.
