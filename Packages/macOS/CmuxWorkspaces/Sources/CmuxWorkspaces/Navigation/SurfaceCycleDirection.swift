/// Direction of travel through a frozen surface-cycle ring.
public enum SurfaceCycleDirection: Sendable {
    /// Advance toward less recently focused surfaces.
    case forward
    /// Advance toward more recently focused surfaces within the active ring.
    case backward

    var offset: Int {
        switch self {
        case .forward: 1
        case .backward: -1
        }
    }
}
