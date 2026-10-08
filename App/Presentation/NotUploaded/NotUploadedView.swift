import SwiftUI
import Photos
import CloudifiedCore
public struct NotUploadedView: View {
    @ObservedObject public var environment: AppEnvironment
    @State private var selectedItemForDetails: NotUploadedItem?

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    DisclosureGroup("Filters") { filtersHeader }
                }
                Section("Items needing attention") {
                    if environment.notUploadedState.filteredItems.isEmpty {
                        if environment.notUploadedState.isLoading { ProgressView("Loading items…") }
                        else { emptyStateView }
                    }
                    ForEach(environment.notUploadedState.filteredItems) { item in
                        NotUploadedRow(item: item) {
                            selectedItemForDetails = item
                        }
                    }
                }
                Section {
                    if let error = environment.notUploadedState.pageError {
                        Text(error).foregroundStyle(.red)
                        Button("Retry page") { environment.reloadFailures() }.disabled(environment.notUploadedState.isLoading)
                    }
                    if environment.notUploadedState.isLoading && !environment.notUploadedState.filteredItems.isEmpty {
                        ProgressView("Loading items…")
                    }
                    if environment.notUploadedState.hasOlder {
                        Button("Older items") { environment.olderFailures() }.disabled(environment.notUploadedState.isLoading)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .onAppear { environment.reloadFailures() }
            .onChange(of: environment.notUploadedState.destinationFilter) { environment.reloadFailures() }
            .onChange(of: environment.notUploadedState.mediaTypeFilter) { environment.reloadFailures() }
            .onChange(of: environment.notUploadedState.statusFilter) { environment.reloadFailures() }
            .refreshable { environment.reloadFailures() }
            .navigationTitle("Not uploaded")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { environment.reloadFailures() } label: {
                        Label("Newest items", systemImage: "arrow.clockwise")
                    }
                }
            }
            .sheet(item: $selectedItemForDetails) { item in
                NotUploadedDetailSheet(item: item, environment: environment)
            }
        }
    }

    private var filtersHeader: some View {
        VStack(spacing: 8) {
            Picker("Destination", selection: $environment.notUploadedState.destinationFilter) {
                ForEach(DestinationFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.menu)

            Picker("Media", selection: $environment.notUploadedState.mediaTypeFilter) {
                ForEach(MediaTypeFilter.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.menu)
            Picker("Status", selection: $environment.notUploadedState.statusFilter) {
                ForEach(FailureStatusFilter.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.menu)
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView("No matching items", systemImage: "tray",
            description: Text("Upload problems and waiting items appear here. Adjust filters to see other states."))
            .listRowBackground(Color.clear)
    }

}

/// Row displaying an asset failure or pending item.
public struct NotUploadedRow: View {
    public let item: NotUploadedItem
    public let onTap: () -> Void

    public var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                NotUploadedThumbnailView(localIdentifier: item.localIdentifier, mediaType: item.mediaType)
                    .privacySensitive()
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.filename).font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary).lineLimit(1).truncationMode(.middle).privacySensitive()
                    Text("\(item.provider) · \(item.status)").font(.caption).foregroundStyle(.secondary)
                    Text(item.plainLanguageReason).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }.padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the reason, remedy and attempt history")
    }

}

struct NotUploadedThumbnailView: View {
    let localIdentifier: String
    let mediaType: String
    @StateObject private var loader = RowThumbnailLoader()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 48, height: 48)

            if let img = loader.image {
                #if canImport(UIKit)
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipped()
                    .cornerRadius(6)
                #elseif canImport(AppKit)
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipped()
                    .cornerRadius(6)
                #endif
            } else {
                Image(systemName: mediaType.localizedCaseInsensitiveContains("Video") ? "video" : "photo")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .onAppear {
            loader.load(localIdentifier: localIdentifier)
        }
        .onChange(of: localIdentifier) { loader.load(localIdentifier: localIdentifier) }
        .onDisappear {
            loader.cancel()
        }
    }
}


/// Detailed inspector sheet for an individual failed asset.
public struct NotUploadedDetailSheet: View {
    public let item: NotUploadedItem
    @ObservedObject var environment: AppEnvironment
    @State private var history: [AttemptHistoryRow] = []
    @State private var historyError: String?
    @State private var historyHasOlder = false
    @State private var historyTask: Task<Void, Never>?
    @State private var historyGeneration = UUID()
    @State private var historyLoading = false
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            List {
                Section("What happened") {
                    Text(item.plainLanguageReason)
                    if let remedy = item.suggestedRemedy { Text(remedy).foregroundStyle(.secondary) }
                    if let date = item.nextRetryDate { LabeledContent("Next retry", value: date.formatted()) }
                    if item.canRetry || item.needsRecovery {
                        Button(item.needsRecovery ? "Check existing uploads" : "Retry this item") {
                            if item.needsRecovery { environment.recoverItem(item) } else { environment.retryItem(item) }
                        }.disabled(!environment.dashboardState.controlsAvailable)
                    }
                }
                Section(header: Text("Asset")) {
                    labeledRow(label: "Filename", value: item.filename).privacySensitive()
                    labeledRow(label: "Media Type", value: item.mediaType)
                    labeledRow(label: "Destination", value: item.provider)
                    labeledRow(label: "Capture Date", value: item.captureDate?.formatted() ?? "Unavailable")
                    labeledRow(label: "Attempts", value: item.attemptText)
                }

                Section("Attempt history (durable)") {
                    if historyLoading { ProgressView("Loading attempts…") }
                    if history.isEmpty && !historyLoading && historyError == nil {
                        Text("No attempts recorded for this item.").foregroundStyle(.secondary)
                    }
                    ForEach(history, id: \.cursor) { row in
                        VStack(alignment: .leading) {
                            Text("Attempt \(row.number) · cycle \(row.cycleID.uuidString.prefix(8)) · \(row.startedAt.formatted())")
                            Text(row.failure.map(environment.explain) ?? (row.endedAt == nil ? "No terminal outcome recorded" : "Attempt ended"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let historyError { Text(historyError).foregroundStyle(.red) }
                    if historyHasOlder { Button("Older attempts") { loadHistory(before: history.last?.cursor) }.disabled(historyLoading) }
                    Button("Newest attempts") { loadHistory() }.disabled(historyLoading)
                }
                Section(header: Text("Diagnostic Information")) {
                    labeledRow(label: "Stage", value: item.stage)
                    labeledRow(label: "Category", value: item.errorCategory)
                    if let code = item.technicalCode {
                        labeledRow(label: "Technical Code", value: code)
                    }
                }

                if !item.confirmedComponents.isEmpty || !item.missingObligations.isEmpty {
                    Section(header: Text("Resource Components")) {
                        if !item.confirmedComponents.isEmpty {
                            labeledRow(label: "Confirmed", value: item.confirmedComponents.joined(separator: ", "))
                        }
                        if !item.missingObligations.isEmpty {
                            labeledRow(label: "Missing", value: item.missingObligations.joined(separator: ", "))
                        }
                    }
                }
            }
            .onAppear { loadHistory() }
            .onDisappear { historyGeneration = UUID(); historyTask?.cancel() }
            .navigationTitle("Upload issue")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func loadHistory(before: Int64? = nil) {
        historyTask?.cancel()
        let generation = UUID(); historyGeneration = generation; historyLoading = true; historyError = nil
        historyTask = Task {
            defer { if historyGeneration == generation { historyLoading = false; historyTask = nil } }
            do {
                let page = try await environment.attemptHistory(item, before: before)
                try Task.checkCancellation()
                guard historyGeneration == generation else { return }
                history = page; historyHasOlder = page.count == 25
            } catch is CancellationError { }
            catch {
                guard !Task.isCancelled, historyGeneration == generation else { return }
                historyError = FailureExplanation.message(ProviderSupport.safe(error, domain: .sqlite))
            }
        }
    }

    private func labeledRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}
