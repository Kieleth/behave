import SwiftUI
import SwiftData

@main
struct BehaveApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            LocalSession.self,
            LocalEvent.self,
            LocalSettings.self,
        ])
    }
}
