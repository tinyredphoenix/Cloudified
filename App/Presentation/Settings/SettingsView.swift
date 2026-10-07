import SwiftUI

public struct SettingsView: View {
    @ObservedObject public var environment: AppEnvironment
    @State private var showingGoogleAuthNotice = false
    @State private var showingTelegramAuthNotice = false

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Section 1: Independent Provider Switches
                Section(
                    header: Text("Destinations"),
                    footer: Text("Both enabled providers run concurrently in the same backup batch. Disabling a provider retains its backlog and confirmed counts.")
                ) {
                    Toggle(isOn: $environment.settingsState.isGoogleEnabled) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Google Photos")
                                    .foregroundColor(.primary)
                                Text("Uploads originals via PhotosBackup bridge")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "photo.stack.fill")
                                .foregroundColor(.red)
                        }
                    }

                    Toggle(isOn: $environment.settingsState.isTelegramEnabled) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Telegram")
                                    .foregroundColor(.primary)
                                Text("Archives originals to private channel via TDLib")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }

                // Section 2: Google Photos Account & Configuration
                Section(
                    header: Text("Google Photos Configuration"),
                    footer: Text("Native Live Photo pairing is preferred. When unverified, the selected fallback policy is applied.")
                ) {
                    HStack {
                        Text("Account")
                        Spacer()
                        Text(environment.settingsState.googleAccountEmail ?? "Not connected")
                            .foregroundColor(.secondary)
                    }

                    Button {
                        showingGoogleAuthNotice = true
                    } label: {
                        Text(environment.settingsState.isGoogleConnected ? "Switch Google Account" : "Sign In with Google")
                    }

                    Picker("Live Photo Fallback", selection: $environment.settingsState.livePhotoFallback) {
                        ForEach(LivePhotoFallbackOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }

                    Text(environment.settingsState.livePhotoFallback.summaryDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Section 3: Telegram Account & Destination Channel
                Section(
                    header: Text("Telegram Configuration"),
                    footer: Text("Telegram requires both an authenticated user account and a designated private archive channel.")
                ) {
                    HStack {
                        Text("Account")
                        Spacer()
                        Text(environment.settingsState.telegramAccountName ?? "Not connected")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Target Channel")
                        Spacer()
                        Text(environment.settingsState.telegramChannelName ?? "Not mapped")
                            .foregroundColor(.secondary)
                    }

                    Button {
                        showingTelegramAuthNotice = true
                    } label: {
                        Text(environment.settingsState.isTelegramConnected ? "Change Telegram Account" : "Connect Telegram")
                    }
                }

                // Section 4: Network & Battery Policy
                Section(
                    header: Text("Network & Power Policy"),
                    footer: Text("Wi-Fi only prevents cellular data consumption. The upload batch automatically pauses when disconnected from Wi-Fi.")
                ) {
                    Toggle("Wi-Fi Only", isOn: $environment.settingsState.isWiFiOnlyEnabled)
                }

                // Section 5: Architecture & Version Information
                Section(header: Text("About Cloudified")) {
                    labeledRow(label: "Version", value: "1.0.0 (Build 1)")
                    labeledRow(label: "Platform", value: "iOS 26 Native (Swift 6 / SwiftUI)")
                    labeledRow(label: "Quality Mode", value: "Original Quality Only")
                    labeledRow(label: "Demo/Mock Mode", value: "Disabled (Production Only)")
                    labeledRow(label: "State Ledger", value: "Durable SQLite")
                }
            }
            .navigationTitle("Settings")
            .alert("Google Authentication", isPresented: $showingGoogleAuthNotice) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Google Photos authentication bridge will be connected in Phase 4 using the pinned PhotosBackup implementation.")
            }
            .alert("Telegram TDLib Bridge", isPresented: $showingTelegramAuthNotice) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Telegram TDLib bridge and private channel mapper will be connected in Phase 4.")
            }
        }
    }

    private func labeledRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}
