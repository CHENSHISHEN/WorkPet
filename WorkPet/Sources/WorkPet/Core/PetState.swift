import Foundation

enum PetMood: String {
    case idle       // 发呆
    case happy      // 开心
    case curious    // 好奇
    case excited    // 兴奋
    case focused    // 专注
    case sleepy     // 困了
    case startled   // 吓一跳
    case love       // 喜爱
}

enum PetAction: String {
    case resting    // 静坐
    case breathing  // 呼吸
    case waving     // 挥手
    case bouncing   // 弹跳
    case wiggling   // 扭动
    case spinning   // 转圈
    case squishing  // 被按压
    case sleeping   // 睡觉
    case hiding     // 躲藏
}

enum PetVisualState: String {
    case idle
    case standing
    case datagrip
    case feishu
    case wechat

    static func from(source: NotificationSource) -> PetVisualState {
        let normalized = NotificationSource.from(bundleIdentifier: source.bundleIdentifier)

        switch normalized.bundleIdentifier {
        case NotificationSource.datagrip.bundleIdentifier:
            return .datagrip
        case NotificationSource.feishu.bundleIdentifier:
            return .feishu
        case NotificationSource.wechat.bundleIdentifier:
            return .wechat
        default:
            return .standing
        }
    }
}

struct PetState: Equatable {
    let mood: PetMood
    let action: PetAction
    let message: String?
    let visualState: PetVisualState

    init(
        mood: PetMood,
        action: PetAction,
        message: String?,
        visualState: PetVisualState = .standing
    ) {
        self.mood = mood
        self.action = action
        self.message = message
        self.visualState = visualState
    }

    static let idle = PetState(mood: .idle, action: .breathing, message: nil, visualState: .idle)

    static func from(_ routed: RoutedNotification) -> PetState {
        let display = notificationDisplayParts(for: routed.notification)
        let visualState = PetVisualState.from(source: routed.notification.source)
        switch routed.level {
        case .strong:
            return PetState(
                mood: .excited,
                action: .bouncing,
                message: notificationMessage(
                    source: routed.notification.source.displayName,
                    title: display.title,
                    body: display.body,
                    includeSource: true
                ),
                visualState: visualState
            )
        case .normal:
            return PetState(
                mood: .curious,
                action: .waving,
                message: notificationMessage(
                    source: routed.notification.source.displayName,
                    title: display.title,
                    body: display.body,
                    includeSource: false
                ),
                visualState: visualState
            )
        case .silent:
            return PetState(
                mood: .focused,
                action: .resting,
                message: nil,
                visualState: visualState
            )
        }
    }

    private static func notificationDisplayParts(for notification: WorkNotification) -> (title: String, body: String) {
        let metadataSender = firstCleanValue(
            notification.metadata["sender"],
            notification.metadata["conversation"]
        )
        let title = notification.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = notification.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyPrefix = shouldExtractSenderPrefix(from: notification) ? senderPrefix(from: body) : nil
        let sender = firstCleanValue(metadataSender, bodyPrefix?.sender)
        let displayBody: String
        if let bodyPrefix, sender.caseInsensitiveCompare(bodyPrefix.sender) == .orderedSame {
            displayBody = bodyPrefix.body
        } else {
            displayBody = body
        }

        guard !sender.isEmpty else {
            return (title, displayBody)
        }

        guard !title.isEmpty, sender.caseInsensitiveCompare(title) != .orderedSame else {
            return (sender, displayBody)
        }

        return (sender, displayBody)
    }

    private static func notificationMessage(
        source: String,
        title: String,
        body: String,
        includeSource: Bool
    ) -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = body
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "  ")

        let header: String
        if includeSource {
            header = cleanTitle.isEmpty ? source : "\(source): \(cleanTitle)"
        } else {
            header = cleanTitle.isEmpty ? source : cleanTitle
        }

        guard !cleanBody.isEmpty else {
            return header
        }

        return "\(header)\n\(cleanBody)"
    }

    private static func firstCleanValue(_ values: String?...) -> String {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
    }

    private static func senderPrefix(from body: String) -> (sender: String, body: String)? {
        let firstLine = body
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard firstLine.count <= 220 else {
            return nil
        }

        let separators = [":", "："]
        for separator in separators {
            let parts = firstLine.split(separator: Character(separator), maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else {
                continue
            }

            let sender = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let remaining = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard isLikelySender(sender), !remaining.isEmpty else {
                continue
            }

            return (sender, remaining)
        }

        return nil
    }

    private static func shouldExtractSenderPrefix(from notification: WorkNotification) -> Bool {
        if notification.metadata["sender"] != nil || notification.metadata["conversation"] != nil {
            return true
        }

        if notification.metadata["messageCategory"] != nil {
            return true
        }

        return notification.source == .wechat || notification.source == .feishu
    }

    private static func isLikelySender(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 40 else {
            return false
        }

        let lowercased = value.lowercased()
        return !lowercased.hasPrefix("http")
            && !lowercased.contains("/")
            && !lowercased.contains("\\")
    }
}
