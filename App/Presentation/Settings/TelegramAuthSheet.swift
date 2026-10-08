import SwiftUI

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
    @State private var confirmLogout = false

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
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
        }
        .navigationTitle("Connect Telegram")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var apiCredentialsSection: some View {
        Section(
            header: Text("API Credentials"),
            footer: Text("Obtain your API ID and Hash from my.telegram.org. This allows the app to communicate with Telegram.")
        ) {
            TextField("API ID", text: $apiIdText)
                .keyboardType(.numberPad)
            SecureField("API Hash", text: $apiHashText)
                .textContentType(.password)
                .autocorrectionDisabled()

            Button {
                guard let id = Int32(apiIdText.trimmingCharacters(in: .whitespacesAndNewlines)), id > 0 else {
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
                .keyboardType(.phonePad)
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
                .keyboardType(.numberPad)
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
                .keyboardType(.emailAddress).autocapitalization(.none)
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
                .keyboardType(.numberPad)

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
        Section(header: Text("Archive channel")) {
            Button("Log Out to Switch Account", role: .destructive) { confirmLogout = true }
                .disabled(environment.settingsState.isConnectingTelegram || environment.settingsState.isSettlingTelegram)

            NavigationLink(destination: TelegramChannelPicker(environment: environment, onChannelSelected: { chatID in
                Task {
                    do {
                        try await environment.mapTelegramChannel(chatID: chatID)
                        dismiss()
                    } catch {
                        // Error is recorded in environment.settingsState.telegramAuthErrorMessage
                    }
                }
            })) {
                Text("Select Channel")
            }
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
