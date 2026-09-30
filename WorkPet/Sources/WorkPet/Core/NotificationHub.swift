import Foundation

@MainActor
final class NotificationHub {
    typealias Handler = (RoutedNotification) -> Void

    private let ruleEngine: SourceRuleEngine
    private var handlers: [Handler] = []
    private var recentFingerprints: Set<String> = []
    private var recentOrder: [String] = []
    private let maxRecentCount = 128

    init(ruleEngine: SourceRuleEngine) {
        self.ruleEngine = ruleEngine
    }

    func subscribe(_ handler: @escaping Handler) {
        handlers.append(handler)
    }

    func ingest(_ notification: WorkNotification) {
        let fingerprint = makeFingerprint(for: notification)
        guard remember(fingerprint) else {
            return
        }

        let level = ruleEngine.level(for: notification)
        let routed = RoutedNotification(notification: notification, level: level)
        handlers.forEach { $0(routed) }
    }

    private func makeFingerprint(for notification: WorkNotification) -> String {
        [
            notification.source.bundleIdentifier,
            notification.title,
            notification.body
        ].joined(separator: "|")
    }

    private func remember(_ fingerprint: String) -> Bool {
        guard !recentFingerprints.contains(fingerprint) else {
            return false
        }

        recentFingerprints.insert(fingerprint)
        recentOrder.append(fingerprint)

        if recentOrder.count > maxRecentCount {
            let oldest = recentOrder.removeFirst()
            recentFingerprints.remove(oldest)
        }

        return true
    }
}
