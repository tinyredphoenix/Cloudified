import SwiftUI

public struct CurrentTransferCard: View {
    public let transfer: CurrentTransferState?
    public init(transfer: CurrentTransferState?) { self.transfer = transfer }
    public var body: some View {
        if let current = transfer {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(current.provider).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(current.percentageText).monospacedDigit().foregroundStyle(.secondary)
                }
                Text(current.filename).font(.subheadline).lineLimit(1).truncationMode(.middle).privacySensitive()
                Text(current.activity).font(.footnote).foregroundStyle(.secondary)
                if let fraction = current.fractionCompleted { ProgressView(value: fraction) }
                Text(current.byteProgressText).font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                DisclosureGroup("Transfer details") {
                    Text(current.attemptText).font(.footnote)
                    if let component = current.componentOrPart { Text(component).font(.footnote) }
                    Text(current.mediaType).font(.footnote).foregroundStyle(.secondary)
                }
            }.padding(.vertical, 4)
        }
    }
}
