import SwiftUI

public struct LogsView: View {
    @ObservedObject public var environment: AppEnvironment
    @State private var showingExportAlert = false

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filters Header
                filtersHeader
                    .padding()
                    .background(Color(.secondarySystemBackground))

                // Log entries list or empty state
                if environment.logsState.filteredEntries.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(environment.logsState.filteredEntries) { entry in
                            LogRow(entry: entry)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Logs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingExportAlert = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .alert("Export Redacted Logs", isPresented: $showingExportAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                if environment.logsState.entries.isEmpty {
                    Text("No logs are currently recorded to export.")
                } else {
                    Text("Redacted diagnostic log export with \(environment.logsState.entries.count) events is ready for inspection.")
                }
            }
        }
    }

    private var filtersHeader: some View {
        VStack(spacing: 8) {
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
            Text("No Diagnostic Logs Recorded")
                .font(.headline)
                .foregroundColor(.primary)
            Text("Structured diagnostic logging begins during backup runs. Personal data, auth tokens, and location metadata are strictly redacted on-device.")
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

                Text(entry.timestamp, style: .time)
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
