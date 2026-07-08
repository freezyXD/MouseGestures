import AppKit
import CoreGraphics
import Foundation

enum TrackpadGesture: String, CaseIterable, Codable {
    case swipeLeft
    case swipeRight
    case swipeUp
    case swipeDown

    case threeFingerSwipeLeft
    case threeFingerSwipeRight
    case threeFingerSwipeUp
    case threeFingerSwipeDown

    case pinchIn
    case pinchOut

    case rotateLeft
    case rotateRight

    case smartZoom

    var displayName: String {
        switch self {
        case .swipeLeft: return "2-Finger Swipe Left"
        case .swipeRight: return "2-Finger Swipe Right"
        case .swipeUp: return "2-Finger Swipe Up"
        case .swipeDown: return "2-Finger Swipe Down"
        case .threeFingerSwipeLeft: return "3-Finger Swipe Left"
        case .threeFingerSwipeRight: return "3-Finger Swipe Right"
        case .threeFingerSwipeUp: return "3-Finger Swipe Up"
        case .threeFingerSwipeDown: return "3-Finger Swipe Down"
        case .pinchIn: return "Pinch In"
        case .pinchOut: return "Pinch Out"
        case .rotateLeft: return "Rotate Left"
        case .rotateRight: return "Rotate Right"
        case .smartZoom: return "Smart Zoom"
        }
    }

    var shortName: String {
        switch self {
        case .swipeLeft: return "← 2-finger"
        case .swipeRight: return "→ 2-finger"
        case .swipeUp: return "↑ 2-finger"
        case .swipeDown: return "↓ 2-finger"
        case .threeFingerSwipeLeft: return "← 3-finger"
        case .threeFingerSwipeRight: return "→ 3-finger"
        case .threeFingerSwipeUp: return "↑ 3-finger"
        case .threeFingerSwipeDown: return "↓ 3-finger"
        case .pinchIn: return "Pinch In"
        case .pinchOut: return "Pinch Out"
        case .rotateLeft: return "↺ Rotate"
        case .rotateRight: return "↻ Rotate"
        case .smartZoom: return "Smart Zoom"
        }
    }

    var symbolName: String {
        switch self {
        case .swipeLeft, .threeFingerSwipeLeft: return "arrow.left"
        case .swipeRight, .threeFingerSwipeRight: return "arrow.right"
        case .swipeUp, .threeFingerSwipeUp: return "arrow.up"
        case .swipeDown, .threeFingerSwipeDown: return "arrow.down"
        case .pinchIn: return "arrow.down.right.and.arrow.up.left"
        case .pinchOut: return "arrow.up.left.and.arrow.down.right"
        case .rotateLeft: return "arrow.counterclockwise"
        case .rotateRight: return "arrow.clockwise"
        case .smartZoom: return "plus.magnifyingglass"
        }
    }

    var direction: Direction? {
        switch self {
        case .swipeLeft, .threeFingerSwipeLeft: return .left
        case .swipeRight, .threeFingerSwipeRight: return .right
        case .swipeUp, .threeFingerSwipeUp: return .up
        case .swipeDown, .threeFingerSwipeDown: return .down
        default: return nil
        }
    }

    var category: String {
        switch self {
        case .swipeLeft, .swipeRight, .swipeUp, .swipeDown: return "2-Finger Swipes"
        case .threeFingerSwipeLeft, .threeFingerSwipeRight, .threeFingerSwipeUp, .threeFingerSwipeDown: return "3-Finger Swipes"
        case .pinchIn, .pinchOut: return "Pinch"
        case .rotateLeft, .rotateRight: return "Rotation"
        case .smartZoom: return "Other"
        }
    }

    var systemDefault: String? {
        switch self {
        case .swipeUp, .swipeDown: return "Scroll (vertical)"
        case .swipeLeft, .swipeRight: return "Scroll (horizontal)"
        case .threeFingerSwipeUp: return "Mission Control (show all windows)"
        case .threeFingerSwipeDown: return "App Exposé (windows of current app)"
        case .threeFingerSwipeLeft: return "Previous desktop / full-screen app"
        case .threeFingerSwipeRight: return "Next desktop / full-screen app"
        case .pinchIn: return "Zoom out"
        case .pinchOut: return "Zoom in"
        case .rotateLeft, .rotateRight: return "Off (no default behavior)"
        case .smartZoom: return "Toggle zoom in supported apps"
        }
    }
}

enum Trigger: Equatable, Hashable, CaseIterable {
    case mouseButton(TriggerButton)
    case trackpad(TrackpadGesture)
    case keyboardShortcut(KeyCombo)
    case keyMouseGesture(KeyCombo)

    var displayName: String {
        switch self {
        case .mouseButton(let button): return "🖱  \(button.displayName)"
        case .trackpad(let gesture): return "✋  \(gesture.displayName)"
        case .keyboardShortcut(let combo): return "⌨️  \(combo.displayString)"
        case .keyMouseGesture(let combo): return "🔑  Hold \(combo.displayString)"
        }
    }

    var compactName: String {
        switch self {
        case .mouseButton(let button): return button.shortName
        case .trackpad(let gesture): return gesture.shortName
        case .keyboardShortcut(let combo): return combo.displayString
        case .keyMouseGesture(let combo): return "Hold \(combo.displayString)"
        }
    }

    var symbolName: String {
        switch self {
        case .mouseButton: return "computermouse"
        case .trackpad: return "rectangle.dashed.and.paperclip"
        case .keyboardShortcut: return "keyboard"
        case .keyMouseGesture: return "keyboard.badge.ellipsis"
        }
    }

    static var allCases: [Trigger] {
        return TriggerButton.standardButtons.map(Trigger.mouseButton) + TrackpadGesture.allCases.map(Trigger.trackpad)
    }
}

extension Trigger: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case buttonNumber
        case customName
        case trackpad
        case keyCode
        case modifiers
        case displayKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "mouseButton":
            if let buttonNumber = try container.decodeIfPresent(Int.self, forKey: .buttonNumber) {
                let customName = try container.decodeIfPresent(String.self, forKey: .customName)
                self = .mouseButton(TriggerButton(buttonNumber: buttonNumber, customName: customName))
            } else {
                throw DecodingError.dataCorruptedError(forKey: .buttonNumber, in: container, debugDescription: "Missing buttonNumber")
            }
        case "trackpad":
            let trackpad = try container.decode(TrackpadGesture.self, forKey: .trackpad)
            self = .trackpad(trackpad)
        case "keyboardShortcut", "keyMouseGesture":
            let keyCode = try container.decode(UInt16.self, forKey: .keyCode)
            let modifiers = try container.decode([KeyCombo.Modifier].self, forKey: .modifiers)
            let displayKey = try container.decodeIfPresent(String.self, forKey: .displayKey)
            let combo = KeyCombo(keyCode: keyCode, modifiers: modifiers, displayKey: displayKey)
            self = (kind == "keyMouseGesture") ? .keyMouseGesture(combo) : .keyboardShortcut(combo)
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown trigger kind: \(kind)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .mouseButton(let button):
            try container.encode("mouseButton", forKey: .kind)
            try container.encode(button.buttonNumber, forKey: .buttonNumber)
            try container.encode(button.customName, forKey: .customName)
        case .trackpad(let trackpad):
            try container.encode("trackpad", forKey: .kind)
            try container.encode(trackpad, forKey: .trackpad)
        case .keyboardShortcut(let combo):
            try container.encode("keyboardShortcut", forKey: .kind)
            try container.encode(combo.keyCode, forKey: .keyCode)
            try container.encode(combo.modifiers, forKey: .modifiers)
            try container.encode(combo.displayKey, forKey: .displayKey)
        case .keyMouseGesture(let combo):
            try container.encode("keyMouseGesture", forKey: .kind)
            try container.encode(combo.keyCode, forKey: .keyCode)
            try container.encode(combo.modifiers, forKey: .modifiers)
            try container.encode(combo.displayKey, forKey: .displayKey)
        }
    }
}
