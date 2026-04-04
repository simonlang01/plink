import SwiftUI
import SwiftData

enum TaskSection: String, CaseIterable {
    case overdue, today, tomorrow, upcoming, someday, recentlyCompleted
    var label: LocalizedStringKey {
        switch self {
        case .overdue:           return "section.overdue"
        case .today:             return "section.today"
        case .tomorrow:          return "section.tomorrow"
        case .upcoming:          return "section.upcoming"
        case .someday:           return "section.someday"
        case .recentlyCompleted: return "section.recentlyCompleted"
        }
    }
}

enum GroupFilter: Equatable {
    case all
    case unassigned
    case group(TodoGroup)

    static func == (lhs: GroupFilter, rhs: GroupFilter) -> Bool {
        switch (lhs, rhs) {
        case (.all, .all), (.unassigned, .unassigned): return true
        case (.group(let a), .group(let b)):            return a.id == b.id
        default:                                        return false
        }
    }
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var groupFilter: GroupFilter = .all
    @Published var searchQuery: String = ""

    static let completedVisibilityWindow: TimeInterval = 30 * 60

    func sections(from items: [TodoItem], tick: Bool = false) -> [(TaskSection, [TodoItem])] {
        let cal = Calendar.current
        let now = Date()
        let startOfToday    = cal.startOfDay(for: now)
        let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: startOfToday)!
        let startOfDayAfter = cal.date(byAdding: .day, value: 2, to: startOfToday)!
        let cutoff = now.addingTimeInterval(-Self.completedVisibilityWindow)

        let active = items.filter { !$0.isCompleted && !$0.isDeleted && matches($0) }
        let recentDone = items.filter {
            $0.isCompleted && !$0.isDeleted && matches($0) &&
            (searchQuery.isEmpty ? ($0.completedAt ?? .distantPast) > cutoff : true)
        }

        func bucket(_ item: TodoItem) -> TaskSection {
            guard let due = item.dueDate else { return .someday }
            if due < startOfToday    { return .overdue }
            if due < startOfTomorrow { return .today }
            if due < startOfDayAfter { return .tomorrow }
            return .upcoming
        }

        let grouped = Dictionary(grouping: active, by: bucket)
        var result: [(TaskSection, [TodoItem])] = TaskSection.allCases.compactMap { section in
            guard section != .recentlyCompleted else { return nil }
            guard let items = grouped[section], !items.isEmpty else { return nil }
            return (section, items.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) })
        }

        if !recentDone.isEmpty {
            result.append((.recentlyCompleted, recentDone.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }))
        }
        return result
    }

    private func matches(_ item: TodoItem) -> Bool {
        let inGroup: Bool = {
            switch groupFilter {
            case .all:            return true
            case .unassigned:     return item.group == nil
            case .group(let g):   return item.group?.id == g.id
            }
        }()
        guard !searchQuery.isEmpty else { return inGroup }
        let textMatch = item.title.localizedCaseInsensitiveContains(searchQuery)
                     || item.desc.localizedCaseInsensitiveContains(searchQuery)
        return inGroup && textMatch
    }
}
