import SwiftUI
import CloudifiedCore

public struct TelegramChannelPicker: View {
    @ObservedObject var environment: AppEnvironment
    let onChannelSelected: (Int64) -> Void

    @State private var channels: [TelegramChannel] = []
    @State private var isLoading = false
    @State private var hasMore = true
    @State private var discovery: TelegramChannelDiscovery?
    @State private var errorMessage: String?
    @State private var activeTask: Task<Void, Never>?

    @State private var showManualEntry = false
    @State private var manualChannelID = ""

    public var body: some View {
        List {
            Section(header: Text("Discovered Channels"), footer: Text("Channels you own with auto-delete turned off.")) {
                if channels.isEmpty && !isLoading && errorMessage == nil {
                    Text(hasMore ? "Ready to search for channels." : "No eligible channels found.")
                        .foregroundColor(.secondary)
                }

                ForEach(channels) { channel in
                    Button(action: {
                        onChannelSelected(channel.id)
                    }) {
                        HStack {
                            Text(channel.title).privacySensitive()
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .disabled(environment.settingsState.isConnectingTelegram || environment.settingsState.isSettlingTelegram)
                }

                if hasMore {
                    Button(action: loadMore) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text(channels.isEmpty ? "Search Channels" : "Load More Channels")
                        }
                    }
                    .disabled(isLoading || environment.settingsState.isConnectingTelegram)
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)

                    if hasMore && !isLoading {
                        Button("Retry") { loadMore() }
                    }
                }
            }

            Section(header: Text("Advanced")) {
                DisclosureGroup("Manual Channel Entry", isExpanded: $showManualEntry) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Enter the numeric ID of a private channel. Auto-delete must be off.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("Channel Chat ID", text: $manualChannelID)
                            .keyboardType(.numbersAndPunctuation)
                            .textFieldStyle(.roundedBorder)

                        Button("Use this channel") {
                            if let chatID = Int64(manualChannelID.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                onChannelSelected(chatID)
                            }
                        }
                        .disabled((Int64(manualChannelID.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) == 0 || environment.settingsState.isConnectingTelegram)
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Select Channel")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if discovery == nil {
                discovery = environment.createTelegramChannelDiscovery()
                loadMore()
            }
        }
        .onDisappear {
            activeTask?.cancel()
            activeTask = nil
            discovery?.reset()
        }
    }

    private func loadMore() {
        guard let discovery = discovery, !isLoading, hasMore else { return }
        isLoading = true
        errorMessage = nil
        activeTask?.cancel()

        activeTask = Task {
            do {
                try Task.checkCancellation()
                let result = try await discovery.discoverMore(limit: 50)
                try Task.checkCancellation()

                let existingIds = Set(channels.map { $0.id })
                let newChannels = result.channels.filter { !existingIds.contains($0.id) }

                if !Task.isCancelled {
                    channels.append(contentsOf: newChannels)
                    hasMore = result.hasMore
                    isLoading = false
                }
            } catch is CancellationError {
                // Cancelled, do nothing
            } catch {
                if !Task.isCancelled {
                    let safeError = ProviderSupport.safe(error, domain: .tdlib)
                    errorMessage = FailureExplanation.message(safeError)
                    isLoading = false
                }
            }
        }
    }
}
