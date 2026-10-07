import Foundation

/// Helpers for TDLib JSON encoding and decoding.
/// Strictly preserves 64-bit integer IDs (chat_id, message_id, user_id) without Double rounding.
public enum TDLibJSON {

    /// Parses a JSON string into a top-level dictionary while preserving integer precision.
    public static func parseDictionary(_ jsonString: String) -> [String: Any]? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        do {
            guard let dict = try JSONSerialization.jsonObject(
                with: data,
                options: [.fragmentsAllowed]
            ) as? [String: Any] else {
                return nil
            }
            return dict
        } catch {
            return nil
        }
    }

    /// Serializes a request dictionary into a UTF-8 JSON string.
    public static func serialize(_ dict: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: dict, options: [])
        guard let str = String(data: data, encoding: .utf8) else {
            throw TDLibError.invalidResponse
        }
        return str
    }

    /// Extracts an Int64 ID from a JSON field, supporting both String representation and integer numbers
    /// without converting through a floating-point Double.
    public static func parseID(_ value: Any?) -> Int64? {
        guard let value else { return nil }
        if let str = value as? String {
            return Int64(str)
        }
        if let num = value as? NSNumber {
            // Check if the number is an integer type to avoid Double rounding
            let objCType = String(cString: num.objCType)
            if objCType == "d" || objCType == "f" {
                // If stored as float/double, decode via integer string if safe
                return Int64(num.stringValue)
            }
            return num.int64Value
        }
        if let intVal = value as? Int64 {
            return intVal
        }
        if let intVal = value as? Int {
            return Int64(intVal)
        }
        return nil
    }

    /// Extracts the `@type` discriminator string from a TDLib object dictionary.
    public static func parseType(_ dict: [String: Any]) -> String? {
        dict["@type"] as? String
    }

    /// Extracts the `@extra` correlation string from a TDLib response dictionary.
    public static func parseExtra(_ dict: [String: Any]) -> String? {
        if let extraStr = dict["@extra"] as? String {
            return extraStr
        }
        if let extraNum = dict["@extra"] as? NSNumber {
            return extraNum.stringValue
        }
        return nil
    }

    /// Checks if the dictionary represents a TDLib `error` object and extracts code and message.
    public static func parseError(_ dict: [String: Any]) -> (code: Int32, message: String)? {
        guard parseType(dict) == "error" else { return nil }
        let code = (dict["code"] as? NSNumber)?.int32Value ?? 0
        let message = dict["message"] as? String ?? "Unknown TDLib error"
        return (code, message)
    }
}

/// An immutable, Sendable wrapper around a TDLib response or update dictionary.
public struct TDLibResponse: @unchecked Sendable {
    public let raw: [String: Any]

    public init(_ raw: [String: Any]) {
        self.raw = raw
    }

    public subscript(key: String) -> Any? {
        raw[key]
    }

    public var type: String? {
        raw["@type"] as? String
    }

    public var isError: Bool {
        type == "error"
    }

    public var errorCode: Int? {
        (raw["code"] as? NSNumber)?.intValue ?? raw["code"] as? Int
    }

    public var errorMessage: String? {
        raw["message"] as? String
    }

    public func int64(forKey key: String) -> Int64? {
        TDLibJSON.parseID(raw[key])
    }

    public func string(forKey key: String) -> String? {
        raw[key] as? String
    }

    public func bool(forKey key: String) -> Bool? {
        raw[key] as? Bool
    }

    public func int(forKey key: String) -> Int? {
        (raw[key] as? NSNumber)?.intValue ?? raw[key] as? Int
    }

    public func double(forKey key: String) -> Double? {
        (raw[key] as? NSNumber)?.doubleValue ?? raw[key] as? Double
    }

    public func object(forKey key: String) -> TDLibResponse? {
        (raw[key] as? [String: Any]).map { TDLibResponse($0) }
    }
}
