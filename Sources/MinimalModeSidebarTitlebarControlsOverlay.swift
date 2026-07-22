import AppKit
import CmuxNotifications
import SwiftUI

struct MinimalModeSidebarTitlebarControlsOverlay: View {
    let unreadModel: SidebarUnreadModel
    let layoutModel: TitlebarControlsLayoutModel
    let leadingInset: CGFloat
    let topPadding: CGFloat
    let onToggleSidebar: () -> Void
    let onToggleNotifications: (NSView?) -> Void
    let onNewTab: () -> Void
    let onFocusHistoryBack: () -> Void
    let onFocusHistoryForward: () -> Void

    @AppStorage(WorkspacePresentationModeSettings.modeKey)
    private var workspacePresentationMode = WorkspacePresentationModeSettings.defaultMode.rawValue
    @AppStorage(TitlebarControlsStyle.storageKey)
    private var titlebarControlsStyleRawValue = TitlebarControlsStyle.defaultRawValue

    private var isMinimalMode: Bool {
        WorkspacePresentationModeSettings.mode(for: workspacePresentationMode) == .minimal
    }

    var body: some View {
        if isMinimalMode {
            GeometryReader { geometry in
                let config = TitlebarControlsStyle.stored(rawValue: titlebarControlsStyleRawValue).config
                let presentation = MinimalModeSidebarTitlebarControlsLayout.presentation(
                    sidebarWidth: geometry.size.width,
                    config: config,
                    leadingInset: leadingInset
                )
                HiddenTitlebarSidebarControlsView(
                    unreadModel: unreadModel,
                    layoutModel: layoutModel,
                    presentation: presentation,
                    onToggleSidebar: onToggleSidebar,
                    onToggleNotifications: onToggleNotifications,
                    onNewTab: onNewTab,
                    onFocusHistoryBack: onFocusHistoryBack,
                    onFocusHistoryForward: onFocusHistoryForward
                )
                .padding(.leading, leadingInset)
                .padding(.top, topPadding)
            }
        }
    }
}
