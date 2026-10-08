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
        VStack(spacing: 20) {
            // Icon
            iconForState
                .font(.system(size: 48, weight: .light))
                .padding(.top, 12)
            
            // Title
            VStack(spacing: 6) {
                Text(state.title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                
                if let total = libraryTotal, let saved = savedToBoth, total > 0 {
                    let progress = Double(saved) / Double(total)
                    ProgressView(value: progress)
                        .tint(.blue)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 4)
                    
                    Text("\(saved) of \(total) items saved securely")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else if let total = libraryTotal {
                    Text("\(total) accessible items")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            
            if let reason = waitingReason, !reason.isEmpty {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Primary Action Button
            actionButton
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var iconForState: some View {
        switch state {
        case .completed:
            Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
        case .runningPhotos, .runningVideos, .runningBoth:
            Image(systemName: "arrow.up.circle.fill").foregroundColor(.blue)
        case .paused:
            Image(systemName: "pause.circle.fill").foregroundColor(.yellow)
        case .needsAttention:
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
        default:
            Image(systemName: "cloud.fill").foregroundColor(.blue)
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        if canPause {
            Button(action: onPause) {
                Label("Pause Backup", systemImage: "pause.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.orange)
        } else if canResume {
            Button(action: onResume) {
                Label("Resume Backup", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else {
            Button(action: onBackUp) {
                Label("Back Up", systemImage: "arrow.up.cloud")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canStart)
        }
    }
}
