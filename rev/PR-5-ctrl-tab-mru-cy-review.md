# cy-review: PR 5 - configurable MRU surface cycling

- Date: 2026-07-23
- Round: 1
- Target: `bdec/ctrl-tab-mru`
- Base: `origin/dev/bdec`
- PR: https://github.com/pandec/cmux/pull/5
- Reviewed commit: `cf83a6ad6e`

## Fleet

| Reviewer | Primary responsibility |
| --- | --- |
| Skeptical code | Correctness, regressions, routing, focus lifecycle |
| State and tests | MRU state machine, modifier lifecycle, close behavior, test evidence |
| Settings contract | Settings, shortcuts, schema, docs, localization |
| Adversarial solution | Ownership, API boundaries, duplication, simpler alternatives |

Four reviewers were used because this is stateful, cross-module interaction work spanning runtime routing, shared package logic, settings, and configuration contracts.

## Summary

- Raw findings: 7
- Kept after deduplication: 6
- Fix now: 6
- Deferred: 1
- Discarded: 0

## Combined findings

| Finding | Location | Sources | Severity | Disposition | Rationale |
| --- | --- | --- | --- | --- | --- |
| Only one host may own a modifier-held cycle; external focus must not be overwritten on release | `Sources/AppDelegate+SurfaceCycleShortcut.swift:30` | SK-1, AD-1 | High | Fix now | Multiple active host sessions or an ignored click can commit stale focus after Control is released. |
| Preserve held-cycle behavior for valid Shift-only custom bindings | `Sources/AppDelegate+SurfaceCycleShortcut.swift:73` | ST-1 | Medium | Fix now | Removing Shift unconditionally converts a valid customized binding into immediate per-key commits. |
| Remove closed Dock panels from the bounded MRU ledger | `Sources/DockSplitStore.swift:612` | ST-2 | Medium | Fix now | Dead IDs consume bounded history and gradually degrade surviving MRU order. |
| Add host-level lifecycle and reconciliation tests | `SurfaceCycleModelTests.swift:15` | ST-3 | Medium | Fix now | Model-only happy paths do not prove preview/commit, modifier release, interruption, or close behavior. |
| Guard parity between package and legacy runtime shortcut catalogs | `cmuxTests/KeyboardShortcutContextTests.swift:268` | AD-2 | Medium | Fix now plus defer broader cleanup | Add exact parity coverage for the two new actions; existing catalog drift prevents an exhaustive assertion without broad unrelated work. |
| Keep session mechanics internal and remove unused cancellation API | `SurfaceCycleSession.swift:4` | AD-3 | Low | Fix now | The package does not need to expose ring/index mechanics or an unused host operation. |

## Deferred candidates

| Item | Why deferred |
| --- | --- |
| Unify or exhaustively validate the complete package and legacy shortcut catalogs | The catalogs already differ for `toggleBrowserDesignMode`, outside this feature. The new surface-cycle actions receive exact action/label/default parity coverage now; full consolidation should be a dedicated cleanup. |

## Discarded summary

No candidate findings were discarded after verification.
