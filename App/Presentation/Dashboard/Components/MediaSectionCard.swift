import SwiftUI

public struct MediaSectionCard: View {
    public let state: MediaSectionState
    public init(state: MediaSectionState) { self.state = state }
    public var body: some View {
        DisclosureGroup {
            mediaCounts("Google Photos", saved: state.googleSaved, remaining: state.googleRemaining, failed: state.googleFailed)
            mediaCounts("Telegram", saved: state.telegramSaved, remaining: state.telegramRemaining, failed: state.telegramFailed)
            if let activity = state.activeOperation { Text(activity).font(.footnote).foregroundStyle(.secondary) }
        } label: {
            HStack {
                Label(state.title, systemImage: state.title == "Videos" ? "video" : "photo")
                Spacer()
                Text(state.totalCount.map(String.init) ?? "Not scanned").monospacedDigit().foregroundStyle(.secondary)
            }
        }
    }
    private func mediaCounts(_ name: String, saved: Int?, remaining: Int?, failed: Int?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.subheadline.weight(.medium))
            Text("\(saved.map(String.init) ?? "—") saved · \(remaining.map(String.init) ?? "—") remaining")
                .font(.footnote).monospacedDigit().foregroundStyle(.secondary)
            if let failed, failed > 0 { Text("\(failed) not uploaded").font(.footnote).foregroundStyle(.red) }
        }.padding(.vertical, 4)
    }
}
