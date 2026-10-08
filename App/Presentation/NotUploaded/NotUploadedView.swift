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
            VStack(spacing: 0) {
                // Filters section
                filtersHeader
                    .padding()
                    .background(Color(.secondarySystemBackground))

                // Content list or empty state
                if environment.notUploadedState.filteredItems.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(environment.notUploadedState.filteredItems) { item in
                            NotUploadedRow(item: item) {
                                selectedItemForDetails = item
                            } onRetry: {
                                if item.needsRecovery { environment.recoverItem(item) } else { environment.retryItem(item) }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack {
                    if let error = environment.notUploadedState.pageError { Text(error).font(.caption).foregroundStyle(.red) }
                    if environment.notUploadedState.isLoading { ProgressView() }
                    HStack {
                        Button("Newest") { environment.reloadFailures() }
                        Spacer()
                        Button("Older page") { environment.olderFailures() }.disabled(!environment.notUploadedState.hasOlder || environment.notUploadedState.isLoading)
                    }
                }.padding().background(.regularMaterial)
            }
            .onAppear { environment.reloadFailures() }
            .onChange(of: environment.notUploadedState.destinationFilter) { environment.reloadFailures() }
            .onChange(of: environment.notUploadedState.mediaTypeFilter) { environment.reloadFailures() }
            .onChange(of: environment.notUploadedState.statusFilter) { environment.reloadFailures() }
            .refreshable { environment.reloadFailures() }
            .navigationTitle("Not Uploaded")
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
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Picker("Media", selection: $environment.notUploadedState.mediaTypeFilter) {
                    ForEach(MediaTypeFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Picker("Status", selection: $environment.notUploadedState.statusFilter) {
                    ForEach(FailureStatusFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("No Failed or Pending Uploads")
                .font(.headline)
                .foregroundColor(.primary)
            Text("The library has not been scanned yet, or all processed items were successfully confirmed. Failed or blocked uploads will appear here with diagnostic details.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Row displaying an asset failure or pending item.
public struct NotUploadedRow: View {
    public let item: NotUploadedItem
    public let onTap: () -> Void
    public let onRetry: () -> Void

    public var body: some View {
        HStack {
            HStack(alignment: .top, spacing: 12) {
                // Small error-identification thumbnail (<=100 cached / 16 MiB, cancellable)
                NotUploadedThumbnailView(localIdentifier: item.localIdentifier, mediaType: item.mediaType)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.filename)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Text(item.attemptText)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 6) {
                        Text(item.provider)
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(item.mediaType)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if let duration = item.durationSeconds {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(formatDuration(duration))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button("Details", action: onTap).frame(minHeight: 44)
                    Text(item.plainLanguageReason)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)

                    HStack {
                        Group { if let date = item.captureDate { Text(date, style: .date) } else { Text("Capture date unavailable") } }
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(action: onRetry) {
                            Text(item.needsRecovery ? "Recover" : "Retry")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                        .tint(.accentColor)
                        .frame(minHeight: 44)
                        .disabled(!item.canRetry && !item.needsRecovery)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: seconds) ?? ""
    }
}

struct NotUploadedThumbnailView: View {
    let localIdentifier: String
    let mediaType: String
    @StateObject private var loader = RowThumbnailLoader()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.tertiarySystemFill))
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
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Asset Details")) {
                    labeledRow(label: "Filename", value: item.filename)
                    labeledRow(label: "Media Type", value: item.mediaType)
                    labeledRow(label: "Destination", value: item.provider)
                    labeledRow(label: "Capture Date", value: item.captureDate?.formatted() ?? "Unavailable")
                    labeledRow(label: "Attempts", value: item.attemptText)
                }

                Section("Attempt history (durable)") {
                    ForEach(history, id: \.cursor) { row in
                        VStack(alignment: .leading) {
                            Text("Attempt \(row.number) · cycle \(row.cycleID.uuidString.prefix(8)) · \(row.startedAt.formatted())")
                            Text(row.failure.map(environment.explain) ?? (row.endedAt == nil ? "No terminal outcome recorded" : "Attempt ended"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let historyError { Text(historyError).foregroundStyle(.red) }
                    if historyHasOlder { Button("Older attempts") { loadHistory(before: history.last?.cursor) } }
                    Button("Newest attempts") { loadHistory() }
                }
                Section(header: Text("Diagnostic Information")) {
                    labeledRow(label: "Stage", value: item.stage)
                    labeledRow(label: "Category", value: item.errorCategory)
                    if let code = item.technicalCode {
                        labeledRow(label: "Technical Code", value: code)
                    }
                    labeledRow(label: "Reason", value: item.plainLanguageReason)
                    if let date = item.nextRetryDate { labeledRow(label: "Next retry", value: date.formatted()) }
                    if let remedy = item.suggestedRemedy {
                        labeledRow(label: "Suggested Remedy", value: remedy)
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
            .onDisappear { historyTask?.cancel() }
            .navigationTitle("Failure Details")
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
        historyTask = Task {
            do { let page = try await environment.attemptHistory(item, before: before); try Task.checkCancellation(); history = page; historyHasOlder = page.count == 25; historyError = nil }
            catch is CancellationError { }
            catch { historyError = FailureExplanation.message(ProviderSupport.safe(error, domain: .sqlite)) }
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
        }
    }
}
