import SwiftUI
import SwiftData

@MainActor
final class TaskViewModel: ObservableObject {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func add(title: String, desc: String = "", priority: Priority = .none, dueDate: Date? = nil, group: TodoGroup? = nil) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let item = TodoItem(title: title, desc: desc, priority: priority, dueDate: dueDate, group: group)
        context.insert(item)
    }

    func complete(_ item: TodoItem) {
        item.isCompleted = true
    }

    func softDelete(_ item: TodoItem) {
        item.isDeleted = true
    }

    func restore(_ item: TodoItem) {
        item.isDeleted = false
    }

    func permanentlyDelete(_ item: TodoItem) {
        context.delete(item)
    }
}
