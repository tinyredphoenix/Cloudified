import SwiftUI

public struct CurrentTransferCard: View {
    public let transfer: CurrentTransferState?
    public init(transfer: CurrentTransferState?) { self.transfer = transfer }
    
    public var body: some View {
        if let current = transfer {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: current.provider.contains("Google") ? "photo.on.rectangle.angled" : "paperplane.fill")
                        .foregroundColor(.accentColor)
                        .font(.caption)
                    Text(current.provider)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(current.percentageText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                
                Text(current.filename)
                    .font(.footnote)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .privacySensitive()
                
                if let fraction = current.fractionCompleted {
                    ProgressView(value: fraction)
                        .tint(.blue)
                }
                
                HStack {
                    Text(current.activity)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(current.byteProgressText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 6)
        }
    }
}
