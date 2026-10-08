import SwiftUI

public struct ProviderStatusCard: View {
    public let state: ProviderCardState
    public let onSettingsTapped: () -> Void

    public init(
        state: ProviderCardState,
        onSettingsTapped: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onSettingsTapped = onSettingsTapped
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Provider name + status chips
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: providerIcon)
                        .font(.headline)
                        .foregroundColor(providerAccent)
                        .accessibilityHidden(true)

                    Text(state.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                Spacer()

                if !state.isEnabled {
                    Text("Disabled")
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundColor(.secondary)
                        .clipShape(Capsule())
                } else if state.isConnected {
                    Text("Connected")
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                } else {
                    Button(action: onSettingsTapped) {
                        Text("Not connected")
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                }
            }

            // Connection identity
            HStack(spacing: 6) {
                Text("Destination:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(state.connectionDescription)
                    .font(.caption.bold())
                    .foregroundColor(.primary)
            }

            // Current Activity
            HStack(spacing: 6) {
                Text("Activity:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(state.currentActivity)
                    .font(.caption)
                    .foregroundColor(.primary)
            }

            Divider()

            // Counts: remaining out of total, and confirmed
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remaining")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(state.remainingOutOfTotalText)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Confirmed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(state.confirmedText)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                }
            }

            HStack {
                Text("Failed: \(state.failedCount.map(String.init) ?? "—")")
                Spacer()
                Text("Waiting: \(state.waitingCount.map(String.init) ?? "—")")
            }.font(.caption).foregroundStyle(.secondary)
            // Last confirmed upload date
            if let lastConfirmed = state.lastConfirmedDate {
                HStack(spacing: 4) {
                    Text("Last confirmed upload:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(lastConfirmed, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(lastConfirmed, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var providerIcon: String {
        if state.name.localizedCaseInsensitiveContains("Google") {
            return "photo.stack.fill"
        } else {
            return "paperplane.fill"
        }
    }

    private var providerAccent: Color {
        if state.name.localizedCaseInsensitiveContains("Google") {
            return .red
        } else {
            return .blue
        }
    }
}
