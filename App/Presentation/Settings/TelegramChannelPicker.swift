import SwiftUI
import CloudifiedCore

public struct TelegramChannelPicker: View {
    @ObservedObject var environment: AppEnvironment
    let onMapped: () -> Void
    @State private var channels: [TelegramChannel] = []
    @State private var checked = 0
    @State private var candidateCount = 0
    @State private var hasMore = true
    @State private var isLoading = false
    @State private var isMapping = false
    @State private var query = ""
    @State private var activeQuery = ""
    @State private var discovery: TelegramChannelDiscovery?
    @State private var errorMessage: String?
    @State private var retryChannelID: Int64?
    @State private var selection: TelegramChannelSelection?
    @State private var selectionContext: TelegramDiscoveryContext?
    @State private var activeTask: Task<Void, Never>?
    @State private var mappingTask: Task<Void, Never>?
    @State private var generation = UUID()
    @State private var isVisible = false
    @State private var showManualEntry = false
    @State private var manualChannelID = ""

    public init(environment: AppEnvironment, onMapped: @escaping () -> Void) {
        self.environment = environment
        self.onMapped = onMapped
    }
    private var context: TelegramDiscoveryContext { environment.telegramDiscoveryContext }
    private var available: Bool {
        context.available && [.readyForChannel, .connected].contains(environment.settingsState.telegramAuthStep)
    }

    public var body: some View {
        List {
            if let selection {
                Section("Confirm destination") {
                    LabeledContent("Account", value: selection.accountName).privacySensitive()
                    LabeledContent("Account ID", value: String(selection.accountID)).privacySensitive()
                    LabeledContent("Channel", value: selection.channel.title).privacySensitive()
                    LabeledContent("Channel ID", value: String(selection.channel.id)).privacySensitive()
                    Text("Private channel you own · auto-delete off").font(.footnote).foregroundStyle(.secondary)
                    Button("Use this channel", action: mapSelection).disabled(isMapping || !available)
                    Button("Choose another channel") { self.selection = nil; selectionContext = nil }
                        .disabled(isMapping)
                }
            }
            if isMapping {
                Section { ProgressView("Checking destination and existing uploads…") }
            }
            if let errorMessage {
                Section("Connection issue") {
                    Text(errorMessage).foregroundStyle(.red)
                    if selection == nil {
                        Button("Retry") {
                            if let retryChannelID { review(retryChannelID) } else { loadMore() }
                        }.disabled(isLoading || !available)
                    }
                }
            }
            if selection == nil {
                Section {
                    TextField("Channel title", text: $query)
                        .autocorrectionDisabled()
                        .onSubmit { restart() }
                    Button("Search Telegram") { restart() }
                        .disabled(isLoading || !available || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if !activeQuery.isEmpty {
                        Button("Show recent chats") { query = ""; restart() }.disabled(isLoading || !available)
                    }
                } footer: {
                    Text("Search channels in your Telegram account. Up to 50 matches are checked; use a more specific title for other results.")
                }
                Section {
                    ForEach(channels) { channel in
                        Button { review(channel.id) } label: {
                            HStack {
                                Text(channel.title).foregroundStyle(.primary).privacySensitive()
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                        }.disabled(isLoading || !available)
                    }
                    if isLoading { ProgressView("Checking channels…") }
                    if channels.isEmpty && !isLoading {
                        Text("No eligible channel in the checked results.").foregroundStyle(.secondary)
                    }
                    if hasMore {
                        Button("Check more results", action: loadMore).disabled(isLoading || !available)
                    }
                    if !available {
                        Text("Finish signing in or the current account operation before selecting a channel.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } header: { Text(activeQuery.isEmpty ? "Recent chats" : "Search results") }
                  footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(checked) of \(candidateCount) loaded candidates checked").monospacedDigit()
                        Text(activeQuery.isEmpty
                            ? "Recent discovery checks up to 50 main and 50 archived chats, not your entire account. Search by title or use a channel ID for other channels."
                            : "Only private channels you own with auto-delete off are offered. Search results may be incomplete.")
                    }
                }
                Section("Advanced") {
                    DisclosureGroup("Use a channel ID", isExpanded: $showManualEntry) {
                        TextField("Numeric channel ID", text: $manualChannelID)
                            .keyboardType(.numbersAndPunctuation)
                        Button("Check channel") {
                            if let id = Int64(manualChannelID.trimmingCharacters(in: .whitespacesAndNewlines)) { review(id) }
                        }.disabled(isLoading || !available || (Int64(manualChannelID.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) == 0)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Select channel")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isMapping)
        .interactiveDismissDisabled(isMapping)
        .onAppear { isVisible = true; restart() }
        .onChange(of: context) { if !isMapping { restart() } }
        .onDisappear {
            isVisible = false; generation = UUID(); activeTask?.cancel(); activeTask = nil
            discovery = nil; isLoading = false; selection = nil; selectionContext = nil
            channels = []; manualChannelID = ""; query = ""; mappingTask?.cancel(); mappingTask = nil
        }
    }

    private func restart() {
        guard isVisible, !isMapping else { return }
        activeTask?.cancel(); generation = UUID(); discovery = nil
        channels = []; checked = 0; candidateCount = 0; hasMore = true
        selection = nil; selectionContext = nil; errorMessage = nil; retryChannelID = nil; isLoading = false
        activeQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if available { loadMore() }
    }
    private func loadMore() {
        guard isVisible, available, !isLoading, !isMapping else { return }
        retryChannelID = nil
        runRead({ try await $0.discoverMore() }) { page in
            channels = page.channels; checked = page.checked
            candidateCount = page.candidateCount; hasMore = page.hasMore
        }
    }
    private func review(_ id: Int64) {
        guard available, !isMapping else { return }
        retryChannelID = id
        runRead({ try await $0.selection(chatID: id) }) { result in
            selection = result; selectionContext = context
        }
    }
    private func runRead<Result: Sendable>(
        _ operation: @escaping @Sendable (TelegramChannelDiscovery) async throws -> Result,
        apply: @escaping @MainActor (Result) -> Void
    ) {
        let previous = activeTask; previous?.cancel()
        let id = UUID(); generation = id
        let capturedContext = context
        isLoading = true; errorMessage = nil
        activeTask = Task {
            // Join the prior caller so actor operations cannot overlap on reentry.
            await previous?.value
            guard isCurrent(id, capturedContext) else { return }
            defer { if generation == id { isLoading = false; activeTask = nil } }
            do {
                if discovery == nil { discovery = try environment.createTelegramChannelDiscovery(query: activeQuery) }
                guard let discovery else { return }
                let result = try await operation(discovery)
                guard isCurrent(id, capturedContext) else { return }
                apply(result)
            } catch is CancellationError { }
            catch {
                guard isCurrent(id, capturedContext) else { return }
                let safe = ProviderSupport.safe(error, domain: .tdlib)
                if let discovery {
                    let page = await discovery.snapshot()
                    guard isCurrent(id, capturedContext) else { return }
                    channels = page.channels; checked = page.checked
                    candidateCount = page.candidateCount; hasMore = page.hasMore
                }
                errorMessage = FailureExplanation.message(safe)
                await environment.recordTelegramDiscoveryFailure(safe)
            }
        }
    }
    private func isCurrent(_ id: UUID, _ capturedContext: TelegramDiscoveryContext) -> Bool {
        !Task.isCancelled && isVisible && generation == id && context == capturedContext
    }
    private func mapSelection() {
        guard let selection, selectionContext == context, available, !isMapping else { return }
        let previous = activeTask; previous?.cancel()
        let capturedContext = context
        generation = UUID(); discovery = nil; isLoading = false
        isMapping = true; errorMessage = nil
        mappingTask = Task {
            defer { isMapping = false; mappingTask = nil }
            do {
                await previous?.value
                try Task.checkCancellation()
                guard isVisible, context == capturedContext else { throw CancellationError() }
                try await environment.mapTelegramChannel(chatID: selection.channel.id)
                try Task.checkCancellation()
                if isVisible { onMapped() }
            } catch is CancellationError {
                if !Task.isCancelled && isVisible && context != capturedContext {
                    self.selection = nil; selectionContext = nil
                    channels = []; checked = 0; candidateCount = 0; hasMore = true
                    errorMessage = FailureExplanation.message(SafeFailure(.authentication, domain: .tdlib, cause: .accountChanged))
                }
            }
            catch {
                if isVisible {
                    errorMessage = FailureExplanation.message(ProviderSupport.safe(error, domain: .tdlib))
                    self.selection = nil; selectionContext = nil
                    channels = []; checked = 0; candidateCount = 0; hasMore = true
                }
            }
        }
    }
}
