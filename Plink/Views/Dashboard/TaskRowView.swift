import SwiftUI

struct TaskRowView: View {
    let item: TodoItem
    let onComplete: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false
    @State private var showDetail = false
    @Environment(\.appAccent) private var accent

    private var isOverdue: Bool {
        guard let due = item.dueDate else { return false }
        return due < Calendar.current.startOfDay(for: Date()) && !item.isCompleted
    }

    var body: some View {
        ZStack(alignment: .trailing) {

            // ── Row content (slides left on hover) ──────────────
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13))
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        .strikethrough(item.isCompleted, color: .secondary)
                        .lineLimit(1)

                    if !item.desc.isEmpty {
                        Text(item.desc)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    if item.priority != .none {
                        PriorityDot(priority: item.priority)
                    }
                    if let due = item.dueDate {
                        Text(due, style: .date)
                            .font(.system(size: 11))
                            .foregroundStyle(isOverdue ? AnyShapeStyle(Color.red.opacity(0.8)) : AnyShapeStyle(.tertiary))
                    }
                    if let group = item.group {
                        Text(group.name)
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accent.opacity(0.12), in: Capsule())
                            .foregroundStyle(accent)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .padding(.trailing, hovering ? 72 : 0)
            .background(hovering ? Color.primary.opacity(0.04) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .onTapGesture { showDetail = true }
            .animation(.spring(duration: 0.2), value: hovering)

            // ── Complete button — rendered on top so it wins hit testing ──
            Button(action: onComplete) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(item.isCompleted ? Color.secondary.opacity(0.1) : accent.opacity(0.12))
                    Image(systemName: item.isCompleted ? "arrow.uturn.backward" : "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(item.isCompleted ? .secondary : accent)
                }
                .frame(width: 64)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .scaleEffect(x: hovering ? 1 : 0.7, anchor: .trailing)
            .allowsHitTesting(hovering)
            .animation(.spring(duration: 0.2), value: hovering)
        }
        .onHover { hovering = $0 }
        .contextMenu {
            Button(LocalizedStringKey("task.edit")) { showDetail = true }
            Button(item.isCompleted ? LocalizedStringKey("task.markIncomplete") : LocalizedStringKey("task.markComplete"), action: onComplete)
            Divider()
            Button("action.delete", role: .destructive, action: onDelete)
        }
        .sheet(isPresented: $showDetail) {
            TaskDetailView(item: item)
        }
    }
}

private struct PriorityDot: View {
    let priority: Priority
    @Environment(\.appAccent) private var accent
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
    }
    private var color: Color {
        switch priority {
        case .high:   return .red.opacity(0.8)
        case .medium: return .orange.opacity(0.8)
        case .low:    return accent.opacity(0.6)
        case .none:   return .clear
        }
    }
}
