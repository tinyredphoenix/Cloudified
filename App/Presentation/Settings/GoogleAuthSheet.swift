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
                            Text("Connect Google Photos").font(.title2.weight(.semibold))
                            Text("Sign in with the account you want to back up to. This session is separate from Safari and your other Google apps.")
                                .foregroundStyle(.secondary)
                            Button("Continue to Google") { loading = true; browserError = nil; showBrowser = true }
                        }
                        if let error = browserError ?? environment.settingsState.googleAuthErrorMessage {
                            Section("Connection issue") { Text(error).font(.footnote).foregroundStyle(.red) }
                        }
                        Section {
                            DisclosureGroup("Advanced: login token") {
                                SecureField("PhotosBackup login token", text: $oauthToken)
                                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                                Button("Connect with token") {
                                    let value = oauthToken.trimmingCharacters(in: .whitespacesAndNewlines)
                                    oauthToken = ""; connect(value)
                                }.disabled(oauthToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                Text("Only for an existing PhotosBackup login token. A normal Google API access token is not compatible.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Google Photos").inlineNavigationTitle()
            .interactiveDismissDisabled(exchanging)
            .onDisappear { oauthToken = ""; showBrowser = false; loginTask?.cancel() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(showBrowser ? "Back" : "Cancel") {
                        if showBrowser { showBrowser = false } else { dismiss() }
                    }.disabled(exchanging)
                }
            }
        }
    }
    private func connect(_ token: String) {
        guard !exchanging, !token.isEmpty else { return }
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

// MARK: - Telegram Authentication Sheet

@MainActor
