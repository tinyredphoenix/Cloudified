import SwiftUI

public struct ProviderStatusCard: View {
    public let state: ProviderCardState
    public let onSettingsTapped: () -> Void

    public init(state: ProviderCardState, onSettingsTapped: @escaping () -> Void = {}) {
        self.state = state
        self.onSettingsTapped = onSettingsTapped
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Provider Icon
                ZStack {
                    Circle()
                        .fill(state.isConnected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.1))
                        .frame(width: 36, height: 36)

                    Image(systemName: providerIcon)
                        .foregroundColor(state.isConnected ? .accentColor : .gray)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(state.name).font(.headline)
                        if state.isConnected && !state.isEnabled {
                            Text("Off")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                                .foregroundColor(.secondary)
                        }
                    }
                    if !state.isConnected {
                        Text("Not connected").font(.subheadline).foregroundColor(.secondary)
                    } else {
                        Text(state.currentActivity).font(.subheadline).foregroundColor(.secondary)
                    }
                }
                Spacer()
                if !state.isConnected {
                    Button("Connect", action: onSettingsTapped)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            if state.isConnected {
                if state.totalCount != nil {
                    HStack {
                        Text(state.remainingOutOfTotalText).monospacedDigit()
                        Spacer()
                        Text(state.confirmedText).font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }

                HStack {
                    if let failed = state.failedCount, failed > 0 {
                        Text("\(failed) not uploaded").font(.footnote).foregroundStyle(.red)
                    }
                    Spacer()
                    if let waiting = state.waitingCount, waiting > 0 {
                        Text("\(waiting) waiting").font(.footnote).foregroundStyle(.orange)
                    }
                }

                DisclosureGroup("Destination details") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.connectionDescription).font(.footnote).privacySensitive()
                        if let date = state.lastConfirmedDate {
                            LabeledContent("Last saved", value: date.formatted()).font(.footnote)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var providerIcon: String {
        if state.name.contains("Google") {
            return "photo.on.rectangle.angled"
        } else if state.name.contains("Telegram") {
            return "paperplane.fill"
        }
        return "cloud.fill"
    }
}
