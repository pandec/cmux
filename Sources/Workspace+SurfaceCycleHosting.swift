import Bonsplit
import CmuxWorkspaces
import Foundation

extension Workspace: SurfaceCycleHosting {
    var currentSurfaceCycleScope: SurfaceCycleScope? {
        if layoutMode == .canvas {
            return .workspace(id)
        }
        return bonsplitController.focusedPaneId.map { .pane($0.id) }
    }

    var currentSurfaceCycleSurfaceID: UUID? { focusedPanelId }

    func surfaceCycleCandidates(in scope: SurfaceCycleScope) -> [UUID] {
        switch scope {
        case .pane(let paneID):
            return bonsplitController.tabs(inPane: PaneID(id: paneID)).compactMap {
                panelIdFromSurfaceId($0.id)
            }
        case .workspace(let workspaceID):
            guard workspaceID == id else { return [] }
            return selectableCanvasSurfaceIds()
        }
    }

    func selectSurfaceForCycle(_ surfaceID: UUID, in scope: SurfaceCycleScope, isPreview: Bool) {
        guard panels[surfaceID] != nil else { return }
        focusPanel(surfaceID, resumeHibernatedAgent: !isPreview)
        if layoutMode == .canvas {
            canvasModel.viewport?.modelDidChangeExternally(animated: false)
            canvasModel.viewport?.revealPane(surfaceID, animated: false)
        }
    }
}
