import AppKit
import CmuxSettings
import CmuxWorkspaces

extension AppDelegate {
    func handleSurfaceCycleShortcut(event: NSEvent) -> Bool {
        let direction: SurfaceCycleDirection
        if matchConfiguredShortcut(event: event, action: .cycleSurfaceForward) {
            direction = .forward
        } else if matchConfiguredShortcut(event: event, action: .cycleSurfaceBackward) {
            direction = .backward
        } else {
            return false
        }

        if currentSurfaceCycleOrder == .tabOrder {
            let command: DockShortcutCommand = direction == .forward
                ? .selectNextSurface
                : .selectPreviousSurface
            if performFocusedDockShortcut(command, event: event) { return true }
            let manager = preferredMainWindowContextForShortcutRouting(event: event)?.tabManager ?? tabManager
            if direction == .forward {
                manager?.selectNextSurface()
            } else {
                manager?.selectPreviousSurface()
            }
            return true
        }

        let requiredModifiers = surfaceCycleRequiredModifiers(for: event)
        if let dock = focusedDockStoreForShortcut(preferredWindow: event.window) {
            return dock.performSurfaceCycle(direction: direction, requiredModifiers: requiredModifiers)
        }
        let workspace = (preferredMainWindowContextForShortcutRouting(event: event)?.tabManager ?? tabManager)?.selectedWorkspace
        return workspace?.performSurfaceCycle(
            direction: direction,
            requiredModifiers: requiredModifiers
        ) ?? true
    }

    func finishSurfaceCyclesIfModifiersReleased(_ modifiers: NSEvent.ModifierFlags) {
        let pressed = modifiers.intersection(.deviceIndependentFlagsMask).rawValue
        for context in mainWindowContexts.values {
            for workspace in context.tabManager.tabs where workspace.surfaceCycleModel.hasActiveSession {
                workspace.finishSurfaceCycleIfModifiersReleased(pressed)
            }
        }
        for dock in DockSplitStore.liveStores where dock.surfaceCycleModel.hasActiveSession {
            dock.finishSurfaceCycleIfModifiersReleased(pressed)
        }
    }

    func commitAllSurfaceCycles() {
        for context in mainWindowContexts.values {
            for workspace in context.tabManager.tabs where workspace.surfaceCycleModel.hasActiveSession {
                workspace.commitSurfaceCycle()
            }
        }
        for dock in DockSplitStore.liveStores where dock.surfaceCycleModel.hasActiveSession {
            dock.commitSurfaceCycle()
        }
    }

    private var currentSurfaceCycleOrder: SurfaceCycleOrder {
        let key = AppCatalogSection().surfaceCycleOrder
        guard let raw = UserDefaults.standard.string(forKey: key.userDefaultsKey),
              let stored = SurfaceCycleOrder(rawValue: raw) else {
            return key.defaultValue
        }
        return stored
    }

    private func surfaceCycleRequiredModifiers(for event: NSEvent) -> UInt {
        var modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        modifiers.remove([.shift, .capsLock, .function, .numericPad])
        return modifiers.rawValue
    }
}
