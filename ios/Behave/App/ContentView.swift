import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .session

    enum Tab {
        case session, dashboard, coaching, settings
    }

    var body: some View {
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
                    Label("Coach", systemImage: "bubble.left.and.text.bubble.right")
                }
                .tag(Tab.coaching)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
    }
}

#Preview {
    ContentView()
}
