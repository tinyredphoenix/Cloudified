import Foundation

extension AppEnvironment {
    public func createTelegramChannelDiscovery() -> TelegramChannelDiscovery? {
        guard let client = tdlibClient else { return nil }
        return TelegramChannelDiscovery(client: client)
    }
}
