import SwiftUI
public struct GoogleAuthSheet: View {
    @ObservedObject public var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var oauthToken = ""
    @State private var showBrowser = false
    @State private var loading = true
    @State private var browserError: String?
    @State private var exchanging = false
    @State private var connected = false
    @State private var loginTask: Task<Void, Never>?
    private var busy: Bool { exchanging || environment.settingsState.isConnectingGoogle || environment.settingsState.isSettlingGoogle }
    private var controlsAvailable: Bool { environment.dashboardState.controlsAvailable && !busy }
    public init(environment: AppEnvironment) { self.environment = environment }

    public var body: some View {
        NavigationStack {
            Group {
                if connected {
                    Form {
                        Section {
                            Label("Google Photos connected", systemImage: "checkmark.circle")
                            Text(environment.settingsState.googleAccountEmail ?? "Verified account").privacySensitive()
                            Button("Done") { dismiss() }
                        } footer: { Text("Return to Backup when you're ready to upload.") }
                    }
                } else if exchanging {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Verifying your account…")
                        Text("Checking the destination before enabling uploads.").font(.footnote).foregroundStyle(.secondary)
                    }.padding()
                } else if showBrowser {
                    ZStack(alignment: .top) {
                        GoogleAccountLoginView(active: scenePhase == .active,
                            onToken: connect, onLoading: { loading = $0 }, onFailure: { message, failure in
                                showBrowser = false; browserError = message
                                loginTask = Task {
                                    await environment.report(failure, provider: .google)
                                }
                            })
                        if loading { ProgressView("Loading Google…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) }
                    }
                } else {
                    Form {
                        Section {
                            Text("Choose your backup account").font(.headline)
                            Text("Sign in with the account you want to back up to. This session is separate from Safari and your other Google apps.")
                                .foregroundStyle(.secondary)
                            Text("This PhotosBackup sign-in may appear as a separate device or session in your Google Account. Google controls security checks; Cloudified cannot receive Google verification prompts. Keep another working verification method.")
                                .font(.footnote).foregroundStyle(.secondary)
                            Button("Sign in to Google") { loading = true; browserError = nil; showBrowser = true }.disabled(!controlsAvailable)
                        }
                        if let error = browserError ?? environment.settingsState.googleAuthErrorMessage {
                            Section("Connection issue") {
                                Text(error).font(.footnote).foregroundStyle(.red)
                                if environment.canRetryGoogleVerification {
                                    Button("Retry saved connection") {
                                        exchanging = true
                                        loginTask = Task {
                                            defer { exchanging = false }
                                            do { try await environment.retryGoogleVerification(); connected = true }
                                            catch { }
                                        }
                                    }.disabled(!controlsAvailable)
                                }
                            }
                        }
                        Section {
                            DisclosureGroup("Browser fallback help") {
                                Text("Safari on iPhone cannot share its protected login cookie with this app. Opening Safari alone will not finish this connection.")
                                Text("If you already use a desktop browser: open Google's EmbeddedSetup page in a private window and sign in. In the browser's developer tools, inspect Cookies for accounts.google.com and copy only oauth_token, if Google issued it. Paste it into Advanced: login token below, then close that private window.")
                                Text("Keep that credential private: paste it only in Cloudified, never in chat, GitHub or a log report. If no oauth_token exists, return to in-app sign-in; do not substitute another credential.")
                                Link("Open Google's sign-in page", destination: URL(string: "https://accounts.google.com/EmbeddedSetup")!)
                            }
                        }
                        Section {
                            DisclosureGroup("Advanced: login token") {
                                SecureField("PhotosBackup login token", text: $oauthToken)
                                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                                Button("Connect with token") {
                                    let value = oauthToken.trimmingCharacters(in: .whitespacesAndNewlines)
                                    oauthToken = ""; connect(value)
                                }.disabled(!controlsAvailable || oauthToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                Text("Only the oauth_token cookie from Google's EmbeddedSetup sign-in works here. A normal API access token, master token or password is not compatible.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Google Photos").navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(busy)
            .onDisappear { oauthToken = ""; showBrowser = false; loginTask?.cancel() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(showBrowser ? "Back" : "Cancel") {
                        if showBrowser { showBrowser = false } else { dismiss() }
                    }.disabled(busy)
                }
            }
        }
    }
    private func connect(_ token: String) {
        guard controlsAvailable, !token.isEmpty else { return }
        showBrowser = false; exchanging = true; browserError = nil
        loginTask = Task {
            defer { exchanging = false }
            do {
                try await environment.connectGoogle(oauthToken: token)
                connected = true
            } catch { /* Existing account command persists the classified failure. */ }
        }
    }
}
