import SwiftUI

/// Top-level application tabs.
public enum AppTab: Hashable, Sendable {
    case dashboard
    case notUploaded
    case logs
    case settings
}

public struct RootTabView: View {
    @ObservedObject public var environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        TabView(selection: $environment.selectedTab) {
            DashboardView(environment: environment)
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }
                .tag(AppTab.dashboard)

            NotUploadedView(environment: environment)
                .tabItem {
                    Label("Not Uploaded", systemImage: "exclamationmark.triangle")
                }
                .tag(AppTab.notUploaded)

            LogsView(environment: environment)
                .tabItem {
                    Label("Logs", systemImage: "doc.text")
                }
                .tag(AppTab.logs)

            SettingsView(environment: environment)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
    }
}
