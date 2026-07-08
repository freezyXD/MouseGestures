import CoreGraphics
import Foundation

final class GestureRecognizer {
    private(set) var isTracking = false
    private var startLocation: CGPoint = .zero
    private var delta: CGPoint = .zero
    private let activationThreshold: CGFloat
    private let feedbackThreshold: CGFloat

    init(activationThreshold: CGFloat = 60.0, feedbackThreshold: CGFloat? = nil) {
        self.activationThreshold = activationThreshold
        let resolved = feedbackThreshold ?? max(10.0, activationThreshold * 0.25)
        self.feedbackThreshold = min(resolved, activationThreshold * 0.9)
    }

    func reset() {
        isTracking = false
        delta = .zero
    }

    func begin(at location: CGPoint) {
        isTracking = true
        startLocation = location
        delta = .zero
    }

    func update(to location: CGPoint) {
        guard isTracking else { return }
        delta = CGPoint(
            x: location.x - startLocation.x,
            y: location.y - startLocation.y
        )
    }

    func finish() -> Direction? {
        defer { reset() }
        guard isTracking else { return nil }
        return direction(forMagnitude: currentMagnitude(), minThreshold: activationThreshold)
    }

    func currentDirection() -> Direction? {
        guard isTracking else { return nil }
        return direction(forMagnitude: currentMagnitude(), minThreshold: feedbackThreshold)
    }

    func currentDelta() -> CGPoint {
        return delta
    }

    private func currentMagnitude() -> CGFloat {
        return sqrt(delta.x * delta.x + delta.y * delta.y)
    }

    private func direction(forMagnitude magnitude: CGFloat, minThreshold: CGFloat) -> Direction? {
        guard magnitude >= minThreshold else { return nil }
        let angleDegrees = atan2(delta.y, delta.x) * 180 / .pi
        let normalized = angleDegrees < 0 ? angleDegrees + 360 : angleDegrees
        let index = Int((normalized + 22.5) / 45.0) % 8

        switch index {
        case 0: return .right
        case 1: return .upRight
        case 2: return .up
        case 3: return .upLeft
        case 4: return .left
        case 5: return .downLeft
        case 6: return .down
        case 7: return .downRight
        default: return nil
        }
    }
}
