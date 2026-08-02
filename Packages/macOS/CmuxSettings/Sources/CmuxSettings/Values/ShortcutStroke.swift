import Foundation

/// One keystroke in a (possibly chorded) shortcut.
///
/// `key` is the platform-canonical lower-case character or named token
/// (e.g. `"a"`, `"space"`, `"return"`, `"f5"`, `"←"`). `keyCode` is the
/// optional macOS virtual key code, captured when the user records a
/// shortcut so we can re-match the same physical key after a layout
/// change. Modifier flags are flat booleans because the cmux JSON
/// config encodes them that way for easy hand-editing.
public struct ShortcutStroke: Sendable, Equatable, Hashable, Codable {
    public let key: String
    public let command: Bool
    public let shift: Bool
    public let option: Bool
    public let control: Bool
    public let keyCode: UInt16?

    public init(
        key: String,
        command: Bool = false,
        shift: Bool = false,
        option: Bool = false,
        control: Bool = false,
        keyCode: UInt16? = nil
    ) {
        self.key = key
        self.command = command
        self.shift = shift
        self.option = option
        self.control = control
        self.keyCode = keyCode
    }

    /// True when at least one of `cmd`, `shift`, `opt`, or `ctrl` is set.
    public var hasAnyModifier: Bool { command || shift || option || control }

    /// Whether this non-text navigation key can be bound without a modifier.
    ///
    /// macOS reports Globe/Fn plus an arrow key as Home, End, Page Up, or
    /// Page Down with the Function flag stripped before shortcut matching.
    /// These keys do not produce text, so they are safe to bind without also
    /// allowing bare letters, arrows, Return, or other terminal input.
    public var isModifierlessNavigationKey: Bool {
        switch key {
        case "↖", "↘", "⇞", "⇟": true
        default: false
        }
    }

    /// Returns this stroke with its key normalized to cmux's persisted
    /// physical-key representation when a recording-time key code is present.
    public func canonicalized() -> ShortcutStroke {
        ShortcutStroke(
            key: canonicalShortcutKey(key, keyCode: keyCode),
            command: command,
            shift: shift,
            option: option,
            control: control,
            keyCode: keyCode
        )
    }
}
