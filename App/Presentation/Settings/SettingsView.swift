import SwiftUI
import UIKit
import CloudifiedCore

public struct SettingsView: View {
    @ObservedObject public var environment: AppEnvironment

    @State private var showingGoogleDisconnectAlert = false
    @State private var showingTelegramDisconnectAlert = false
    @State private var showingTelegramLogoutAlert = false

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    private var state: SettingsViewState { environment.settingsState }

    public var body: some View {
        NavigationStack {
            List {
                Section("Photos") {
                    LabeledContent("Access", value: environment.dashboardState.photosAccess.description)
                    if environment.dashboardState.photosAccess == .notDetermined {
                        Button("Allow Photos access", action: environment.requestPhotoLibraryAccess)
                            .disabled(!environment.dashboardState.controlsAvailable)
                    } else if environment.dashboardState.photosAccess == .restricted {
                        Text("Photos access is restricted by this device's settings.").font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Link("Change Photos access", destination: URL(string: UIApplication.openSettingsURLString)!)
                        if environment.dashboardState.photosAccess.canRead {
                            Button("Scan library", action: environment.requestPhotoLibraryAccess)
                                .disabled(!environment.dashboardState.controlsAvailable || environment.dashboardState.canPause)
                        }
                    }
                }

                Section("Upload Destinations") {
                    NavigationLink(destination: googlePhotosSettings) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled").foregroundColor(.blue).frame(width: 24)
                            Text("Google Photos")
                            Spacer()
                            Text(state.isGoogleConnected ? "Connected" : "Off").foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink(destination: telegramSettings) {
                        HStack {
                            Image(systemName: "paperplane.fill").foregroundColor(.blue).frame(width: 24)
                            Text("Telegram")
                            Spacer()
                            Text(state.isTelegramConnected ? "Connected" : "Off").foregroundStyle(.secondary)
                        }
                    }
                }

                Section(header: Text("Preferences")) {
                    Toggle("Wi-Fi Only", isOn: Binding(
                        get: { state.isWiFiOnlyEnabled },
                        set: { environment.setWiFiOnly($0) }
                    ))

                    Picker("Live Photo Fallback (Google Only)", selection: Binding(
                        get: { state.livePhotoFallback },
                        set: { environment.updateLivePhotoPolicy($0) }
                    )) {
                        ForEach(LivePhotoFallbackOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(state.livePhotoFallback.summaryDescription)
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    Text("Telegram always uploads both original video and original photo.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section("System") {
                    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
                    let revision = Bundle.main.object(forInfoDictionaryKey: "CloudifiedRevision") as? String ?? "unknown"
                    LabeledContent("Version", value: "\(version) (\(revision))")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
        }
    }

    private var googlePhotosSettings: some View {
        List {
            Section {
                Toggle("Enable Google Photos", isOn: Binding(
                    get: { state.isGoogleEnabled },
                    set: { environment.setGoogleEnabled($0) }
                ))
            }

            Section("Account Details") {
                if state.isGoogleConnected {
                    LabeledContent("Email", value: state.googleAccountEmail ?? "Unknown").privacySensitive()
                    NavigationLink("Change Account") {
                        GoogleAuthSheet(environment: environment)
                    }
                    Button("Disconnect", role: .destructive) { showingGoogleDisconnectAlert = true }
                    .disabled(state.isSettlingGoogle)
                } else {
                    NavigationLink("Connect Google Photos") {
                        GoogleAuthSheet(environment: environment)
                    }
                }
            }

            if let error = state.googleAuthErrorMessage {
                Section {
                    Text(error).foregroundColor(.red).font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Google Photos")
        .alert("Disconnect Google Photos?", isPresented: $showingGoogleDisconnectAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Disconnect", role: .destructive) {
                Task { try? await environment.disconnectGoogle() }
            }
        }
    }

    private var telegramSettings: some View {
        List {
            Section {
                Toggle("Enable Telegram", isOn: Binding(
                    get: { state.isTelegramEnabled },
                    set: { environment.setTelegramEnabled($0) }
                ))
            }

            Section("Account Details") {
                if state.isTelegramConnected {
                    LabeledContent("Account", value: state.telegramAccountName ?? "Unknown").privacySensitive()
                    LabeledContent("Channel", value: state.telegramChannelName ?? "Unknown").privacySensitive()
                    if let chatID = state.telegramChatID {
                        LabeledContent("Channel ID", value: String(chatID)).privacySensitive()
                    }

                    NavigationLink("Change Channel") {
                        TelegramChannelPicker(environment: environment, onChannelSelected: { chatID in
                            Task {
                                try? await environment.mapTelegramChannel(chatID: chatID)
                            }
                        })
                    }

                    Button("Disconnect Device", role: .destructive) { showingTelegramDisconnectAlert = true }
                    .disabled(state.isSettlingTelegram)

                    Button("Log Out Account", role: .destructive) { showingTelegramLogoutAlert = true }
                    .disabled(state.isSettlingTelegram)
                } else {
                    NavigationLink("Connect Telegram Account") {
                        TelegramAuthSheet(environment: environment)
                    }
                }
            }

            if let error = state.telegramAuthErrorMessage {
                Section {
                    Text(error).foregroundColor(.red).font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Telegram")
        .alert("Disconnect from device?", isPresented: $showingTelegramDisconnectAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Disconnect", role: .destructive) {
                Task { try? await environment.disconnectTelegram() }
            }
        } message: { Text("This removes the local mapping. You remain logged into Telegram.") }
        .alert("Log out of Telegram?", isPresented: $showingTelegramLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                Task { try? await environment.logoutTelegram() }
            }
        } message: { Text("This logs the account out of Telegram completely.") }
    }
}
