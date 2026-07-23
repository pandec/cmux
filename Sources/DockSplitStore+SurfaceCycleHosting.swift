import Bonsplit
import CmuxWorkspaces
import Foundation

extension DockSplitStore: SurfaceCycleHosting {
    var currentSurfaceCycleScope: SurfaceCycleScope? {
        bonsplitController.focusedPaneId.map { .pane($0.id) }
    }

    var currentSurfaceCycleSurfaceID: UUID? { focusedPanelId }

    func surfaceCycleCandidates(in scope: SurfaceCycleScope) -> [UUID] {
        guard case .pane(let paneID) = scope else { return [] }
        return bonsplitController.tabs(inPane: PaneID(id: paneID)).compactMap { panel(for: $0.id)?.id }
    }

    func selectSurfaceForCycle(_ surfaceID: UUID, in scope: SurfaceCycleScope, isPreview: Bool) {
        focusPanel(surfaceID)
    }
}
