import SwiftUI

public struct OverallActivityCard: View {
    public let state: OverallActivityState
    public let waitingReason: String?
    public let libraryTotal: Int?
    public let savedToBoth: Int?
    public let permissionScope: String
    public let scanDate: Date?
    public let canPause: Bool
    public let canResume: Bool
    public let canStart: Bool
    public let onBackUp: () -> Void
    public let onPause: () -> Void
    public let onResume: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(state.title).font(.title2.weight(.semibold))
            if let total = libraryTotal, let saved = savedToBoth {
                Text("\(saved) of \(total) saved to both")
                    .monospacedDigit().foregroundStyle(.secondary)
            } else if let total = libraryTotal {
                Text("\(total) accessible items").monospacedDigit().foregroundStyle(.secondary)
            }
            if let reason = waitingReason, !reason.isEmpty {
                DisclosureGroup("Status details") { Text(reason).font(.footnote).foregroundStyle(.secondary) }
            }
            if canPause {
                Button("Pause backup", action: onPause).buttonStyle(.bordered).controlSize(.large)
            } else if canResume {
                Button("Resume backup", action: onResume).buttonStyle(.borderedProminent).controlSize(.large)
            } else {
                Button("Back Up", action: onBackUp).buttonStyle(.borderedProminent).controlSize(.large).disabled(!canStart)
            }
        }.padding(.vertical, 8)
    }
}
