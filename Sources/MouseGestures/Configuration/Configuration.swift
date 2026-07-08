import Foundation

struct Configuration: Codable, Equatable {
    var version: Int
    var enabled: Bool
    var defaultTrigger: Trigger
    var activationThreshold: CGFloat
    var showFeedback: Bool
    var launchAtLogin: Bool
    var gestures: [Gesture]
    var directionUpdateDelay: TimeInterval

    static let currentVersion = 3
    static let maxSupportedVersion = 3
    static let maxFileSize: Int = 256 * 1024

    init(
        version: Int = Configuration.currentVersion,
        enabled: Bool = true,
        defaultTrigger: Trigger = .mouseButton(.right),
        activationThreshold: CGFloat = 60.0,
        showFeedback: Bool = true,
        launchAtLogin: Bool = false,
        gestures: [Gesture] = Configuration.defaultGestures(),
        directionUpdateDelay: TimeInterval = 0.03
    ) {
        self.version = version
        self.enabled = enabled
        self.defaultTrigger = defaultTrigger
        self.activationThreshold = Self.clampThreshold(activationThreshold)
        self.showFeedback = showFeedback
        self.launchAtLogin = launchAtLogin
        self.gestures = gestures
        self.directionUpdateDelay = Self.clampDelay(directionUpdateDelay)
    }

    static func defaultGestures() -> [Gesture] {
        let right = Trigger.mouseButton(.right)
        return [
            Gesture(trigger: right, direction: .left, action: .keyCombo(KeyCombo(keyCode: 0x7B, modifiers: [.command]))),
            Gesture(trigger: right, direction: .right, action: .keyCombo(KeyCombo(keyCode: 0x7C, modifiers: [.command]))),
            Gesture(trigger: right, direction: .up, action: .keyCombo(KeyCombo(keyCode: 0x74, modifiers: [.command]))),
            Gesture(trigger: right, direction: .down, action: .keyCombo(KeyCombo(keyCode: 0x79, modifiers: [.command])))
        ]
    }

    static func clampThreshold(_ value: CGFloat) -> CGFloat {
        max(10.0, min(value, 500.0))
    }

    static func clampDelay(_ value: TimeInterval) -> TimeInterval {
        max(0.0, min(value, 0.4))
    }

    enum CodingKeys: String, CodingKey {
        case version
        case enabled
        case triggerButton
        case defaultTrigger
        case activationThreshold
        case showFeedback
        case launchAtLogin
        case gestures
        case directionUpdateDelay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawVersion = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        guard rawVersion <= Configuration.maxSupportedVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .version,
                in: container,
                debugDescription: "Unsupported configuration version: \(rawVersion)"
            )
        }

        self.version = Configuration.currentVersion
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        let threshold = try container.decodeIfPresent(CGFloat.self, forKey: .activationThreshold) ?? 60.0
        self.activationThreshold = Self.clampThreshold(threshold)
        self.showFeedback = try container.decodeIfPresent(Bool.self, forKey: .showFeedback) ?? true
        self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        var delay = try container.decodeIfPresent(TimeInterval.self, forKey: .directionUpdateDelay) ?? 0.03
        if abs(delay - 0.125) < 0.001 {
            delay = 0.03
        }
        self.directionUpdateDelay = Self.clampDelay(delay)

        if rawVersion >= 2 {
            self.defaultTrigger = try container.decodeIfPresent(Trigger.self, forKey: .defaultTrigger) ?? .mouseButton(.right)
            self.gestures = try container.decodeIfPresent([Gesture].self, forKey: .gestures) ?? []
        } else {
            let oldTriggerButton = try Self.decodeLegacyTriggerButton(from: container)
            self.defaultTrigger = .mouseButton(oldTriggerButton)
            let oldEntries = try container.decodeIfPresent([LegacyGestureEntry].self, forKey: .gestures) ?? []
            self.gestures = oldEntries.compactMap { entry in
                guard let direction = entry.direction else { return nil }
                return Gesture(
                    trigger: .mouseButton(oldTriggerButton),
                    direction: direction,
                    action: entry.action
                )
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(defaultTrigger, forKey: .defaultTrigger)
        try container.encode(activationThreshold, forKey: .activationThreshold)
        try container.encode(showFeedback, forKey: .showFeedback)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(gestures, forKey: .gestures)
        try container.encode(directionUpdateDelay, forKey: .directionUpdateDelay)
    }

    private static func decodeLegacyTriggerButton(from container: KeyedDecodingContainer<CodingKeys>) throws -> TriggerButton {
        if let button = try? container.decode(TriggerButton.self, forKey: .triggerButton) {
            return button
        }
        if let name = try? container.decode(String.self, forKey: .triggerButton) {
            switch name.lowercased() {
            case "left": return .left
            case "right": return .right
            case "middle": return .middle
            case "x1": return .x1
            case "x2": return .x2
            default: break
            }
        }
        return .right
    }

    private struct LegacyGestureEntry: Codable {
        let directionRaw: String
        let action: Action

        var direction: Direction? {
            return Direction(rawValue: directionRaw)
        }

        enum CodingKeys: String, CodingKey {
            case directionRaw = "direction"
            case action
        }
    }
}
