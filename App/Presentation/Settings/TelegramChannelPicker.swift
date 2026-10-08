import SwiftUI

public struct TelegramChannelPicker: View {
    @ObservedObject var environment: AppEnvironment
    let onChannelSelected: (Int64) -> Void
    
    @State private var channels: [TelegramChannel] = []
    @State private var isLoading = false
    @State private var hasMore = true
    @State private var discovery: TelegramChannelDiscovery?
    @State private var errorMessage: String?
    
    @State private var showManualEntry = false
    @State private var manualChannelID = ""
    
    public var body: some View {
        List {
            if !channels.isEmpty {
                Section(header: Text("Discovered Channels"), footer: Text("Channels you own with auto-delete turned off.")) {
                    ForEach(channels) { channel in
                        Button(action: {
                            onChannelSelected(channel.id)
                        }) {
                            HStack {
                                Text(channel.title)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    if hasMore {
                        Button(action: loadMore) {
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Load More Channels")
                            }
                        }
                        .disabled(isLoading)
                    }
                }
            } else if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Discovering channels...")
                        Spacer()
                    }
                }
            } else if !isLoading && channels.isEmpty {
                Section {
                    Text("No eligible channels found.")
                        .foregroundColor(.secondary)
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
                        .disabled((Int64(manualChannelID.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) == 0)
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Select Channel")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if discovery == nil {
                discovery = environment.createTelegramChannelDiscovery()
                loadMore()
            }
        }
    }
    
    private func loadMore() {
        guard let discovery = discovery, !isLoading, hasMore else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await discovery.discoverMore(limit: 50)
                // Filter out already added channels just in case
                let existingIds = Set(channels.map { $0.id })
                let newChannels = result.channels.filter { !existingIds.contains($0.id) }
                
                await MainActor.run {
                    channels.append(contentsOf: newChannels)
                    hasMore = result.hasMore
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load channels: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}
