import Foundation

final class SourceRuleEngine {
    private let defaultLevel: NotificationLevel
    private let sourceLevels: [String: NotificationLevel]
    private let messageApps: [MessageAppRule]

    init(
        defaultLevel: NotificationLevel = .normal,
        sourceLevels: [String: NotificationLevel] = [:],
        messageApps: [MessageAppRule] = []
    ) {
        self.defaultLevel = defaultLevel
        self.sourceLevels = sourceLevels
        self.messageApps = messageApps
    }

    convenience init(configuration: SourceRulesConfiguration) {
        self.init(
            defaultLevel: configuration.defaultLevel,
            sourceLevels: configuration.sources.reduce(into: [:]) { result, rule in
                result[rule.bundleIdentifier] = rule.level
            },
            messageApps: configuration.messageApps
        )
    }

    func level(for source: NotificationSource) -> NotificationLevel {
        sourceLevels[source.bundleIdentifier] ?? defaultLevel
    }

    func level(for notification: WorkNotification) -> NotificationLevel {
        guard let messageApp = messageApps.first(where: { $0.matches(source: notification.source) }) else {
            return level(for: notification.source)
        }

        let context = MessageRuleContext(notification: notification)
        let category = context.category

        if let level = messageApp.blacklist.first(where: { $0.matches(context: context) })?.effectiveLevel {
            return level
        }

        if let level = messageApp.whitelist.first(where: { $0.matches(context: context) })?.effectiveLevel {
            return level
        }

        if let level = messageApp.categories?[category] {
            return level
        }

        return messageApp.defaultLevel ?? sourceLevels[notification.source.bundleIdentifier] ?? defaultLevel
    }
}

struct SourceRulesConfiguration: Codable {
    let defaultLevel: NotificationLevel
    let sources: [SourceRule]
    let messageApps: [MessageAppRule]

    enum CodingKeys: String, CodingKey {
        case defaultLevel
        case sources
        case messageApps
    }

    init(
        defaultLevel: NotificationLevel,
        sources: [SourceRule],
        messageApps: [MessageAppRule] = []
    ) {
        self.defaultLevel = defaultLevel
        self.sources = sources
        self.messageApps = messageApps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.defaultLevel = try container.decodeIfPresent(NotificationLevel.self, forKey: .defaultLevel) ?? .normal
        self.sources = try container.decodeIfPresent([SourceRule].self, forKey: .sources) ?? []
        self.messageApps = try container.decodeIfPresent([MessageAppRule].self, forKey: .messageApps) ?? []
    }

    static let fallback = SourceRulesConfiguration(
        defaultLevel: .normal,
        sources: [
            SourceRule(bundleIdentifier: NotificationSource.calendar.bundleIdentifier, level: .strong),
            SourceRule(bundleIdentifier: NotificationSource.datagrip.bundleIdentifier, level: .strong)
        ]
    )
}

struct SourceRule: Codable {
    let bundleIdentifier: String
    let level: NotificationLevel
}

struct MessageAppRule: Codable {
    let id: String
    let displayName: String
    let bundleIdentifiers: [String]
    let defaultLevel: NotificationLevel?
    let categories: [MessageCategory: NotificationLevel]?
    let whitelist: [MessageMatchRule]
    let blacklist: [MessageMatchRule]

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case bundleIdentifiers
        case defaultLevel
        case categories
        case whitelist
        case blacklist
    }

    init(
        id: String,
        displayName: String,
        bundleIdentifiers: [String],
        defaultLevel: NotificationLevel?,
        categories: [MessageCategory: NotificationLevel]?,
        whitelist: [MessageMatchRule],
        blacklist: [MessageMatchRule]
    ) {
        self.id = id
        self.displayName = displayName
        self.bundleIdentifiers = bundleIdentifiers
        self.defaultLevel = defaultLevel
        self.categories = categories
        self.whitelist = whitelist
        self.blacklist = blacklist
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? id
        self.bundleIdentifiers = try container.decodeIfPresent([String].self, forKey: .bundleIdentifiers) ?? []
        self.defaultLevel = try container.decodeIfPresent(NotificationLevel.self, forKey: .defaultLevel)
        self.categories = try container.decodeIfPresent([MessageCategory: NotificationLevel].self, forKey: .categories)
        self.whitelist = try container.decodeIfPresent([MessageMatchRule].self, forKey: .whitelist) ?? []
        self.blacklist = try container.decodeIfPresent([MessageMatchRule].self, forKey: .blacklist) ?? []
    }

    func matches(source: NotificationSource) -> Bool {
        bundleIdentifiers.contains(source.bundleIdentifier)
    }
}

struct MessageMatchRule: Codable {
    let category: MessageCategory?
    let senderContains: [String]?
    let titleContains: [String]?
    let bodyContains: [String]?
    let contains: [String]?
    let level: NotificationLevel?

    init(
        category: MessageCategory?,
        senderContains: [String]?,
        titleContains: [String]?,
        bodyContains: [String]?,
        contains: [String]?,
        level: NotificationLevel?
    ) {
        self.category = category
        self.senderContains = senderContains
        self.titleContains = titleContains
        self.bodyContains = bodyContains
        self.contains = contains
        self.level = level
    }

    var effectiveLevel: NotificationLevel {
        level ?? .normal
    }

    func matches(context: MessageRuleContext) -> Bool {
        if let category, category != context.category {
            return false
        }

        return matchesAny(senderContains, in: context.sender)
            || matchesAny(titleContains, in: context.title)
            || matchesAny(bodyContains, in: context.body)
            || matchesAny(contains, in: context.combinedText)
            || category != nil && senderContains == nil && titleContains == nil && bodyContains == nil && contains == nil
    }

    private func matchesAny(_ needles: [String]?, in haystack: String) -> Bool {
        guard let needles, !needles.isEmpty else {
            return false
        }

        let lowercasedHaystack = haystack.lowercased()
        return needles.contains { needle in
            lowercasedHaystack.contains(needle.lowercased())
        }
    }
}

enum MessageCategory: String, Codable, Hashable {
    case direct
    case group
    case official
    case system
    case unknown
}

struct MessageRuleContext {
    let notification: WorkNotification
    let category: MessageCategory
    let sender: String
    let title: String
    let body: String
    let combinedText: String

    init(notification: WorkNotification) {
        self.notification = notification
        self.sender = notification.metadata["sender"] ?? notification.metadata["conversation"] ?? ""
        self.title = notification.title
        self.body = notification.body
        self.combinedText = [
            sender,
            notification.title,
            notification.body,
            notification.metadata["rawPayload"] ?? ""
        ].joined(separator: " ")
        self.category = MessageRuleContext.resolveCategory(notification: notification, combinedText: combinedText)
    }

    private static func resolveCategory(notification: WorkNotification, combinedText: String) -> MessageCategory {
        if let rawCategory = notification.metadata["messageCategory"],
           let category = MessageCategory(rawValue: rawCategory) {
            return category
        }

        let lowercased = combinedText.lowercased()
        if lowercased.contains("公众号")
            || lowercased.contains("订阅号")
            || lowercased.contains("服务号")
            || lowercased.contains("official")
            || lowercased.contains("subscription") {
            return .official
        }

        if lowercased.contains("群")
            || lowercased.contains("group")
            || lowercased.contains("chatroom")
            || lowercased.contains("@all")
            || lowercased.contains("@所有人") {
            return .group
        }

        if lowercased.contains("系统")
            || lowercased.contains("安全")
            || lowercased.contains("登录")
            || lowercased.contains("system")
            || lowercased.contains("security")
            || lowercased.contains("login") {
            return .system
        }

        if !notification.title.isEmpty || !notification.body.isEmpty {
            return .direct
        }

        return .unknown
    }
}

enum SourceRulesLoader {
    static func load() -> SourceRulesConfiguration {
        guard let url = Bundle.module.url(forResource: "source-rules", withExtension: "json") else {
            return .fallback
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SourceRulesConfiguration.self, from: data)
        } catch {
            return .fallback
        }
    }
}
