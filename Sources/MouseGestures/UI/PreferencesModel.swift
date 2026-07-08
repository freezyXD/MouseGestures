import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class PreferencesModel: ObservableObject {
    @Published var configuration: Configuration
    @Published var editingGestureId: UUID?

    private let store: ConfigStore

    init(store: ConfigStore = .shared) {
        self.store = store
        self.configuration = store.load()
    }

    func resetToDefaults() {
        configuration = Configuration()
    }

    func revealConfigFile() {
        NSWorkspace.shared.activateFileViewerSelecting([store.configFileURL])
    }

    func addGesture() {
        let new = Gesture(
            trigger: configuration.defaultTrigger,
            direction: .right,
            action: .keyCombo(KeyCombo(keyCode: 0x7C, modifiers: [.command]))
        )
        var newConfig = configuration
        newConfig.gestures.append(new)
        configuration = newConfig
        editingGestureId = new.id
    }

    func addTemplate(_ template: SystemGestureTemplate) {
        let new = Gesture(
            trigger: template.gesture.trigger,
            direction: template.gesture.direction,
            action: template.gesture.action
        )
        var newConfig = configuration
        newConfig.gestures.append(new)
        configuration = newConfig
    }

    func updateGesture(_ updated: Gesture) {
        guard let index = configuration.gestures.firstIndex(where: { $0.id == updated.id }) else { return }
        var newConfig = configuration
        newConfig.gestures[index] = updated
        configuration = newConfig
    }

    func deleteGesture(id: UUID) {
        var newConfig = configuration
        newConfig.gestures.removeAll { $0.id == id }
        configuration = newConfig
        if editingGestureId == id {
            editingGestureId = nil
        }
    }

    func editingGesture() -> Gesture? {
        guard let id = editingGestureId else { return nil }
        return configuration.gestures.first { $0.id == id }
    }

    func closeEditor() {
        editingGestureId = nil
    }
}
