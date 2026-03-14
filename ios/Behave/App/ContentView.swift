import SwiftUI

struct ContentView: View {
    @StateObject private var consentManager = ConsentManager.shared
    @State private var selectedTab: Tab = .session

    enum Tab {
        case session, dashboard, coaching, settings
    }

    var body: some View {
        if consentManager.hasConsented {
            TabView(selection: $selectedTab) {
                SessionView()
                    .tabItem {
                        Label("Session", systemImage: "figure.stand")
                    }
                    .tag(Tab.session)

                DashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(Tab.dashboard)

                CoachingView()
                    .tabItem {
                        Label("Coach", systemImage: "brain.head.profile")
                    }
                    .tag(Tab.coaching)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(Tab.settings)
            }
        } else {
            OnboardingView(consentManager: consentManager)
        }
    }
}
