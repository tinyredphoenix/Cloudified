import Foundation

public struct TelegramChannel: Identifiable, Sendable, Equatable {
    public let id: Int64
    public let title: String
}

public actor TelegramChannelDiscovery {
    private let client: TDLibClient
    private var isExhausted = false
    private var loadedChats = Set<Int64>()
    
    public init(client: TDLibClient) {
        self.client = client
    }
    
    public func discoverMore(limit: Int = 50) async throws -> (channels: [TelegramChannel], hasMore: Bool) {
        guard !isExhausted else { return ([], false) }
        
        do {
            _ = try await client.request([
                "@type": "loadChats",
                "chat_list": ["@type": "chatListMain"],
                "limit": limit
            ])
        } catch let error as SafeFailure {
            if error.code == 404 {
                isExhausted = true
            } else {
                throw error
            }
        } catch {
            let safe = TDLibClient.classify(error)
            if safe.code == 404 {
                isExhausted = true
            } else {
                throw safe
            }
        }
        
        let chatsResponse = try await client.request([
            "@type": "getChats",
            "chat_list": ["@type": "chatListMain"],
            "limit": 1000
        ])
        
        guard let chatIds = chatsResponse.array(forKey: "chat_ids") else {
            return ([], !isExhausted)
        }
        
        var results: [TelegramChannel] = []
        
        for chatIdVal in chatIds {
            try Task.checkCancellation()
            guard let chatId = TDLibJSON.parseID(chatIdVal), !loadedChats.contains(chatId) else { continue }
            loadedChats.insert(chatId)
            
            do {
                let chat = try await client.request(["@type": "getChat", "chat_id": chatId])
                guard chat["message_auto_delete_time"]?.int32Value == 0 else { continue }
                guard let type = chat.object(forKey: "type"), 
                      type.type == "chatTypeSupergroup", 
                      type["is_channel"]?.boolValue == true, 
                      let groupID = type["supergroup_id"]?.int64Value else { continue }
                
                let group = try await client.request(["@type": "getSupergroup", "supergroup_id": groupID])
                let isCreator = group.object(forKey: "status")?.type == "chatMemberStatusCreator"
                let isMember = group.object(forKey: "status")?["is_member"]?.boolValue == true
                let isPrivate = group.object(forKey: "usernames") == nil || group.object(forKey: "usernames")?.array(forKey: "active_usernames")?.isEmpty == true
                
                if isCreator && isMember && isPrivate {
                    let title = chat.string(forKey: "title") ?? "Unnamed Channel"
                    results.append(TelegramChannel(id: chatId, title: title))
                }
            } catch {
                continue
            }
        }
        
        return (results, !isExhausted)
    }
}
