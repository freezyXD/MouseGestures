import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController: NSWindowController {
    private let model: PreferencesModel
    private let onApply: (Configuration) -> Void

    init(model: PreferencesModel, onApply: @escaping (Configuration) -> Void) {
        self.model = model
        self.onApply = onApply

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MouseGestures Preferences"
        window.isReleasedWhenClosed = false
        window.center()

        let view = PreferencesView(model: model, onApply: onApply)
        window.contentView = NSHostingView(rootView: view)

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        guard let window = window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
