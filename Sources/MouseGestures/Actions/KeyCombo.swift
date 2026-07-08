import AppKit
import Carbon
import CoreGraphics
import Foundation

struct KeyCombo: Codable, Hashable {
    var keyCode: UInt16
    private var storedModifiers: [Modifier]
    var displayKey: String?

    var modifiers: [Modifier] {
        get { storedModifiers }
        set { storedModifiers = Self.normalized(newValue) }
    }

    enum Modifier: String, Codable, CaseIterable {
        case command
        case control
        case option
        case shift

        var cgFlag: CGEventFlags {
            switch self {
            case .command: return .maskCommand
            case .control: return .maskControl
            case .option: return .maskAlternate
            case .shift: return .maskShift
            }
        }

        var symbol: String {
            switch self {
            case .command: return "⌘"
            case .control: return "⌃"
            case .option: return "⌥"
            case .shift: return "⇧"
            }
        }
    }

    init(keyCode: UInt16, modifiers: [Modifier], displayKey: String? = nil) {
        self.keyCode = keyCode
        self.storedModifiers = Self.normalized(modifiers)
        self.displayKey = displayKey
    }

    var cgFlags: CGEventFlags {
        modifiers.reduce(into: CGEventFlags()) { $0.insert($1.cgFlag) }
    }

    var modifierSet: Set<Modifier> {
        Set(modifiers)
    }

    func matches(keyCode: UInt16, modifiers: [Modifier]) -> Bool {
        self.keyCode == keyCode && modifierSet == Set(modifiers)
    }

    var displayString: String {
        let symbols = Self.normalized(modifiers).map { $0.symbol }.joined()
        let key = displayKey ?? Self.name(for: keyCode) ?? "Key(\(keyCode))"
        return symbols + key
    }

    static func normalized(_ modifiers: [Modifier]) -> [Modifier] {
        var seen = Set<Modifier>()
        var result: [Modifier] = []
        for modifier in Modifier.allCases {
            if modifiers.contains(modifier), !seen.contains(modifier) {
                seen.insert(modifier)
                result.append(modifier)
            }
        }
        return result
    }

    var isCleared: Bool {
        return keyCode == 0 && modifiers.isEmpty
    }

    static func from(event: NSEvent) -> KeyCombo {
        let keyCode = UInt16(event.keyCode)
        let modifiers = Modifier.from(nsFlags: event.modifierFlags)
        let display = event.charactersIgnoringModifiers?.uppercased()
        return KeyCombo(keyCode: keyCode, modifiers: modifiers, displayKey: display)
    }

    enum CodingKeys: String, CodingKey {
        case keyCode
        case modifiers
        case displayKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        let rawModifiers = try container.decodeIfPresent([Modifier].self, forKey: .modifiers) ?? []
        storedModifiers = Self.normalized(rawModifiers)
        displayKey = try container.decodeIfPresent(String.self, forKey: .displayKey)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(storedModifiers, forKey: .modifiers)
        try container.encodeIfPresent(displayKey, forKey: .displayKey)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(storedModifiers)
        hasher.combine(displayKey)
    }

    static func == (lhs: KeyCombo, rhs: KeyCombo) -> Bool {
        lhs.keyCode == rhs.keyCode
            && lhs.storedModifiers == rhs.storedModifiers
            && lhs.displayKey == rhs.displayKey
    }

    static func name(for keyCode: UInt16) -> String? {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
        case kVK_Space: return "Space"
        case kVK_Tab: return "⇥"
        case kVK_Return: return "↩"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Escape: return "⎋"
        case kVK_Home: return "Home"
        case kVK_End: return "End"
        case kVK_PageUp: return "Page Up"
        case kVK_PageDown: return "Page Down"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Grave: return "`"
        case kVK_CapsLock: return "⇪"
        default: return nil
        }
    }

    static let standardKeys: [(label: String, code: UInt16)] = [
        ("↑", 0x7E),
        ("↓", 0x7D),
        ("←", 0x7B),
        ("→", 0x7C),
        ("Space", 0x31),
        ("Tab ⇥", 0x30),
        ("Return ↩", 0x24),
        ("Backspace ⌫", 0x33),
        ("Forward Delete ⌦", 0x75),
        ("Escape ⎋", 0x35),
        ("Home", 0x73),
        ("End", 0x77),
        ("Page Up", 0x74),
        ("Page Down", 0x79),
        ("A", 0x00),
        ("B", 0x0B),
        ("C", 0x08),
        ("D", 0x02),
        ("E", 0x0E),
        ("F", 0x03),
        ("G", 0x05),
        ("H", 0x04),
        ("I", 0x22),
        ("J", 0x26),
        ("K", 0x28),
        ("L", 0x25),
        ("M", 0x2E),
        ("N", 0x2D),
        ("O", 0x1F),
        ("P", 0x23),
        ("Q", 0x0C),
        ("R", 0x0F),
        ("S", 0x01),
        ("T", 0x11),
        ("U", 0x20),
        ("V", 0x09),
        ("W", 0x0D),
        ("X", 0x07),
        ("Y", 0x10),
        ("Z", 0x06),
        ("0", 0x1D),
        ("1", 0x12),
        ("2", 0x13),
        ("3", 0x14),
        ("4", 0x15),
        ("5", 0x17),
        ("6", 0x16),
        ("7", 0x1A),
        ("8", 0x1C),
        ("9", 0x19),
        ("F1", 0x7A),
        ("F2", 0x78),
        ("F3", 0x63),
        ("F4", 0x76),
        ("F5", 0x60),
        ("F6", 0x61),
        ("F7", 0x62),
        ("F8", 0x64),
        ("F9", 0x65),
        ("F10", 0x6D),
        ("F11", 0x67),
        ("F12", 0x6F),
        ("F13", 0x69),
        ("F14", 0x6B),
        ("F15", 0x71),
        ("F16", 0x6A),
        ("F17", 0x40),
        ("F18", 0x4F),
        ("F19", 0x50),
        ("F20", 0x5A),
        ("-", 0x1B),
        ("=", 0x18),
        ("[", 0x21),
        ("]", 0x1E),
        ("\\", 0x2A),
        (";", 0x29),
        ("'", 0x27),
        (",", 0x2B),
        (".", 0x2F),
        ("/", 0x2C),
        ("`", 0x32),
        ("⇪ Caps Lock", 0x39)
    ]
}

extension KeyCombo.Modifier {
    static func from(cgFlags: CGEventFlags) -> [KeyCombo.Modifier] {
        var mods: [KeyCombo.Modifier] = []
        if cgFlags.contains(.maskCommand) { mods.append(.command) }
        if cgFlags.contains(.maskControl) { mods.append(.control) }
        if cgFlags.contains(.maskAlternate) { mods.append(.option) }
        if cgFlags.contains(.maskShift) { mods.append(.shift) }
        return mods
    }

    static func from(nsFlags: NSEvent.ModifierFlags) -> [KeyCombo.Modifier] {
        var mods: [KeyCombo.Modifier] = []
        if nsFlags.contains(.command) { mods.append(.command) }
        if nsFlags.contains(.control) { mods.append(.control) }
        if nsFlags.contains(.option) { mods.append(.option) }
        if nsFlags.contains(.shift) { mods.append(.shift) }
        return mods
    }
}
