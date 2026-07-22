import Testing
@testable import CmuxSettings

@Suite("Surface cycle settings")
struct SurfaceCycleSettingsTests {
    @Test("Surface cycle order defaults to visual tab order")
    func defaultOrderPreservesExistingBehavior() {
        let key = AppCatalogSection().surfaceCycleOrder
        #expect(key.defaultValue == .tabOrder)
        #expect(key.id == "app.surfaceCycleOrder")
        #expect(SurfaceCycleOrder(rawValue: "mostRecentlyUsed") == .mostRecentlyUsed)
    }

    @Test("Dedicated cycle actions use Control-Tab defaults")
    func shortcutDefaults() {
        #expect(
            ShortcutAction.cycleSurfaceForward.defaultShortcut == StoredShortcut(
                first: ShortcutStroke(key: "\t", control: true)
            )
        )
        #expect(
            ShortcutAction.cycleSurfaceBackward.defaultShortcut == StoredShortcut(
                first: ShortcutStroke(key: "\t", shift: true, control: true)
            )
        )
    }
}
