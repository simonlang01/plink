import SwiftUI

struct SectionHeaderView: View {
    let section: TaskSection
    let count: Int
    var searchActive: Bool = false
    @Environment(\.appAccent) private var accent

    private var label: LocalizedStringKey {
        if section == .recentlyCompleted && searchActive { return "section.completed" }
        return section.label
    }

    var body: some View {
        HStack(spacing: 6) {
            if section == .overdue {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.75))
            } else if section == .recentlyCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(accent.opacity(0.7))
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    section == .overdue           ? Color.red.opacity(0.75) :
                    section == .recentlyCompleted ? accent.opacity(0.7) : .secondary
                )
                .textCase(.uppercase)
                .tracking(0.5)
            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 4)
    }
}
