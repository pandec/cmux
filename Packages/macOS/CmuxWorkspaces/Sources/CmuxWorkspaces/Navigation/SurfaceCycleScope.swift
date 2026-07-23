public import Foundation

/// Stable identity of the surface collection participating in one cycle.
public enum SurfaceCycleScope: Equatable, Sendable {
    /// The tabs in one split pane.
    case pane(UUID)
    /// All selectable surfaces in a workspace-wide layout such as Canvas.
    case workspace(UUID)
}
