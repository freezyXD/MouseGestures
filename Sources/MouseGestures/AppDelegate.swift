import AppKit
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.freezy.MouseGestures", category: "AppDelegate")

    let configStore: ConfigStore
    let preferencesModel: PreferencesModel
    let actionExecutor: ActionExecutor
    let feedbackOverlay: FeedbackOverlayController

    private(set) var engine: GestureEngine?

    private var statusBar: StatusBarController?
    private var preferencesWindow: PreferencesWindowController?

    private var currentConfiguration: Configuration

    override init() {
        self.configStore = ConfigStore.shared
        self.preferencesModel = PreferencesModel(store: configStore)
        self.actionExecutor = ActionExecutor()
        self.feedbackOverlay = FeedbackOverlayController()
        self.currentConfiguration = configStore.load()
        self.preferencesModel.configuration = self.currentConfiguration
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        checkPermissionsAtLaunch()
        feedbackOverlay.directionUpdateDelay = currentConfiguration.directionUpdateDelay
        statusBar = StatusBarController(
            configuration: currentConfiguration,
            onToggleEnabled: { [weak self] enabled in
                self?.applyEnabledChange(enabled)
            },
            onToggleFeedback: { [weak self] showFeedback in
                self?.applyShowFeedbackChange(showFeedback)
            },
            onToggleLaunchAtLogin: { [weak self] enabled in
                self?.applyLaunchAtLoginChange(enabled)
            },
            onOpenPreferences: { [weak self] in
                self?.openPreferences()
            },
            onRequestAccessibility: { [weak self] in
                self?.requestAccessibilityFromMenu()
            },
            onRequestInputMonitoring: { [weak self] in
                self?.requestInputMonitoringFromMenu()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        statusBar?.install()
        updatePermissionWarnings()

        preferencesWindow = PreferencesWindowController(
            model: preferencesModel,
            onApply: { [weak self] newConfig in
                self?.applyConfiguration(newConfig)
            }
        )

        applyConfiguration(currentConfiguration)
        logger.info("MouseGestures started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        feedbackOverlay.forceShowCursor()
        engine?.stop()
        try? configStore.save(currentConfiguration)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        updatePermissionWarnings()
        if engine == nil && currentConfiguration.enabled {
            rebuildEngine()
        }
    }

    private func checkPermissionsAtLaunch() {
        if !Permissions.isAccessibilityGranted() {
            requestAccessibilityFromMenu()
        }
        if !Permissions.isInputMonitoringGranted() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.requestInputMonitoringFromMenu()
            }
        }
    }

    private func updatePermissionWarnings() {
        statusBar?.setPermissionWarnings(
            accessibility: !Permissions.isAccessibilityGranted(),
            inputMonitoring: !Permissions.isInputMonitoringGranted()
        )
    }

    private func requestAccessibilityFromMenu() {
        let response = showAccessibilityAlert()
        guard response == .alertFirstButtonReturn else { return }
        _ = Permissions.requestAccessibility()
        Permissions.openAccessibilitySettings()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.updatePermissionWarnings()
        }
    }

    private func requestInputMonitoringFromMenu() {
        let response = showInputMonitoringAlert()
        guard response == .alertFirstButtonReturn else { return }
        _ = Permissions.requestInputMonitoring()
        Permissions.openInputMonitoringSettings()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.updatePermissionWarnings()
        }
    }

    @discardableResult
    private func showAccessibilityAlert() -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = """
        MouseGestures needs Accessibility access to capture mouse events globally.

        1. Click "Open Settings"
        2. Enable the toggle next to MouseGestures
        3. Come back here — the warning will disappear automatically
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        return alert.runModal()
    }

    @discardableResult
    private func showInputMonitoringAlert() -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = "Input Monitoring Required"
        alert.informativeText = """
        MouseGestures needs Input Monitoring access to capture keyboard shortcuts and trackpad gestures globally.

        1. Click "Open Settings"
        2. Enable the toggle next to MouseGestures
        3. Quit and relaunch MouseGestures for the change to take effect
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        return alert.runModal()
    }

    private func openPreferences() {
        preferencesWindow?.show()
    }

    private func applyConfiguration(_ newConfig: Configuration) {
        var sanitized = newConfig
        sanitized.activationThreshold = Configuration.clampThreshold(sanitized.activationThreshold)
        sanitized.directionUpdateDelay = Configuration.clampDelay(sanitized.directionUpdateDelay)
        currentConfiguration = sanitized
        statusBar?.update(with: sanitized)
        feedbackOverlay.directionUpdateDelay = sanitized.directionUpdateDelay
        rebuildEngine()
        if #available(macOS 13.0, *) {
            _ = LaunchAtLogin.setEnabled(sanitized.launchAtLogin)
        }
        do {
            try configStore.save(sanitized)
        } catch {
            logger.error("Failed to save config: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func applyEnabledChange(_ enabled: Bool) {
        var config = currentConfiguration
        config.enabled = enabled
        applyConfiguration(config)
        preferencesModel.configuration = config
    }

    private func applyShowFeedbackChange(_ showFeedback: Bool) {
        var config = currentConfiguration
        config.showFeedback = showFeedback
        applyConfiguration(config)
        preferencesModel.configuration = config
    }

    private func applyLaunchAtLoginChange(_ enabled: Bool) {
        var config = currentConfiguration
        config.launchAtLogin = enabled
        applyConfiguration(config)
        preferencesModel.configuration = config
    }

    private func rebuildEngine() {
        engine?.stop()
        engine = nil
        updatePermissionWarnings()
        guard currentConfiguration.enabled else {
            statusBar?.setEngineRunning(false)
            return
        }
        guard Permissions.isAccessibilityGranted() else {
            statusBar?.setEngineRunning(false)
            logger.error("Cannot start engine: Accessibility not granted")
            return
        }

        let needsInputMonitoring = currentConfiguration.gestures.contains { gesture in
            switch gesture.trigger {
            case .trackpad, .keyboardShortcut, .keyMouseGesture: return true
            default: return false
            }
        }
        let inputGranted = Permissions.isInputMonitoringGranted()
        let allowTrackpad = inputGranted
        let allowKeyboard = inputGranted

        if needsInputMonitoring && !inputGranted {
            logger.error("Input Monitoring not granted; keyboard/trackpad gestures disabled, mouse gestures still active")
        }

        let engineGestures = currentConfiguration.gestures.filter { gesture in
            switch gesture.trigger {
            case .mouseButton:
                return true
            case .trackpad:
                return allowTrackpad
            case .keyboardShortcut, .keyMouseGesture:
                return allowKeyboard
            }
        }

        let newEngine = GestureEngine(
            gestures: engineGestures,
            activationThreshold: currentConfiguration.activationThreshold,
            allowTrackpad: allowTrackpad,
            allowKeyboard: allowKeyboard
        )
        newEngine.delegate = self
        newEngine.start()
        engine = newEngine
        statusBar?.setEngineRunning(newEngine.isEnabled)
    }
}

extension AppDelegate: @preconcurrency GestureEngineDelegate {
    func gestureEngine(_ engine: GestureEngine, didStartTrackingAt location: CGPoint) {
        feedbackOverlay.beginTracking(showOverlay: currentConfiguration.showFeedback, at: location)
    }

    func gestureEngine(_ engine: GestureEngine, didUpdateTrackingWith direction: Direction?, at location: CGPoint) {
        feedbackOverlay.update(direction: direction, at: location)
    }

    func gestureEngine(_ engine: GestureEngine, didRecognize direction: Direction?, trigger: Trigger, action: Action, at location: CGPoint) {
        logger.info("Gesture recognized: \(trigger.compactName, privacy: .public)")
        feedbackOverlay.showFinish(direction: direction, at: location)
        actionExecutor.execute(action)
    }

    func gestureEngine(_ engine: GestureEngine, didCancelAt location: CGPoint) {
        feedbackOverlay.cancel()
    }

    func gestureEngineDidFailToCreateTap(_ engine: GestureEngine) {
        feedbackOverlay.forceShowCursor()
        statusBar?.setEngineRunning(false)
        updatePermissionWarnings()
    }
}
