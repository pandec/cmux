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
            commitActiveSurfaceCycle()
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

        let requiredModifiers = Self.surfaceCycleRequiredModifiers(from: event.modifierFlags)
        if let dock = focusedDockStoreForShortcut(preferredWindow: event.window) {
            return performSurfaceCycle(
                on: dock,
                direction: direction,
                requiredModifiers: requiredModifiers
            )
        }
        let workspace = (preferredMainWindowContextForShortcutRouting(event: event)?.tabManager ?? tabManager)?.selectedWorkspace
        guard let workspace else { return true }
        return performSurfaceCycle(
            on: workspace,
            direction: direction,
            requiredModifiers: requiredModifiers
        )
    }

    func finishSurfaceCyclesIfModifiersReleased(_ modifiers: NSEvent.ModifierFlags) {
        let pressed = modifiers.intersection(.deviceIndependentFlagsMask).rawValue
        guard let activeSurfaceCycleHost,
              activeSurfaceCycleHost.finishSurfaceCycleIfModifiersReleased(pressed) else {
            return
        }
        self.activeSurfaceCycleHost = nil
    }

    func commitAllSurfaceCycles() {
        commitActiveSurfaceCycle()
    }

    func recordSurfaceCycleFocus(_ surfaceID: UUID, in host: any SurfaceCycleHosting) {
        if let activeSurfaceCycleHost, activeSurfaceCycleHost !== host {
            self.activeSurfaceCycleHost = nil
            activeSurfaceCycleHost.commitSurfaceCycle()
        }
        host.surfaceCycleModel.recordFocus(surfaceID)
        if activeSurfaceCycleHost === host, !host.surfaceCycleModel.hasActiveSession {
            activeSurfaceCycleHost = nil
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

    static func surfaceCycleRequiredModifiers(from flags: NSEvent.ModifierFlags) -> UInt {
        var modifiers = flags.intersection(.deviceIndependentFlagsMask)
        modifiers.remove([.capsLock, .function, .numericPad])
        if modifiers.contains(.shift), !modifiers.subtracting(.shift).isEmpty {
            modifiers.remove(.shift)
        }
        return modifiers.rawValue
    }

    private func performSurfaceCycle(
        on host: any SurfaceCycleHosting,
        direction: SurfaceCycleDirection,
        requiredModifiers: UInt
    ) -> Bool {
        if let activeSurfaceCycleHost, activeSurfaceCycleHost !== host {
            self.activeSurfaceCycleHost = nil
            activeSurfaceCycleHost.commitSurfaceCycle()
        }
        activeSurfaceCycleHost = host
        let consumed = host.performSurfaceCycle(
            direction: direction,
            requiredModifiers: requiredModifiers
        )
        if !host.surfaceCycleModel.hasActiveSession {
            activeSurfaceCycleHost = nil
        }
        return consumed
    }

    private func commitActiveSurfaceCycle() {
        guard let activeSurfaceCycleHost else { return }
        self.activeSurfaceCycleHost = nil
        activeSurfaceCycleHost.commitSurfaceCycle()
    }
}
