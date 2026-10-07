import SwiftUI

public struct DashboardView: View {
    @ObservedObject public var environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Unconnected destinations warning banner
                    if !environment.dashboardState.googleStatus.isConnected && !environment.dashboardState.telegramStatus.isConnected {
                        unconnectedNoticeBanner
                    }

                    // 1. Overall Activity & Controls
                    OverallActivityCard(
                        state: environment.dashboardState.overallState,
                        waitingReason: environment.dashboardState.waitingOrErrorReason,
                        libraryTotal: environment.dashboardState.accessibleLibraryTotal,
                        savedToBoth: environment.dashboardState.savedToBothCount,
                        permissionScope: environment.dashboardState.permissionScopeDescription,
                        scanDate: environment.dashboardState.scanTimestamp,
                        onBackUp: {
                            environment.requestBackup()
                        },
                        onPause: {
                            environment.requestPause()
                        },
                        onResume: {
                            environment.requestResume()
                        }
                    )

                    // 2. Active Transfer (Current file, bytes, part, attempt)
                    CurrentTransferCard(
                        transfer: environment.dashboardState.currentTransfer
                    )

                    // 3. Independent Destinations (Google & Telegram)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Destinations")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("Both enabled destinations run concurrently. Neither waits for the other to finish.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ProviderStatusCard(
                            state: environment.dashboardState.googleStatus,
                            onSettingsTapped: {
                                environment.selectedTab = .settings
                            }
                        )

                        ProviderStatusCard(
                            state: environment.dashboardState.telegramStatus,
                            onSettingsTapped: {
                                environment.selectedTab = .settings
                            }
                        )
                    }

                    // 4. Separate Media Breakdown (Photos & Videos)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Media Breakdown")
                            .font(.headline)
                            .foregroundColor(.primary)

                        MediaSectionCard(
                            state: environment.dashboardState.photosSection
                        )

                        MediaSectionCard(
                            state: environment.dashboardState.videosSection
                        )
                    }

                    // 5. Session Metrics
                    sessionMetricsCard
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        environment.selectedTab = .settings
                    } label: {
                        Image(systemName: "gearshape")
                            .accessibilityLabel("Settings")
                    }
                }
            }
        }
    }

    private var unconnectedNoticeBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                Text("No Destinations Connected")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
            }

            Text("Connect your Google Photos and/or Telegram accounts in Settings to start backing up.")
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                environment.selectedTab = .settings
            } label: {
                Text("Configure Destinations in Settings")
                    .font(.caption.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(12)
    }

    private var sessionMetricsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session Details")
                .font(.headline)
                .foregroundColor(.primary)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Session Saved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(environment.dashboardState.confirmedThisSessionCount.map(String.init) ?? "--")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Transfer Speed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let speed = environment.dashboardState.currentTransferSpeedBytesPerSec {
                        Text("\(ByteCountFormatter.string(fromByteCount: speed, countStyle: .binary))/s")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                    } else {
                        Text("-- KB/s")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Estimated Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let eta = environment.dashboardState.estimatedRemainingTimeSeconds {
                        Text(formatDuration(eta))
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                    } else {
                        Text("--")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "--"
    }
}
