import SwiftUI

public struct CurrentTransferCard: View {
    public let transfer: CurrentTransferState?

    public init(transfer: CurrentTransferState?) {
        self.transfer = transfer
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.and.down.circle.fill")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                        .accessibilityHidden(true)

                    Text("Active Transfer")
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                Spacer()

                if let current = transfer {
                    Text(current.attemptText)
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                } else {
                    Text("Unavailable")
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundColor(.secondary)
                        .clipShape(Capsule())
                }
            }

            Divider()

            if let current = transfer {
                // Active file details
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(current.filename)
                                .font(.subheadline.bold())
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundColor(.primary)

                            HStack(spacing: 8) {
                                Text(current.mediaType)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Destination: \(current.provider)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Text(current.percentageText)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                    }

                    // Progress bar
                    if let fraction = current.fractionCompleted {
                        ProgressView(value: fraction)
                            .progressViewStyle(.linear)
                            .tint(.accentColor)
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                    }

                    // Bytes progress & Component/Part
                    HStack {
                        Text(current.byteProgressText)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        if let component = current.componentOrPart {
                            Text(component)
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                // Honest unpopulated state
                VStack(alignment: .center, spacing: 6) {
                    Text("No active transfer")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("File-level progress and attempt counts appear here during backup.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
