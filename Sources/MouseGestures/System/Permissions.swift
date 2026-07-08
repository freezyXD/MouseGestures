import AppKit
import ApplicationServices
import Foundation

enum Permissions {
    static func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccessibility() -> Bool {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options: [CFString: Any] = [key: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func isInputMonitoringGranted() -> Bool {
        return CGPreflightListenEventAccess()
    }

    @discardableResult
    static func requestInputMonitoring() -> Bool {
        return CGRequestListenEventAccess()
    }

    static func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    static func allGranted() -> Bool {
        return isAccessibilityGranted() && isInputMonitoringGranted()
    }
}
