import Testing
@testable import CmuxSettings

@Suite struct ModifierlessNavigationShortcutTests {
    @Test(arguments: ["↖", "↘", "⇞", "⇟"])
    func navigationKeysAreAcceptedWithoutModifiers(key: String) throws {
        let shortcut = StoredShortcut(first: ShortcutStroke(key: key))

        #expect(
            ShortcutAction.focusLeft.shortcutBindingPolicyResult(for: shortcut) == .accepted
        )
    }

    @Test func printableKeyStillRequiresModifier() {
        let shortcut = StoredShortcut(first: ShortcutStroke(key: "a"))

        #expect(
            ShortcutAction.focusLeft.shortcutBindingPolicyResult(for: shortcut) == .bareFirstStrokeNotAllowed
        )
    }

    @Test(arguments: [
        ("home", "↖"),
        ("end", "↘"),
        ("pageup", "⇞"),
        ("pagedown", "⇟"),
    ])
    func configParserAcceptsModifierlessNavigationKeys(rawValue: String, expectedKey: String) throws {
        let shortcut = try #require(StoredShortcut.parseConfig(rawValue))

        #expect(shortcut == StoredShortcut(first: ShortcutStroke(key: expectedKey)))
    }
}
