import AppKit
import CoreGraphics
import QuartzCore
import SwiftUI

@MainActor
final class FeedbackOverlayController {
    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?
    private var pendingDirectionWorkItem: DispatchWorkItem?
    private var currentDirection: Direction?
    private let panelSize: CGFloat = 64
    private var overlayVisible: Bool = false
    private let cursorLock = CursorLock()
    var directionUpdateDelay: TimeInterval = 0.03

    func beginTracking(showOverlay: Bool, at point: CGPoint) {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        pendingDirectionWorkItem?.cancel()
        pendingDirectionWorkItem = nil
        currentDirection = nil
        cursorLock.lock()
        guard showOverlay else {
            hideOverlayPanel()
            return
        }
        ensurePanel()
        updateContent(direction: nil, animated: false)
        positionPanel(at: NSEvent.mouseLocation)
        guard let panel = panel else { return }
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        overlayVisible = true
    }

    func update(direction: Direction?, at point: CGPoint) {
        cursorLock.reassert()
        guard overlayVisible else { return }
        if direction != currentDirection {
            pendingDirectionWorkItem?.cancel()
            let target = direction
            let isFirstDirection = currentDirection == nil && target != nil
            let applyImmediately = isFirstDirection || target == nil || directionUpdateDelay <= 0.0001
            if applyImmediately {
                currentDirection = target
                updateContent(direction: target, animated: !isFirstDirection && target != nil)
            } else {
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    self.currentDirection = target
                    self.updateContent(direction: target, animated: true)
                }
                pendingDirectionWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + directionUpdateDelay, execute: workItem)
            }
        }
        positionPanel(at: NSEvent.mouseLocation)
    }

    func showFinish(direction: Direction?, at point: CGPoint) {
        pendingDirectionWorkItem?.cancel()
        hideWorkItem?.cancel()
        cursorLock.unlock()
        if overlayVisible {
            ensurePanel()
            currentDirection = direction
            updateContent(direction: direction, animated: false)
            positionPanel(at: NSEvent.mouseLocation)
            if let panel = panel, panel.alphaValue < 1 {
                panel.alphaValue = 1
            }
            panel?.orderFrontRegardless()
            let workItem = DispatchWorkItem { [weak self] in
                self?.dismissOverlay(animated: true)
            }
            hideWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: workItem)
        } else {
            dismissOverlay(animated: false)
        }
    }

    func cancel() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        pendingDirectionWorkItem?.cancel()
        pendingDirectionWorkItem = nil
        cursorLock.unlock()
        dismissOverlay(animated: overlayVisible)
    }

    func forceShowCursor() {
        cursorLock.unlock()
    }

    private func ensurePanel() {
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: panelSize, height: panelSize),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            let view = FeedbackNSView(frame: NSRect(x: 0, y: 0, width: panelSize, height: panelSize))
            panel.contentView = view
            self.panel = panel
        }
    }

    private func updateContent(direction: Direction?, animated: Bool) {
        guard let view = panel?.contentView as? FeedbackNSView else { return }
        view.setDirection(direction, animated: animated)
    }

    private func positionPanel(at point: CGPoint) {
        guard let panel = panel else { return }
        let origin = NSPoint(
            x: point.x - panelSize / 2,
            y: point.y - panelSize / 2
        )
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: panelSize, height: panelSize)), display: false)
    }

    private func dismissOverlay(animated: Bool) {
        currentDirection = nil
        if animated, let panel = panel, overlayVisible {
            overlayVisible = false
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.1
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        } else {
            hideOverlayPanel()
        }
    }

    private func hideOverlayPanel() {
        overlayVisible = false
        panel?.orderOut(nil)
        panel?.alphaValue = 0
    }
}

@MainActor
final class CursorLock {
    private var isLocked = false
    private var displayHideDepth = 0
    private var nsHideDepth = 0

    func lock() {
        if isLocked {
            reassert()
            return
        }
        isLocked = true
        CGAssociateMouseAndMouseCursorPosition(boolean_t(0))
        if CGDisplayHideCursor(kCGNullDirectDisplay) == .success {
            displayHideDepth = 1
        }
        NSCursor.hide()
        nsHideDepth = 1
    }

    func reassert() {
        guard isLocked else { return }
        CGAssociateMouseAndMouseCursorPosition(boolean_t(0))
        if displayHideDepth == 0,
           CGDisplayHideCursor(kCGNullDirectDisplay) == .success {
            displayHideDepth = 1
        }
    }

    func unlock() {
        guard isLocked || displayHideDepth > 0 || nsHideDepth > 0 else {
            CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
            return
        }
        isLocked = false
        while displayHideDepth > 0 {
            _ = CGDisplayShowCursor(kCGNullDirectDisplay)
            displayHideDepth -= 1
        }
        while nsHideDepth > 0 {
            NSCursor.unhide()
            nsHideDepth -= 1
        }
        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
        NSCursor.setHiddenUntilMouseMoves(false)
        NSCursor.arrow.set()
    }
}

final class FeedbackNSView: NSView {
    private var direction: Direction?
    private var displayAngle: CGFloat?
    private var targetAngle: CGFloat?
    private var animationTimer: Timer?
    private var animationStartTime: CFTimeInterval = 0
    private var animationFromAngle: CGFloat = 0
    private var animationToAngle: CGFloat = 0
    private let animationDuration: CFTimeInterval = 0.12

    override var isFlipped: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    deinit {
        animationTimer?.invalidate()
    }

    func setDirection(_ newDirection: Direction?, animated: Bool) {
        let oldDirection = direction
        direction = newDirection
        let newAngle = newDirection.map { Self.drawingAngle(for: $0) }

        if newDirection == nil {
            stopAngleAnimation()
            displayAngle = nil
            targetAngle = nil
            needsDisplay = true
            return
        }

        guard let newAngle else { return }
        targetAngle = newAngle

        if !animated || oldDirection == nil || displayAngle == nil {
            stopAngleAnimation()
            displayAngle = newAngle
            needsDisplay = true
            return
        }

        animationFromAngle = displayAngle ?? newAngle
        animationToAngle = Self.shortestAngle(from: animationFromAngle, to: newAngle)
        animationStartTime = CACurrentMediaTime()
        startAngleAnimation()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard NSGraphicsContext.current != nil else { return }

        let bgPath = NSBezierPath(ovalIn: bounds.insetBy(dx: 1.25, dy: 1.25))
        NSColor.black.withAlphaComponent(0.55).setFill()
        bgPath.fill()
        NSColor.white.setStroke()
        bgPath.lineWidth = 2.5
        bgPath.stroke()

        if let angle = displayAngle {
            drawArrow(at: angle)
        } else {
            drawCenterDot()
        }
    }

    private func drawCenterDot() {
        let dotSize: CGFloat = 6
        let dotRect = NSRect(
            x: bounds.midX - dotSize / 2,
            y: bounds.midY - dotSize / 2,
            width: dotSize,
            height: dotSize
        )
        NSColor.white.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
    }

    private func drawArrow(at angle: CGFloat) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let lineLength: CGFloat = 14
        let headLength: CGFloat = 7

        let tipX = center.x + lineLength * cos(angle)
        let tipY = center.y + lineLength * sin(angle)

        let path = NSBezierPath()
        path.move(to: center)
        path.line(to: NSPoint(x: tipX, y: tipY))

        let headAngle1 = angle + .pi * 0.75
        let headAngle2 = angle - .pi * 0.75

        let head1End = NSPoint(
            x: tipX + headLength * cos(headAngle1),
            y: tipY + headLength * sin(headAngle1)
        )
        let head2End = NSPoint(
            x: tipX + headLength * cos(headAngle2),
            y: tipY + headLength * sin(headAngle2)
        )

        path.move(to: NSPoint(x: tipX, y: tipY))
        path.line(to: head1End)
        path.move(to: NSPoint(x: tipX, y: tipY))
        path.line(to: head2End)

        path.lineWidth = 3
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        NSColor.white.setStroke()
        path.stroke()
    }

    private static func drawingAngle(for direction: Direction) -> CGFloat {
        switch direction {
        case .right: return 0
        case .upRight: return .pi / 4
        case .up: return .pi / 2
        case .upLeft: return 3 * .pi / 4
        case .left: return .pi
        case .downLeft: return -3 * .pi / 4
        case .down: return -.pi / 2
        case .downRight: return -.pi / 4
        }
    }

    private static func shortestAngle(from: CGFloat, to: CGFloat) -> CGFloat {
        var delta = to - from
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        return from + delta
    }

    private func startAngleAnimation() {
        stopAngleAnimation()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tickAngleAnimation()
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    private func stopAngleAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func tickAngleAnimation() {
        let elapsed = CACurrentMediaTime() - animationStartTime
        let t = min(1.0, elapsed / animationDuration)
        let eased = 1 - pow(1 - t, 3)
        displayAngle = animationFromAngle + (animationToAngle - animationFromAngle) * CGFloat(eased)
        needsDisplay = true
        if t >= 1 {
            displayAngle = targetAngle
            stopAngleAnimation()
            needsDisplay = true
        }
    }
}
