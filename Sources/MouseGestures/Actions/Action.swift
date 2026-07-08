import Foundation

enum Action: Codable, Equatable {
    case none
    case keyCombo(KeyCombo)
    case shell(String)
    case appleScript(String)

    var displayDescription: String {
        switch self {
        case .none:
            return "No action"
        case .keyCombo(let combo):
            return combo.displayString
        case .shell(let command):
            let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 40 {
                return String(trimmed.prefix(40)) + "…"
            }
            return trimmed
        case .appleScript(let script):
            let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 40 {
                return String(trimmed.prefix(40)) + "…"
            }
            return trimmed
        }
    }

    var isDangerous: Bool {
        switch self {
        case .shell, .appleScript: return true
        case .none, .keyCombo: return false
        }
    }
}
