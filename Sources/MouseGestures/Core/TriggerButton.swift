import CoreGraphics
import Foundation

struct TriggerButton: Codable, Equatable, Hashable {
    var buttonNumber: Int
    var customName: String?

    init(buttonNumber: Int, customName: String? = nil) {
        self.buttonNumber = max(0, min(buttonNumber, 31))
        if let customName, !customName.isEmpty {
            self.customName = String(customName.prefix(64))
        } else {
            self.customName = nil
        }
    }

    static let left = TriggerButton(buttonNumber: 0, customName: "Left")
    static let right = TriggerButton(buttonNumber: 1, customName: "Right")
    static let middle = TriggerButton(buttonNumber: 2, customName: "Middle")
    static let x1 = TriggerButton(buttonNumber: 3, customName: "X1")
    static let x2 = TriggerButton(buttonNumber: 4, customName: "X2")

    static let standardButtons: [TriggerButton] = [.left, .right, .middle, .x1, .x2]

    var isStandard: Bool {
        return buttonNumber >= 0 && buttonNumber <= 4
    }

    var identity: Int {
        buttonNumber
    }

    var displayName: String {
        if let name = customName, !name.isEmpty { return name }
        switch buttonNumber {
        case 0: return "Left Button"
        case 1: return "Right Button"
        case 2: return "Middle Button"
        case 3: return "Side Button 1 (X1)"
        case 4: return "Side Button 2 (X2)"
        default: return "Button \(buttonNumber)"
        }
    }

    var shortName: String {
        if let name = customName, !name.isEmpty { return name }
        switch buttonNumber {
        case 0: return "Left"
        case 1: return "Right"
        case 2: return "Middle"
        case 3: return "X1"
        case 4: return "X2"
        default: return "Btn \(buttonNumber)"
        }
    }

    var eventType: CGEventType {
        switch buttonNumber {
        case 0: return .leftMouseDown
        case 1: return .rightMouseDown
        default: return .otherMouseDown
        }
    }

    var upEventType: CGEventType {
        switch buttonNumber {
        case 0: return .leftMouseUp
        case 1: return .rightMouseUp
        default: return .otherMouseUp
        }
    }

    var draggedEventType: CGEventType {
        switch buttonNumber {
        case 0: return .leftMouseDragged
        case 1: return .rightMouseDragged
        default: return .otherMouseDragged
        }
    }

    static func == (lhs: TriggerButton, rhs: TriggerButton) -> Bool {
        lhs.buttonNumber == rhs.buttonNumber
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(buttonNumber)
    }

    enum CodingKeys: String, CodingKey {
        case buttonNumber
        case customName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let number = try container.decode(Int.self, forKey: .buttonNumber)
        let name = try container.decodeIfPresent(String.self, forKey: .customName)
        self.init(buttonNumber: number, customName: name)
    }
}
