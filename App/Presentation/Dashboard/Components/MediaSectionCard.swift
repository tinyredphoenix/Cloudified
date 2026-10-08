import SwiftUI

public struct MediaSectionCard: View {
    public let state: MediaSectionState
    public init(state: MediaSectionState) { self.state = state }

    public var body: some View {
        NavigationLink(destination: detailsView) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(UIColor.secondarySystemFill))
                        .frame(width: 40, height: 40)
                    Image(systemName: state.title == "Videos" ? "video.fill" : "photo.fill")
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.body.weight(.medium))

                    if let total = state.totalCount {
                        Text("\(total) items")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    } else {
                        Text("Not scanned")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var detailsView: some View {
        List {
            Section {
                Text(state.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section("Google Photos") {
                statRow(title: "Saved", value: state.googleSaved)
                statRow(title: "Remaining", value: state.googleRemaining)
                if let failed = state.googleFailed, failed > 0 {
                    statRow(title: "Failed", value: failed, isError: true)
                }
            }

            Section("Telegram") {
                statRow(title: "Saved", value: state.telegramSaved)
                statRow(title: "Remaining", value: state.telegramRemaining)
                if let failed = state.telegramFailed, failed > 0 {
                    statRow(title: "Failed", value: failed, isError: true)
                }
            }

            if let active = state.activeOperation {
                Section("Activity") {
                    Text(active).font(.footnote).foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(state.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statRow(title: String, value: Int?, isError: Bool = false) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value.map(String.init) ?? "—")
                .monospacedDigit()
                .foregroundColor(isError ? .red : .secondary)
        }
    }
}
