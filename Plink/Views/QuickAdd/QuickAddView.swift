import SwiftUI
import SwiftData

struct QuickAddView: View {
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var ctx
    @Environment(\.appAccent) private var accent
    @Query(sort: \TodoGroup.name) private var groups: [TodoGroup]

    enum DateSelection: Equatable {
        case none, today, tomorrow, custom(Date)
        var date: Date? {
            switch self {
            case .none:           return nil
            case .today:          return .today
            case .tomorrow:       return .tomorrow
            case .custom(let d):  return d
            }
        }
    }

    @State private var title = ""
    @State private var selectedGroup: TodoGroup? = nil
    @State private var dateSelection: DateSelection = .none
    @State private var priority: Priority = .none
    @State private var showDatePicker = false
    @State private var smartMode: Bool
    @FocusState private var focused: Bool

    let smartInputEnabled: Bool

    init(smartInputEnabled: Bool, onDismiss: @escaping () -> Void) {
        self.smartInputEnabled = smartInputEnabled
        self.onDismiss = onDismiss
        _smartMode = State(initialValue: smartInputEnabled)
    }

    private static let chipDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Input row
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(accent)

                TextField(smartMode ? LocalizedStringKey("smart.placeholder") : LocalizedStringKey("task.title.placeholder"), text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($focused)
                    .onSubmit { submitWithCurrentDate() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            // Action row
            HStack(spacing: 8) {
                if !smartMode {
                    QuickAddChip(label: NSLocalizedString("task.date.today", comment: ""), icon: "sun.max", active: dateSelection == .today) {
                        dateSelection = .today
                    }
                    QuickAddChip(label: NSLocalizedString("task.date.tomorrow", comment: ""), icon: "sunrise", active: dateSelection == .tomorrow) {
                        dateSelection = .tomorrow
                    }

                    QuickAddChip(
                        label: {
                            if case .custom(let d) = dateSelection {
                                return Self.chipDateFormatter.string(from: d)
                            }
                            return NSLocalizedString("task.dueDate", comment: "")
                        }(),
                        icon: "calendar",
                        active: { if case .custom = dateSelection { return true }; return showDatePicker }()
                    ) {
                        showDatePicker.toggle()
                    }
                    .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
                        MiniCalendarPicker(selected: Binding(
                            get: {
                                if case .custom(let d) = dateSelection { return d }
                                return .today
                            },
                            set: { dateSelection = .custom($0) }
                        )) {
                            showDatePicker = false
                        }
                    }

                    Divider().frame(height: 14)

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

                    if !groups.isEmpty {
                        Divider().frame(height: 14)
                        Menu {
                            Button(LocalizedStringKey("group.allTasks")) { selectedGroup = nil }
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

                    Divider().frame(height: 14)
                } else {
                    // Smart mode hint
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text(LocalizedStringKey("smart.hint"))
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(accent.opacity(0.7))
                }

                Spacer()

                // Smart input toggle (only shown if feature is enabled in Settings)
                if smartInputEnabled {
                    Button {
                        smartMode.toggle()
                        if !smartMode {
                            dateSelection = .none
                            priority = .none
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                            Text(LocalizedStringKey("smart.toggle.label"))
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(smartMode ? accent : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(smartMode ? accent.opacity(0.1) : Color.clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(LocalizedStringKey("smart.toggle.help"))
                }

                Button {
                    submitWithCurrentDate()
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(title.trimmingCharacters(in: .whitespaces).isEmpty
                            ? accent.opacity(0.25) : accent)
                }
                .buttonStyle(.plain)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.regularMaterial)
        .onAppear { DispatchQueue.main.async { focused = true } }
        .onExitCommand { onDismiss() }
    }

    private func submitWithCurrentDate() {
        if smartMode {
            let t = title.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { return }
            onDismiss() // dismiss immediately; insert happens async
            Task {
                let result = await SmartInputParser.parse(t)
                await MainActor.run {
                    ctx.insert(TodoItem(title: result.title, desc: result.desc, priority: result.priority, dueDate: result.dueDate, group: selectedGroup))
                }
            }
        } else {
            submit(dueDate: dateSelection.date)
        }
    }

    private func submit(dueDate: Date?) {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        ctx.insert(TodoItem(title: t, priority: priority, dueDate: dueDate, group: selectedGroup))
        onDismiss()
    }
}

// MARK: – Chip

private struct QuickAddChip: View {
    enum Label {
        case localized(LocalizedStringKey)
        case plain(String)
    }

    let label: Label
    let icon: String
    var active: Bool = false
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.appAccent) private var accent

    init(label: LocalizedStringKey, icon: String, active: Bool = false, action: @escaping () -> Void) {
        self.label = .localized(label)
        self.icon = icon
        self.active = active
        self.action = action
    }

    init(label: String, icon: String, active: Bool = false, action: @escaping () -> Void) {
        self.label = .plain(label)
        self.icon = icon
        self.active = active
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Group {
                    switch label {
                    case .localized(let key): Text(key)
                    case .plain(let str):     Text(str)
                    }
                }
                .font(.system(size: 12))
                .lineLimit(1)
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
