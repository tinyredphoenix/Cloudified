import Foundation

/// Genuinely immutable, Sendable JSON value model for TDLib interactions.
public enum TDLibValue: Sendable, Equatable {
    case string(String)
    case integer(Int64)
    case double(Double)
    case boolean(Bool)
    case null
    case array([TDLibValue])
    case object([String: TDLibValue])

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var boolValue: Bool? {
        if case .boolean(let b) = self { return b }
        return nil
    }

    public var int32Value: Int32? {
        if case .integer(let n) = self, n >= Int64(Int32.min), n <= Int64(Int32.max) {
            return Int32(n)
        }
        return nil
    }

    public var int64Value: Int64? {
        if case .integer(let n) = self { return n }
        return nil
    }

    public var objectValue: [String: TDLibValue]? {
        if case .object(let dict) = self { return dict }
        return nil
    }

    public var arrayValue: [TDLibValue]? {
        if case .array(let arr) = self { return arr }
        return nil
    }
}

/// Genuinely immutable, Sendable representation of a TDLib response or update dictionary.
public struct TDLibResponse: Sendable, Equatable {
    public let fields: [String: TDLibValue]

    public init(fields: [String: TDLibValue]) {
        self.fields = fields
    }

    public subscript(key: String) -> TDLibValue? {
        fields[key]
    }

    public var type: String? {
        fields["@type"]?.stringValue
    }

    public var isError: Bool {
        type == "error"
    }

    public var errorCode: Int32? {
        fields["code"]?.int32Value
    }

    public var errorMessage: String? {
        fields["message"]?.stringValue
    }

    public var extra: String? {
        fields["@extra"]?.stringValue
    }

    public var clientID: Int32? {
        fields["@client_id"]?.int32Value
    }

    public func int64(forKey key: String) -> Int64? {
        TDLibJSON.parseID(fields[key])
    }

    public func string(forKey key: String) -> String? {
        fields[key]?.stringValue
    }

    public func bool(forKey key: String) -> Bool? {
        fields[key]?.boolValue
    }

    public func object(forKey key: String) -> TDLibResponse? {
        guard let obj = fields[key]?.objectValue else { return nil }
        return TDLibResponse(fields: obj)
    }

    public func array(forKey key: String) -> [TDLibValue]? {
        fields[key]?.arrayValue
    }
}

/// Helpers for TDLib JSON encoding and decoding.
/// Strictly validates 64-bit integer IDs (chat_id, message_id, user_id), rejects rounded/fractional values,
/// enforces size and depth limits, and preserves Sendable value models.
public enum TDLibJSON {
    public static let maxJSONBytes: Int = 10 * 1024 * 1024 // 10 MiB limit
    public static let maxRecursionDepth: Int = 64

    /// Parses a JSON string into an immutable Sendable TDLibResponse.
    public static func parse(_ jsonString: String) throws -> TDLibResponse {
        guard jsonString.utf8.count <= maxJSONBytes else {
            throw TDLibError.malformedResponse
        }
        guard let data = jsonString.data(using: .utf8) else {
            throw TDLibError.malformedResponse
        }
        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw TDLibError.malformedResponse
        }
        guard let dict = jsonObject as? [String: Any] else {
            throw TDLibError.malformedResponse
        }
        let converted = try convertDictionary(dict, depth: 0)
        return TDLibResponse(fields: converted)
    }

    /// Converts Foundation object tree into TDLibValue with depth protection.
    public static func convertValue(_ value: Any, depth: Int) throws -> TDLibValue {
        guard depth <= maxRecursionDepth else {
            throw TDLibError.malformedResponse
        }
        if let s = value as? String {
            return .string(s)
        }
        if let num = value as? NSNumber {
            // Strict check: CFBoolean is distinct from actual numeric numbers
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                return .boolean(num.boolValue)
            }
            let objCType = String(cString: num.objCType)
            if objCType == "d" || objCType == "f" {
                let d = num.doubleValue
                guard d.isFinite else { throw TDLibError.malformedResponse }
                // Never recover identifiers from an already rounded floating value.
                // Double(Int64.max) rounds to 2^63; converting that boundary traps.
                return .double(d)
            }
            guard let integer = Int64(num.stringValue) else { throw TDLibError.malformedResponse }
            return .integer(integer)
        }
        if let arr = value as? [Any] {
            var items: [TDLibValue] = []
            items.reserveCapacity(min(arr.count, 10_000))
            for item in arr {
                items.append(try convertValue(item, depth: depth + 1))
            }
            return .array(items)
        }
        if let dict = value as? [String: Any] {
            return .object(try convertDictionary(dict, depth: depth + 1))
        }
        if value is NSNull {
            return .null
        }
        throw TDLibError.malformedResponse
    }

    public static func convertDictionary(_ dict: [String: Any], depth: Int) throws -> [String: TDLibValue] {
        var result: [String: TDLibValue] = [:]
        for (k, v) in dict {
            result[k] = try convertValue(v, depth: depth)
        }
        return result
    }

    /// Serializes a request dictionary into a UTF-8 JSON string.
    public static func serializeRequest(_ dict: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: dict, options: [])
        guard data.count <= maxJSONBytes else {
            throw TDLibError.malformedResponse
        }
        guard let str = String(data: data, encoding: .utf8) else {
            throw TDLibError.malformedResponse
        }
        return str
    }

    /// Extracts an exact signed 64-bit integer ID.
    /// Rejects Booleans, fractional/rounded floating values, overflowing unsigned numbers, and invalid strings.
    public static func parseID(_ value: TDLibValue?) -> Int64? {
        guard let value else { return nil }
        switch value {
        case .integer(let id):
            return id
        case .string(let str):
            guard let id = Int64(str), String(id) == str else { return nil }
            return id
        case .boolean, .double, .null, .array, .object:
            // Explicitly reject booleans, doubles, nulls, arrays, and objects
            return nil
        }
    }

    /// Legacy parseID overload for raw Any values.
    public static func parseID(_ value: Any?) -> Int64? {
        guard let value else { return nil }
        if let str = value as? String {
            guard let id = Int64(str), String(id) == str else { return nil }
            return id
        }
        if let num = value as? NSNumber {
            // Reject booleans
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                return nil
            }
            let objCType = String(cString: num.objCType)
            // Reject float/double representations that could be fractional or rounded
            if objCType == "d" || objCType == "f" {
                return nil
            }
            return Int64(num.stringValue)
        }
        if let id = value as? Int64 {
            return id
        }
        if let id = value as? Int {
            return Int64(id)
        }
        return nil
    }
}
