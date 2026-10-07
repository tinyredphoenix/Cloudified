import SwiftUI

/// Main entry point for the Cloudified native iOS application.
@main
struct CloudifiedApp: App {
    @StateObject private var environment = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView(environment: environment)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                // App became active; UI refreshes from durable state when wired in Phase 5.
                break
            case .inactive:
                break
            case .background:
                // Memory cleanup and background lease protection when backgrounded.
                break
            @unknown default:
                break
            }
        }
    }
}
