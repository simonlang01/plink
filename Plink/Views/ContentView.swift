import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showOnboarding = !FileManager.default.fileExists(
        atPath: PersistenceController.dataDirectory.appendingPathComponent(".onboarding_complete").path
    )

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
        .preferredColorScheme(appState.appearanceMode.colorScheme)
        .environment(\.appAccent, appState.accentOption.color)
    }
}
