import SwiftUI

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
                    Label("Issues", systemImage: "exclamationmark.triangle.fill")
                }
                .tag(AppTab.notUploaded)

            LogsView(environment: environment)
                .tabItem {
                    Label("Logs", systemImage: "doc.text.fill")
                }
                .tag(AppTab.logs)

            SettingsView(environment: environment)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
        }
        .tint(.blue)
    }
}
