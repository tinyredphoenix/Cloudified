import SwiftUI
#if os(iOS)
import UIKit
#endif

public struct LogsView: View {
    @ObservedObject public var environment: AppEnvironment
    @State private var reportURL: URL?
    @State private var reportTask: Task<Void, Never>?
    @State private var uploadingReport = false
    @State private var exportedFileURL: URL? = nil
    @State private var isExporting = false
    @State private var exportTask: Task<Void, Never>?
    @State private var exportErrorMessage: String? = nil

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        uploadingReport = true
                        reportTask = Task {
                            defer { uploadingReport = false }
                            do {
                                let url = try await environment.uploadDiagnosticReport()
                                reportURL = url
                                #if os(iOS)
                                UIPasteboard.general.url = url
                                #endif
                            } catch is CancellationError { }
                            catch { exportErrorMessage = FailureExplanation.message(ProviderSupport.safe(error, domain: .urlSession)) }
                        }
                    } label: {
                        if uploadingReport { ProgressView("Preparing and uploading report…") }
                        else { Label("Upload public diagnostics", systemImage: "arrow.up.doc") }
                    }.disabled(uploadingReport)
                    if let reportURL {
                        Link("Open uploaded report", destination: reportURL)
                        Button("Copy report link") {
                            #if os(iOS)
                            UIPasteboard.general.url = reportURL
                            #endif
                        }
                        Text("Link copied. Send it in the Cloudified chat so the report can be read and filed on GitHub.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Uploads recent redacted diagnostics to paste.rs. The report is public to anyone with its link. Credentials, media, account names and private paths are excluded. No sign-in or installation required.")
                }
                Section {
                    DisclosureGroup("Filters") { filtersHeader }
                }
                if !environment.logsState.fallbackEntries.isEmpty {
                    Section("Diagnostics not saved to disk") {
                        Text("These persistence errors are held in memory, included in public diagnostic reports, and excluded from file export.")
                            .font(.footnote).foregroundStyle(.secondary)
                        ForEach(environment.logsState.fallbackEntries) { entry in
                            NavigationLink { LogDetail(entry: entry) } label: { LogRow(entry: entry) }
                        }
                    }
                }
                Section("Events") {
                    if environment.logsState.filteredEntries.isEmpty {
                        if environment.logsState.isLoading { ProgressView("Loading events…") }
                        else { emptyStateView }
                    }
                    ForEach(environment.logsState.filteredEntries) { entry in
                        NavigationLink { LogDetail(entry: entry) } label: { LogRow(entry: entry) }
                    }
                }
                Section {
                    if let error = environment.logsState.pageError {
                        Text(error).foregroundStyle(.red)
                        Button("Retry page") { environment.reloadLogs() }.disabled(environment.logsState.isLoading)
                    }
                    if environment.logsState.isLoading && !environment.logsState.filteredEntries.isEmpty {
                        ProgressView("Loading events…")
                    }
                    if environment.logsState.hasOlder {
                        Button("Older events") { environment.olderLogs() }.disabled(environment.logsState.isLoading)
                    }
                } footer: {
                    if environment.logsState.prunedEventCount > 0 {
                        Text("\(environment.logsState.prunedEventCount) routine events pruned. Critical records retained.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .onAppear { environment.reloadLogs(); environment.loadRuns() }
            .onDisappear { reportTask?.cancel(); if exportedFileURL == nil { exportTask?.cancel() } }
            .onChange(of: environment.logsState.originFilter) { environment.reloadLogs() }
            .onChange(of: environment.logsState.severityFilter) { environment.reloadLogs() }
            .onChange(of: environment.logsState.selectedRunID) { environment.reloadLogs() }
            .refreshable { environment.reloadLogs() }
            .navigationTitle("Logs")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { environment.reloadLogs(); environment.loadRuns() } label: {
                        Label("Newest logs", systemImage: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isExporting = true
                        exportTask = Task {
                            defer { isExporting = false }
                            do {
                                let url = try await environment.exportRedactedLogs()
                                exportedFileURL = url
                            } catch is CancellationError {
                                // Owner releases an export completed after cancellation.
                            } catch {
                                exportErrorMessage = FailureExplanation.message(ProviderSupport.safe(error, domain: .fileSystem))
                            }
                        }
                    } label: {
                        if isExporting {
                            ProgressView()
                        } else {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(isExporting)
                }
            }
            #if os(iOS)
            .sheet(isPresented: Binding(
                get: { exportedFileURL != nil },
                set: { if !$0 { cleanupExportFile() } }
            )) {
                if let url = exportedFileURL {
                    ShareSheet(activityItems: [url]) {
                        cleanupExportFile()
                    }
                }
            }
            #endif
            .alert("Diagnostics issue", isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportErrorMessage ?? "Could not export diagnostic logs.")
            }
        }
    }

    private func cleanupExportFile() {
        if let url = exportedFileURL {
            environment.releaseExport(url)
            exportedFileURL = nil
        }
    }


    private var filtersHeader: some View {
        VStack(spacing: 8) {
            Picker("Run", selection: $environment.logsState.selectedRunID) {
                Text("All runs").tag(nil as UUID?)
                if let selected = environment.logsState.selectedRunID, !environment.logsState.runs.contains(where: { $0.id == selected }) {
                    Text("Selected run \(selected.uuidString.prefix(8))").tag(Optional(selected))
                }
                ForEach(environment.logsState.runs) { run in Text(run.title).tag(Optional(run.id)) }
            }
            if environment.logsState.hasOlderRuns { Button("Older runs") { environment.loadRuns(older: true) } }
            Picker("Origin", selection: $environment.logsState.originFilter) {
                ForEach(LogOriginFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.menu)

            Picker("Severity", selection: $environment.logsState.severityFilter) {
                ForEach(LogSeverityFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView("No matching events", systemImage: "doc.text.magnifyingglass",
            description: Text("Connection and backup events appear here. Adjust filters or export diagnostics to report a problem."))
            .listRowBackground(Color.clear)
    }

}

/// Row displaying an individual redacted diagnostic log entry.
public struct LogRow: View {
    public let entry: DiagnosticLogEntry

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(entry.origin, systemImage: severityIcon).foregroundStyle(severityColor)
                Spacer()
                Text(entry.timestamp, style: .time).foregroundStyle(.secondary)
            }.font(.caption)
            Text(entry.stage).font(.subheadline.weight(.semibold))
            Text(entry.message).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.severity), \(entry.origin), \(entry.stage), \(entry.message), \(entry.timestamp.formatted())")
    }

    private var severityColor: Color {
        switch entry.severity.lowercased() {
        case "error":
            return .red
        case "warning":
            return .orange
        default:
            return .blue
        }
    }

    private var severityIcon: String {
        switch entry.severity.lowercased() {
        case "error":
            return "xmark.circle.fill"
        case "warning":
            return "exclamationmark.triangle.fill"
        default:
            return "info.circle.fill"
        }
    }
}

private struct LogDetail: View {
    let entry: DiagnosticLogEntry
    var body: some View {
        List {
            Section("Event") {
                Text(entry.message).textSelection(.enabled)
            }
            Section("Details") {
                LabeledContent("Time", value: entry.timestamp.formatted(date: .complete, time: .standard))
                LabeledContent("Destination", value: entry.origin)
                LabeledContent("Severity", value: entry.severity)
                LabeledContent("Stage", value: entry.stage)
                if let attempt = entry.attemptNumber { LabeledContent("Attempt", value: String(attempt)) }
                if let code = entry.safeErrorCode { LabeledContent("Safe code", value: code).textSelection(.enabled) }
            }
        }.navigationTitle("Event details")
    }
}

#if os(iOS)
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onDismiss: @MainActor @Sendable () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            Task { @MainActor in onDismiss() }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
