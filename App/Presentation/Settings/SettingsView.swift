import SwiftUI
import UIKit
import CloudifiedCore

public struct SettingsView: View {
    @ObservedObject public var environment: AppEnvironment
    private enum LinkSheet: String, Identifiable {
        case google, telegram, channel
        var id: String { rawValue }
    }
    @State private var linkSheet: LinkSheet?
    @State private var showingGoogleDisconnectAlert = false
    @State private var showingTelegramDisconnectAlert = false
    @State private var showingTelegramLogoutAlert = false
    @State private var actionTask: Task<Void, Never>?
    @State private var isWorking = false
    @State private var actionError: String?

    public init(environment: AppEnvironment) { self.environment = environment }
    private var state: SettingsViewState { environment.settingsState }
    private var busy: Bool {
        isWorking || state.isConnectingGoogle || state.isConnectingTelegram || state.isSettlingGoogle || state.isSettlingTelegram
    }
    private var controlsAvailable: Bool { environment.dashboardState.controlsAvailable && !busy }
    private func status(connected: Bool, enabled: Bool) -> String {
        connected ? (enabled ? "Enabled" : "Disabled") : "Not connected"
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Destinations") {
                    NavigationLink { googlePhotosSettings } label: {
                        destinationRow("Google Photos", symbol: "photo.on.rectangle.angled",
                            status: status(connected: state.isGoogleConnected, enabled: state.isGoogleEnabled))
                    }
                    NavigationLink { telegramSettings } label: {
                        destinationRow("Telegram", symbol: "paperplane",
                            status: status(connected: state.isTelegramConnected, enabled: state.isTelegramEnabled))
                    }
                }
                Section("Photos library") {
                    LabeledContent("Access", value: environment.dashboardState.photosAccess.description)
                    if environment.dashboardState.photosAccess == .notDetermined {
                        Button("Allow Photos access", action: environment.requestPhotoLibraryAccess).disabled(!controlsAvailable)
                    } else if environment.dashboardState.photosAccess == .restricted {
                        Text("Photos access is restricted by this device's settings.").foregroundStyle(.secondary)
                    } else {
                        Link("Change Photos access", destination: URL(string: UIApplication.openSettingsURLString)!)
                        if environment.dashboardState.photosAccess.canRead {
                            Button("Scan library", action: environment.requestPhotoLibraryAccess)
                                .disabled(!controlsAvailable || environment.dashboardState.canPause)
                        }
                    }
                }
                Section("Upload preferences") {
                    Toggle("Wi-Fi only", isOn: Binding(get: { state.isWiFiOnlyEnabled }, set: environment.setWiFiOnly))
                        .disabled(busy)
                    NavigationLink("Live Photos") { livePhotoSettings }
                }
                Section("About") {
                    LabeledContent("Version", value: bundleValue("CFBundleShortVersionString"))
                    LabeledContent("Build", value: bundleValue("CFBundleVersion"))
                    LabeledContent("Revision", value: bundleValue("CloudifiedRevision"))
                        .font(.footnote).textSelection(.enabled)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .sheet(item: $linkSheet) { sheet in
                switch sheet {
                case .google: GoogleAuthSheet(environment: environment)
                case .telegram: TelegramAuthSheet(environment: environment)
                case .channel:
                    NavigationStack {
                        TelegramChannelPicker(environment: environment) { linkSheet = nil }
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Cancel") { linkSheet = nil }
                                        .disabled(state.isConnectingTelegram || state.isSettlingTelegram)
                                }
                            }
                    }
                    .interactiveDismissDisabled(state.isConnectingTelegram || state.isSettlingTelegram)
                }
            }
            .alert("Account operation failed", isPresented: Binding(
                get: { actionError != nil }, set: { if !$0 { actionError = nil } }
            )) { Button("OK", role: .cancel) { } }
            message: { Text(actionError ?? "") }
            .onDisappear { actionTask?.cancel() }
        }
    }

    private var googlePhotosSettings: some View {
        List {
            Section {
                Toggle("Enable uploads", isOn: Binding(get: { state.isGoogleEnabled }, set: environment.setGoogleEnabled))
                    .disabled(!controlsAvailable || !state.isGoogleConnected)
            } footer: { Text("Google Photos and Telegram upload independently. Disabling one keeps the other running.") }
            Section("Account") {
                if state.isGoogleConnected {
                    LabeledContent("Email", value: state.googleAccountEmail ?? "Unavailable").privacySensitive()
                }
                Button(state.isGoogleConnected ? "Change account" : "Connect Google Photos") { linkSheet = .google }
                    .disabled(!controlsAvailable)
            }
            if let error = state.googleAuthErrorMessage { Section("Connection issue") { Text(error).foregroundStyle(.red) } }
            if isWorking { Section { ProgressView("Updating account…") } }
            if state.isGoogleConnected {
                Section {
                    Button("Disconnect Google Photos", role: .destructive) { showingGoogleDisconnectAlert = true }
                        .disabled(!controlsAvailable)
                }
            }
        }
        .navigationTitle("Google Photos")
        .navigationBarBackButtonHidden(isWorking)
        .alert("Disconnect Google Photos?", isPresented: $showingGoogleDisconnectAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Disconnect", role: .destructive) { perform { try await environment.disconnectGoogle() } }
        } message: { Text("Uploads to this account stop. Photos already saved in Google Photos remain there.") }
    }

    private var telegramSettings: some View {
        List {
            Section {
                Toggle("Enable uploads", isOn: Binding(get: { state.isTelegramEnabled }, set: environment.setTelegramEnabled))
                    .disabled(!controlsAvailable || !state.isTelegramConnected)
            } footer: { Text("Original photos and videos are sent as files to your private archive channel.") }
            Section("Account and channel") {
                if state.isTelegramConnected {
                    LabeledContent("Account", value: state.telegramAccountName ?? "Unavailable").privacySensitive()
                    LabeledContent("Channel", value: state.telegramChannelName ?? "Unavailable").privacySensitive()
                    if let id = state.telegramChatID { LabeledContent("Channel ID", value: String(id)).privacySensitive() }
                    Button("Change channel") { linkSheet = .channel }.disabled(!controlsAvailable)
                } else {
                    Button("Connect Telegram") { linkSheet = .telegram }.disabled(!controlsAvailable)
                }
            }
            if let error = state.telegramAuthErrorMessage { Section("Connection issue") { Text(error).foregroundStyle(.red) } }
            if isWorking { Section { ProgressView("Updating Telegram session…") } }
            if state.isTelegramConnected || [.readyForChannel, .connected].contains(state.telegramAuthStep) {
                Section {
                    if state.isTelegramConnected {
                        Button("Disconnect destination", role: .destructive) { showingTelegramDisconnectAlert = true }
                            .disabled(!controlsAvailable)
                    }
                    Button("Log out of this app", role: .destructive) { showingTelegramLogoutAlert = true }
                        .disabled(!controlsAvailable)
                }
            }
        }
        .navigationTitle("Telegram")
        .navigationBarBackButtonHidden(isWorking)
        .alert("Disconnect destination?", isPresented: $showingTelegramDisconnectAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Disconnect", role: .destructive) { perform { try await environment.disconnectTelegram() } }
        } message: { Text("This removes the local channel mapping. Your Telegram session and saved files remain.") }
        .alert("Log out of this app's Telegram session?", isPresented: $showingTelegramLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Log out", role: .destructive) { perform { try await environment.logoutTelegram() } }
        } message: { Text("Other Telegram apps and devices stay signed in. This app's current destination will be disconnected.") }
    }

    private var livePhotoSettings: some View {
        Form {
            Section {
                Picker("Google Photos", selection: Binding(get: { state.livePhotoFallback }, set: environment.updateLivePhotoPolicy)) {
                    ForEach(LivePhotoFallbackOption.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.inline).disabled(!controlsAvailable)
            } footer: { Text(state.livePhotoFallback.summaryDescription) }
            Section { Text("Telegram preserves both the original photo and the original motion video for every Live Photo.") }
        }.navigationTitle("Live Photos")
    }
    private func destinationRow(_ title: String, symbol: String, status: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Color.accentColor).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(status).font(.footnote).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 4)
    }
    private func bundleValue(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "Unavailable"
    }
    private func perform(_ operation: @escaping @MainActor () async throws -> Void) {
        guard controlsAvailable else { return }
        isWorking = true; actionError = nil
        actionTask = Task {
            defer { isWorking = false; actionTask = nil }
            do { try Task.checkCancellation(); try await operation() }
            catch is CancellationError { }
            catch { actionError = FailureExplanation.message(ProviderSupport.safe(error, domain: .core)) }
        }
    }
}
