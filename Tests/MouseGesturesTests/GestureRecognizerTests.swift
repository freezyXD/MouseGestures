import XCTest
@testable import MouseGestures

final class GestureRecognizerTests: XCTestCase {
    func testSmallMovementDoesNotTrigger() {
        let recognizer = GestureRecognizer(activationThreshold: 50)
        recognizer.begin(at: .zero)
        recognizer.update(to: CGPoint(x: 10, y: 10))
        XCTAssertNil(recognizer.finish())
    }

    func testRightwardGesture() {
        let recognizer = GestureRecognizer(activationThreshold: 50)
        recognizer.begin(at: CGPoint(x: 100, y: 100))
        recognizer.update(to: CGPoint(x: 200, y: 105))
        XCTAssertEqual(recognizer.finish(), .right)
    }

    func testLeftwardGesture() {
        let recognizer = GestureRecognizer(activationThreshold: 50)
        recognizer.begin(at: CGPoint(x: 200, y: 100))
        recognizer.update(to: CGPoint(x: 100, y: 105))
        XCTAssertEqual(recognizer.finish(), .left)
    }

    func testUpwardGesture() {
        let recognizer = GestureRecognizer(activationThreshold: 50)
        recognizer.begin(at: CGPoint(x: 100, y: 200))
        recognizer.update(to: CGPoint(x: 105, y: 300))
        XCTAssertEqual(recognizer.finish(), .up)
    }

    func testDownwardGesture() {
        let recognizer = GestureRecognizer(activationThreshold: 50)
        recognizer.begin(at: CGPoint(x: 100, y: 300))
        recognizer.update(to: CGPoint(x: 105, y: 200))
        XCTAssertEqual(recognizer.finish(), .down)
    }

    func testUpRightDiagonal() {
        let recognizer = GestureRecognizer(activationThreshold: 50)
        recognizer.begin(at: .zero)
        recognizer.update(to: CGPoint(x: 100, y: 100))
        XCTAssertEqual(recognizer.finish(), .upRight)
    }

    func testDownLeftDiagonal() {
        let recognizer = GestureRecognizer(activationThreshold: 50)
        recognizer.begin(at: CGPoint(x: 100, y: 100))
        recognizer.update(to: CGPoint(x: 10, y: 10))
        XCTAssertEqual(recognizer.finish(), .downLeft)
    }

    func testUpLeftDiagonal() {
        let recognizer = GestureRecognizer(activationThreshold: 50)
        recognizer.begin(at: CGPoint(x: 100, y: 100))
        recognizer.update(to: CGPoint(x: 30, y: 170))
        XCTAssertEqual(recognizer.finish(), .upLeft)
    }

    func testDownRightDiagonal() {
        let recognizer = GestureRecognizer(activationThreshold: 50)
        recognizer.begin(at: CGPoint(x: 30, y: 170))
        recognizer.update(to: CGPoint(x: 100, y: 100))
        XCTAssertEqual(recognizer.finish(), .downRight)
    }

    func testFinishWithoutBeginReturnsNil() {
        let recognizer = GestureRecognizer()
        XCTAssertNil(recognizer.finish())
    }

    func testResetClearsState() {
        let recognizer = GestureRecognizer(activationThreshold: 50)
        recognizer.begin(at: .zero)
        recognizer.update(to: CGPoint(x: 200, y: 0))
        recognizer.reset()
        XCTAssertNil(recognizer.finish())
        XCTAssertFalse(recognizer.isTracking)
    }
}
