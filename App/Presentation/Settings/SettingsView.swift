import SwiftUI

public struct SettingsView: View {
    @ObservedObject public var environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }
    
    private var state: SettingsViewState { environment.settingsState }

    public var body: some View {
        NavigationStack {
            List {
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
                    
                    Picker("Live Photo Fallback", selection: Binding(
                        get: { state.livePhotoFallback },
                        set: { environment.setLivePhotoFallback($0) }
                    )) {
                        ForEach(LivePhotoFallbackOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text(state.livePhotoFallback.summaryDescription)
                        .font(.footnote)
                        .foregroundColor(.secondary)
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
                    LabeledContent("Email", value: state.googleAccountEmail ?? "Unknown")
                    Button("Disconnect", role: .destructive) {
                        Task { try? await environment.disconnectGoogle() }
                    }
                    .disabled(state.isSettlingGoogle)
                } else {
                    GoogleAccountLoginView(environment: environment)
                        .frame(height: 50)
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
                    LabeledContent("Account", value: state.telegramAccountName ?? "Unknown")
                    LabeledContent("Channel", value: state.telegramChannelName ?? "Unknown")
                    if let chatID = state.telegramChatID {
                        LabeledContent("Channel ID", value: String(chatID))
                    }
                    Button("Disconnect", role: .destructive) {
                        Task { try? await environment.disconnectTelegram() }
                    }
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
    }
}
