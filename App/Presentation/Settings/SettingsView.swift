import SwiftUI

public struct SettingsView: View {
    @ObservedObject public var environment: AppEnvironment
    @State private var showingGoogleAuthSheet = false
    @State private var showingTelegramAuthSheet = false
    @State private var showingGoogleDisconnectAlert = false
    @State private var showingTelegramDisconnectAlert = false

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
                    Toggle(isOn: Binding(
                        get: { environment.settingsState.isGoogleEnabled },
                        set: { environment.setGoogleEnabled($0) }
                    )) {
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

                    Toggle(isOn: Binding(
                        get: { environment.settingsState.isTelegramEnabled },
                        set: { environment.setTelegramEnabled($0) }
                    )) {
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
                        showingGoogleAuthSheet = true
                    } label: {
                        Text(environment.settingsState.isGoogleConnected ? "Switch Google Account" : "Sign In with Google")
                    }

                    if environment.settingsState.isGoogleConnected {
                        Button(role: .destructive) {
                            showingGoogleDisconnectAlert = true
                        } label: {
                            if environment.settingsState.isSettlingGoogle {
                                HStack {
                                    ProgressView()
                                    Text("Settling & Disconnecting...")
                                }
                            } else {
                                Text("Disconnect Google Photos")
                            }
                        }
                        .disabled(environment.settingsState.isSettlingGoogle)
                    }

                    Picker("Live Photo Fallback", selection: Binding(
                        get: { environment.settingsState.livePhotoFallback },
                        set: { environment.updateLivePhotoPolicy($0) }
                    )) {
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
                    footer: Text("Telegram requires both an authenticated user account and a designated private archive channel with zero message auto-delete.")
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

                    HStack {
                        Text("Auth Status")
                        Spacer()
                        Text(environment.settingsState.telegramAuthStep.rawValue)
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                    }

                    Button {
                        showingTelegramAuthSheet = true
                    } label: {
                        Text(environment.settingsState.isTelegramConnected ? "Change Telegram Account / Channel" : "Connect Telegram")
                    }

                    if environment.settingsState.isTelegramConnected {
                        Button(role: .destructive) {
                            showingTelegramDisconnectAlert = true
                        } label: {
                            if environment.settingsState.isSettlingTelegram {
                                HStack {
                                    ProgressView()
                                    Text("Settling & Disconnecting...")
                                }
                            } else {
                                Text("Disconnect Telegram")
                            }
                        }
                        .disabled(environment.settingsState.isSettlingTelegram)
                    }
                }

                // Section 4: Network & Battery Policy
                Section(
                    header: Text("Network & Power Policy"),
                    footer: Text("Wi-Fi only prevents cellular data consumption. The upload batch automatically pauses when disconnected from Wi-Fi.")
                ) {
                    Toggle("Wi-Fi Only", isOn: Binding(
                        get: { environment.settingsState.isWiFiOnlyEnabled },
                        set: { environment.setWiFiOnly($0) }
                    ))
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
    @State private var oauthToken = ""

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text("Google Photos Sign In"),
                    footer: Text("Provide your Google OAuth 2.0 access token with Photos scope. Cloudified exchanges this for an Android master token using the pinned PhotosBackup implementation, verifies your OpenID subject identity, and securely stores credentials in the Keychain.")
                ) {
                    SecureField("OAuth Access Token", text: $oauthToken)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button {
                        let token = oauthToken.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !token.isEmpty else { return }
                        Task {
                            do {
                                try await environment.connectGoogle(oauthToken: token)
                                dismiss()
                            } catch {
                                // Error is recorded in environment.settingsState.googleAuthErrorMessage
                            }
                        }
                    } label: {
                        if environment.settingsState.isConnectingGoogle {
                            HStack {
                                ProgressView()
                                Text("Verifying Account & Connecting...")
                            }
                        } else {
                            Text("Connect with Token")
                        }
                    }
                    .disabled(oauthToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || environment.settingsState.isConnectingGoogle)
                }

                if let err = environment.settingsState.googleAuthErrorMessage {
                    Section {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Google Sign In")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
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

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        NavigationStack {
            Form {
                switch environment.settingsState.telegramAuthStep {
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
            .navigationTitle("Telegram Authentication")
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
            header: Text("Telegram API Credentials"),
            footer: Text("Enter your Telegram API ID and API Hash from my.telegram.org. Credentials are encrypted and stored in the iOS Keychain.")
        ) {
            TextField("API ID (e.g. 1234567)", text: $apiIdText)
                .numberKeyboard()
            TextField("API Hash", text: $apiHashText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button {
                guard let id = Int32(apiIdText.trimmingCharacters(in: .whitespacesAndNewlines)),
                      !apiHashText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return
                }
                let hash = apiHashText.trimmingCharacters(in: .whitespacesAndNewlines)
                Task {
                    try? await environment.saveTelegramAPICredentials(apiId: id, apiHash: hash)
                }
            } label: {
                if environment.settingsState.isConnectingTelegram {
                    ProgressView()
                } else {
                    Text("Save & Initialize TDLib")
                }
            }
            .disabled(environment.settingsState.isConnectingTelegram)
        }
    }

    private var phoneNumberSection: some View {
        Section(
            header: Text("Phone Number"),
            footer: Text("Enter your Telegram account phone number in international format (e.g. +1234567890).")
        ) {
            TextField("Phone Number", text: $phoneNumber)
                .phoneKeyboard()

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
                    Text("Submit Phone Number")
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

            Button {
                let code = verificationCode.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !code.isEmpty else { return }
                Task {
                    try? await environment.submitTelegramCode(code)
                }
            } label: {
                if environment.settingsState.isConnectingTelegram {
                    ProgressView()
                } else {
                    Text("Submit Code")
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

            Button {
                let pwd = password.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !pwd.isEmpty else { return }
                Task {
                    try? await environment.submitTelegramPassword(pwd)
                }
            } label: {
                if environment.settingsState.isConnectingTelegram {
                    ProgressView()
                } else {
                    Text("Submit Password")
                }
            }
            .disabled(password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || environment.settingsState.isConnectingTelegram)
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
            header: Text("Target Channel Mapping"),
            footer: Text("Cloudified requires an owned private channel (supergroup) with creator permissions and message auto-delete disabled (0 seconds). Public channels or channels with auto-delete are rejected.")
        ) {
            TextField("Channel Chat ID (e.g. -1001234567890)", text: $channelChatIDText)
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
                    Text("Verify & Map Channel")
                }
            }
            .disabled(channelChatIDText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || environment.settingsState.isConnectingTelegram)
        }
    }

    private var errorOrClosedSection: some View {
        Section(header: Text("Session Status")) {
            Text("Session state: \(environment.settingsState.telegramAuthStep.rawValue)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Re-initialize Client") {
                Task {
                    await environment.reconnectTelegram()
                }
            }
        }
    }
}
