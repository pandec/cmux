import Foundation

/// Frozen candidate ring for one modifier-held surface-cycle interaction.
struct SurfaceCycleSession: Equatable, Sendable {
    /// Scope whose candidates were captured when cycling began.
    let scope: SurfaceCycleScope
    /// Modifier mask that must remain pressed to keep the session open.
    let requiredModifiers: UInt
    /// Frozen MRU ring, with the original surface at index zero.
    private(set) var ring: [UUID]
    /// Current selection within ``ring``.
    private(set) var index: Int

    /// Creates a cycle session when at least two distinct candidates exist.
    ///
    /// - Parameters:
    ///   - ring: Candidate order with `currentSurfaceID` included.
    ///   - currentSurfaceID: Surface focused when cycling begins.
    ///   - scope: Pane or workspace whose surfaces participate.
    ///   - requiredModifiers: Raw modifier mask that keeps the session active.
    init?(
        ring: [UUID],
        currentSurfaceID: UUID,
        scope: SurfaceCycleScope,
        requiredModifiers: UInt
    ) {
        var seen = Set<UUID>()
        let uniqueRing = ring.filter { seen.insert($0).inserted }
        guard uniqueRing.count > 1,
              let currentIndex = uniqueRing.firstIndex(of: currentSurfaceID) else {
            return nil
        }
        self.scope = scope
        self.requiredModifiers = requiredModifiers
        self.ring = uniqueRing
        self.index = currentIndex
    }

    /// Selected surface at the current ring position.
    var selectedSurfaceID: UUID { ring[index] }

    /// Advances with wraparound and returns the next selected surface.
    ///
    /// - Parameter direction: Direction to move through the frozen ring.
    /// - Returns: Newly selected surface identifier.
    mutating func advance(_ direction: SurfaceCycleDirection) -> UUID {
        index = (index + direction.offset + ring.count) % ring.count
        return selectedSurfaceID
    }

    /// Removes candidates that no longer belong to the live scope.
    ///
    /// - Parameter liveSurfaceIDs: Current surface identifiers in the scope.
    /// - Returns: The surviving selection, or `nil` when no candidates remain.
    mutating func reconcile(liveSurfaceIDs: Set<UUID>) -> UUID? {
        let selected = selectedSurfaceID
        ring.removeAll { !liveSurfaceIDs.contains($0) }
        guard !ring.isEmpty else { return nil }
        index = ring.firstIndex(of: selected) ?? min(index, ring.count - 1)
        return selectedSurfaceID
    }
}
