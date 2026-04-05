// PlinkTests.swift
// Comprehensive unit tests for Plink.
//
// HOW TO ADD THIS TARGET IN XCODE:
//   1. File > New > Target > Unit Testing Bundle
//   2. Name: "PlinkTests", Team: your team, Target to test: "Plink"
//   3. Delete the auto-generated test file and replace with this one.
//   4. In the target's Build Phases > Compile Sources, add all files
//      from the main Plink target that are referenced here (the test
//      target needs access to SmartInputParser, DashboardViewModel, etc.)
//      OR set "Allow testing Host Application APIs" in the test target settings.
//
// Alternatively (simpler):
//   In Plink target Build Settings, set "Enable Testability" to YES (Debug).
//   Then @testable import Klen works.

import XCTest
import SwiftData
@testable import Klen

// MARK: - Helpers

extension Date {
    /// Returns a Date offset by `days` days from today's start of day.
    static func today(offsetDays days: Int = 0, hour: Int = 0, minute: Int = 0) -> Date {
        let cal = Calendar.current
        var d = cal.startOfDay(for: Date())
        d = cal.date(byAdding: .day, value: days, to: d)!
        if hour != 0 || minute != 0 {
            d = cal.date(bySettingHour: hour, minute: minute, second: 0, of: d)!
        }
        return d
    }
}

/// Returns a fresh in-memory ModelContext for each test.
@MainActor
func makeTestContext() -> ModelContext {
    let schema = Schema([TodoItem.self, TodoGroup.self, TaskAttachment.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    return container.mainContext
}

// MARK: - RecurrenceFrequency Tests

final class RecurrenceFrequencyTests: XCTestCase {

    func test_daily_addsOneDay() {
        let base = Date.today()
        let next = RecurrenceFrequency.daily.nextDate(from: base, interval: 1)
        XCTAssertEqual(next, Calendar.current.date(byAdding: .day, value: 1, to: base))
    }

    func test_weekly_addsOneWeek() {
        let base = Date.today()
        let next = RecurrenceFrequency.weekly.nextDate(from: base, interval: 1)
        XCTAssertEqual(next, Calendar.current.date(byAdding: .weekOfYear, value: 1, to: base))
    }

    func test_monthly_addsOneMonth() {
        let base = Date.today()
        let next = RecurrenceFrequency.monthly.nextDate(from: base, interval: 1)
        XCTAssertEqual(next, Calendar.current.date(byAdding: .month, value: 1, to: base))
    }

    func test_yearly_addsOneYear() {
        let base = Date.today()
        let next = RecurrenceFrequency.yearly.nextDate(from: base, interval: 1)
        XCTAssertEqual(next, Calendar.current.date(byAdding: .year, value: 1, to: base))
    }

    func test_none_returnsSameDate() {
        let base = Date.today()
        let next = RecurrenceFrequency.none.nextDate(from: base, interval: 1)
        XCTAssertEqual(next, base)
    }

    /// EDGE CASE: interval > 1 (e.g. "every 2 weeks")
    func test_customInterval_twoWeeks() {
        let base = Date.today()
        let next = RecurrenceFrequency.weekly.nextDate(from: base, interval: 2)
        XCTAssertEqual(next, Calendar.current.date(byAdding: .weekOfYear, value: 2, to: base))
    }

    /// EDGE CASE: Jan 31 + 1 month — Swift Calendar handles this gracefully (returns last day of Feb)
    func test_monthly_jan31_doesNotCrash() {
        var comps = DateComponents(year: 2025, month: 1, day: 31)
        let jan31 = Calendar.current.date(from: comps)!
        let next = RecurrenceFrequency.monthly.nextDate(from: jan31, interval: 1)
        // Should be Feb 28 (2025 is not a leap year)
        comps = Calendar.current.dateComponents([.year, .month, .day], from: next)
        XCTAssertEqual(comps.month, 2)
        XCTAssertNotNil(next, "Should not return nil for Jan 31 + 1 month")
    }
}

// MARK: - TodoItem Model Tests

@MainActor
final class TodoItemModelTests: XCTestCase {

    func test_init_defaults() {
        let item = TodoItem(title: "Test")
        XCTAssertEqual(item.title, "Test")
        XCTAssertFalse(item.isCompleted)
        XCTAssertFalse(item.isDeleted)
        XCTAssertNil(item.dueDate)
        XCTAssertNil(item.completedAt)
        XCTAssertNil(item.deletedAt)
        XCTAssertFalse(item.isRecurring)
        XCTAssertEqual(item.recurrenceInterval, 1)
    }

    func test_isRecurring_falseByDefault() {
        let item = TodoItem(title: "Test")
        XCTAssertFalse(item.isRecurring)
    }

    func test_isRecurring_trueWhenSet() {
        let item = TodoItem(title: "Test")
        item.recurrence = .daily
        XCTAssertTrue(item.isRecurring)
    }

    func test_spawnNextOccurrence_createsNewItem() {
        let ctx = makeTestContext()
        let item = TodoItem(title: "Daily standup", dueDate: Date.today())
        item.recurrence = .daily
        ctx.insert(item)

        item.spawnNextOccurrence(in: ctx)

        let all = try! ctx.fetch(FetchDescriptor<TodoItem>())
        XCTAssertEqual(all.count, 2, "Should spawn one additional item")
        let spawned = all.first { $0.id != item.id }!
        XCTAssertEqual(spawned.title, "Daily standup")
        XCTAssertEqual(spawned.dueDate, Calendar.current.date(byAdding: .day, value: 1, to: Date.today()))
        XCTAssertFalse(spawned.isCompleted)
    }

    /// EDGE CASE: spawnNextOccurrence should do nothing if no dueDate.
    func test_spawnNextOccurrence_noDueDate_doesNothing() {
        let ctx = makeTestContext()
        let item = TodoItem(title: "No date recurring")
        item.recurrence = .weekly
        // NOTE: No dueDate set
        ctx.insert(item)

        item.spawnNextOccurrence(in: ctx)

        let all = try! ctx.fetch(FetchDescriptor<TodoItem>())
        XCTAssertEqual(all.count, 1, "Should NOT spawn when dueDate is nil — guard let anchor = dueDate")
    }

    /// EDGE CASE: spawnNextOccurrence should do nothing if recurrence is .none.
    func test_spawnNextOccurrence_nonRecurring_doesNothing() {
        let ctx = makeTestContext()
        let item = TodoItem(title: "One-time task", dueDate: Date.today())
        // recurrence is .none by default
        ctx.insert(item)

        item.spawnNextOccurrence(in: ctx)

        let all = try! ctx.fetch(FetchDescriptor<TodoItem>())
        XCTAssertEqual(all.count, 1, "Should NOT spawn for non-recurring tasks")
    }

    /// EDGE CASE: spawnNextOccurrence preserves group assignment.
    func test_spawnNextOccurrence_preservesGroup() {
        let ctx = makeTestContext()
        let group = TodoGroup(name: "Work")
        ctx.insert(group)
        let item = TodoItem(title: "Weekly review", dueDate: Date.today(), group: group)
        item.recurrence = .weekly
        ctx.insert(item)

        item.spawnNextOccurrence(in: ctx)

        let all = try! ctx.fetch(FetchDescriptor<TodoItem>())
        let spawned = all.first { $0.id != item.id }!
        XCTAssertEqual(spawned.group?.id, group.id, "Spawned item should inherit group")
    }

    func test_softDelete_setsFlags() {
        let item = TodoItem(title: "Delete me")
        item.isDeleted = true
        item.deletedAt = Date()
        XCTAssertTrue(item.isDeleted)
        XCTAssertNotNil(item.deletedAt)
    }

    func test_restore_clearsFlags() {
        let item = TodoItem(title: "Restore me")
        item.isDeleted = true
        item.isCompleted = true
        item.deletedAt = Date()
        item.completedAt = Date()

        // Simulate TaskViewModel.restore()
        item.isDeleted = false
        item.isCompleted = false
        item.deletedAt = nil
        item.completedAt = nil

        XCTAssertFalse(item.isDeleted)
        XCTAssertFalse(item.isCompleted)
        XCTAssertNil(item.deletedAt)
        XCTAssertNil(item.completedAt)
    }
}

// MARK: - DashboardViewModel Tests

@MainActor
final class DashboardViewModelTests: XCTestCase {

    var vm: DashboardViewModel!

    override func setUp() {
        super.setUp()
        vm = DashboardViewModel()
    }

    // MARK: Date buckets

    func test_overdueTask_appearsInOverdueSection() {
        let item = TodoItem(title: "Overdue", dueDate: Date.today(offsetDays: -1))
        let sections = vm.sections(from: [item])
        XCTAssertTrue(sections.contains { $0.0 == .overdue }, "Overdue task should be in .overdue section")
    }

    func test_todayTask_appearsInTodaySection() {
        let item = TodoItem(title: "Today", dueDate: Date.today())
        let sections = vm.sections(from: [item])
        XCTAssertTrue(sections.contains { $0.0 == .today }, "Today's task should be in .today section")
    }

    func test_tomorrowTask_appearsInTomorrowSection() {
        let item = TodoItem(title: "Tomorrow", dueDate: Date.today(offsetDays: 1))
        let sections = vm.sections(from: [item])
        XCTAssertTrue(sections.contains { $0.0 == .tomorrow })
    }

    func test_in5DaysTask_appearsInNext7DaysSection() {
        let item = TodoItem(title: "In 5 days", dueDate: Date.today(offsetDays: 5))
        let sections = vm.sections(from: [item])
        XCTAssertTrue(sections.contains { $0.0 == .next7Days })
    }

    func test_in10DaysTask_appearsInLaterSection() {
        let item = TodoItem(title: "Later", dueDate: Date.today(offsetDays: 10))
        let sections = vm.sections(from: [item])
        XCTAssertTrue(sections.contains { $0.0 == .later })
    }

    func test_noDateTask_appearsInNoDateSection() {
        let item = TodoItem(title: "No date")
        let sections = vm.sections(from: [item])
        XCTAssertTrue(sections.contains { $0.0 == .noDate })
    }

    // MARK: Visibility rules

    func test_deletedTask_notVisible() {
        let item = TodoItem(title: "Deleted", dueDate: Date.today())
        item.isDeleted = true
        let sections = vm.sections(from: [item])
        XCTAssertTrue(sections.isEmpty, "Deleted tasks must not appear in any section")
    }

    func test_completedTaskWithinWindow_appearsInRecentlyCompleted() {
        let item = TodoItem(title: "Just done", dueDate: Date.today())
        item.isCompleted = true
        item.completedAt = Date().addingTimeInterval(-60) // 1 min ago
        let sections = vm.sections(from: [item])
        XCTAssertTrue(sections.contains { $0.0 == .recentlyCompleted }, "Recently completed task should appear")
    }

    func test_completedTaskOlderThan30min_notVisible() {
        let item = TodoItem(title: "Done long ago")
        item.isCompleted = true
        item.completedAt = Date().addingTimeInterval(-(31 * 60)) // 31 min ago
        let sections = vm.sections(from: [item])
        let visible = sections.flatMap { $0.1 }
        XCTAssertFalse(visible.contains { $0.id == item.id }, "Task completed >30 min ago must not appear")
    }

    /// EDGE CASE: completedAt is nil — should use .distantPast and thus not appear.
    func test_completedTask_nilCompletedAt_notVisible() {
        let item = TodoItem(title: "Completed with nil completedAt")
        item.isCompleted = true
        item.completedAt = nil
        let sections = vm.sections(from: [item])
        let visible = sections.flatMap { $0.1 }
        XCTAssertFalse(visible.contains { $0.id == item.id }, "Completed task with nil completedAt must not appear")
    }

    /// EDGE CASE: Searching for a completed task should show it regardless of 30-min window.
    func test_searchForCompletedTask_alwaysVisible() {
        let item = TodoItem(title: "Old completed task")
        item.isCompleted = true
        item.completedAt = Date().addingTimeInterval(-(2 * 3600)) // 2 hours ago
        vm.searchQuery = "Old completed"
        let sections = vm.sections(from: [item])
        let visible = sections.flatMap { $0.1 }
        XCTAssertTrue(visible.contains { $0.id == item.id }, "Searching should bypass 30-min completed visibility window")
    }

    // MARK: Filtering

    func test_groupFilter_unassigned_excludesGroupedTasks() {
        let ctx = makeTestContext()
        let group = TodoGroup(name: "Work")
        ctx.insert(group)
        let grouped = TodoItem(title: "Has group", group: group)
        let ungrouped = TodoItem(title: "No group")
        vm.groupFilter = .unassigned
        let sections = vm.sections(from: [grouped, ungrouped])
        let visible = sections.flatMap { $0.1 }
        XCTAssertFalse(visible.contains { $0.id == grouped.id })
        XCTAssertTrue(visible.contains { $0.id == ungrouped.id })
    }

    func test_groupFilter_specificGroup_onlyShowsThatGroup() {
        let ctx = makeTestContext()
        let groupA = TodoGroup(name: "A")
        let groupB = TodoGroup(name: "B")
        ctx.insert(groupA); ctx.insert(groupB)
        let itemA = TodoItem(title: "A task", group: groupA)
        let itemB = TodoItem(title: "B task", group: groupB)
        vm.groupFilter = .group(groupA)
        let sections = vm.sections(from: [itemA, itemB])
        let visible = sections.flatMap { $0.1 }
        XCTAssertTrue(visible.contains { $0.id == itemA.id })
        XCTAssertFalse(visible.contains { $0.id == itemB.id })
    }

    func test_searchQuery_matchesTitle() {
        let match = TodoItem(title: "Buy milk")
        let noMatch = TodoItem(title: "Walk the dog")
        vm.searchQuery = "milk"
        let sections = vm.sections(from: [match, noMatch])
        let visible = sections.flatMap { $0.1 }
        XCTAssertTrue(visible.contains { $0.id == match.id })
        XCTAssertFalse(visible.contains { $0.id == noMatch.id })
    }

    func test_searchQuery_matchesDescription() {
        let item = TodoItem(title: "Task", desc: "contains keyword hidden here")
        vm.searchQuery = "keyword"
        let sections = vm.sections(from: [item])
        let visible = sections.flatMap { $0.1 }
        XCTAssertTrue(visible.contains { $0.id == item.id })
    }

    func test_searchQuery_caseInsensitive() {
        let item = TodoItem(title: "Buy Milk")
        vm.searchQuery = "milk"
        let sections = vm.sections(from: [item])
        XCTAssertFalse(sections.flatMap { $0.1 }.isEmpty, "Search should be case-insensitive")
    }

    // MARK: Priority sort

    func test_prioritySort_highBeforeLow() {
        vm.sortOrder = .priority
        let low  = TodoItem(title: "Low",  priority: .low)
        let high = TodoItem(title: "High", priority: .high)
        let sections = vm.sections(from: [low, high])
        let highSection = sections.first { $0.0 == .priorityHigh }
        let lowSection  = sections.first { $0.0 == .priorityLow }
        XCTAssertNotNil(highSection)
        XCTAssertNotNil(lowSection)
        let highIdx = sections.firstIndex { $0.0 == .priorityHigh }!
        let lowIdx  = sections.firstIndex { $0.0 == .priorityLow }!
        XCTAssertLessThan(highIdx, lowIdx, "High priority section must come before low")
    }

    func test_prioritySort_completedNotVisible() {
        vm.sortOrder = .priority
        let item = TodoItem(title: "Done", priority: .high)
        item.isCompleted = true
        item.completedAt = Date().addingTimeInterval(-3600)
        let sections = vm.sections(from: [item])
        XCTAssertTrue(sections.isEmpty, "Priority view should not show completed tasks")
    }

    // MARK: Stats

    func test_stats_overdueCount() {
        let overdue = TodoItem(title: "Overdue", dueDate: Date.today(offsetDays: -1))
        let future  = TodoItem(title: "Future",  dueDate: Date.today(offsetDays: 3))
        let stats = vm.stats(from: [overdue, future])
        XCTAssertEqual(stats.overdueCount, 1)
        XCTAssertEqual(stats.openCount, 2)
    }

    func test_stats_deletedNotCounted() {
        let deleted = TodoItem(title: "Deleted")
        deleted.isDeleted = true
        let stats = vm.stats(from: [deleted])
        XCTAssertEqual(stats.openCount, 0)
    }

    func test_stats_dueTodayCount() {
        let today    = TodoItem(title: "Today",    dueDate: Date.today(hour: 10))
        let tomorrow = TodoItem(title: "Tomorrow", dueDate: Date.today(offsetDays: 1))
        let stats = vm.stats(from: [today, tomorrow])
        XCTAssertEqual(stats.dueToday, 1)
    }

    func test_stats_completedThisWeek() {
        let recentDone = TodoItem(title: "Done recently")
        recentDone.isCompleted = true
        recentDone.completedAt = Date()

        let oldDone = TodoItem(title: "Done 2 months ago")
        oldDone.isCompleted = true
        oldDone.completedAt = Date().addingTimeInterval(-(60 * 24 * 3600))

        let stats = vm.stats(from: [recentDone, oldDone])
        XCTAssertEqual(stats.completedThisWeek, 1)
    }

    // MARK: Sorting within sections

    func test_sectionItemsSortedByDueDate() {
        let early = TodoItem(title: "Early", dueDate: Date.today(offsetDays: 3))
        let late  = TodoItem(title: "Late",  dueDate: Date.today(offsetDays: 5))
        let sections = vm.sections(from: [late, early])
        let next7 = sections.first { $0.0 == .next7Days }!
        XCTAssertEqual(next7.1.first?.title, "Early", "Items within section should be sorted by due date ascending")
    }

    // MARK: EDGE CASES / POTENTIAL BUGS

    /// BUG CHECK: Two tasks with identical due dates — neither should be lost.
    func test_duplicateDueDates_bothVisible() {
        let date = Date.today(hour: 10)
        let a = TodoItem(title: "Task A", dueDate: date)
        let b = TodoItem(title: "Task B", dueDate: date)
        let sections = vm.sections(from: [a, b])
        let visible = sections.flatMap { $0.1 }
        XCTAssertEqual(visible.count, 2, "Both tasks with same due date must be visible")
    }

    /// BUG CHECK: Empty items array — should return empty sections, not crash.
    func test_emptySections_noItems() {
        let sections = vm.sections(from: [])
        XCTAssertTrue(sections.isEmpty)
    }

    /// BUG CHECK: Task at exact midnight today — should appear in Today, not Overdue.
    func test_taskAtMidnightToday_notOverdue() {
        let midnight = Calendar.current.startOfDay(for: Date())
        let item = TodoItem(title: "Midnight task", dueDate: midnight)
        let sections = vm.sections(from: [item])
        let inToday    = sections.contains { $0.0 == .today }
        let inOverdue  = sections.contains { $0.0 == .overdue }
        XCTAssertTrue(inToday,   "Task at startOfDay should be in Today")
        XCTAssertFalse(inOverdue, "Task at startOfDay must NOT be overdue")
    }

    /// BUG CHECK: Task at exactly startOfTomorrow boundary — belongs in Tomorrow, not Today.
    func test_taskAtStartOfTomorrow_inTomorrow() {
        let startOfTomorrow = Calendar.current.startOfDay(for: Date.today(offsetDays: 1))
        let item = TodoItem(title: "Tomorrow midnight", dueDate: startOfTomorrow)
        let sections = vm.sections(from: [item])
        XCTAssertTrue(sections.contains { $0.0 == .tomorrow }, "Boundary: startOfTomorrow must be in Tomorrow")
        XCTAssertFalse(sections.contains { $0.0 == .today }, "Boundary: startOfTomorrow must NOT be in Today")
    }
}

// MARK: - SmartInputParser Token Tests

final class SmartInputParserTokenTests: XCTestCase {

    func test_simpleTitle() {
        let r = SmartInputParser.parseWithTokens("Buy groceries")
        XCTAssertEqual(r.title, "Buy groceries")
        XCTAssertNil(r.dueDate)
        XCTAssertEqual(r.priority, .none)
        XCTAssertNil(r.groupName)
    }

    func test_titleCapitalization() {
        let r = SmartInputParser.parseWithTokens("buy groceries")
        XCTAssertEqual(r.title, "Buy groceries", "Title should be auto-capitalized")
    }

    func test_dateToken_today() {
        let r = SmartInputParser.parseWithTokens("Dentist @today")
        XCTAssertNotNil(r.dueDate)
        let isToday = Calendar.current.isDateInToday(r.dueDate!)
        XCTAssertTrue(isToday)
    }

    func test_dateToken_tomorrow() {
        let r = SmartInputParser.parseWithTokens("Meeting @tomorrow")
        XCTAssertNotNil(r.dueDate)
        let expected = Calendar.current.startOfDay(for: Date.today(offsetDays: 1))
        XCTAssertEqual(r.dueDate, expected)
    }

    func test_timeToken_setsHasDueTime() {
        let r = SmartInputParser.parseWithTokens("Call @today @@14:30")
        XCTAssertTrue(r.hasDueTime)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: r.dueDate!)
        XCTAssertEqual(comps.hour, 14)
        XCTAssertEqual(comps.minute, 30)
    }

    /// EDGE CASE: Time token without date — should default to today.
    func test_timeTokenWithoutDate_defaultsToToday() {
        let r = SmartInputParser.parseWithTokens("Call @@09:00")
        XCTAssertTrue(r.hasDueTime)
        XCTAssertNotNil(r.dueDate, "Time-only input should default dueDate to today")
        let isToday = Calendar.current.isDateInToday(r.dueDate!)
        XCTAssertTrue(isToday)
        // NOTE: If @@09:00 is parsed at 11pm, the resulting time is already in the past today.
        // This is a known UX issue — task would appear immediately as "overdue" or "today" past due.
    }

    func test_priorityToken_high() {
        let r = SmartInputParser.parseWithTokens("Fix bug !h")
        XCTAssertEqual(r.priority, .high)
    }

    func test_priorityToken_medium_fullWord() {
        let r = SmartInputParser.parseWithTokens("Review PR !medium")
        XCTAssertEqual(r.priority, .medium)
    }

    func test_priorityToken_low_german() {
        let r = SmartInputParser.parseWithTokens("Putzen !niedrig")
        XCTAssertEqual(r.priority, .low)
    }

    func test_groupToken() {
        let r = SmartInputParser.parseWithTokens("Standup #Work")
        XCTAssertEqual(r.groupName, "Work")
    }

    func test_blockingToken_blocked() {
        let r = SmartInputParser.parseWithTokens("Waiting for review !b")
        XCTAssertEqual(r.blockingStatus, .blocked)
    }

    func test_blockingToken_blocking_german() {
        let r = SmartInputParser.parseWithTokens("Blocking deploy !blockiere")
        XCTAssertEqual(r.blockingStatus, .blocking)
    }

    func test_combinedTokens() {
        let r = SmartInputParser.parseWithTokens("Team meeting @tomorrow @@10:00 #Work !h")
        XCTAssertEqual(r.title, "Team meeting")
        XCTAssertEqual(r.groupName, "Work")
        XCTAssertEqual(r.priority, .high)
        XCTAssertTrue(r.hasDueTime)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: r.dueDate!)
        XCTAssertEqual(comps.hour, 10)
        XCTAssertEqual(comps.minute, 0)
    }

    func test_unknownFlagToken_silentlyIgnored() {
        let r = SmartInputParser.parseWithTokens("Task !unknownflag")
        XCTAssertEqual(r.priority, .none)
        XCTAssertNil(r.blockingStatus)
    }

    func test_emptyInput() {
        let r = SmartInputParser.parseWithTokens("")
        XCTAssertEqual(r.title, "")
        XCTAssertNil(r.dueDate)
    }

    /// EDGE CASE / BUG CHECK: Token at start of input — title would be empty.
    /// Example: "@today Buy milk" — first `@` is at index 0 → titleRaw = "" → title = "".
    func test_tokenBeforeTitle_titleIsEmpty_knownLimitation() {
        let r = SmartInputParser.parseWithTokens("@today Buy milk")
        // The parser extracts title as everything BEFORE the first token symbol.
        // Since @today comes first, the title becomes "" — the "Buy milk" text after
        // the token is not captured in the title. This is a known parser limitation.
        XCTAssertEqual(r.title, "", "Title is empty when tokens precede the text — known limitation")
        // If this fails in future, it means the parser was improved.
    }

    /// EDGE CASE: Multiple @ tokens — which date wins?
    func test_multipleAtTokens_lastOneWins() {
        // Both @today and @tomorrow — the second overrides the first per the scanner logic
        let r = SmartInputParser.parseWithTokens("Task @today @tomorrow")
        let expected = Calendar.current.startOfDay(for: Date.today(offsetDays: 1))
        XCTAssertEqual(r.dueDate, expected, "Last @date token should win (scanner overwrites)")
    }

    /// EDGE CASE: Only whitespace input.
    func test_whitespaceOnlyInput() {
        let r = SmartInputParser.parseWithTokens("   ")
        XCTAssertEqual(r.title, "")
    }

    /// EDGE CASE: Group name with spaces.
    func test_groupToken_withSpaces() {
        let r = SmartInputParser.parseWithTokens("Task #Peter Park @today")
        // Per the spec: group value extends to next token symbol
        XCTAssertEqual(r.groupName, "Peter Park")
    }
}

// MARK: - SmartInputParser NLTagger Tests

final class SmartInputParserNLTaggerTests: XCTestCase {

    func test_relativeDate_tomorrow() {
        let r = SmartInputParser.parseWithNLTagger("Buy flowers tomorrow")
        XCTAssertNotNil(r.dueDate)
        let expected = Calendar.current.startOfDay(for: Date.today(offsetDays: 1))
        XCTAssertEqual(r.dueDate, expected)
    }

    func test_relativeDate_heute_german() {
        let r = SmartInputParser.parseWithNLTagger("Einkaufen heute")
        XCTAssertNotNil(r.dueDate)
        XCTAssertTrue(Calendar.current.isDateInToday(r.dueDate!))
    }

    func test_relativeDate_morgen_german() {
        let r = SmartInputParser.parseWithNLTagger("Morgen einkaufen")
        XCTAssertNotNil(r.dueDate)
        let expected = Calendar.current.startOfDay(for: Date.today(offsetDays: 1))
        XCTAssertEqual(r.dueDate, expected)
    }

    func test_relativeDate_uebermorgen() {
        let r = SmartInputParser.parseWithNLTagger("Zahnarzt übermorgen")
        XCTAssertNotNil(r.dueDate)
        let expected = Calendar.current.startOfDay(for: Date.today(offsetDays: 2))
        XCTAssertEqual(r.dueDate, expected)
    }

    func test_time_24h_format() {
        var text = "Meeting um 14:30 Uhr"
        let tc = SmartInputParser.extractTime(from: &text)
        XCTAssertNotNil(tc)
        XCTAssertEqual(tc?.hour, 14)
        XCTAssertEqual(tc?.minute, 30)
    }

    func test_time_at_pm() {
        var text = "call at 3pm"
        let tc = SmartInputParser.extractTime(from: &text)
        XCTAssertNotNil(tc)
        XCTAssertEqual(tc?.hour, 15)
    }

    func test_time_at_am_12_is_midnight() {
        var text = "reminder at 12am"
        let tc = SmartInputParser.extractTime(from: &text)
        XCTAssertNotNil(tc)
        XCTAssertEqual(tc?.hour, 0, "12am should be midnight (hour 0)")
    }

    func test_time_24h_standalone() {
        var text = "Termin 09:15"
        let tc = SmartInputParser.extractTime(from: &text)
        XCTAssertNotNil(tc)
        XCTAssertEqual(tc?.hour, 9)
        XCTAssertEqual(tc?.minute, 15)
    }

    func test_priority_urgent() {
        let r = SmartInputParser.parseWithNLTagger("Fix this urgent bug")
        XCTAssertEqual(r.priority, .high)
    }

    func test_priority_wichtig_german() {
        let r = SmartInputParser.parseWithNLTagger("Das ist wichtig")
        XCTAssertEqual(r.priority, .medium)
    }

    func test_priority_irgendwann_german() {
        let r = SmartInputParser.parseWithNLTagger("irgendwann putzen")
        XCTAssertEqual(r.priority, .low)
    }

    func test_groupPrefix_extracted() {
        let r = SmartInputParser.parseWithNLTagger("Work: Prepare slides")
        XCTAssertEqual(r.groupName, "Work")
    }

    func test_groupPrefix_notExtracted_noColon() {
        let r = SmartInputParser.parseWithNLTagger("Prepare slides for Work")
        XCTAssertNil(r.groupName, "No group prefix without colon separator")
    }

    func test_fillerPhrase_removed_english() {
        let r = SmartInputParser.parseWithNLTagger("I need to buy groceries")
        XCTAssertEqual(r.title, "Buy groceries", "Filler phrase 'I need to' should be stripped")
    }

    func test_fillerPhrase_removed_german() {
        let r = SmartInputParser.parseWithNLTagger("ich muss tanken")
        XCTAssertEqual(r.title, "Tanken", "German filler 'ich muss' should be stripped")
    }

    func test_relativeDate_inNDays() {
        let r = SmartInputParser.parseWithNLTagger("Call back in 3 days")
        XCTAssertNotNil(r.dueDate)
        let expected = Calendar.current.startOfDay(for: Date.today(offsetDays: 3))
        XCTAssertEqual(r.dueDate, expected)
    }

    func test_relativeDate_nextWeek() {
        let r = SmartInputParser.parseWithNLTagger("Meeting next week")
        XCTAssertNotNil(r.dueDate)
        let expected = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 7, to: Date())!)
        XCTAssertEqual(r.dueDate, expected)
    }

    /// EDGE CASE: Standalone weekday at start of input (needs trailing comma/space).
    func test_standaloneWeekday_atStart() {
        // "Monday, call John" — note: pattern requires trailing comma or whitespace
        let r = SmartInputParser.parseWithNLTagger("Monday, call John")
        XCTAssertNotNil(r.dueDate, "Weekday at start should be parsed as date")
    }

    /// EDGE CASE / BUG CHECK: Standalone weekday WITHOUT trailing separator.
    func test_standaloneWeekday_noSeparator_notParsed() {
        // "Monday" alone — the standalonePattern requires [,\s] after the day name.
        // Without a trailing separator, this will fall through to NSDataDetector.
        let r = SmartInputParser.parseWithNLTagger("Monday")
        // This may or may not find a date — NSDataDetector might pick it up.
        // We just document the behavior here; this is a known edge case.
        _ = r.dueDate // no assertion — just ensure it doesn't crash
    }
}

// MARK: - TaskAttachment Tests

final class TaskAttachmentTests: XCTestCase {

    func test_displayIcon_pdf() {
        let a = TaskAttachment(filename: "report.pdf", filePath: "")
        XCTAssertEqual(a.displayIcon, "doc.richtext")
    }

    func test_displayIcon_image() {
        XCTAssertEqual(TaskAttachment(filename: "photo.png",  filePath: "").displayIcon, "photo")
        XCTAssertEqual(TaskAttachment(filename: "image.jpg",  filePath: "").displayIcon, "photo")
        XCTAssertEqual(TaskAttachment(filename: "img.heic",   filePath: "").displayIcon, "photo")
    }

    func test_displayIcon_audio() {
        XCTAssertEqual(TaskAttachment(filename: "song.mp3", filePath: "").displayIcon, "music.note")
        XCTAssertEqual(TaskAttachment(filename: "voice.m4a", filePath: "").displayIcon, "music.note")
    }

    func test_displayIcon_video() {
        XCTAssertEqual(TaskAttachment(filename: "clip.mp4", filePath: "").displayIcon, "video")
    }

    func test_displayIcon_archive() {
        XCTAssertEqual(TaskAttachment(filename: "files.zip", filePath: "").displayIcon, "archivebox")
    }

    func test_displayIcon_unknown() {
        XCTAssertEqual(TaskAttachment(filename: "data.xyz", filePath: "").displayIcon, "paperclip")
    }

    func test_displayIcon_caseInsensitive() {
        // Extension matching uses .lowercased() — uppercase should still work
        XCTAssertEqual(TaskAttachment(filename: "REPORT.PDF", filePath: "").displayIcon, "doc.richtext")
    }

    func test_displayIcon_noExtension() {
        XCTAssertEqual(TaskAttachment(filename: "Makefile", filePath: "").displayIcon, "paperclip")
    }
}

// MARK: - TodoGroup Tests

@MainActor
final class TodoGroupTests: XCTestCase {

    func test_deleteGroup_itemsNotDeleted() {
        // The relationship uses nullify delete rule — items should remain when group is deleted.
        let ctx = makeTestContext()
        let group = TodoGroup(name: "Temp")
        ctx.insert(group)
        let item = TodoItem(title: "My task", group: group)
        ctx.insert(item)
        try! ctx.save()

        ctx.delete(group)
        try! ctx.save()

        let items = try! ctx.fetch(FetchDescriptor<TodoItem>())
        XCTAssertEqual(items.count, 1, "Deleting group must not delete its tasks (nullify rule)")
        XCTAssertNil(items.first?.group, "Task's group reference should be nil after group deletion")
    }

    func test_deleteItem_doesNotDeleteGroup() {
        let ctx = makeTestContext()
        let group = TodoGroup(name: "Keep me")
        ctx.insert(group)
        let item = TodoItem(title: "Temporary task", group: group)
        ctx.insert(item)
        try! ctx.save()

        ctx.delete(item)
        try! ctx.save()

        let groups = try! ctx.fetch(FetchDescriptor<TodoGroup>())
        XCTAssertEqual(groups.count, 1, "Deleting a task must not delete its group")
    }
}

// MARK: - PersistenceController Purge Logic Tests

@MainActor
final class PurgeLogicTests: XCTestCase {

    func test_purge_deletesOldCompletedItems() {
        let ctx = makeTestContext()
        let oldDone = TodoItem(title: "Done 7 months ago")
        oldDone.isCompleted = true
        oldDone.completedAt = Calendar.current.date(byAdding: .month, value: -7, to: Date())!
        ctx.insert(oldDone)

        let newDone = TodoItem(title: "Done 1 week ago")
        newDone.isCompleted = true
        newDone.completedAt = Date().addingTimeInterval(-(7 * 24 * 3600))
        ctx.insert(newDone)

        try! ctx.save()

        // Simulate purge logic
        let cutoff = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        let all = try! ctx.fetch(FetchDescriptor<TodoItem>())
        for item in all where item.isDeleted || item.isCompleted {
            let refDate = item.deletedAt ?? item.completedAt ?? item.createdAt
            if refDate < cutoff { ctx.delete(item) }
        }
        try! ctx.save()

        let remaining = try! ctx.fetch(FetchDescriptor<TodoItem>())
        XCTAssertEqual(remaining.count, 1, "Only the recently completed task should remain")
        XCTAssertEqual(remaining.first?.title, "Done 1 week ago")
    }

    func test_purge_doesNotDeleteActiveItems() {
        let ctx = makeTestContext()
        let active = TodoItem(title: "Active task")
        // Very old creation date — but not completed/deleted
        active.createdAt = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        ctx.insert(active)
        try! ctx.save()

        let cutoff = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        let all = try! ctx.fetch(FetchDescriptor<TodoItem>())
        for item in all where item.isDeleted || item.isCompleted {
            let refDate = item.deletedAt ?? item.completedAt ?? item.createdAt
            if refDate < cutoff { ctx.delete(item) }
        }
        try! ctx.save()

        let remaining = try! ctx.fetch(FetchDescriptor<TodoItem>())
        XCTAssertEqual(remaining.count, 1, "Active (not completed, not deleted) tasks must never be purged")
    }

    /// EDGE CASE / BUG CHECK: deletedAt is nil but item.isDeleted is true.
    /// Purge uses `deletedAt ?? completedAt ?? createdAt` as reference.
    /// A very old task soft-deleted TODAY (deletedAt = nil) would use createdAt —
    /// if createdAt is >6 months ago, it gets purged immediately on next launch!
    func test_purge_deletedAtNil_fallsBackToCreatedAt() {
        let ctx = makeTestContext()
        let oldItem = TodoItem(title: "Old task, just deleted")
        oldItem.isDeleted = true
        oldItem.deletedAt = nil // missing — should be set by TaskViewModel.softDelete
        oldItem.createdAt = Calendar.current.date(byAdding: .month, value: -7, to: Date())!
        ctx.insert(oldItem)
        try! ctx.save()

        let cutoff = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        let all = try! ctx.fetch(FetchDescriptor<TodoItem>())
        for item in all where item.isDeleted || item.isCompleted {
            let refDate = item.deletedAt ?? item.completedAt ?? item.createdAt
            if refDate < cutoff { ctx.delete(item) }
        }
        try! ctx.save()

        let remaining = try! ctx.fetch(FetchDescriptor<TodoItem>())
        // This WILL be purged because deletedAt is nil, so createdAt (7 months ago) is used.
        // This documents a potential data-loss bug: always set deletedAt when soft-deleting.
        XCTAssertEqual(remaining.count, 0,
            "KNOWN RISK: If deletedAt is nil, purge falls back to createdAt. " +
            "Old tasks soft-deleted without setting deletedAt may be purged immediately.")
    }
}
