import Carbon
import Foundation

struct SystemGestureTemplate: Identifiable {
    enum PresetKind: String, Hashable, CaseIterable {
        case missionControl
        case appExpose
        case previousFullScreen
        case nextFullScreen
        case showDesktop
        case launchpad
    }

    let id: String
    let kind: PresetKind
    let title: String
    let description: String
    let symbolName: String
    let gesture: Gesture
}

extension SystemGestureTemplate {
    static let all: [SystemGestureTemplate] = [
        SystemGestureTemplate(
            id: "missionControl",
            kind: .missionControl,
            title: "Mission Control",
            description: "3-finger swipe up — show all open windows",
            symbolName: "macwindow.on.rectangle",
            gesture: Gesture(
                trigger: .trackpad(.threeFingerSwipeUp),
                direction: .up,
                action: .keyCombo(KeyCombo(keyCode: 0x7E, modifiers: [.control]))
            )
        ),
        SystemGestureTemplate(
            id: "appExpose",
            kind: .appExpose,
            title: "App Exposé",
            description: "3-finger swipe down — windows of current app",
            symbolName: "rectangle.stack.fill",
            gesture: Gesture(
                trigger: .trackpad(.threeFingerSwipeDown),
                direction: .down,
                action: .keyCombo(KeyCombo(keyCode: 0x7D, modifiers: [.control]))
            )
        ),
        SystemGestureTemplate(
            id: "previousFullScreen",
            kind: .previousFullScreen,
            title: "Previous Full-Screen App",
            description: "3-finger swipe left",
            symbolName: "arrow.left.circle",
            gesture: Gesture(
                trigger: .trackpad(.threeFingerSwipeLeft),
                direction: .left,
                action: .keyCombo(KeyCombo(keyCode: 0x7B, modifiers: [.control]))
            )
        ),
        SystemGestureTemplate(
            id: "nextFullScreen",
            kind: .nextFullScreen,
            title: "Next Full-Screen App",
            description: "3-finger swipe right",
            symbolName: "arrow.right.circle",
            gesture: Gesture(
                trigger: .trackpad(.threeFingerSwipeRight),
                direction: .right,
                action: .keyCombo(KeyCombo(keyCode: 0x7C, modifiers: [.control]))
            )
        ),
        SystemGestureTemplate(
            id: "showDesktop",
            kind: .showDesktop,
            title: "Show Desktop",
            description: "Spread fingers apart — show desktop",
            symbolName: "menubar.dock.rectangle",
            gesture: Gesture(
                trigger: .trackpad(.pinchOut),
                direction: .right,
                action: .keyCombo(KeyCombo(keyCode: 0x67, modifiers: []))
            )
        ),
        SystemGestureTemplate(
            id: "launchpad",
            kind: .launchpad,
            title: "Launchpad",
            description: "Pinch fingers together — open Launchpad",
            symbolName: "square.grid.2x2.fill",
            gesture: Gesture(
                trigger: .trackpad(.pinchIn),
                direction: .right,
                action: .keyCombo(KeyCombo(keyCode: 0x60, modifiers: []))
            )
        )
    ]
}
