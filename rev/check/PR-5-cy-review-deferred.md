# PR 5 cy-review deferred items

## Shortcut catalog unification

The package settings model and the legacy app runtime shortcut model are duplicated and already differ for `toggleBrowserDesignMode`. That drift can allow a future action or default to appear in Settings but behave differently at runtime. This PR adds exact parity coverage for the two new surface-cycle actions, but making the complete catalogs exhaustive would broaden an otherwise focused feature. Handle the existing mismatch and then add an exhaustive catalog/default parity test in a dedicated follow-up.

> cy-review complete — 2026-07-23T10:19:16Z — rounds: 3
