import SwiftUI
import CloudifiedCore

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
    @State private var showingPicker = false
    @State private var actionTask: Task<Void, Never>?
    @State private var isWorking = false
    @State private var actionError: String?

    private var busy: Bool {
        isWorking || environment.settingsState.isConnectingTelegram || environment.settingsState.isSettlingTelegram
    }
    private var controlsAvailable: Bool { environment.dashboardState.controlsAvailable && !busy }

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
                if busy { Section { ProgressView("Updating Telegram session…") } }
                if let message = actionError ?? environment.settingsState.telegramAuthErrorMessage {
                    Section("Connection issue") { Text(message).foregroundStyle(.red) }
                }
            }
            .disabled(busy)
            .navigationTitle("Connect Telegram")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { clearInputs(); dismiss() }.disabled(busy)
                }
            }
            .interactiveDismissDisabled(busy)
            .alert("Log out of this app's Telegram session?", isPresented: $confirmLogout) {
                Button("Cancel", role: .cancel) { }
                Button("Log out", role: .destructive) { perform { try await environment.logoutTelegram() } }
            } message: { Text("Other Telegram apps and devices stay signed in. This app's current destination will be disconnected.") }
            .sheet(isPresented: $showingPicker) {
                NavigationStack {
                    TelegramChannelPicker(environment: environment) { showingPicker = false; dismiss() }
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showingPicker = false }.disabled(busy)
                            }
                        }
                }
                .interactiveDismissDisabled(busy)
            }
            .onDisappear { clearInputs(); actionTask?.cancel(); actionTask = nil }
        }
    }

    private var apiCredentialsSection: some View {
        Section(
            header: Text("API Credentials"),
            footer: Text("Obtain your API ID and Hash from my.telegram.org. This allows the app to communicate with Telegram.")
        ) {
            Link("Get Telegram API credentials", destination: URL(string: "https://my.telegram.org/apps")!)
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
                apiHashText = ""
                perform { try await environment.saveTelegramAPICredentials(apiId: id, apiHash: hash) }
            } label: {
                if environment.settingsState.isConnectingTelegram {
                    ProgressView()
                } else {
                    Text("Continue")
                }
            }
            .disabled((Int32(apiIdText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) <= 0 || apiHashText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !controlsAvailable)
        }
    }

    private var phoneNumberSection: some View {
        Section(
            header: Text("Phone Number"),
            footer: Text("Enter your Telegram account phone number including the country code.")
        ) {
            TextField("Phone Number", text: $phoneNumber)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)

            Button {
                let phone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !phone.isEmpty else { return }
                phoneNumber = ""
                perform { try await environment.submitTelegramPhone(phone) }
            } label: {
                if environment.settingsState.isConnectingTelegram {
                    ProgressView()
                } else {
                    Text("Continue")
                }
            }
            .disabled(phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !controlsAvailable)
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
                verificationCode = ""
                perform { try await environment.submitTelegramCode(code) }
            } label: {
                if environment.settingsState.isConnectingTelegram {
                    ProgressView()
                } else {
                    Text("Continue")
                }
            }
            .disabled(verificationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !controlsAvailable)
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
                password = ""
                perform { try await environment.submitTelegramPassword(pwd) }
            } label: {
                if environment.settingsState.isConnectingTelegram {
                    ProgressView()
                } else {
                    Text("Continue")
                }
            }
            .disabled(password.isEmpty || !controlsAvailable)
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
                email = ""
                perform { try await environment.submitTelegramEmail(em) }
            }
            .disabled(!controlsAvailable)
        }
    }

    private var emailCodeSection: some View {
        Section(header: Text("Email Verification Code")) {
            TextField("Email Code", text: $emailCode)
                .keyboardType(.numberPad)

            Button("Submit Email Code") {
                let code = emailCode.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !code.isEmpty else { return }
                emailCode = ""
                perform { try await environment.submitTelegramEmailCode(code) }
            }
            .disabled(!controlsAvailable)
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
                .disabled(!controlsAvailable)

            Button("Select channel") { showingPicker = true }.disabled(!controlsAvailable)
            Text("Choose a private channel you own with auto-delete off. Existing uploads are checked before this destination is enabled.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var errorOrClosedSection: some View {
        Section(header: Text("Session Status")) {
            Text("Session state: \(environment.settingsState.telegramAuthStep.rawValue)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Re-initialize Client") {
                perform { try await environment.reconnectTelegram() }
            }.disabled(!controlsAvailable)
        }
    }
    private func perform(_ operation: @escaping @MainActor () async throws -> Void) {
        guard controlsAvailable else { return }
        isWorking = true; actionError = nil
        actionTask = Task {
            defer { isWorking = false; actionTask = nil }
            do { try Task.checkCancellation(); try await operation() }
            catch is CancellationError { }
            catch { actionError = FailureExplanation.message(ProviderSupport.safe(error, domain: .tdlib)) }
        }
    }
    private func clearInputs() {
        apiIdText = ""; apiHashText = ""; phoneNumber = ""; verificationCode = ""
        password = ""; email = ""; emailCode = ""
    }

}
