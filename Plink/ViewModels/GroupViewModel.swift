import SwiftUI
import SwiftData

@MainActor
final class GroupViewModel: ObservableObject {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func add(name: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        context.insert(TodoGroup(name: name))
    }

    func delete(_ group: TodoGroup) {
        context.delete(group) // cascade deletes items
    }
}
