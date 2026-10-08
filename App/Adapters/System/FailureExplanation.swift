import Foundation
import CloudifiedCore

enum FailureExplanation {
    static func message(_ failure: SafeFailure) -> String {
        if failure.domain == .fileSystem {
            switch failure.cause {
            case .storageUnavailable:
                return "Cloudified could not prepare its local app storage\(failure.code.map { " (error \($0))" } ?? ""). Close and reopen the app, then retry. If it persists, export diagnostics."
            case .storagePathConflict:
                return "Cloudified found a file or redirected path where a local storage folder is required. Setup stopped to protect existing data. Export diagnostics; do not delete the app's database."
            case .permissionDenied:
                return "iOS denied access to Cloudified's local storage\(failure.code.map { " (error \($0))" } ?? ""). Unlock the iPhone, reopen the app and retry. This is a local storage error."
            default: break
            }
        }
        switch failure.cause {
        case .identityUnverified: return "Google could not verify this account's identity. Reconnect with a supported PhotosBackup login token."
        case .pairingUnverified: return "Google Live Photo pairing could not be verified. Choose an explicit Google Live Photo option in Settings."
        case .pendingSendUnmatched: return "Telegram has an unresolved send. Its input is protected; recover the same account and channel before sending again."
        case .privateChannelRequired: return "Telegram requires a channel you own, with no public username and auto-delete turned off."
        case .accountChanged: return "The account or channel differs from this upload's verified destination. Reconnect the original mapping."
        case .loginRequired: return "Authentication is required. Open this destination in Settings."
        case .permissionDenied: return "Access was denied. Check Photos permission or the destination's permissions."
        case .insufficientSpace: return "More device space is needed to stage the original safely. Other admissible assets can continue."
        case .formatRejected: return "The original format or resource layout is unsupported by this destination. No quality conversion was made."
        case .contentChanged: return "This asset changed while its original was being prepared. Refresh the library and try again."
        case .sourceMissing: return "The original asset is no longer available in the accessible Photos library."
        case .interrupted: return "Work was interrupted. Uncertain sends are checked before another upload."
        case .serverRateLimit: return "The destination requested a delay. Its retry time is retained; the other destination can continue."
        case .deadlineExceeded: return "The request timed out. A missing acknowledgement is checked before another send."
        case .offline: return "Waiting for a network connection. A network path does not guarantee internet access."
        case .lowDataMode: return "Waiting for Low Data Mode to be turned off for this network."
        case .wifiRequired: return "Waiting for Wi-Fi under your network preference."
        case .thermalPressure: return "Waiting for the device to cool before preparing more originals."
        case .backgroundRestricted: return "Background execution is unavailable. Open Cloudified to continue this backup."
        case .backgroundExpired: return "The system ended this backup's background time. Resume to continue safely."
        case .outcomeUnknown: return "Remote acceptance is unknown. Reconciliation is required; the asset will not be blindly resent."
        case .incompleteHistory: return "Remote history is incomplete. Absence cannot yet be proved."
        case .persistenceFailed: return "The local ledger could not persist a change. Saved status cannot be confirmed."
        case .invalidContract: return "An internal consistency check failed. Export the safe diagnostics for investigation."
        case .quotaExceeded: return "The destination reports a storage limit. Check its account status."
        case .providerRejected: return "The destination rejected this operation. Check the technical code below."
        case .disabled: return "This destination is disabled; its backlog is retained."
        case .paused: return "Backup is paused."
        case .storageUnavailable, .storagePathConflict: return "Local app storage is unavailable. Export diagnostics before changing stored data."
        case .unknown: return "The cause is unknown (\(failure.category.rawValue), \(failure.domain.rawValue)\(failure.code.map { ", code \($0)" } ?? ""))."
        }
    }
    static func remedy(_ failure: SafeFailure?) -> String {
        guard let failure else { return "Check the pending operation's status before retrying." }
        if failure.domain == .fileSystem && failure.cause == .permissionDenied {
            return "Unlock the iPhone, reopen Cloudified and retry. Check the local storage error code."
        }
        switch failure.cause {
        case .loginRequired, .identityUnverified, .accountChanged: return "Reconnect the correct destination in Settings."
        case .pendingSendUnmatched, .outcomeUnknown, .incompleteHistory: return "Recover the existing destination; do not resend while acceptance is uncertain."
        case .insufficientSpace: return "Free device space, then retry this asset."
        case .permissionDenied, .sourceMissing: return "Check Photos access and availability of the original."
        case .pairingUnverified: return "Select an explicit Google Live Photo policy."
        case .serverRateLimit, .offline, .wifiRequired: return "Wait for the listed retry time or an allowed network."
        case .storageUnavailable: return "Unlock the iPhone, reopen Cloudified and retry. Export diagnostics if setup still fails."
        case .storagePathConflict: return "Export diagnostics for investigation. Keep existing local data intact."
        default: return "Review the safe error code and export diagnostics if the error persists."
        }
    }
    static func requiresReconciliation(_ failure: SafeFailure?) -> Bool {
        guard let failure else { return false }
        return [.outcomeUnknown, .pendingSendUnmatched, .incompleteHistory].contains(failure.cause)
    }
}
