import Foundation

struct NotificationPayload {
    let sourceHint: String
    let sender: String
    let title: String
    let body: String
    let flattenedText: String
}

enum NotificationPayloadParser {
    static func parse(base64Data: String) -> NotificationPayload? {
        guard
            let data = Data(base64Encoded: base64Data),
            let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        else {
            return nil
        }

        let pairs = flatten(object)
        let flatText = pairs
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        let sourceHint = firstValue(
            keysContaining: ["bundle", "app", "identifier", "section"],
            in: pairs
        )
        let title = firstValue(
            keysContaining: ["title", "subtitle"],
            in: pairs
        )
        let sender = firstValue(
            keysContaining: ["sender", "from", "author", "conversation", "thread"],
            in: pairs
        )
        let body = firstValue(
            keysContaining: ["body", "message", "informative", "text"],
            in: pairs
        )

        return NotificationPayload(
            sourceHint: sourceHint,
            sender: sender,
            title: title,
            body: body,
            flattenedText: flatText
        )
    }

    private static func firstValue(keysContaining needles: [String], in pairs: [(key: String, value: String)]) -> String {
        for needle in needles {
            if let match = pairs.first(where: { pair in
                pair.key.lowercased().contains(needle) && !pair.value.isEmpty
            }) {
                return match.value
            }
        }
        return ""
    }

    private static func flatten(_ object: Any, prefix: String = "") -> [(key: String, value: String)] {
        if let dictionary = object as? [String: Any] {
            return dictionary.flatMap { key, value in
                flatten(value, prefix: prefix.isEmpty ? key : "\(prefix).\(key)")
            }
        }

        if let dictionary = object as? [AnyHashable: Any] {
            return dictionary.flatMap { key, value in
                flatten(value, prefix: prefix.isEmpty ? "\(key)" : "\(prefix).\(key)")
            }
        }

        if let array = object as? [Any] {
            return array.enumerated().flatMap { index, value in
                flatten(value, prefix: "\(prefix)[\(index)]")
            }
        }

        if let data = object as? Data {
            if let nested = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) {
                return flatten(nested, prefix: prefix)
            }
            if let string = String(data: data, encoding: .utf8) {
                return [(prefix, string)]
            }
            return [(prefix, data.base64EncodedString())]
        }

        if let date = object as? Date {
            return [(prefix, ISO8601DateFormatter().string(from: date))]
        }

        return [(prefix, "\(object)")]
    }
}
