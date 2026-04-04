import Foundation
import SwiftUI
import SwiftData

enum Priority: Int, Codable, CaseIterable {
    case none = 0, low, medium, high

    var chipLabel: String {
        switch self {
        case .none:   return NSLocalizedString("priority.none", comment: "")
        case .low:    return NSLocalizedString("priority.low", comment: "")
        case .medium: return NSLocalizedString("priority.medium", comment: "")
        case .high:   return NSLocalizedString("priority.high", comment: "")
        }
    }

    var color: Color {
        switch self {
        case .none:   return .secondary
        case .low:    return Theme.defaultAccent
        case .medium: return .orange
        case .high:   return .red
        }
    }
}

@Model
final class TodoItem {
    var id: UUID
    var title: String
    var desc: String
    var priority: Priority
    var dueDate: Date?
    var isCompleted: Bool
    var isDeleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var deletedAt: Date?
    var group: TodoGroup?

    init(
        title: String,
        desc: String = "",
        priority: Priority = .none,
        dueDate: Date? = nil,
        group: TodoGroup? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.desc = desc
        self.priority = priority
        self.dueDate = dueDate
        self.isCompleted = false
        self.isDeleted = false
        self.createdAt = Date()
        self.group = group
    }
}
