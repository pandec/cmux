/// Ordering used by the dedicated surface-cycle shortcuts.
public enum SurfaceCycleOrder: String, CaseIterable, Sendable, SettingCodable {
    /// Follow the visual order of tabs in the active pane.
    case tabOrder
    /// Follow most-recently-used order captured when cycling begins.
    case mostRecentlyUsed
}
