// MIT License
// Copyright (c) 2024 xob0t (PhotosBackup)
// Vendored and adapted for Cloudified under the MIT License. See licenses/LICENSE-PhotosBackup.txt.

import Foundation

/// OAuth token -> Android master token -> Google Photos credential.
/// Wire format corresponds to gotohp @ 0637c745 (backend/googleauth.go).
public enum GoogleTokenExchange {
    public struct Failure: LocalizedError, Sendable, Equatable {
        public let stage: String
        public let message: String
        public var errorDescription: String? { "\(stage): \(message)" }
    }

    public struct Result: Sendable, Equatable {
        public let androidId: String
        public let email: String
        public let masterToken: String
        public let photosAccessToken: String
        public let photosTokenExpiry: Date?
        public let authData: String
        public let encrypted: Bool

        public init(
            androidId: String,
            email: String,
            masterToken: String,
            photosAccessToken: String,
            photosTokenExpiry: Date?,
            authData: String,
            encrypted: Bool
        ) {
            self.androidId = androidId
            self.email = email
            self.masterToken = masterToken
            self.photosAccessToken = photosAccessToken
            self.photosTokenExpiry = photosTokenExpiry
            self.authData = authData
            self.encrypted = encrypted
        }
    }

    private static let authURL = URL(string: "https://android.clients.google.com/auth")!
    private static let androidSig = "38918a453d07199354f8b19af05ec6562ced5788"
    private static let photosSig = "24bb24c05e47e0aefa68a58a766179d9b613a600"

    public static func run(
        oauthToken: String,
        androidId: String = randomAndroidId(),
        session: URLSession = .shared,
        requestPolicy: @Sendable (inout URLRequest) -> Void = { _ in }
    ) async throws -> Result {
        let (masterToken, email, enc1) = try await exchangeOAuthToken(
            oauthToken: oauthToken,
            androidId: androidId,
            session: session,
            requestPolicy: requestPolicy
        )

        let cred = googlePhotosCredentialBody(androidId: androidId, email: email, masterToken: masterToken)
        let (accessToken, expiry, enc2) = try await redeemCredential(body: cred, session: session, requestPolicy: requestPolicy)

        return Result(
            androidId: androidId,
            email: email,
            masterToken: masterToken,
            photosAccessToken: accessToken,
            photosTokenExpiry: expiry,
            authData: cred,
            encrypted: enc1 || enc2
        )
    }

    static func oauthExchangeBody(oauthToken: String, androidId: String) -> [(String, String)] {
        [
            ("accountType", "HOSTED_OR_GOOGLE"),
            ("Email", "oauth-token@example.com"),
            ("has_permission", "1"),
            ("add_account", "1"),
            ("ACCESS_TOKEN", "1"),
            ("Token", oauthToken),
            ("service", "ac2dm"),
            ("source", "android"),
            ("androidId", androidId),
            ("device_country", "us"),
            ("operatorCountry", "us"),
            ("lang", "en"),
            ("sdk_version", "17"),
            ("google_play_services_version", "240913000"),
            ("client_sig", androidSig),
            ("callerSig", androidSig),
            ("droidguard_results", "dummy123"),
        ]
    }

    static func makeRequest(formPairs: [(String, String)]) -> URLRequest {
        var req = URLRequest(url: authURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("GoogleAuth/1.4", forHTTPHeaderField: "User-Agent")
        req.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        req.httpBody = Data(encodeForm(formPairs).utf8)
        req.timeoutInterval = 60
        return req
    }

    private static func exchangeOAuthToken(
        oauthToken: String,
        androidId: String,
        session: URLSession,
        requestPolicy: @Sendable (inout URLRequest) -> Void
    ) async throws -> (String, String, Bool) {
        var req = makeRequest(formPairs: oauthExchangeBody(oauthToken: oauthToken, androidId: androidId))
        requestPolicy(&req)
        let (data, _) = try await send(req, session: session, stage: "master token")
        let fields = parseAuthResponse(data)

        if let err = fields["Error"] {
            throw Failure(stage: "master token",
                          message: googleError(err, url: fields["Url"], detail: fields["ErrorDetail"]))
        }
        guard let token = fields["Token"], !token.isEmpty else {
            throw Failure(stage: "master token",
                          message: "Google accepted the request but returned no master token.")
        }
        let email = fields["Email"].flatMap(normaliseEmail) ?? "unknown"
        let encrypted = fields["TokenEncrypted"] == "1"
        return (token, email, encrypted)
    }

    public static func googlePhotosCredentialPairs(androidId: String, email: String, masterToken: String) -> [(String, String)] {
        [
            ("androidId", androidId),
            ("app", "com.google.android.apps.photos"),
            ("callerPkg", "com.google.android.apps.photos"),
            ("callerSig", photosSig),
            ("client_sig", photosSig),
            ("device_country", "us"),
            ("Email", email),
            ("google_play_services_version", "240913000"),
            ("lang", "en_US"),
            ("oauth2_foreground", "1"),
            ("operatorCountry", "us"),
            ("sdk_version", "33"),
            ("service", "oauth2:openid https://www.googleapis.com/auth/mobileapps.native https://www.googleapis.com/auth/photos.native"),
            ("source", "android"),
            ("Token", masterToken),
        ]
    }

    public static func googlePhotosCredentialBody(androidId: String, email: String, masterToken: String) -> String {
        encodeForm(googlePhotosCredentialPairs(androidId: androidId, email: email, masterToken: masterToken))
    }

    private static func redeemCredential(
        body: String,
        session: URLSession,
        requestPolicy: @Sendable (inout URLRequest) -> Void
    ) async throws -> (String, Date?, Bool) {
        var req = URLRequest(url: authURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("GoogleAuth/1.4", forHTTPHeaderField: "User-Agent")
        req.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        req.httpBody = Data(body.utf8)
        req.timeoutInterval = 60
        requestPolicy(&req)
        let (data, _) = try await send(req, session: session, stage: "photos token")
        let fields = parseAuthResponse(data)

        if let err = fields["Error"] {
            throw Failure(stage: "photos token", message: googleError(err, url: fields["Url"], detail: fields["ErrorDetail"]))
        }
        if fields["TokenEncrypted"] == "1" {
            throw Failure(stage: "photos token",
                          message: "Google returned TokenEncrypted=1 (token binding). This build requires unbound tokens.")
        }
        guard let auth = fields["Auth"], !auth.isEmpty else {
            throw Failure(stage: "photos token", message: "No Auth field in the response.")
        }
        let expiry = fields["Expiry"].flatMap(TimeInterval.init).map { Date(timeIntervalSince1970: $0) }
        return (auth, expiry, false)
    }

    private static func send(
        _ req: URLRequest,
        session: URLSession,
        stage: String
    ) async throws -> (Data, HTTPURLResponse) {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await ForegroundFileUploadTransport(configuration: session.configuration).requestData(req)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw Failure(stage: stage, message: "Could not reach Google authentication service.")
        }
        guard let http = response as? HTTPURLResponse else {
            throw Failure(stage: stage, message: "Non-HTTP response.")
        }
        if (300..<400).contains(http.statusCode) {
            throw Failure(stage: stage, message: "Google redirected the auth request (HTTP \(http.statusCode)); token rejected.")
        }
        if http.statusCode == 200 || http.statusCode == 403 {
            return (data, http)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw Failure(stage: stage, message: "Authentication service returned HTTP \(http.statusCode).")
        }
        return (data, http)
    }

    static func parseAuthResponse(_ data: Data) -> [String: String] {
        var out: [String: String] = [:]
        for line in String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline) {
            guard let eq = line.firstIndex(of: "=") else { continue }
            out[String(line[..<eq])] = String(line[line.index(after: eq)...])
        }
        return out
    }

    private static func googleError(_ code: String, url: String?, detail: String?) -> String {
        switch code {
        case "BadAuthentication":
            return "BadAuthentication — the oauth_token is invalid or expired."
        case "NeedsBrowser", "DeviceManagementRequiredOrSyncDisabled":
            return "\(code) — Google requested interactive challenge."
        default:
            // Unknown code/detail/challenge URLs may contain private server data.
            return "Google rejected authentication; interactive sign-in may be required."
        }
    }

    private static func normaliseEmail(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") ? trimmed : nil
    }

    static func encodeForm(_ pairs: [(String, String)]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return pairs.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
    }

    public static func randomAndroidId() -> String {
        let hex = "0123456789abcdef"
        return String((0..<16).map { _ in hex.randomElement()! })
    }
}
