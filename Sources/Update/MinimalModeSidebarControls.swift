import AppKit
import CmuxTestSupport
import SwiftUI

enum MinimalModeSidebarTitlebarControlsPresentation: Equatable {
    case expanded
    case compact
}

enum MinimalModeSidebarTitlebarControlsLayout {
    static func minimumExpandedSidebarWidth(
        config: TitlebarControlsStyleConfig,
        leadingInset: CGFloat
    ) -> CGFloat {
        leadingInset + hostWidth(presentation: .expanded, config: config)
    }

    static func presentation(
        sidebarWidth: CGFloat?,
        config: TitlebarControlsStyleConfig,
        leadingInset: CGFloat
    ) -> MinimalModeSidebarTitlebarControlsPresentation {
        guard let sidebarWidth else { return .expanded }
        return sidebarWidth >= minimumExpandedSidebarWidth(config: config, leadingInset: leadingInset)
            ? .expanded
            : .compact
    }

    static func hostWidth(
        presentation: MinimalModeSidebarTitlebarControlsPresentation,
        config: TitlebarControlsStyleConfig
    ) -> CGFloat {
        switch presentation {
        case .expanded:
            return ceil(TitlebarControlsLayoutMetrics.buttonRowWidth(config: config) + 14)
        case .compact:
            return MinimalModeSidebarTitlebarControlsMetrics.singleButtonHostWidth
        }
    }

    static func slots(
        for presentation: MinimalModeSidebarTitlebarControlsPresentation
    ) -> [MinimalModeSidebarControlActionSlot] {
        switch presentation {
        case .expanded:
            return [
                .toggleSidebar,
                .showNotifications,
                .newTab,
                .cloudVM,
                .focusHistoryBack,
                .focusHistoryForward,
            ]
        case .compact:
            return [.compactMenu]
        }
    }
}

struct MinimalModeSidebarControlActionProxyView: NSViewRepresentable {
    let config: TitlebarControlsStyleConfig
    var presentation = MinimalModeSidebarTitlebarControlsPresentation.expanded
    var isEnabled = true
    var requiresRevealedState = false
    var exposesAccessibility = true
    var compactMenuAccessibilityValue: String?
    let onAction: (MinimalModeSidebarControlActionSlot, NSView, NSPoint) -> Void

    func makeNSView(context: Context) -> MinimalModeSidebarControlActionView {
        let view = MinimalModeSidebarControlActionView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: MinimalModeSidebarControlActionView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: MinimalModeSidebarControlActionView) {
        view.config = config
        view.presentation = presentation
        view.isEnabled = isEnabled
        view.requiresRevealedState = requiresRevealedState
        view.exposesAccessibility = exposesAccessibility
        view.compactMenuAccessibilityValue = compactMenuAccessibilityValue
        view.onAction = onAction
    }
}

enum TitlebarControlsHitRegions {
    static let outerLeadingPadding: CGFloat = HeaderChromeControlMetrics.titlebarControlsLeadingPadding
    static let buttonCount = MinimalModeSidebarTitlebarControlsLayout.slots(for: .expanded).count

    static func buttonXRanges(config: TitlebarControlsStyleConfig) -> [ClosedRange<CGFloat>] {
        buttonXRanges(config: config, presentation: .expanded)
    }

    static func buttonXRanges(
        config: TitlebarControlsStyleConfig,
        presentation: MinimalModeSidebarTitlebarControlsPresentation
    ) -> [ClosedRange<CGFloat>] {
        MinimalModeSidebarTitlebarControlsLayout.slots(for: presentation).compactMap {
            buttonXRange(for: $0, config: config)
        }
    }

    static func buttonXRange(
        for slot: MinimalModeSidebarControlActionSlot,
        config: TitlebarControlsStyleConfig
    ) -> ClosedRange<CGFloat>? {
        let startX = outerLeadingPadding + config.groupPadding.leading
        let sidebarX = startX
        let notificationsX = sidebarX + config.buttonSize + config.spacing
        let newTabX = notificationsX + config.buttonSize + config.spacing
        let newTabWidth = TitlebarNewWorkspaceCloudSplitButtonMetrics.primaryWidth(config: config)
        let cloudMenuX = newTabX + newTabWidth
        let cloudMenuWidth = TitlebarNewWorkspaceCloudSplitButtonMetrics.dropdownWidth(config: config)
        let focusBackX = cloudMenuX + cloudMenuWidth + config.spacing
        let focusForwardX = focusBackX + config.buttonSize + config.spacing

        let minX: CGFloat = switch slot {
        case .toggleSidebar:
            sidebarX
        case .showNotifications:
            notificationsX
        case .newTab:
            newTabX
        case .cloudVM:
            cloudMenuX
        case .focusHistoryBack:
            focusBackX
        case .focusHistoryForward:
            focusForwardX
        case .compactMenu:
            startX
        }
        let width: CGFloat = switch slot {
        case .newTab:
            newTabWidth
        case .cloudVM:
            cloudMenuWidth
        case .toggleSidebar, .showNotifications, .focusHistoryBack, .focusHistoryForward, .compactMenu:
            config.buttonSize
        }
        return minX...(minX + width)
    }

    static func sidebarActionSlot(
        at point: NSPoint,
        config: TitlebarControlsStyleConfig
    ) -> MinimalModeSidebarControlActionSlot? {
        sidebarActionSlot(at: point, config: config, presentation: .expanded)
    }

    static func sidebarActionSlot(
        at point: NSPoint,
        config: TitlebarControlsStyleConfig,
        presentation: MinimalModeSidebarTitlebarControlsPresentation
    ) -> MinimalModeSidebarControlActionSlot? {
        let slots = MinimalModeSidebarTitlebarControlsLayout.slots(for: presentation)
        let ranges = buttonXRanges(config: config, presentation: presentation)
        for (slot, range) in zip(slots, ranges) where range.contains(point.x) {
            return slot
        }
        return nil
    }

    static func pointFallsInButtonColumn(_ point: NSPoint, config: TitlebarControlsStyleConfig) -> Bool {
        sidebarActionSlot(at: point, config: config) != nil
    }

    static func pointFallsInButtonColumn(
        _ point: NSPoint,
        config: TitlebarControlsStyleConfig,
        presentation: MinimalModeSidebarTitlebarControlsPresentation
    ) -> Bool {
        sidebarActionSlot(at: point, config: config, presentation: presentation) != nil
    }
}

final class MinimalModeSidebarControlActionView: NSView {
    var config = TitlebarControlsStyle.classic.config
    {
        didSet {
            guard config != oldValue else { return }
            needsLayout = true
        }
    }
    var presentation = MinimalModeSidebarTitlebarControlsPresentation.expanded
    {
        didSet {
            guard presentation != oldValue else { return }
            needsLayout = true
            syncButtons()
        }
    }
    var isEnabled = true
    {
        didSet {
            guard isEnabled != oldValue else { return }
            syncButtons()
        }
    }
    var requiresRevealedState = false
    var exposesAccessibility = true
    {
        didSet {
            guard exposesAccessibility != oldValue else { return }
            syncButtons()
        }
    }
    var compactMenuAccessibilityValue: String?
    {
        didSet {
            guard compactMenuAccessibilityValue != oldValue else { return }
            syncButtons()
        }
    }
    var telemetryPrefix = "minimalSidebarClickProxy"
    var onAction: ((MinimalModeSidebarControlActionSlot, NSView, NSPoint) -> Void)?
    private let buttons: [MinimalModeSidebarControlActionSlot: MinimalModeSidebarControlButton]

    override init(frame frameRect: NSRect) {
        var buttons: [MinimalModeSidebarControlActionSlot: MinimalModeSidebarControlButton] = [:]
        for slot in MinimalModeSidebarControlActionSlot.allCases {
            buttons[slot] = Self.makeButton(for: slot)
        }
        self.buttons = buttons
        super.init(frame: frameRect)
        for (slot, button) in buttons {
            button.target = self
            button.tag = slot.rawValue
            button.actionOwner = self
            button.setAccessibilityParent(self)
            addSubview(button)
        }
        syncButtons()
    }

    required init?(coder: NSCoder) {
        var buttons: [MinimalModeSidebarControlActionSlot: MinimalModeSidebarControlButton] = [:]
        for slot in MinimalModeSidebarControlActionSlot.allCases {
            buttons[slot] = Self.makeButton(for: slot)
        }
        self.buttons = buttons
        super.init(coder: coder)
        for (slot, button) in buttons {
            button.target = self
            button.action = #selector(buttonPressed(_:))
            button.tag = slot.rawValue
            button.actionOwner = self
            button.setAccessibilityParent(self)
            addSubview(button)
        }
        syncButtons()
    }

    private static func makeButton(for slot: MinimalModeSidebarControlActionSlot) -> MinimalModeSidebarControlButton {
        let button = MinimalModeSidebarControlButton(slot: slot)
        button.isBordered = false
        button.isTransparent = true
        button.title = ""
        button.bezelStyle = .regularSquare
        button.focusRingType = .none
        button.refusesFirstResponder = true
        button.setButtonType(.momentaryChange)
        button.action = #selector(buttonPressed(_:))
        button.identifier = NSUserInterfaceItemIdentifier(slot.accessibilityIdentifier)
        button.setAccessibilityIdentifier(slot.accessibilityIdentifier)
        button.setAccessibilityLabel(slot.accessibilityLabel)
        button.setAccessibilityRole(slot == .compactMenu ? .menuButton : .button)
        return button
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func isAccessibilityElement() -> Bool {
        false
    }

    override func accessibilityChildren() -> [Any]? {
        guard exposesAccessibility, isEnabled else { return [] }
        return MinimalModeSidebarTitlebarControlsLayout.slots(for: presentation).compactMap { buttons[$0] }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let eventType = NSApp.currentEvent?.type,
           eventType != .leftMouseDown,
           eventType != .rightMouseDown {
            return nil
        }
        guard bounds.contains(point) else { return nil }
        guard let slot = TitlebarControlsHitRegions.sidebarActionSlot(
            at: point,
            config: config,
            presentation: presentation
        ) else {
            return nil
        }
        if NSApp.currentEvent?.type == .rightMouseDown, !slot.acceptsContextMenu {
            return nil
        }
        guard shouldAcceptAction(at: point) else { return nil }
        #if DEBUG
        if ProcessInfo.processInfo.environment["CMUX_UI_TEST_BONSPLIT_TAB_DRAG_SETUP"] == "1" {
            _ = UITestCaptureSink().mutateJSONObjectIfConfigured(envKey: "CMUX_UI_TEST_BONSPLIT_TAB_DRAG_PATH") { payload in
                payload["\(telemetryPrefix)LastHitTestSlot"] = slot.debugName
                payload["\(telemetryPrefix)LastHitTestPoint"] = windowDragHandleFormatPoint(point)
                payload["\(telemetryPrefix)LastHitTestWindowNumber"] = window.map { String($0.windowNumber) } ?? "nil"
                payload["\(telemetryPrefix)LastHitTestRevealed"] = String(isRevealed)
            }
        }
        #endif
        return self
    }

    override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        guard let slot = TitlebarControlsHitRegions.sidebarActionSlot(
            at: localPoint,
            config: config,
            presentation: presentation
        ) else {
            super.mouseDown(with: event)
            return
        }
        guard shouldAcceptAction(at: localPoint) else {
            super.mouseDown(with: event)
            return
        }
        performAction(slot: slot, anchorView: self, locationInWindow: event.locationInWindow)
    }

    override func rightMouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        guard let slot = TitlebarControlsHitRegions.sidebarActionSlot(
            at: localPoint,
            config: config,
            presentation: presentation
        ),
              shouldAcceptAction(at: localPoint) else {
            super.rightMouseDown(with: event)
            return
        }
        switch slot {
        case .toggleSidebar:
            CmuxExtensionSidebarSelection.showMenu(anchorView: self, event: event)
        case .newTab:
            _ = AppDelegate.shared?.showNewWorkspaceContextMenu(anchorView: self, event: event)
        case .cloudVM:
            _ = AppDelegate.shared?.showNewWorkspaceContextMenu(
                anchorView: self,
                event: event,
                debugSource: "titlebar.minimalSidebar.cloudMenu.rightClick"
            )
        case .focusHistoryBack:
            _ = AppDelegate.shared?.showFocusHistoryContextMenu(anchorView: self, event: event, direction: .back)
        case .focusHistoryForward:
            _ = AppDelegate.shared?.showFocusHistoryContextMenu(anchorView: self, event: event, direction: .forward)
        case .showNotifications:
            super.rightMouseDown(with: event)
        case .compactMenu:
            performAction(slot: slot, anchorView: self, locationInWindow: event.locationInWindow)
        }
    }

    override func layout() {
        super.layout()
        let slots = MinimalModeSidebarTitlebarControlsLayout.slots(for: presentation)
        let ranges = TitlebarControlsHitRegions.buttonXRanges(config: config, presentation: presentation)
        for button in buttons.values {
            button.isHidden = true
        }
        for (slot, range) in zip(slots, ranges) {
            guard let button = buttons[slot] else { continue }
            button.isHidden = false
            button.frame = NSRect(
                x: range.lowerBound,
                y: max(0, (bounds.height - config.buttonSize) / 2),
                width: range.upperBound - range.lowerBound,
                height: config.buttonSize
            )
        }
        syncButtons()
    }

    @objc private func buttonPressed(_ sender: NSButton) {
        guard let sender = sender as? MinimalModeSidebarControlButton else { return }
        performButtonAction(sender)
    }

    fileprivate func performButtonAction(_ sender: MinimalModeSidebarControlButton) {
        let localPoint = sender.frame.center
        performAction(slot: sender.slot, anchorView: sender, locationInWindow: convert(localPoint, to: nil))
    }

    private func performAction(
        slot: MinimalModeSidebarControlActionSlot,
        anchorView: NSView,
        locationInWindow: NSPoint
    ) {
        guard isEnabled else { return }

        #if DEBUG
        if ProcessInfo.processInfo.environment["CMUX_UI_TEST_BONSPLIT_TAB_DRAG_SETUP"] == "1" {
            _ = UITestCaptureSink().mutateJSONObjectIfConfigured(envKey: "CMUX_UI_TEST_BONSPLIT_TAB_DRAG_PATH") { payload in
                payload["\(telemetryPrefix)LastAction"] = slot.debugName
                payload["\(telemetryPrefix)LastPoint"] = windowDragHandleFormatPoint(convert(locationInWindow, from: nil))
                payload["\(telemetryPrefix)WindowNumber"] = window.map { String($0.windowNumber) } ?? "nil"
                payload["\(telemetryPrefix)LastActionRevealed"] = String(isRevealed)
            }
        }
        #endif

        if let window {
            MinimalModeSidebarChromeHoverState.shared.setHovering(true, windowNumber: window.windowNumber)
        }
        onAction?(slot, anchorView, locationInWindow)
    }

    private func syncButtons() {
        let visibleSlots = Set(MinimalModeSidebarTitlebarControlsLayout.slots(for: presentation))
        for (slot, button) in buttons {
            let isVisible = visibleSlots.contains(slot)
            button.isHidden = !isVisible
            button.isEnabled = isVisible && isEnabled
            button.setAccessibilityElement(isVisible && isEnabled && exposesAccessibility)
            button.setAccessibilityValue(slot == .compactMenu ? compactMenuAccessibilityValue : nil)
        }
    }

    private var isRevealed: Bool {
        guard isEnabled else { return false }
        guard requiresRevealedState else { return true }
        guard let window else { return false }
        return MinimalModeSidebarChromeHoverState.shared.hoveredWindowNumber == window.windowNumber
            || NotificationsPopoverVisibilityState.shared.isShown(in: window.windowNumber)
    }

    private func shouldAcceptAction(at localPoint: NSPoint) -> Bool {
        guard isEnabled else { return false }
        guard requiresRevealedState else { return true }
        return isRevealed
    }
}

private final class MinimalModeSidebarControlButton: NSButton {
    let slot: MinimalModeSidebarControlActionSlot
    weak var actionOwner: MinimalModeSidebarControlActionView?

    init(slot: MinimalModeSidebarControlActionSlot) {
        self.slot = slot
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func accessibilityIdentifier() -> String {
        slot.accessibilityIdentifier
    }

    override func accessibilityLabel() -> String? {
        slot.accessibilityLabel
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        slot == .compactMenu ? .menuButton : .button
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        actionOwner?.performButtonAction(self)
    }

    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        actionOwner?.performButtonAction(self)
        return true
    }
}

private extension NSRect {
    var center: NSPoint {
        NSPoint(x: midX, y: midY)
    }
}
