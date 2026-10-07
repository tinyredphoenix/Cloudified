import SwiftUI

public struct MediaSectionCard: View {
    public let state: MediaSectionState

    public init(state: MediaSectionState) {
        self.state = state
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(.headline)
                        .foregroundColor(.accentColor)
                        .accessibilityHidden(true)

                    Text(state.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("Total:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(state.totalCount.map(String.init) ?? "--")
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                }
            }

            Text(state.subtitle)
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            // Google breakdown
            VStack(alignment: .leading, spacing: 4) {
                Text("Google Photos")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    metricBadge(label: "Saved", value: state.googleSaved)
                    metricBadge(label: "Remaining", value: state.googleRemaining)
                    metricBadge(label: "Failed", value: state.googleFailed, isFailure: true)
                }
            }

            // Telegram breakdown
            VStack(alignment: .leading, spacing: 4) {
                Text("Telegram")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    metricBadge(label: "Saved", value: state.telegramSaved)
                    metricBadge(label: "Remaining", value: state.telegramRemaining)
                    metricBadge(label: "Failed", value: state.telegramFailed, isFailure: true)
                }
            }

            if let op = state.activeOperation {
                Divider()
                HStack {
                    Text("Status:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(op)
                        .font(.caption)
                        .foregroundColor(.primary)
                    Spacer()
                    if let progress = state.byteProgress {
                        Text(progress)
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func metricBadge(label: String, value: Int?, isFailure: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value.map(String.init) ?? "--")
                .font(.caption2.bold())
                .foregroundColor(isFailure && (value ?? 0) > 0 ? .red : .primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(6)
    }

    private var iconName: String {
        state.title.localizedCaseInsensitiveContains("Video") ? "video.fill" : "photo.fill"
    }
}
