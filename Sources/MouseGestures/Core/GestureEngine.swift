import AppKit
import CoreGraphics
import Foundation
import os

protocol GestureEngineDelegate: AnyObject {
    func gestureEngine(_ engine: GestureEngine, didStartTrackingAt location: CGPoint)
    func gestureEngine(_ engine: GestureEngine, didUpdateTrackingWith direction: Direction?, at location: CGPoint)
    func gestureEngine(_ engine: GestureEngine, didRecognize direction: Direction?, trigger: Trigger, action: Action, at location: CGPoint)
    func gestureEngine(_ engine: GestureEngine, didCancelAt location: CGPoint)
    func gestureEngineDidFailToCreateTap(_ engine: GestureEngine)
}

final class GestureEngine {
    weak var delegate: GestureEngineDelegate?

    let activationThreshold: CGFloat

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var recognizers: [TriggerButton: GestureRecognizer] = [:]
    private var trackpadMonitor: Any?
    private var keyboardMonitor: Any?
    private var keyMouseGestureState: KeyMouseGestureState?
    private var mousePollTimer: DispatchSourceTimer?
    private var lastPollLocation: CGPoint = .zero
    private var gestures: [Gesture]
    private var monitoredButtons: Set<TriggerButton> = []
    private var lastTrackpadFire: [TrackpadGesture: Date] = [:]
    private let trackpadDebounceInterval: TimeInterval = 0.4
    private var allowTrackpad: Bool
    private var allowKeyboard: Bool

    private struct KeyMouseGestureState {
        let trigger: KeyCombo
        let recognizer: GestureRecognizer
        let startLocation: CGPoint
    }

    init(
        gestures: [Gesture] = [],
        activationThreshold: CGFloat = 60.0,
        allowTrackpad: Bool = true,
        allowKeyboard: Bool = true
    ) {
        self.activationThreshold = activationThreshold
        self.gestures = gestures
        self.allowTrackpad = allowTrackpad
        self.allowKeyboard = allowKeyboard
        rebuildRecognizers(restartIfNeeded: false)
    }

    deinit {
        stop()
    }

    func update(gestures: [Gesture], allowTrackpad: Bool, allowKeyboard: Bool) {
        self.gestures = gestures
        self.allowTrackpad = allowTrackpad
        self.allowKeyboard = allowKeyboard
        rebuildRecognizers(restartIfNeeded: true)
        if isEnabled {
            restartMonitors()
        }
    }

    private func rebuildRecognizers(restartIfNeeded: Bool) {
        var needed: Set<TriggerButton> = []
        for gesture in gestures {
            if case .mouseButton(let button) = gesture.trigger {
                needed.insert(button)
            }
        }
        let buttonsChanged = needed != monitoredButtons
        monitoredButtons = needed
        recognizers = recognizers.filter { needed.contains($0.key) }
        for button in needed where recognizers[button] == nil {
            recognizers[button] = GestureRecognizer(activationThreshold: activationThreshold)
        }
        if restartIfNeeded && buttonsChanged && isEnabled {
            let wasEnabled = isEnabled
            stop()
            if wasEnabled {
                start()
            }
        }
    }

    private(set) var isEnabled = false

    func start() {
        var eventMask: CGEventMask = 0
        for button in monitoredButtons {
            eventMask |= (1 << button.eventType.rawValue)
            eventMask |= (1 << button.upEventType.rawValue)
            eventMask |= (1 << button.draggedEventType.rawValue)
        }
        if hasKeyMouseGesture && allowKeyboard {
            eventMask |= (1 << CGEventType.mouseMoved.rawValue)
        }
        eventMask |= (1 << CGEventType.tapDisabledByTimeout.rawValue)
        eventMask |= (1 << CGEventType.tapDisabledByUserInput.rawValue)

        if eventMask != 0 {
            startEventTap(mask: eventMask)
        }

        if allowTrackpad {
            startTrackpadMonitor()
        }
        if allowKeyboard {
            startKeyboardMonitor()
        }

        isEnabled = true
    }

    private var hasKeyMouseGesture: Bool {
        return gestures.contains { gesture in
            if case .keyMouseGesture = gesture.trigger { return true }
            return false
        }
    }

    private func restartMonitors() {
        if let monitor = trackpadMonitor {
            NSEvent.removeMonitor(monitor)
            trackpadMonitor = nil
        }
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
        if allowTrackpad {
            startTrackpadMonitor()
        }
        if allowKeyboard {
            startKeyboardMonitor()
        }
    }

    private func startEventTap(mask: CGEventMask) {
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let engine = Unmanaged<GestureEngine>.fromOpaque(refcon).takeUnretainedValue()
                return engine.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            delegate?.gestureEngineDidFailToCreateTap(self)
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func startTrackpadMonitor() {
        trackpadMonitor = NSEvent.addGlobalMonitorForEvents(matching: .gesture) { [weak self] event in
            self?.handleTrackpadEvent(event)
        }
    }

    private func startKeyboardMonitor() {
        keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            self?.handleKeyboardEvent(event)
        }
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }
        if let monitor = trackpadMonitor {
            NSEvent.removeMonitor(monitor)
            trackpadMonitor = nil
        }
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
        stopMousePolling()
        keyMouseGestureState = nil
        isEnabled = false
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let location = NSEvent.mouseLocation

        if type == .mouseMoved, let state = keyMouseGestureState {
            state.recognizer.update(to: location)
            let currentDirection = state.recognizer.currentDirection()
            delegate?.gestureEngine(self, didUpdateTrackingWith: currentDirection, at: location)
        }

        var anyMatched = false
        for (button, recognizer) in recognizers {
            let phase: Phase?
            switch type {
            case button.eventType: phase = .begin
            case button.draggedEventType: phase = .update
            case button.upEventType: phase = .finish
            default: phase = nil
            }
            guard let phase = phase else { continue }

            if button.buttonNumber >= 2 {
                let eventButtonNumber = Int(event.getIntegerValueField(.mouseEventButtonNumber))
                guard eventButtonNumber == button.buttonNumber else { continue }
            }

            switch phase {
            case .begin:
                recognizer.begin(at: location)
                delegate?.gestureEngine(self, didStartTrackingAt: location)
            case .update:
                recognizer.update(to: location)
                let currentDirection = recognizer.currentDirection()
                delegate?.gestureEngine(self, didUpdateTrackingWith: currentDirection, at: location)
            case .finish:
                if let direction = recognizer.finish() {
                    if let gesture = matchGesture(trigger: .mouseButton(button), direction: direction) {
                        delegate?.gestureEngine(self, didRecognize: direction, trigger: .mouseButton(button), action: gesture.action, at: location)
                        return nil
                    }
                }
                delegate?.gestureEngine(self, didCancelAt: location)
            }
            anyMatched = true
        }
        if !anyMatched {
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
        }
        return Unmanaged.passUnretained(event)
    }

    private enum Phase {
        case begin, update, finish
    }

    private func handleTrackpadEvent(_ event: NSEvent) {
        guard allowTrackpad else { return }
        let subtype = event.subtype.rawValue
        let location = NSEvent.mouseLocation
        let fingerCount = Self.estimatedFingerCount(from: event)

        switch subtype {
        case 0x11:
            handleSwipe(data1: event.data1, fingerCount: fingerCount, location: location)
        case 0x15:
            handlePinch(data1: event.data1, location: location)
        case 0x14:
            handleRotate(data1: event.data1, location: location)
        case 0x16:
            handleSmartZoom(location: location)
        default:
            return
        }
    }

    private func handleKeyboardEvent(_ event: NSEvent) {
        guard allowKeyboard else { return }
        let keyCode = UInt16(event.keyCode)
        let modifiers = KeyCombo.Modifier.from(nsFlags: event.modifierFlags)
        switch event.type {
        case .keyDown:
            if event.isARepeat { return }
            handleKeyDown(keyCode: keyCode, modifiers: modifiers)
        case .keyUp:
            handleKeyUp(keyCode: keyCode)
        default:
            break
        }
    }

    private func handleKeyDown(keyCode: UInt16, modifiers: [KeyCombo.Modifier]) {
        for gesture in gestures {
            if case .keyboardShortcut(let combo) = gesture.trigger,
               combo.matches(keyCode: keyCode, modifiers: modifiers) {
                let location = NSEvent.mouseLocation
                delegate?.gestureEngine(self, didRecognize: nil, trigger: .keyboardShortcut(combo), action: gesture.action, at: location)
                return
            }
        }
        if keyMouseGestureState == nil {
            for gesture in gestures {
                if case .keyMouseGesture(let combo) = gesture.trigger,
                   combo.matches(keyCode: keyCode, modifiers: modifiers) {
                    startKeyMouseGesture(trigger: combo, startLocation: NSEvent.mouseLocation)
                    return
                }
            }
        }
    }

    private func handleKeyUp(keyCode: UInt16) {
        guard let state = keyMouseGestureState else { return }
        guard state.trigger.keyCode == keyCode else { return }
        finishKeyMouseGesture()
    }

    private func startKeyMouseGesture(trigger: KeyCombo, startLocation: CGPoint) {
        let recognizer = GestureRecognizer(activationThreshold: activationThreshold)
        recognizer.begin(at: startLocation)
        keyMouseGestureState = KeyMouseGestureState(trigger: trigger, recognizer: recognizer, startLocation: startLocation)
        lastPollLocation = startLocation
        delegate?.gestureEngine(self, didStartTrackingAt: startLocation)
        startMousePolling()
    }

    private func finishKeyMouseGesture() {
        guard let state = keyMouseGestureState else { return }
        stopMousePolling()
        let direction = state.recognizer.finish()
        let location = NSEvent.mouseLocation
        keyMouseGestureState = nil
        if let direction = direction {
            for gesture in gestures {
                if case .keyMouseGesture(let combo) = gesture.trigger,
                   combo == state.trigger,
                   gesture.direction == direction {
                    delegate?.gestureEngine(self, didRecognize: direction, trigger: .keyMouseGesture(combo), action: gesture.action, at: location)
                    return
                }
            }
        }
        delegate?.gestureEngine(self, didCancelAt: location)
    }

    private func startMousePolling() {
        stopMousePolling()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(8))
        timer.setEventHandler { [weak self] in
            self?.pollMousePosition()
        }
        timer.resume()
        mousePollTimer = timer
    }

    private func stopMousePolling() {
        mousePollTimer?.cancel()
        mousePollTimer = nil
    }

    private func pollMousePosition() {
        guard let state = keyMouseGestureState else { return }
        let location = NSEvent.mouseLocation
        if location == lastPollLocation { return }
        lastPollLocation = location
        state.recognizer.update(to: location)
        let currentDirection = state.recognizer.currentDirection()
        delegate?.gestureEngine(self, didUpdateTrackingWith: currentDirection, at: location)
    }

    private func handleSwipe(data1: Int, fingerCount: Int, location: CGPoint) {
        guard let direction = directionFromTrackpadData(data1) else { return }
        let prefersThree = fingerCount >= 3
        let candidates = gestures.compactMap { gesture -> (TrackpadGesture, Action)? in
            guard case .trackpad(let trackpad) = gesture.trigger,
                  trackpad.isSwipe,
                  trackpad.direction == direction else { return nil }
            return (trackpad, gesture.action)
        }
        guard !candidates.isEmpty else { return }

        let preferred = candidates.first { prefersThree ? $0.0.isThreeFinger : !$0.0.isThreeFinger }
            ?? candidates.first { prefersThree ? !$0.0.isThreeFinger : $0.0.isThreeFinger }
        if let match = preferred {
            fireTrackpadGesture(match.0, direction: direction, location: location, action: match.1)
        }
    }

    private func handlePinch(data1: Int, location: CGPoint) {
        let target: TrackpadGesture = data1 > 0 ? .pinchOut : .pinchIn
        for gesture in gestures {
            if case .trackpad(let trackpad) = gesture.trigger, trackpad == target {
                fireTrackpadGesture(trackpad, direction: nil, location: location, action: gesture.action)
                return
            }
        }
    }

    private func handleRotate(data1: Int, location: CGPoint) {
        let target: TrackpadGesture = data1 > 0 ? .rotateRight : .rotateLeft
        for gesture in gestures {
            if case .trackpad(let trackpad) = gesture.trigger, trackpad == target {
                fireTrackpadGesture(trackpad, direction: nil, location: location, action: gesture.action)
                return
            }
        }
    }

    private func handleSmartZoom(location: CGPoint) {
        for gesture in gestures {
            if case .trackpad(let trackpad) = gesture.trigger, trackpad == .smartZoom {
                fireTrackpadGesture(trackpad, direction: nil, location: location, action: gesture.action)
                return
            }
        }
    }

    private func fireTrackpadGesture(_ trackpad: TrackpadGesture, direction: Direction?, location: CGPoint, action: Action) {
        let now = Date()
        if let last = lastTrackpadFire[trackpad], now.timeIntervalSince(last) < trackpadDebounceInterval {
            return
        }
        lastTrackpadFire[trackpad] = now
        delegate?.gestureEngine(self, didRecognize: direction, trigger: .trackpad(trackpad), action: action, at: location)
    }

    private func directionFromTrackpadData(_ data: Int) -> Direction? {
        switch data {
        case 1: return .left
        case 2: return .right
        case 3: return .up
        case 4: return .down
        default: return nil
        }
    }

    private func matchGesture(trigger: Trigger, direction: Direction) -> Gesture? {
        return gestures.first { gesture in
            gesture.trigger == trigger && gesture.direction == direction
        }
    }

    private static func estimatedFingerCount(from event: NSEvent) -> Int {
        let touches = event.touches(matching: .any, in: nil)
        if !touches.isEmpty {
            return touches.count
        }
        if #available(macOS 10.12, *) {
            let phase = event.phase
            if phase.contains(.began) || phase.contains(.changed) {
                return event.buttonNumber > 0 ? max(2, event.buttonNumber) : 2
            }
        }
        return 2
    }
}

extension TrackpadGesture {
    var isSwipe: Bool {
        switch self {
        case .swipeLeft, .swipeRight, .swipeUp, .swipeDown,
             .threeFingerSwipeLeft, .threeFingerSwipeRight, .threeFingerSwipeUp, .threeFingerSwipeDown:
            return true
        default:
            return false
        }
    }

    var isThreeFinger: Bool {
        switch self {
        case .threeFingerSwipeLeft, .threeFingerSwipeRight, .threeFingerSwipeUp, .threeFingerSwipeDown:
            return true
        default:
            return false
        }
    }
}
