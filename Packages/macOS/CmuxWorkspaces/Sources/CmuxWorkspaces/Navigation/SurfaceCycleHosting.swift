public import Foundation

/// Host seam for shared MRU surface-cycle behavior.
@MainActor
public protocol SurfaceCycleHosting: AnyObject {
    /// Per-host recency ledger and frozen interaction state.
    var surfaceCycleModel: SurfaceCycleModel { get }
    /// Current pane or workspace-wide cycle scope.
    var currentSurfaceCycleScope: SurfaceCycleScope? { get }
    /// Currently focused surface in ``currentSurfaceCycleScope``.
    var currentSurfaceCycleSurfaceID: UUID? { get }

    /// Returns live candidates in stable tab order.
    ///
    /// - Parameter scope: Scope whose candidates should be read.
    func surfaceCycleCandidates(in scope: SurfaceCycleScope) -> [UUID]

    /// Applies a cycle selection.
    ///
    /// - Parameters:
    ///   - surfaceID: Surface to select.
    ///   - scope: Scope containing the surface.
    ///   - isPreview: Whether expensive activation such as agent resume should be deferred.
    func selectSurfaceForCycle(_ surfaceID: UUID, in scope: SurfaceCycleScope, isPreview: Bool)
}

public extension SurfaceCycleHosting {
    /// Starts or advances an MRU cycle through the current scope.
    ///
    /// - Parameters:
    ///   - direction: Direction through the frozen MRU ring.
    ///   - requiredModifiers: Raw modifier mask that keeps the interaction open.
    /// - Returns: `true` when the request was consumed.
    @discardableResult
    func performSurfaceCycle(
        direction: SurfaceCycleDirection,
        requiredModifiers: UInt
    ) -> Bool {
        guard let scope = currentSurfaceCycleScope,
              let currentSurfaceID = currentSurfaceCycleSurfaceID else {
            return true
        }

        if let activeScope = surfaceCycleModel.activeScope, activeScope != scope {
            commitSurfaceCycle()
        }

        let candidates = surfaceCycleCandidates(in: scope)
        guard let target = surfaceCycleModel.cycle(
            candidates: candidates,
            currentSurfaceID: currentSurfaceID,
            scope: scope,
            direction: direction,
            requiredModifiers: requiredModifiers
        ) else {
            return true
        }

        let isPreview = requiredModifiers != 0
        selectSurfaceForCycle(target, in: scope, isPreview: isPreview)
        if !isPreview {
            _ = surfaceCycleModel.commit()
        }
        return true
    }

    /// Commits an active cycle once its required modifiers are released.
    ///
    /// - Parameter pressedModifiers: Raw currently pressed modifier mask.
    /// - Returns: Whether a session was committed.
    @discardableResult
    func finishSurfaceCycleIfModifiersReleased(_ pressedModifiers: UInt) -> Bool {
        guard let required = surfaceCycleModel.requiredModifiers,
              pressedModifiers & required != required else {
            return false
        }
        commitSurfaceCycle()
        return true
    }

    /// Commits the active preview selection with full activation behavior.
    func commitSurfaceCycle() {
        guard let scope = surfaceCycleModel.activeScope else { return }
        _ = surfaceCycleModel.reconcile(liveSurfaceIDs: Set(surfaceCycleCandidates(in: scope)))
        guard let target = surfaceCycleModel.commit() else { return }
        selectSurfaceForCycle(target, in: scope, isPreview: false)
    }

    /// Cancels an active cycle and restores its initial surface.
    func cancelSurfaceCycle() {
        guard let scope = surfaceCycleModel.activeScope,
              let target = surfaceCycleModel.cancel(),
              surfaceCycleCandidates(in: scope).contains(target) else {
            return
        }
        selectSurfaceForCycle(target, in: scope, isPreview: false)
    }
}
