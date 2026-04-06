import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showOnboarding = !FileManager.default.fileExists(
        atPath: PersistenceController.dataDirectory.appendingPathComponent(".onboarding_complete").path
    )
    @State private var showWhatsNew = false
    @State private var languageID = UUID()

    private static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView { showOnboarding = false }
                    .frame(width: 520, height: 480)
            } else {
                DashboardView()
                    .frame(minWidth: 700, minHeight: 480)
            }
        }
        .id(languageID)
        .preferredColorScheme(appState.appearanceMode.colorScheme)
        .environment(\.appAccent, appState.accentOption.color)
        .onReceive(NotificationCenter.default.publisher(for: .plinkLanguageChanged)) { _ in
            languageID = UUID()
        }
        .onAppear {
            // Show What's New once per version, never during onboarding
            let seen = UserDefaults.standard.string(forKey: "lastSeenWhatsNewVersion") ?? ""
            if !showOnboarding && seen != Self.currentVersion {
                showWhatsNew = true
            }
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewSheet(version: Self.currentVersion) {
                UserDefaults.standard.set(Self.currentVersion, forKey: "lastSeenWhatsNewVersion")
                showWhatsNew = false
            }
            .environment(\.appAccent, appState.accentOption.color)
            .preferredColorScheme(appState.appearanceMode.colorScheme)
        }
    }
}

// MARK: – What's New Sheet

struct WhatsNewEntry {
    let icon: String
    let color: Color
    let title: String
    let text: String
}

struct WhatsNewContent {
    let headline: String
    let subline: String?
    let slogan: String?
    let buttonLabel: String
    let entries: [WhatsNewEntry]
}

// MARK: — Add new versions here

private func whatsNewContent(for version: String) -> WhatsNewContent {
    switch version {
    case "3.0":
        return WhatsNewContent(
            headline: "Plink is now Klen.",
            subline: "[klɛn]",
            slogan: "Noted in a blink. Organized in Klen.",
            buttonLabel: "Get started with Klen",
            entries: [
                .init(icon: "checkmark.seal.fill", color: .green,
                      title: "A new name",
                      text: "Same app, same speed. Klen is the leanest way to capture tasks — now with a name that reflects it."),
                .init(icon: "arrow.triangle.2.circlepath", color: .orange,
                      title: "Nothing was lost",
                      text: "Your tasks, groups, and settings are fully intact."),
                .init(icon: "paintbrush.fill", color: .purple,
                      title: "New icon & identity",
                      text: "Inspired by Scandinavian precision. Clean, minimal, unmistakably Klen."),
            ]
        )
    default:
        return WhatsNewContent(
            headline: "What's new in \(version)",
            subline: nil,
            slogan: nil,
            buttonLabel: "Continue",
            entries: [
                .init(icon: "sparkles", color: .blue,
                      title: "Improvements & fixes",
                      text: "This update includes bug fixes and stability improvements."),
            ]
        )
    }
}

private struct WhatsNewSheet: View {
    let version: String
    let onDismiss: () -> Void
    @Environment(\.appAccent) private var accent

    var body: some View {
        let content = whatsNewContent(for: version)
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .padding(.top, 36)
                .padding(.bottom, 16)

            Text(content.headline)
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)

            if let subline = content.subline {
                Text(subline)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(content.entries, id: \.title) { entry in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: entry.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(entry.color)
                            .frame(width: 26)
                            .padding(.top, 1)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.system(size: 13, weight: .semibold))
                            Text(entry.text)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)

            Spacer(minLength: 20)

            if let slogan = content.slogan {
                Text(slogan)
                    .font(.system(size: 12, weight: .medium))
                    .italic()
                    .foregroundStyle(accent)
                    .padding(.bottom, 16)
            }

            Button {
                onDismiss()
            } label: {
                Text(content.buttonLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 220)
                    .padding(.vertical, 11)
                    .background(accent, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [])
            .padding(.bottom, 32)
        }
        .frame(width: 420)
    }
}
