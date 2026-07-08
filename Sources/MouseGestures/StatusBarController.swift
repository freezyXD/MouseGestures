import AppKit

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    private var configuration: Configuration
    private let onToggleEnabled: (Bool) -> Void
    private let onToggleFeedback: (Bool) -> Void
    private let onToggleLaunchAtLogin: (Bool) -> Void
    private let onOpenPreferences: () -> Void
    private let onRequestAccessibility: () -> Void
    private let onRequestInputMonitoring: () -> Void
    private let onQuit: () -> Void

    private var enabledMenuItem: NSMenuItem?
    private var feedbackMenuItem: NSMenuItem?
    private var launchAtLoginMenuItem: NSMenuItem?
    private var statusMenuItem: NSMenuItem?
    private var accessibilityMenuItem: NSMenuItem?
    private var inputMonitoringMenuItem: NSMenuItem?
    private var needsAccessibility: Bool = false
    private var needsInputMonitoring: Bool = false
    private var engineRunning: Bool = false

    init(
        configuration: Configuration,
        onToggleEnabled: @escaping (Bool) -> Void,
        onToggleFeedback: @escaping (Bool) -> Void,
        onToggleLaunchAtLogin: @escaping (Bool) -> Void,
        onOpenPreferences: @escaping () -> Void,
        onRequestAccessibility: @escaping () -> Void,
        onRequestInputMonitoring: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.configuration = configuration
        self.onToggleEnabled = onToggleEnabled
        self.onToggleFeedback = onToggleFeedback
        self.onToggleLaunchAtLogin = onToggleLaunchAtLogin
        self.onOpenPreferences = onOpenPreferences
        self.onRequestAccessibility = onRequestAccessibility
        self.onRequestInputMonitoring = onRequestInputMonitoring
        self.onQuit = onQuit
        super.init()
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            applyIcon(to: button, active: true)
        }
        statusItem = item
        rebuildMenu()
    }

    func update(with configuration: Configuration) {
        self.configuration = configuration
        rebuildMenu()
    }

    func setEngineRunning(_ running: Bool) {
        engineRunning = running
        if let button = statusItem?.button {
            applyIcon(to: button, active: running)
        }
        statusMenuItem?.title = running
            ? "MouseGestures (\(configuration.gestures.count) gesture\(configuration.gestures.count == 1 ? "" : "s"))"
            : "MouseGestures (paused)"
    }

    private func applyIcon(to button: NSStatusBarButton, active: Bool) {
        if let image = MenuBarIcon.image(active: active) {
            button.image = image
            button.imagePosition = .imageOnly
            button.title = ""
            button.appearsDisabled = !active
            button.alphaValue = active ? 1.0 : 0.45
        } else {
            button.image = nil
            button.title = active ? "MG" : "mg"
            button.appearsDisabled = !active
        }
    }

    func setPermissionWarnings(accessibility: Bool, inputMonitoring: Bool) {
        let hadChanges = needsAccessibility != accessibility || needsInputMonitoring != inputMonitoring
        needsAccessibility = accessibility
        needsInputMonitoring = inputMonitoring
        if let item = statusMenuItem {
            if accessibility && inputMonitoring {
                item.title = "MouseGestures (no permissions)"
            } else if accessibility {
                item.title = "MouseGestures (no Accessibility)"
            } else if inputMonitoring {
                item.title = "MouseGestures (no Input Monitoring)"
            } else if engineRunning {
                item.title = "MouseGestures (\(configuration.gestures.count) gesture\(configuration.gestures.count == 1 ? "" : "s"))"
            } else {
                item.title = "MouseGestures"
            }
        }
        if hadChanges {
            rebuildMenu()
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let title: String
        if needsAccessibility && needsInputMonitoring {
            title = "MouseGestures (no permissions)"
        } else if needsAccessibility {
            title = "MouseGestures (no Accessibility)"
        } else if needsInputMonitoring {
            title = "MouseGestures (no Input Monitoring)"
        } else if engineRunning {
            title = "MouseGestures (\(configuration.gestures.count) gesture\(configuration.gestures.count == 1 ? "" : "s"))"
        } else {
            title = "MouseGestures"
        }
        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        statusMenuItem = header
        menu.addItem(header)

        if needsAccessibility || needsInputMonitoring {
            if needsAccessibility {
                let warningItem = NSMenuItem(
                    title: "⚠️  Grant Accessibility Access",
                    action: #selector(requestAccessibility),
                    keyEquivalent: ""
                )
                warningItem.target = self
                menu.addItem(warningItem)
                accessibilityMenuItem = warningItem
            }
            if needsInputMonitoring {
                let warningItem = NSMenuItem(
                    title: "⚠️  Grant Input Monitoring",
                    action: #selector(requestInputMonitoring),
                    keyEquivalent: ""
                )
                warningItem.target = self
                menu.addItem(warningItem)
                inputMonitoringMenuItem = warningItem
            }
            menu.addItem(.separator())
        }

        let enabledItem = NSMenuItem(
            title: "Enabled",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = configuration.enabled ? .on : .off
        menu.addItem(enabledItem)
        enabledMenuItem = enabledItem

        let feedbackItem = NSMenuItem(
            title: "Show Feedback Overlay",
            action: #selector(toggleFeedback),
            keyEquivalent: ""
        )
        feedbackItem.target = self
        feedbackItem.state = configuration.showFeedback ? .on : .off
        menu.addItem(feedbackItem)
        feedbackMenuItem = feedbackItem

        menu.addItem(.separator())

        if #available(macOS 13.0, *) {
            let launchItem = NSMenuItem(
                title: "Launch at Login",
                action: #selector(toggleLaunchAtLogin),
                keyEquivalent: ""
            )
            launchItem.target = self
            launchItem.state = configuration.launchAtLogin ? .on : .off
            menu.addItem(launchItem)
            launchAtLoginMenuItem = launchItem
        }

        let prefsItem = NSMenuItem(
            title: "Preferences…",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit MouseGestures",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        self.menu = menu
        statusItem?.menu = menu
    }

    @objc private func toggleEnabled() {
        onToggleEnabled(!configuration.enabled)
    }

    @objc private func toggleFeedback() {
        onToggleFeedback(!configuration.showFeedback)
    }

    @objc private func toggleLaunchAtLogin() {
        onToggleLaunchAtLogin(!configuration.launchAtLogin)
    }

    @objc private func openPreferences() {
        onOpenPreferences()
    }

    @objc private func quit() {
        onQuit()
    }

    @objc private func requestAccessibility() {
        onRequestAccessibility()
    }

    @objc private func requestInputMonitoring() {
        onRequestInputMonitoring()
    }
}

enum MenuBarIcon {
    static func image(active: Bool) -> NSImage? {
        let name = active ? "computermouse.fill" : "computermouse"
        if let img = NSImage(systemSymbolName: name, accessibilityDescription: "MouseGestures") {
            img.isTemplate = true
            return img
        }
        if let img = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "MouseGestures") {
            img.isTemplate = true
            return img
        }
        return nil
    }
}
