import CoreGraphics
import Foundation

enum Direction: String, CaseIterable, Codable {
    case up
    case down
    case left
    case right
    case upLeft
    case upRight
    case downLeft
    case downRight

    var displayName: String {
        switch self {
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .upLeft: return "Up-Left"
        case .upRight: return "Up-Right"
        case .downLeft: return "Down-Left"
        case .downRight: return "Down-Right"
        }
    }

    var symbolName: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        case .upLeft: return "arrow.up.left"
        case .upRight: return "arrow.up.right"
        case .downLeft: return "arrow.down.left"
        case .downRight: return "arrow.down.right"
        }
    }

    var keyCode: CGKeyCode {
        switch self {
        case .up: return 0x74
        case .down: return 0x79
        case .left: return 0x7B
        case .right: return 0x7C
        case .upLeft: return 0x7B
        case .upRight: return 0x7C
        case .downLeft: return 0x7B
        case .downRight: return 0x7C
        }
    }
}
