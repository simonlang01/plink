import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    /// ~/Library/Application Support/Plink  (or Plink-Dev in debug)
    /// Survives app updates. Deleted by the uninstall script.
    static var dataDirectory: URL {
        #if DEBUG
        let folder = "Plink-Dev"
        #else
        let folder = "Plink"
        #endif
        let url = URL.applicationSupportDirectory.appending(path: folder, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private init() {
        let schema = Schema([TodoItem.self, TodoGroup.self])
        let storeURL = Self.dataDirectory.appending(path: "plink.sqlite")
        let config = ModelConfiguration(schema: schema, url: storeURL)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
        purgeExpiredItems()
    }

    /// Permanently deletes completed/deleted items older than 6 months.
    private func purgeExpiredItems() {
        let ctx = container.mainContext
        let cutoff = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        guard let items = try? ctx.fetch(FetchDescriptor<TodoItem>()) else { return }
        for item in items where item.isDeleted || item.isCompleted {
            let refDate = item.deletedAt ?? item.completedAt ?? item.createdAt
            if refDate < cutoff { ctx.delete(item) }
        }
        try? ctx.save()
    }

    /// In-memory container for previews / tests
    static var preview: ModelContainer = {
        let schema = Schema([TodoItem.self, TodoGroup.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let ctx = container.mainContext
        let group = TodoGroup(name: "Work")
        ctx.insert(group)
        ctx.insert(TodoItem(title: "Design icon", priority: .high, group: group))
        ctx.insert(TodoItem(title: "Write tests", priority: .medium))
        return container
    }()
}
