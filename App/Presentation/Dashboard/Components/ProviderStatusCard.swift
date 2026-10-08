import SwiftUI

public struct ProviderStatusCard: View {
    public let state: ProviderCardState
    public let onSettingsTapped: () -> Void
    
    public init(state: ProviderCardState, onSettingsTapped: @escaping () -> Void = {}) {
        self.state = state
        self.onSettingsTapped = onSettingsTapped
    }
    
    public var body: some View {
        Button(action: onSettingsTapped) {
            HStack(spacing: 16) {
                // Provider Icon
                ZStack {
                    Circle()
                        .fill(state.isConnected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: providerIcon)
                        .font(.title2)
                        .foregroundColor(state.isConnected ? .accentColor : .gray)
                }
                
                // Details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(state.name)
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                        
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
                        Text("Not connected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        if state.totalCount != nil {
                            Text(state.remainingOutOfTotalText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        } else {
                            Text(state.currentActivity)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Show quick errors
                        if let failed = state.failedCount, failed > 0 {
                            Text("\(failed) failed")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
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
