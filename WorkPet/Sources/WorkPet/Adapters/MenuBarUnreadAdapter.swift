import AppKit
import ApplicationServices
import Foundation

@MainActor
final class MenuBarUnreadAdapter: NotificationAdapter {
    let name = "Menu Bar Unread"

    private struct TargetApp {
        let bundleIdentifiers: Set<String>
        let source: NotificationSource
        let displayName: String
    }

    private let targets: [TargetApp] = [
        TargetApp(
            bundleIdentifiers: [
                "com.tencent.xinWeChat",
                "com.tencent.xinWeChat64",
                "com.tencent.flue.WeChatAppEx"
            ],
            source: .wechat,
            displayName: "微信"
        ),
        TargetApp(
            bundleIdentifiers: [
                "com.electron.lark",
                "com.electron.lark-notifier",
                "com.bytedance.lark"
            ],
            source: .feishu,
            displayName: "飞书"
        )
    ]

    private var timer: Timer?
    private var lastCounts: [String: Int] = [:]
    private var hasReportedPermission = false

    func start(emit: @escaping (WorkNotification) -> Void) {
        guard isAccessibilityTrusted else {
            reportPermissionIfNeeded(emit: emit)
            startPermissionRetry(emit: emit)
            return
        }

        startPolling(emit: emit)
    }

    private var isAccessibilityTrusted: Bool {
        AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false
        ] as CFDictionary)
    }

    private func startPermissionRetry(emit: @escaping (WorkNotification) -> Void) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }

                if self.isAccessibilityTrusted {
                    self.startPolling(emit: emit)
                } else {
                    self.reportPermissionIfNeeded(emit: emit)
                }
            }
        }
    }

    private func startPolling(emit: @escaping (WorkNotification) -> Void) {
        timer?.invalidate()
        poll(emit: emit)
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll(emit: emit)
            }
        }
    }

    private func reportPermissionIfNeeded(emit: @escaping (WorkNotification) -> Void) {
        guard !hasReportedPermission else {
            return
        }

        hasReportedPermission = true
        emit(
            WorkNotification(
                source: .workpet,
                title: "微信/飞书未读角标监听未开启",
                body: "菜单栏未读数不是 macOS 通知事件。若要监听截图里的微信/飞书角标，请在“系统设置 > 隐私与安全性 > 辅助功能”里允许当前运行的 WorkPet 或终端。",
                metadata: ["adapter": "MenuBarUnread", "status": "accessibilityRequired"]
            )
        )
    }

    private func poll(emit: @escaping (WorkNotification) -> Void) {
        for target in targets {
            guard let count = unreadCount(for: target) else {
                continue
            }

            let key = target.source.bundleIdentifier
            let previous = lastCounts[key] ?? 0
            lastCounts[key] = count

            guard count > 0, count != previous else {
                continue
            }

            emit(
                WorkNotification(
                    source: target.source,
                    title: "\(target.displayName) 未读消息",
                    body: "\(target.displayName) 当前有 \(count) 条未读消息。",
                    metadata: [
                        "adapter": "MenuBarUnread",
                        "unreadCount": "\(count)"
                    ]
                )
            )
        }
    }

    private func unreadCount(for target: TargetApp) -> Int? {
        let runningApps = NSWorkspace.shared.runningApplications.filter { app in
            guard let bundleIdentifier = app.bundleIdentifier else {
                return false
            }
            return target.bundleIdentifiers.contains(bundleIdentifier)
        }

        for app in runningApps {
            let element = AXUIElementCreateApplication(app.processIdentifier)
            let texts = accessibilityTexts(from: element, maxDepth: 4, maxItems: 160)
            if let count = extractUnreadCount(from: texts) {
                return count
            }
        }

        return nil
    }

    private func accessibilityTexts(
        from element: AXUIElement,
        maxDepth: Int,
        maxItems: Int
    ) -> [String] {
        var texts: [String] = []
        var visited = 0

        func visit(_ element: AXUIElement, depth: Int) {
            guard depth <= maxDepth, visited < maxItems else {
                return
            }

            visited += 1

            for attribute in [
                kAXTitleAttribute,
                kAXDescriptionAttribute,
                kAXValueAttribute,
                kAXHelpAttribute
            ] {
                if let text = stringAttribute(attribute, from: element), !text.isEmpty {
                    texts.append(text)
                }
            }

            for attribute in [
                kAXExtrasMenuBarAttribute,
                kAXMenuBarAttribute,
                kAXChildrenAttribute
            ] {
                for child in elementArrayAttribute(attribute, from: element) {
                    visit(child, depth: depth + 1)
                }
            }
        }

        visit(element, depth: 0)
        return texts
    }

    private func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }

        if let string = value as? String {
            return string
        }

        if let number = value as? NSNumber {
            return number.stringValue
        }

        return nil
    }

    private func elementArrayAttribute(_ attribute: String, from element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return []
        }

        if let elements = value as? [AXUIElement] {
            return elements
        }

        if let element = value, CFGetTypeID(element) == AXUIElementGetTypeID() {
            return [element as! AXUIElement]
        }

        return []
    }

    private func extractUnreadCount(from texts: [String]) -> Int? {
        let combined = texts.joined(separator: " ")
        let pattern = #"(?<![\d.])([1-9]\d{0,2})(?![\d.])"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(combined.startIndex..<combined.endIndex, in: combined)
        let counts = regex.matches(in: combined, range: range).compactMap { match -> Int? in
            guard let matchRange = Range(match.range(at: 1), in: combined) else {
                return nil
            }
            return Int(combined[matchRange])
        }

        return counts.min()
    }
}
