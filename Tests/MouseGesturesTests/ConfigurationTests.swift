import XCTest
@testable import MouseGestures

final class ConfigurationTests: XCTestCase {
    func testDefaultConfiguration() {
        let config = Configuration()
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.defaultTrigger, .mouseButton(.right))
        XCTAssertEqual(config.gestures.count, 4)
        XCTAssertEqual(config.gestures[0].direction, .left)
    }

    func testRoundTripEncoding() throws {
        let original = Configuration(
            enabled: false,
            defaultTrigger: .mouseButton(.middle),
            activationThreshold: 120,
            showFeedback: false,
            launchAtLogin: true,
            gestures: [
                Gesture(trigger: .mouseButton(.right), direction: .up, action: .keyCombo(KeyCombo(keyCode: 0x7B, modifiers: [.command, .shift]))),
                Gesture(trigger: .mouseButton(.middle), direction: .down, action: .shell("echo hi")),
                Gesture(trigger: .trackpad(.swipeLeft), direction: .left, action: .appleScript("tell application \"Finder\" to activate")),
                Gesture(trigger: .mouseButton(.left), direction: .upRight, action: .none)
            ],
            directionUpdateDelay: 0.3
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Configuration.self, from: data)
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.directionUpdateDelay, 0.3, accuracy: 0.0001)
    }

    func testDirectionUpdateDelayPersists() throws {
        let original = Configuration(directionUpdateDelay: 0.45)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Configuration.self, from: data)
        XCTAssertEqual(decoded.directionUpdateDelay, 0.45, accuracy: 0.0001)
    }

    func testThresholdClampedOnDecode() throws {
        let json = """
        {
            "version": 2,
            "activationThreshold": 99999
        }
        """
        let data = Data(json.utf8)
        let config = try JSONDecoder().decode(Configuration.self, from: data)
        XCTAssertLessThanOrEqual(config.activationThreshold, 500)
    }

    func testDelayClampedOnDecode() throws {
        let json = """
        {
            "version": 3,
            "directionUpdateDelay": 9.0
        }
        """
        let data = Data(json.utf8)
        let config = try JSONDecoder().decode(Configuration.self, from: data)
        XCTAssertLessThanOrEqual(config.directionUpdateDelay, 0.4)
    }

    func testV1Migration() throws {
        let v1JSON = """
        {
            "version": 1,
            "enabled": true,
            "triggerButton": "right",
            "activationThreshold": 60,
            "gestures": [
                { "direction": "left", "action": { "keyCombo": { "keyCode": 123, "modifiers": ["command"] } } },
                { "direction": "right", "action": { "keyCombo": { "keyCode": 124, "modifiers": ["command"] } } }
            ]
        }
        """
        let data = Data(v1JSON.utf8)
        let config = try JSONDecoder().decode(Configuration.self, from: data)
        XCTAssertEqual(config.version, Configuration.currentVersion)
        XCTAssertEqual(config.defaultTrigger, .mouseButton(.right))
        XCTAssertEqual(config.gestures.count, 2)
        XCTAssertEqual(config.gestures[0].trigger, .mouseButton(.right))
        XCTAssertEqual(config.gestures[0].direction, .left)
    }

    func testUnsupportedVersionRejected() {
        let json = """
        { "version": 999 }
        """
        let data = Data(json.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(Configuration.self, from: data))
    }

    func testTriggerEncoding() throws {
        let triggers: [Trigger] = [
            .mouseButton(.right),
            .trackpad(.swipeLeft)
        ]
        for trigger in triggers {
            let data = try JSONEncoder().encode(trigger)
            let decoded = try JSONDecoder().decode(Trigger.self, from: data)
            XCTAssertEqual(decoded, trigger)
        }
    }

    func testTriggerButtonEqualityIgnoresCustomName() {
        let a = TriggerButton(buttonNumber: 1, customName: "Right")
        let b = TriggerButton(buttonNumber: 1, customName: "Primary")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }
}
