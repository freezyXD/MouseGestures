import CoreGraphics
import Foundation
import os

final class ActionExecutor {
    private let logger = Logger(subsystem: "com.freezy.MouseGestures", category: "ActionExecutor")
    private let shellTimeoutSeconds: TimeInterval = 5.0
    private let appleScriptTimeoutSeconds: TimeInterval = 5.0
    private let executionQueue = DispatchQueue(label: "com.freezy.MouseGestures.ActionExecutor", qos: .userInitiated)

    func execute(_ action: Action) {
        switch action {
        case .none:
            return
        case .keyCombo(let combo):
            executionQueue.async { [weak self] in
                self?.sendKeyCombo(combo)
            }
        case .shell(let command):
            executionQueue.async { [weak self] in
                self?.runShell(command)
            }
        case .appleScript(let script):
            executionQueue.async { [weak self] in
                self?.runAppleScript(script)
            }
        }
    }

    private func sendKeyCombo(_ combo: KeyCombo) {
        guard
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: combo.keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: combo.keyCode, keyDown: false)
        else {
            logger.error("Failed to create key event for keyCode=\(combo.keyCode)")
            return
        }
        keyDown.flags = combo.cgFlags
        keyUp.flags = combo.cgFlags
        keyDown.post(tap: .cghidEventTap)
        usleep(20_000)
        keyUp.post(tap: .cghidEventTap)
    }

    private func runShell(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", trimmed]
        process.standardInput = FileHandle.nullDevice

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            logger.error("Failed to run shell command: \(error.localizedDescription, privacy: .public)")
            return
        }

        let deadline = DispatchTime.now() + shellTimeoutSeconds
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: deadline)
        timer.setEventHandler {
            if process.isRunning {
                process.terminate()
            }
        }
        timer.resume()

        process.waitUntilExit()
        timer.cancel()

        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        _ = stdoutPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            let preview = String(stderr.prefix(200))
            logger.error("Shell exit=\(process.terminationStatus) stderr=\(preview, privacy: .private)")
        }
    }

    private func runAppleScript(_ script: String) {
        let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", trimmed]
        process.standardInput = FileHandle.nullDevice

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            logger.error("Failed to run AppleScript: \(error.localizedDescription, privacy: .public)")
            return
        }

        let deadline = DispatchTime.now() + appleScriptTimeoutSeconds
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: deadline)
        timer.setEventHandler {
            if process.isRunning {
                process.terminate()
            }
        }
        timer.resume()

        process.waitUntilExit()
        timer.cancel()

        if process.terminationStatus != 0 {
            let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let preview = String(stderr.prefix(200))
            logger.error("AppleScript exit=\(process.terminationStatus) stderr=\(preview, privacy: .private)")
        } else {
            _ = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        }
    }
}
