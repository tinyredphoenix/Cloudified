import SwiftUI

public struct ProviderStatusCard: View {
    public let state: ProviderCardState
    public let onSettingsTapped: () -> Void
    public init(state: ProviderCardState, onSettingsTapped: @escaping () -> Void = {}) {
        self.state = state; self.onSettingsTapped = onSettingsTapped
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(state.name).font(.headline)
                Spacer()
                if state.isConnected && !state.isEnabled { Text("Off").font(.caption).foregroundStyle(.secondary) }
            }
            if !state.isConnected {
                Button("Connect", action: onSettingsTapped)
            } else {
                Text(state.currentActivity).font(.subheadline).foregroundStyle(.secondary)
                if state.totalCount != nil {
                    Text(state.remainingOutOfTotalText).monospacedDigit()
                    Text(state.confirmedText).font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                }
                if let failed = state.failedCount, failed > 0 {
                    Text("\(failed) not uploaded").font(.footnote).foregroundStyle(.red)
                }
                if let waiting = state.waitingCount, waiting > 0 {
                    Text("\(waiting) waiting").font(.footnote).foregroundStyle(.secondary)
                }
                DisclosureGroup("Destination details") {
                    Text(state.connectionDescription).font(.footnote).privacySensitive()
                    if let date = state.lastConfirmedDate {
                        LabeledContent("Last saved", value: date.formatted()).font(.footnote)
                    }
                }
            }
        }.padding(.vertical, 4)
    }
}
