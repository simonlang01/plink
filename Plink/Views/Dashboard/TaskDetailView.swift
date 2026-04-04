import SwiftUI
import SwiftData

struct TaskDetailView: View {
    let item: TodoItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccent) private var accent
    @Query(sort: \TodoGroup.name) private var groups: [TodoGroup]

    // Local copies — only written back on save
    @State private var title: String
    @State private var desc: String
    @State private var priority: Priority
    @State private var dateSelection: DateSelection
    @State private var selectedGroup: TodoGroup?

    @State private var discardChanges = false
    @State private var showDatePicker = false
    @FocusState private var titleFocused: Bool

    enum DateSelection: Equatable {
        case none, today, tomorrow, custom(Date)
        var date: Date? {
            switch self {
            case .none:          return nil
            case .today:         return .today
            case .tomorrow:      return .tomorrow
            case .custom(let d): return d
            }
        }
        static func from(_ date: Date?) -> DateSelection {
            guard let date else { return .none }
            let cal = Calendar.current
            if cal.isDateInToday(date)     { return .today }
            if cal.isDateInTomorrow(date)  { return .tomorrow }
            return .custom(date)
        }
    }

    private static let chipDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()

    init(item: TodoItem) {
        self.item = item
        _title         = State(initialValue: item.title)
        _desc          = State(initialValue: item.desc)
        _priority      = State(initialValue: item.priority)
        _dateSelection = State(initialValue: .from(item.dueDate))
        _selectedGroup = State(initialValue: item.group)
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Title ──────────────────────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 15))
                    .foregroundStyle(accent)

                TextField(LocalizedStringKey("task.detail.title.placeholder"), text: $title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1...3)
                    .focused($titleFocused)
                    .onKeyPress(.return, phases: .down) { press in
                        guard !press.modifiers.contains(.shift) else { return .ignored }
                        save(); dismiss(); return .handled
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            // ── Description ────────────────────────────────────────
            TextField("Description (optional)", text: $desc, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(2...6)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .onKeyPress(.return, phases: .down) { press in
                    guard !press.modifiers.contains(.shift) else { return .ignored }
                    save(); dismiss(); return .handled
                }

            Divider()

            // ── Attribute chips ────────────────────────────────────
            HStack(spacing: 8) {

                // Date chips
                DetailChip(label: NSLocalizedString("task.date.today", comment: ""), icon: "sun.max", active: dateSelection == .today) {
                    dateSelection = dateSelection == .today ? .none : .today
                }
                DetailChip(label: NSLocalizedString("task.date.tomorrow", comment: ""), icon: "sunrise", active: dateSelection == .tomorrow) {
                    dateSelection = dateSelection == .tomorrow ? .none : .tomorrow
                }
                DetailChip(
                    label: {
                        if case .custom(let d) = dateSelection {
                            return Self.chipDateFormatter.string(from: d)
                        }
                        return NSLocalizedString("task.date.custom", comment: "")
                    }(),
                    icon: "calendar",
                    active: { if case .custom = dateSelection { return true }; return showDatePicker }()
                ) {
                    showDatePicker.toggle()
                }
                .popover(isPresented: $showDatePicker, arrowEdge: .top) {
                    MiniCalendarPicker(
                        selected: Binding(
                            get: { if case .custom(let d) = dateSelection { return d }; return .today },
                            set: { dateSelection = .custom($0) }
                        )
                    ) { showDatePicker = false }
                }

                Divider().frame(height: 14)

                // Priority menu
                Menu {
                    ForEach(Priority.allCases, id: \.self) { p in
                        Button {
                            priority = p
                        } label: {
                            Label(p.chipLabel, systemImage: priority == p ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: priority == .none ? "flag" : "flag.fill")
                            .font(.system(size: 11))
                        if priority != .none {
                            Text(priority.chipLabel).font(.system(size: 12))
                        }
                    }
                    .foregroundStyle(priority == .none ? .secondary : priority.color)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Group menu
                if !groups.isEmpty {
                    Divider().frame(height: 14)
                    Menu {
                        Button(LocalizedStringKey("task.noGroup")) { selectedGroup = nil }
                        Divider()
                        ForEach(groups) { group in
                            Button(group.name) { selectedGroup = group }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder").font(.system(size: 11))
                            Text(selectedGroup?.name ?? NSLocalizedString("group.title", comment: ""))
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(selectedGroup == nil ? .secondary : accent)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // ── Save / Discard ─────────────────────────────────────
            HStack(spacing: 10) {
                Button {
                    discardChanges = true
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .help(LocalizedStringKey("task.discard.help"))

                Spacer()

                Button {
                    save()
                    dismiss()
                } label: {
                    Label(LocalizedStringKey("task.save"), systemImage: "checkmark")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .controlSize(.small)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.regularMaterial)
        .frame(width: 460)
        .onAppear { DispatchQueue.main.async { titleFocused = true } }
        .onExitCommand {
            discardChanges = true
            dismiss()
        }
        .onDisappear {
            if !discardChanges { save() }
        }
    }

    private func save() {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        item.title    = t
        item.desc     = desc
        item.priority = priority
        item.dueDate  = dateSelection.date
        item.group    = selectedGroup
        if item.isCompleted && item.completedAt == nil { item.completedAt = Date() }
    }
}

// MARK: – Detail Chip (same style as QuickAddChip)

private struct DetailChip: View {
    let label: String
    let icon: String
    var active: Bool = false
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.appAccent) private var accent

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 12)).lineLimit(1)
            }
            .foregroundStyle(active || hovering ? accent : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(active || hovering ? accent.opacity(0.1) : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

