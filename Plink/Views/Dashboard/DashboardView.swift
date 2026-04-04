import SwiftUI
import SwiftData
import KeyboardShortcuts

struct DashboardView: View {
    @StateObject private var vm = DashboardViewModel()
    @Query private var allItems: [TodoItem]
    @Environment(\.modelContext) private var ctx
    @EnvironmentObject private var appState: AppState
    @State private var showAddSheet = false
    @State private var showTrash = false
    @State private var showHelp = false
    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var tick = false
    @Environment(\.appAccent) private var accent

    var body: some View {
        NavigationSplitView {
            SidebarView(groupFilter: $vm.groupFilter, showTrash: $showTrash)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            if showTrash { TrashView() } else { taskList }
        }
        .searchable(text: $vm.searchQuery, placement: .toolbar, prompt: LocalizedStringKey("search.placeholder"))
        .toolbar { toolbarContent }
        .navigationTitle("")
        .sheet(isPresented: $showHelp) {
            HelpView()
                .environment(\.appAccent, appState.accentOption.color)
        }
        .sheet(isPresented: $showAddSheet) {
            let preselectedGroup: TodoGroup? = {
                if case .group(let g) = vm.groupFilter { return g }
                return nil
            }()
            AddTaskSheet(smartInputEnabled: appState.smartInputEnabled, preselectedGroup: preselectedGroup)
        }
        .onReceive(refreshTimer) { _ in tick.toggle() }
    }

    // MARK: Task list

    @ViewBuilder
    private var taskList: some View {
        let sections = vm.sections(from: allItems, tick: tick)

        if sections.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(sections, id: \.0) { section, items in
                        SwiftUI.Section {
                            ForEach(items) { item in
                                TaskRowView(
                                    item: item,
                                    onComplete: { complete(item) },
                                    onDelete: { softDelete(item) }
                                )
                            }
                        } header: {
                            SectionHeaderView(section: section, count: items.count, searchActive: !vm.searchQuery.isEmpty)
                                .background(.background)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(accent.opacity(0.4))
            Text("dashboard.empty.title")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            if allItems.isEmpty {
                Button {
                    showAddSheet = true
                } label: {
                    Label(LocalizedStringKey("dashboard.empty.cta"), systemImage: "plus")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .controlSize(.regular)
                .padding(.top, 6)
            } else {
                Text(String(format: NSLocalizedString("dashboard.empty.hint", comment: ""), KeyboardShortcuts.getShortcut(for: .quickAdd)?.description ?? "⌥Space"))
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .fontWeight(.semibold)
            }
            .keyboardShortcut("n", modifiers: .option)
            .help(LocalizedStringKey("dashboard.newTask.help"))
        }
        ToolbarItem(placement: .automatic) {
            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .help("Help")
        }
    }

    // MARK: Actions

    private func complete(_ item: TodoItem) {
        withAnimation(.spring(duration: 0.25)) {
            item.isCompleted.toggle()
            item.completedAt = item.isCompleted ? Date() : nil
        }
    }

    private func softDelete(_ item: TodoItem) {
        withAnimation(.spring(duration: 0.2)) {
            item.isDeleted = true
            item.deletedAt = Date()
        }
    }
}
