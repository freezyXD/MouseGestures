import XCTest
@testable import MouseGestures

final class ActionTests: XCTestCase {
    func testKeyComboEncoding() throws {
        let combo = KeyCombo(keyCode: 0x7B, modifiers: [.command, .shift])
        let action: Action = .keyCombo(combo)
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(Action.self, from: data)
        XCTAssertEqual(action, decoded)
    }

    func testShellEncoding() throws {
        let action: Action = .shell("echo hello")
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(Action.self, from: data)
        XCTAssertEqual(action, decoded)
    }

    func testAppleScriptEncoding() throws {
        let action: Action = .appleScript("tell application \"Finder\" to activate")
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(Action.self, from: data)
        XCTAssertEqual(action, decoded)
    }

    func testDisplayDescriptionTruncation() {
        let longShell = Action.shell(String(repeating: "x", count: 200))
        let description = longShell.displayDescription
        XCTAssertTrue(description.count <= 41)
        XCTAssertTrue(description.hasSuffix("…"))
    }

    func testKeyComboDisplayString() {
        let combo = KeyCombo(keyCode: 0x7B, modifiers: [.command, .shift])
        XCTAssertEqual(combo.displayString, "⌘⇧←")
    }

    func testDangerousFlag() {
        XCTAssertFalse(Action.none.isDangerous)
        XCTAssertFalse(Action.keyCombo(KeyCombo(keyCode: 0, modifiers: [])).isDangerous)
        XCTAssertTrue(Action.shell("ls").isDangerous)
        XCTAssertTrue(Action.appleScript("").isDangerous)
    }

    func testDisplayKeyOverride() {
        let combo = KeyCombo(keyCode: 0x00, modifiers: [.command], displayKey: "A")
        XCTAssertEqual(combo.displayString, "⌘A")
    }

    func testStandardKeysCoverage() {
        XCTAssertGreaterThan(KeyCombo.standardKeys.count, 30)
        XCTAssertNotNil(KeyCombo.name(for: 0x00))
        XCTAssertNotNil(KeyCombo.name(for: 0x7A))
        XCTAssertNotNil(KeyCombo.name(for: 0x31))
    }

    func testIsCleared() {
        XCTAssertTrue(KeyCombo(keyCode: 0, modifiers: []).isCleared)
        XCTAssertFalse(KeyCombo(keyCode: 1, modifiers: []).isCleared)
        XCTAssertFalse(KeyCombo(keyCode: 0, modifiers: [.command]).isCleared)
    }

    func testDisplayKeyBackwardCompatible() throws {
        let oldJSON = """
        { "keyCode": 123, "modifiers": ["command"] }
        """
        let data = Data(oldJSON.utf8)
        let combo = try JSONDecoder().decode(KeyCombo.self, from: data)
        XCTAssertEqual(combo.keyCode, 123)
        XCTAssertEqual(combo.modifiers, [.command])
        XCTAssertNil(combo.displayKey)
    }

    func testModifierOrderNormalizedForMatching() {
        let a = KeyCombo(keyCode: 0x7B, modifiers: [.shift, .command])
        let b = KeyCombo(keyCode: 0x7B, modifiers: [.command, .shift])
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.matches(keyCode: 0x7B, modifiers: [.shift, .command]))
        XCTAssertTrue(a.matches(keyCode: 0x7B, modifiers: [.command, .shift]))
    }

    func testDuplicateModifiersNormalized() {
        let combo = KeyCombo(keyCode: 1, modifiers: [.command, .command, .shift])
        XCTAssertEqual(combo.modifiers, [.command, .shift])
    }
}
