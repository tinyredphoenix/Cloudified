import Foundation
import CloudifiedCore

public struct TelegramChannel: Identifiable, Sendable, Equatable {
    public let id: Int64
    public let title: String
}

public actor TelegramChannelDiscovery {
    private let client: TDLibClient
    private var mainExhausted = false
    private var archiveExhausted = false
    private var loadedChats = Set<Int64>()
    private var discoveryTask: Task<[TelegramChannel], Error>?

    public init(client: TDLibClient) {
        self.client = client
    }

    public func discoverMore(limit: Int = 100) async throws -> (channels: [TelegramChannel], hasMore: Bool) {
        if let existing = discoveryTask { return (try await existing.value, !(mainExhausted && archiveExhausted)) }

        let task = Task {
            var results: [TelegramChannel] = []

            while results.isEmpty && !(mainExhausted && archiveExhausted) {
                try Task.checkCancellation()

                let listType = mainExhausted ? "chatListArchive" : "chatListMain"

                do {
                    _ = try await client.request([
                        "@type": "loadChats",
                        "chat_list": ["@type": listType],
                        "limit": limit
                    ])
                } catch {
                    let safe = ProviderSupport.safe(error, domain: .tdlib)
                    if safe.code == 404 {
                        if mainExhausted { archiveExhausted = true }
                        else { mainExhausted = true }
                    } else {
                        throw safe
                    }
                }

                let chatsResponse = try await client.request([
                    "@type": "getChats",
                    "chat_list": ["@type": listType],
                    "limit": 10000
                ])

                guard let chatIds = chatsResponse.array(forKey: "chat_ids") else { continue }

                for chatIdVal in chatIds {
                    try Task.checkCancellation()
                    guard let chatId = TDLibJSON.parseID(chatIdVal) else { continue }
                    if loadedChats.contains(chatId) { continue }

                    do {
                        let chat = try await client.request(["@type": "getChat", "chat_id": chatId])
                        guard chat["message_auto_delete_time"]?.int32Value == 0 else {
                            loadedChats.insert(chatId); continue
                        }

                        guard let type = chat.object(forKey: "type"),
                              type.type == "chatTypeSupergroup",
                              type["is_channel"]?.boolValue == true,
                              let groupID = type["supergroup_id"]?.int64Value else {
                            loadedChats.insert(chatId); continue
                        }

                        let group = try await client.request(["@type": "getSupergroup", "supergroup_id": groupID])
                        loadedChats.insert(chatId)

                        let isCreator = group.object(forKey: "status")?.type == "chatMemberStatusCreator"
                        let isMember = group.object(forKey: "status")?["is_member"]?.boolValue == true
                        let isPrivate = group.object(forKey: "usernames") == nil || group.object(forKey: "usernames")?.array(forKey: "active_usernames")?.isEmpty == true

                        if isCreator && isMember && isPrivate {
                            let title = chat.string(forKey: "title") ?? "Unnamed Channel"
                            results.append(TelegramChannel(id: chatId, title: title))
                        }
                    } catch {
                        if error is CancellationError { throw error }
                        let safe = ProviderSupport.safe(error, domain: .tdlib)
                        if safe.cause == .interrupted || safe.cause == .offline { throw safe }
                        continue
                    }
                }
            }
            return results
        }

        discoveryTask = task
        defer { discoveryTask = nil }

        let results = try await task.value
        return (results, !(mainExhausted && archiveExhausted))
    }

    public func reset() {
        discoveryTask?.cancel()
        discoveryTask = nil
        mainExhausted = false
        archiveExhausted = false
        loadedChats.removeAll()
    }
}
