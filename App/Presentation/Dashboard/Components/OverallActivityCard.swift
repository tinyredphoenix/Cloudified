import SwiftUI

public struct OverallActivityCard: View {
    public let state: OverallActivityState
    public let waitingReason: String?
    public let libraryTotal: Int?
    public let savedToBoth: Int?
    public let permissionScope: String
    public let scanDate: Date?
    public let onBackUp: () -> Void
    public let onPause: () -> Void
    public let onResume: () -> Void

    public init(
        state: OverallActivityState,
        waitingReason: String? = nil,
        libraryTotal: Int? = nil,
        savedToBoth: Int? = nil,
        permissionScope: String = "Not determined",
        scanDate: Date? = nil,
        onBackUp: @escaping () -> Void = {},
        onPause: @escaping () -> Void = {},
        onResume: @escaping () -> Void = {}
    ) {
        self.state = state
        self.waitingReason = waitingReason
        self.libraryTotal = libraryTotal
        self.savedToBoth = savedToBoth
        self.permissionScope = permissionScope
        self.scanDate = scanDate
        self.onBackUp = onBackUp
        self.onPause = onPause
        self.onResume = onResume
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header status
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(statusColor)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let reason = waitingReason, !reason.isEmpty {
                        Text(reason)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // State badge
                Text(badgeText)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .foregroundColor(statusColor)
                    .clipShape(Capsule())
            }

            Divider()

            // Library scope and counts
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Library Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(libraryTotal.map(String.init) ?? "--")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved to Both")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(savedToBoth.map(String.init) ?? "--")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Photos Access")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(permissionScope)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                }
            }

            if let date = scanDate {
                HStack(spacing: 4) {
                    Text("Last scanned:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(date, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(date, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Controls
            HStack(spacing: 10) {
                Button(action: onBackUp) {
                    Label("Back Up", systemImage: "arrow.clockwise.icloud.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)

                if state == .uploading || state == .preparing || state == .checking {
                    Button(action: onPause) {
                        Label("Pause", systemImage: "pause.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                } else if state == .paused {
                    Button(action: onResume) {
                        Label("Resume", systemImage: "play.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var iconName: String {
        switch state {
        case .notScanned, .idle:
            return "clock"
        case .scanning:
            return "magnifyingglass"
        case .preparing, .checking:
            return "gearshape.2"
        case .uploading, .finalizing:
            return "arrow.up.circle.fill"
        case .waiting:
            return "hourglass"
        case .paused:
            return "pause.circle.fill"
        case .complete:
            return "checkmark.circle.fill"
        case .needsAttention:
            return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch state {
        case .notScanned, .idle:
            return .secondary
        case .scanning, .preparing, .checking:
            return .blue
        case .uploading, .finalizing:
            return .accentColor
        case .waiting:
            return .orange
        case .paused:
            return .secondary
        case .complete:
            return .green
        case .needsAttention:
            return .red
        }
    }

    private var badgeText: String {
        switch state {
        case .notScanned:
            return "Not Scanned"
        case .idle:
            return "Idle"
        case .scanning:
            return "Scanning"
        case .preparing:
            return "Preparing"
        case .checking:
            return "Checking"
        case .uploading:
            return "Uploading"
        case .finalizing:
            return "Finalizing"
        case .waiting:
            return "Waiting"
        case .paused:
            return "Paused"
        case .complete:
            return "Complete"
        case .needsAttention:
            return "Action Needed"
        }
    }
}
