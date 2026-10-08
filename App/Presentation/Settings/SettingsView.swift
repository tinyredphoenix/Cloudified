import SwiftUI
import UIKit
import CloudifiedCore

public struct SettingsView: View {
    @ObservedObject public var environment: AppEnvironment
    @State private var showingGoogleAuthSheet = false
    @State private var showingTelegramAuthSheet = false
    @State private var showingGoogleDisconnectAlert = false
    @State private var showingTelegramDisconnectAlert = false
    @State private var showingTelegramLogoutAlert = false

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        NavigationStack {
            Form {
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
                Section("Destinations") {
                    NavigationLink { googleSettings } label: {
                        accountRow("Google Photos", subtitle: environment.settingsState.googleAccountEmail ?? "Not connected", icon: "photo.stack")
                    }
                    NavigationLink { telegramSettings } label: {
                        accountRow("Telegram", subtitle: environment.settingsState.telegramChannelName ?? "Not connected", icon: "paperplane")
                    }
                }
                Section("Backup options") {
                    Toggle("Wi-Fi Only", isOn: Binding(get: { environment.settingsState.isWiFiOnlyEnabled }, set: environment.setWiFiOnly))
                    NavigationLink("Live Photos") {
                        Form {
                            Section {
                                Picker("Google Photos", selection: Binding(get: { environment.settingsState.livePhotoFallback }, set: environment.updateLivePhotoPolicy)) {
                                    ForEach(LivePhotoFallbackOption.allCases) { Text($0.rawValue).tag($0) }
                                }.pickerStyle(.inline)
                            } footer: { Text(environment.settingsState.livePhotoFallback.summaryDescription) }
                            Section { Text("Telegram keeps both original components.").foregroundStyle(.secondary) }
                        }.navigationTitle("Live Photos").inlineNavigationTitle()
                    }
                }
                Section {
                    labeledRow(label: "Version", value: "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unavailable") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unavailable"))")
                } footer: { Text("Original photos and videos. You control when backup starts.") }

            }
            .disabled(environment.settingsState.isSettlingGoogle || environment.settingsState.isSettlingTelegram)
            .navigationTitle("Settings")
            .sheet(isPresented: $showingGoogleAuthSheet) {
                GoogleAuthSheet(environment: environment)
            }
            .sheet(isPresented: $showingTelegramAuthSheet) {
                TelegramAuthSheet(environment: environment)
            }
            .alert("Disconnect Google Photos?", isPresented: $showingGoogleDisconnectAlert) {
                Button("Disconnect", role: .destructive) {
                    Task {
                        try? await environment.disconnectGoogle()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will settle active transfers and unlink the Google Photos destination. Remote uploads will not be deleted.")
            }
            .alert("Log out of Telegram?", isPresented: $showingTelegramLogoutAlert) {
                Button("Log Out", role: .destructive) { Task { try? await environment.logoutTelegram() } }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Settles retained inputs, logs out the native Telegram account, and unlinks the channel. Remote documents remain.") }
            .alert("Disconnect Telegram?", isPresented: $showingTelegramDisconnectAlert) {
                Button("Disconnect", role: .destructive) {
                    Task {
                        try? await environment.disconnectTelegram()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will settle active transfers and unlink the Telegram channel destination. Remote messages will not be deleted.")
            }
        }
    }

    private func accountRow(_ title: String, subtitle: String, icon: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(subtitle).font(.footnote).foregroundStyle(.secondary).lineLimit(1).privacySensitive()
            }
        } icon: { Image(systemName: icon) }
    }
    private var googleSettings: some View {
        Form {
            Section {
                if environment.settingsState.isGoogleConnected {
                    LabeledContent("Account", value: environment.settingsState.googleAccountEmail ?? "Connected").privacySensitive()
                    Toggle("Upload to Google Photos", isOn: Binding(get: { environment.settingsState.isGoogleEnabled }, set: environment.setGoogleEnabled))
                }
                Button(environment.settingsState.isGoogleConnected ? "Switch account" : "Connect Google Photos") { showingGoogleAuthSheet = true }
            } footer: { Text("Sign in separately for Cloudified. Your other Google apps stay signed in.") }
            if let error = environment.settingsState.googleAuthErrorMessage {
                Section("Connection issue") { Text(error).font(.footnote).foregroundStyle(.red) }
            }
            if environment.settingsState.isGoogleConnected {
                Section { Button("Disconnect", role: .destructive) { showingGoogleDisconnectAlert = true } }
            }
        }.navigationTitle("Google Photos").inlineNavigationTitle()
    }
    private var telegramSettings: some View {
        Form {
            Section {
                if environment.settingsState.isTelegramConnected {
                    LabeledContent("Account", value: environment.settingsState.telegramAccountName ?? "Connected").privacySensitive()
                    LabeledContent("Channel", value: environment.settingsState.telegramChannelName ?? "Not mapped").privacySensitive()
                    Toggle("Upload to Telegram", isOn: Binding(get: { environment.settingsState.isTelegramEnabled }, set: environment.setTelegramEnabled))
                }
                Button(environment.settingsState.isTelegramConnected ? "Change archive channel" : "Connect Telegram") { showingTelegramAuthSheet = true }
            } footer: { Text("Use an owned private archive channel with auto-delete off.") }
            if let error = environment.settingsState.telegramAuthErrorMessage {
                Section("Connection issue") { Text(error).font(.footnote).foregroundStyle(.red) }
            }
            if environment.settingsState.isTelegramConnected {
                Section {
                    Button("Switch Telegram account", role: .destructive) { showingTelegramLogoutAlert = true }
                    Button("Disconnect", role: .destructive) { showingTelegramDisconnectAlert = true }
                }
            }
        }.navigationTitle("Telegram").inlineNavigationTitle()
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

// MARK: - View Modifiers for Platform Compatibility

private extension View {
    @ViewBuilder
    func phoneKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.phonePad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func numberKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func emailKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.emailAddress)
        #else
        self
        #endif
    }

    @ViewBuilder
    func numbersAndPunctuationKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.numbersAndPunctuation)
        #else
        self
        #endif
    }

    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

// MARK: - Google Authentication Sheet

@MainActor
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
public struct TelegramAuthSheet: View {
    @ObservedObject public var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    // API credentials state
    @State private var apiIdText = ""
    @State private var apiHashText = ""

    // Auth steps state
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var password = ""
    @State private var email = ""
    @State private var emailCode = ""
    @State private var channelChatIDText = ""
    @State private var confirmLogout = false

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        NavigationStack {
            Form {
                switch environment.settingsState.telegramAuthStep {
                case .initializing:
                    Section { ProgressView("Starting Telegram…") }
                case .unconfigured:
                    apiCredentialsSection
                case .enterPhoneNumber:
                    phoneNumberSection
                case .enterCode:
                    codeSection
                case .enterPassword:
                    passwordSection
                case .enterEmail:
                    emailSection
                case .enterEmailCode:
                    emailCodeSection
                case .otherDeviceConfirmation:
                    otherDeviceSection
                case .registration:
                    registrationSection
                case .premiumPurchase:
                    premiumSection
                case .readyForChannel, .connected:
                    channelMappingSection
                case .closing, .closed, .error:
                    errorOrClosedSection
                }

                if let err = environment.settingsState.telegramAuthErrorMessage {
                    Section {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .onDisappear { apiHashText = ""; password = ""; verificationCode = ""; emailCode = ""; phoneNumber = ""; email = "" }
            .alert("Switch Telegram account?", isPresented: $confirmLogout) {
                Button("Log Out", role: .destructive) { Task { try? await environment.logoutTelegram() } }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Logs out this native account after retained inputs settle. Remote documents remain.") }
            .navigationTitle("Connect Telegram")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var apiCredentialsSection: some View {
        Section(
            header: Text("One-time API setup"),
            footer: Text("Telegram requires these once. Cloudified stores them in the iOS Keychain.")
        ) {
            Link("Get API credentials", destination: URL(string: "https://my.telegram.org")!)
            TextField("API ID", text: $apiIdText)
                .numberKeyboard()
            SecureField("API Hash", text: $apiHashText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button {
                guard let id = Int32(apiIdText.trimmingCharacters(in: .whitespacesAndNewlines)),
                      !apiHashText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return
                }
                let hash = apiHashText.trimmingCharacters(in: .whitespacesAndNewlines)
                Task {
                    defer { apiHashText = "" }
                    try? await environment.saveTelegramAPICredentials(apiId: id, apiHash: hash)
                }
            } label: {
                if environment.settingsState.isConnectingTelegram {
                    ProgressView()
                } else {
                    Text("Continue")
                }
            }
            .disabled((Int32(apiIdText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) <= 0 || apiHashText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || environment.settingsState.isConnectingTelegram)
        }
    }

    private var phoneNumberSection: some View {
        Section(
            header: Text("Phone Number"),
            footer: Text("Enter your Telegram account phone number in international format (e.g. +1234567890).")
        ) {
            TextField("Phone Number", text: $phoneNumber)
                .phoneKeyboard()
                .textContentType(.telephoneNumber)

            Button {
                let phone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !phone.isEmpty else { return }
                Task {
                    try? await environment.submitTelegramPhone(phone)
                }
            } label: {
                if environment.settingsState.isConnectingTelegram {
                    ProgressView()
                } else {
                    Text("Continue")
                }
            }
            .disabled(phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || environment.settingsState.isConnectingTelegram)
        }
    }

    private var codeSection: some View {
        Section(
            header: Text("Verification Code"),
            footer: Text("Enter the verification code sent to your Telegram app or via SMS.")
        ) {
            TextField("Verification Code", text: $verificationCode)
                .numberKeyboard()
                .textContentType(.oneTimeCode)

            Button {
                let code = verificationCode.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !code.isEmpty else { return }
                Task {
                    defer { verificationCode = "" }
                    try? await environment.submitTelegramCode(code)
                }
            } label: {
                if environment.settingsState.isConnectingTelegram {
                    ProgressView()
                } else {
                    Text("Continue")
                }
            }
            .disabled(verificationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || environment.settingsState.isConnectingTelegram)
        }
    }

    private var passwordSection: some View {
        Section(
            header: Text("Two-Factor Authentication"),
            footer: Text("Enter your 2FA cloud password configured for this Telegram account.")
        ) {
            SecureField("2FA Password", text: $password)
                .textContentType(.password)

            Button {
                let pwd = password
                guard !pwd.isEmpty else { return }
                Task {
                    defer { password = "" }
                    try? await environment.submitTelegramPassword(pwd)
                }
            } label: {
                if environment.settingsState.isConnectingTelegram {
                    ProgressView()
                } else {
                    Text("Continue")
                }
            }
            .disabled(password.isEmpty || environment.settingsState.isConnectingTelegram)
        }
    }

    private var emailSection: some View {
        Section(header: Text("Email Address Verification")) {
            TextField("Email Address", text: $email)
                .emailKeyboard()
                .autocorrectionDisabled()

            Button("Submit Email") {
                let em = email.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !em.isEmpty else { return }
                Task {
                    try? await environment.submitTelegramEmail(em)
                }
            }
            .disabled(environment.settingsState.isConnectingTelegram)
        }
    }

    private var emailCodeSection: some View {
        Section(header: Text("Email Verification Code")) {
            TextField("Email Code", text: $emailCode)
                .numberKeyboard()

            Button("Submit Email Code") {
                let code = emailCode.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !code.isEmpty else { return }
                Task {
                    defer { emailCode = "" }
                    try? await environment.submitTelegramEmailCode(code)
                }
            }
            .disabled(environment.settingsState.isConnectingTelegram)
        }
    }

    private var otherDeviceSection: some View {
        Section(header: Text("Other Device Confirmation")) {
            Text("Please open Telegram on another logged-in device and confirm this sign-in request.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var registrationSection: some View {
        Section(header: Text("Registration Required")) {
            Text("This phone number is not registered on Telegram. Please register using the official Telegram app first.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var premiumSection: some View {
        Section(header: Text("Telegram Premium Required")) {
            Text("Telegram requires a Telegram Premium subscription to sign in with this account.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var channelMappingSection: some View {
        Section(
            header: Text("Archive channel"),
            footer: Text("Enter the numeric ID of an owned private channel. Auto-delete must be off.")
        ) {
            Button("Log Out to Switch Account", role: .destructive) { confirmLogout = true }
                .disabled(environment.settingsState.isConnectingTelegram || environment.settingsState.isSettlingTelegram)
            TextField("Channel Chat ID", text: $channelChatIDText)
                .numbersAndPunctuationKeyboard()

            Button {
                guard let chatID = Int64(channelChatIDText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    return
                }
                Task {
                    do {
                        try await environment.mapTelegramChannel(chatID: chatID)
                        dismiss()
                    } catch {
                        // Error is recorded in environment.settingsState.telegramAuthErrorMessage
                    }
                }
            } label: {
                if environment.settingsState.isConnectingTelegram {
                    ProgressView()
                } else {
                    Text("Use this channel")
                }
            }
            .disabled((Int64(channelChatIDText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) == 0 || environment.settingsState.isConnectingTelegram)
        }
    }

    private var errorOrClosedSection: some View {
        Section(header: Text("Session Status")) {
            Text("Session state: \(environment.settingsState.telegramAuthStep.rawValue)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Re-initialize Client") {
                Task {
                    try? await environment.reconnectTelegram()
                }
            }
        }
    }
}
