import Foundation

struct WorkNotification: Identifiable, Equatable {
    let id: UUID
    let source: NotificationSource
    let title: String
    let body: String
    let receivedAt: Date
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        source: NotificationSource,
        title: String,
        body: String,
        receivedAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.source = source
        self.title = title
        self.body = body
        self.receivedAt = receivedAt
        self.metadata = metadata
    }
}

struct NotificationSource: Hashable, Codable {
    let bundleIdentifier: String
    let displayName: String

    static let calendar = NotificationSource(
        bundleIdentifier: "com.apple.Calendar",
        displayName: "Calendar"
    )

    static let datagrip = NotificationSource(
        bundleIdentifier: "com.jetbrains.datagrip",
        displayName: "DataGrip"
    )

    static let wechat = NotificationSource(
        bundleIdentifier: "com.tencent.xinWeChat",
        displayName: "WeChat"
    )

    static let feishu = NotificationSource(
        bundleIdentifier: "com.bytedance.lark",
        displayName: "Feishu"
    )

    static let demo = NotificationSource(
        bundleIdentifier: "dev.workpet.demo",
        displayName: "WorkPet Demo"
    )

    static let workpet = NotificationSource(
        bundleIdentifier: "dev.workpet.app",
        displayName: "WorkPet"
    )

    /// 已知 App 的 bundle identifier -> NotificationSource 映射
    static let knownSources: [String: NotificationSource] = [
        "com.tencent.xinWeChat": .wechat,
        "com.tencent.xinWeChat64": .wechat,
        "com.tencent.flue.WeChatAppEx": .wechat,
        "com.tencent.xinWeChat.WeChatMacShare": .wechat,
        "com.bytedance.lark": .feishu,
        "com.electron.lark": .feishu,
        "com.electron.lark-notifier": .feishu,
        "com.jetbrains.datagrip": .datagrip,
        "com.apple.Calendar": .calendar,
        "dev.workpet.app": .workpet
    ]

    /// 根据 bundle identifier 查找或构造 NotificationSource
    static func from(bundleIdentifier: String) -> NotificationSource {
        knownSources[bundleIdentifier] ?? NotificationSource(
            bundleIdentifier: bundleIdentifier,
            displayName: bundleIdentifier.components(separatedBy: ".").last ?? bundleIdentifier
        )
    }
}

enum NotificationLevel: String, Codable, CaseIterable {
    case strong
    case normal
    case silent
}

struct RoutedNotification: Identifiable, Equatable {
    let id: UUID
    let notification: WorkNotification
    let level: NotificationLevel

    init(notification: WorkNotification, level: NotificationLevel) {
        self.id = notification.id
        self.notification = notification
        self.level = level
    }
}
