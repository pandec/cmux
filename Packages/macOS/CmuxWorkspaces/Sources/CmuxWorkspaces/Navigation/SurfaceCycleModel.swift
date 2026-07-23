public import Foundation
import Observation

/// Per-host MRU ledger and active frozen surface-cycle session.
@MainActor
@Observable
public final class SurfaceCycleModel {
    private var recentSurfaceIDs: [UUID] = []
    private var session: SurfaceCycleSession?
    private let maximumRecentSurfaceCount: Int

    /// Creates an empty surface-cycle model.
    ///
    /// - Parameter maximumRecentSurfaceCount: Maximum remembered surface identifiers.
    public init(maximumRecentSurfaceCount: Int = 64) {
        self.maximumRecentSurfaceCount = max(2, maximumRecentSurfaceCount)
    }

    /// Whether a modifier-held cycle is currently active.
    public var hasActiveSession: Bool { session != nil }

    /// Scope of the active cycle, when one exists.
    public var activeScope: SurfaceCycleScope? { session?.scope }

    /// Modifier mask that must remain pressed to keep the active cycle open.
    public var requiredModifiers: UInt? { session?.requiredModifiers }

    /// Records a completed user focus, promoting it to the front of the MRU ledger.
    /// Intermediate preview selections are ignored while a cycle is active. A
    /// different explicit focus ends the cycle so modifier release cannot
    /// overwrite the user's newer choice.
    ///
    /// - Parameter surfaceID: Focused surface identifier.
    public func recordFocus(_ surfaceID: UUID) {
        if let session {
            guard session.selectedSurfaceID != surfaceID else { return }
            self.session = nil
        }
        promote(surfaceID)
    }

    /// Removes a closed surface from remembered and active state.
    ///
    /// - Parameter surfaceID: Closed surface identifier.
    public func forget(_ surfaceID: UUID) {
        recentSurfaceIDs.removeAll { $0 == surfaceID }
    }

    /// Builds the current MRU order for a live candidate collection.
    ///
    /// Known surfaces are returned most-recent-first. Never-focused surfaces
    /// follow in the caller's stable tab order.
    ///
    /// - Parameter candidates: Live surface identifiers in stable tab order.
    /// - Returns: Every distinct live candidate in MRU order.
    public func cycleOrder(candidates: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        let uniqueCandidates = candidates.filter { seen.insert($0).inserted }
        let live = Set(uniqueCandidates)
        let recent = recentSurfaceIDs.filter { live.contains($0) }
        let known = Set(recent)
        return recent + uniqueCandidates.filter { !known.contains($0) }
    }

    /// Starts or advances a frozen cycle session.
    ///
    /// - Parameters:
    ///   - candidates: Live surfaces in stable tab order.
    ///   - currentSurfaceID: Currently focused surface.
    ///   - scope: Pane or workspace containing the candidates.
    ///   - direction: Direction to travel through MRU order.
    ///   - requiredModifiers: Raw modifier mask that keeps the interaction active.
    /// - Returns: Surface to preview, or `nil` when cycling cannot move.
    public func cycle(
        candidates: [UUID],
        currentSurfaceID: UUID,
        scope: SurfaceCycleScope,
        direction: SurfaceCycleDirection,
        requiredModifiers: UInt
    ) -> UUID? {
        if var active = session, active.scope == scope {
            guard active.reconcile(liveSurfaceIDs: Set(candidates)) != nil else {
                session = nil
                return nil
            }
            let target = active.advance(direction)
            session = active
            return target
        }

        guard session == nil else { return nil }
        promote(currentSurfaceID)
        let ordered = cycleOrder(candidates: candidates)
        guard var next = SurfaceCycleSession(
            ring: ordered,
            currentSurfaceID: currentSurfaceID,
            scope: scope,
            requiredModifiers: requiredModifiers
        ) else {
            return nil
        }
        let target = next.advance(direction)
        session = next
        return target
    }

    /// Reconciles the active ring against its live scope.
    ///
    /// - Parameter liveSurfaceIDs: Current surface identifiers in the scope.
    /// - Returns: Surviving selection, or `nil` when the session can no longer continue.
    public func reconcile(liveSurfaceIDs: Set<UUID>) -> UUID? {
        guard var active = session else { return nil }
        let selected = active.reconcile(liveSurfaceIDs: liveSurfaceIDs)
        session = selected == nil ? nil : active
        return selected
    }

    /// Commits the active selection and promotes it in the MRU ledger.
    ///
    /// - Returns: Surface to activate fully, or `nil` when no session exists.
    public func commit() -> UUID? {
        guard let active = session else { return nil }
        session = nil
        promote(active.selectedSurfaceID)
        return active.selectedSurfaceID
    }

    /// Clears the ledger and any active interaction.
    public func reset() {
        recentSurfaceIDs.removeAll(keepingCapacity: false)
        session = nil
    }

    private func promote(_ surfaceID: UUID) {
        recentSurfaceIDs.removeAll { $0 == surfaceID }
        recentSurfaceIDs.insert(surfaceID, at: 0)
        if recentSurfaceIDs.count > maximumRecentSurfaceCount {
            recentSurfaceIDs.removeLast(recentSurfaceIDs.count - maximumRecentSurfaceCount)
        }
    }
}
