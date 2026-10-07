import SwiftUI
import Combine

/// Presentation coordinator and environment for the Cloudified application.
/// Provides reactive UI state to SwiftUI views and acts as the composition root
/// that will bind to Packages/CloudifiedCore in Phase 5.
@MainActor
public final class AppEnvironment: ObservableObject {
    @Published public var selectedTab: AppTab = .dashboard
    @Published public var dashboardState: DashboardViewState
    @Published public var notUploadedState: NotUploadedViewState
    @Published public var logsState: LogsViewState
    @Published public var settingsState: SettingsViewState

    public init(
        dashboardState: DashboardViewState = DashboardViewState(),
        notUploadedState: NotUploadedViewState = NotUploadedViewState(),
        logsState: LogsViewState = LogsViewState(),
        settingsState: SettingsViewState = SettingsViewState()
    ) {
        self.dashboardState = dashboardState
        self.notUploadedState = notUploadedState
        self.logsState = logsState
        self.settingsState = settingsState
    }

    /// Action invoked when the user taps "Back Up" on the Dashboard.
    public func requestBackup() {
        // Honest validation: without real connected destinations or photo permissions,
        // we do not simulate a backup or manufacture progress.
        if !dashboardState.canStartBackup {
            dashboardState.waitingOrErrorReason = "Connect Google Photos or Telegram in Settings to start."
            dashboardState.overallState = .needsAttention(reason: "No destinations connected")
        } else {
            // Core engine integration will be wired in Phase 5.
            dashboardState.waitingOrErrorReason = "Engine connection pending Phase 5 integration."
        }
    }

    /// Action invoked when the user pauses an active backup.
    public func requestPause() {
        dashboardState.overallState = .paused
    }

    /// Action invoked when the user resumes a paused backup.
    public func requestResume() {
        dashboardState.overallState = .idle
    }

    /// Action invoked when retrying a specific failed asset from the Not Uploaded screen.
    public func retryItem(_ item: NotUploadedItem) {
        // Will be routed to the durable retry queue in CloudifiedCore.
    }
}
