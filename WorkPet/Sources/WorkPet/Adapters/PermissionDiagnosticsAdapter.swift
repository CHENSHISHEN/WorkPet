import EventKit
import ApplicationServices
import Foundation

@MainActor
final class PermissionDiagnosticsAdapter: NotificationAdapter {
    let name = "Permission Diagnostics"

    private let notificationCandidates: [(directoryPath: String, dbPath: String)]
    private let datagripWatchPath: String

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.notificationCandidates = SystemNotificationAdapter.notificationDatabaseCandidates(home: home)
        self.datagripWatchPath = "\(home)/Library/Application Support/WorkPet/datagrip-tasks"
    }

    func start(emit: @escaping (WorkNotification) -> Void) {
        let findings = [
            calendarPermissionStatus(),
            remindersPermissionStatus(),
            notificationDatabaseStatus(),
            accessibilityPermissionStatus(),
            dataGripWatchStatus()
        ]

        let hasWarning = findings.contains { $0.hasPrefix("待处理") || $0.hasPrefix("异常") }
        let title = hasWarning ? "WorkPet 启动检查：需要配置" : "WorkPet 启动检查完成"

        emit(
            WorkNotification(
                source: .workpet,
                title: title,
                body: findings.joined(separator: "\n"),
                metadata: [
                    "adapter": "PermissionDiagnostics",
                    "hasWarning": hasWarning ? "true" : "false"
                ]
            )
        )
    }

    private func calendarPermissionStatus() -> String {
        let status = EKEventStore.authorizationStatus(for: .event)

        if #available(macOS 14.0, *) {
            switch status {
            case .fullAccess:
                return "正常：日历完全访问已授权"
            case .writeOnly:
                return "待处理：日历仅写入权限，无法读取今日待办"
            case .notDetermined:
                return "待处理：日历权限尚未授权"
            case .denied, .restricted:
                return "异常：日历权限被拒绝"
            case .authorized:
                return "正常：日历访问已授权"
            @unknown default:
                return "待处理：未知日历权限状态"
            }
        }

        switch status {
        case .authorized:
            return "正常：日历访问已授权"
        case .fullAccess:
            return "正常：日历完全访问已授权"
        case .writeOnly:
            return "待处理：日历仅写入权限，无法读取今日待办"
        case .notDetermined:
            return "待处理：日历权限尚未授权"
        case .denied, .restricted:
            return "异常：日历权限被拒绝"
        @unknown default:
            return "待处理：未知日历权限状态"
        }
    }

    private func remindersPermissionStatus() -> String {
        let status = EKEventStore.authorizationStatus(for: .reminder)

        if #available(macOS 14.0, *) {
            switch status {
            case .fullAccess:
                return "正常：提醒事项完全访问已授权"
            case .writeOnly:
                return "待处理：提醒事项仅写入权限，无法读取今日提醒"
            case .notDetermined:
                return "待处理：提醒事项权限尚未授权"
            case .denied, .restricted:
                return "异常：提醒事项权限被拒绝"
            case .authorized:
                return "正常：提醒事项访问已授权"
            @unknown default:
                return "待处理：未知提醒事项权限状态"
            }
        }

        switch status {
        case .authorized:
            return "正常：提醒事项访问已授权"
        case .fullAccess:
            return "正常：提醒事项完全访问已授权"
        case .writeOnly:
            return "待处理：提醒事项仅写入权限，无法读取今日提醒"
        case .notDetermined:
            return "待处理：提醒事项权限尚未授权"
        case .denied, .restricted:
            return "异常：提醒事项权限被拒绝"
        @unknown default:
            return "待处理：未知提醒事项权限状态"
        }
    }

    private func notificationDatabaseStatus() -> String {
        let fileManager = FileManager.default

        guard let notificationDbPath = notificationCandidates.first(where: { fileManager.fileExists(atPath: $0.dbPath) })?.dbPath else {
            let paths = notificationCandidates.map(\.dbPath).joined(separator: "、")
            return "异常：通知数据库未找到，已尝试：\(paths)"
        }

        guard fileManager.isReadableFile(atPath: notificationDbPath) else {
            return "待处理：通知数据库不可读，需要给 WorkPet 全盘访问权限"
        }

        if let sqliteError = notificationDatabaseSQLiteError(notificationDbPath) {
            return "待处理：通知数据库 sqlite 读取失败，需要给当前运行方式全盘访问权限（\(sqliteError)）"
        }

        return "正常：通知数据库可读"
    }

    private func notificationDatabaseSQLiteError(_ notificationDbPath: String) -> String? {
        do {
            _ = try NotificationSQLiteReader.query(dbPath: notificationDbPath, sql: "SELECT count(*) FROM record LIMIT 1;")
            return nil
        } catch {
            return "\(error)"
        }
    }

    private func accessibilityPermissionStatus() -> String {
        let trusted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false
        ] as CFDictionary)

        return trusted
            ? "正常：辅助功能权限已授权，可监听菜单栏未读角标"
            : "待处理：辅助功能权限未授权，无法监听微信/飞书菜单栏未读角标"
    }

    private func dataGripWatchStatus() -> String {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: datagripWatchPath) {
            do {
                try fileManager.createDirectory(atPath: datagripWatchPath, withIntermediateDirectories: true)
            } catch {
                return "异常：DataGrip 监听目录创建失败"
            }
        }

        guard fileManager.isWritableFile(atPath: datagripWatchPath) else {
            return "异常：DataGrip 监听目录不可写"
        }

        return "正常：DataGrip 监听目录可写"
    }
}
