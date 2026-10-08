import SwiftUI

public struct LogsView: View {
    @ObservedObject public var environment: AppEnvironment
    @State private var exportedFileURL: URL? = nil
    @State private var isExporting = false
    @State private var exportTask: Task<Void, Never>?
    @State private var exportErrorMessage: String? = nil

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filters Header
                DisclosureGroup("Filters") { filtersHeader.padding(.top, 8) }
                    .padding(.horizontal)
                    .padding(.vertical, 10)

                // Log entries list or empty state
                if environment.logsState.filteredEntries.isEmpty && environment.logsState.fallbackEntries.isEmpty {
                    emptyStateView
                } else {
                    List {
                        if !environment.logsState.fallbackEntries.isEmpty {
                            Section("Persistence failures — memory only; excluded from export") {
                                ForEach(environment.logsState.fallbackEntries) { LogRow(entry: $0) }
                            }
                        }
                        ForEach(environment.logsState.filteredEntries) { entry in
                            LogRow(entry: entry)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if environment.logsState.pageError != nil || environment.logsState.isLoading || environment.logsState.prunedEventCount > 0 || environment.logsState.hasOlder {
                VStack {
                    if let error = environment.logsState.pageError { Text(error).font(.caption).foregroundStyle(.red) }
                    if environment.logsState.isLoading { ProgressView() }
                    if environment.logsState.prunedEventCount > 0 {
                        Text("Routine events pruned: \(environment.logsState.prunedEventCount). Critical records retained.").font(.caption).foregroundStyle(.secondary)
                    }
                    if environment.logsState.hasOlder {
                        Button("Older page") { environment.olderLogs() }.disabled(environment.logsState.isLoading)
                    }
                }.padding(.horizontal).padding(.vertical, 8).background(.regularMaterial)
                }
            }
            .onAppear { environment.reloadLogs(); environment.loadRuns() }
            .onDisappear { if exportedFileURL == nil { exportTask?.cancel() } }
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
            .alert("Export Failed", isPresented: Binding(
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
            .pickerStyle(.segmented)

            Picker("Severity", selection: $environment.logsState.severityFilter) {
                ForEach(LogSeverityFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("No matching events")
                .font(.headline)
                .foregroundColor(.primary)
            Text("Connection and backup events appear here. Use Export to save diagnostics when reporting a problem.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Row displaying an individual redacted diagnostic log entry.
public struct LogRow: View {
    public let entry: DiagnosticLogEntry

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                // Severity icon
                Image(systemName: severityIcon)
                    .font(.caption2)
                    .foregroundColor(severityColor)

                Text(entry.origin)
                    .font(.caption2.bold())
                    .foregroundColor(.primary)

                Text("•")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(entry.stage)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if let attempt = entry.attemptNumber {
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Attempt \(attempt)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(entry.message)
                .font(.subheadline)
                .foregroundColor(.primary)

            if let code = entry.safeErrorCode {
                Text("Code: \(code)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
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
