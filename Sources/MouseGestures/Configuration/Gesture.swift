import Foundation

struct Gesture: Identifiable, Codable, Equatable {
    var id: UUID
    var trigger: Trigger
    var direction: Direction
    var action: Action

    init(
        id: UUID = UUID(),
        trigger: Trigger,
        direction: Direction,
        action: Action
    ) {
        self.id = id
        self.trigger = trigger
        self.direction = direction
        self.action = action
    }
}
