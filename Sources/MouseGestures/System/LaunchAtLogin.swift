import Foundation
import ServiceManagement

@available(macOS 13.0, *)
final class LaunchAtLogin {
    static let service = SMAppService.mainApp

    static var isEnabled: Bool {
        return service.status == .enabled
    }

    @discardableResult
    static func enable() -> Bool {
        do {
            try service.register()
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func disable() -> Bool {
        do {
            try service.unregister()
            return true
        } catch {
            return false
        }
    }

    static func setEnabled(_ enabled: Bool) -> Bool {
        return enabled ? enable() : disable()
    }
}
