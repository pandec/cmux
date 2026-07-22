# PR #4 cy-review

## Pass 1

Reviewed the complete diff against `origin/dev/bdec` with four independent lenses: correctness/regression, solution design, accessibility/interaction, and efficiency/state ownership.

### Fix now

- `SK-1`: align the compact menu visual with its AppKit hit lane. The visual currently starts at x=0 while the hit lane starts at the shared outer/group leading inset.
- `AX-1`: keep the compact menu discoverable and invokable through accessibility even while its hover-only visual is hidden.
- `AX-2`: suppress accessibility exposure on the content-view click target so the titlebar proxy remains the single accessible control.
- `AX-3`: expose the compact notification badge count as an accessibility value, reusing the existing localized unread-notification strings.
- `AX-4`: expose the compact control as a menu button rather than a pop-up button.
- `DE-1`: avoid relayout/accessibility churn when the mouse-event path reapplies unchanged proxy configuration.
- `DE-2` / `AX-5`: update the legacy expanded-controls test to compare against the expanded slot registry rather than all enum cases.

### Deferred / rejected after verification

- `ADV-1`: no change. The AppKit click target needs the current sidebar-derived presentation before and outside SwiftUI hit-region lookup; replacing it with registry geometry would broaden the interaction architecture without a demonstrated mismatch. Both values originate from the same canonical sidebar layout state, and decoration reapplication is restricted to presentation threshold changes.
- `ADV-2`: no change. The visual SwiftUI controls retain their established action closures as a fallback interaction path, while the proxy supplies titlebar-layer routing and accessibility. Replacing the compact button with a bespoke passive renderer would add UI code for no verified behavior gain.

### Verification plan

- Add focused regression assertions for compact visual/hit alignment, expanded slot enumeration, accessibility availability/role/value, and suppression on the content click target.
- Run the narrow titlebar and window/drag test suites plus repository localization/static gates.
- Run a second cy-review pass only if the fixes materially change the interaction design.
