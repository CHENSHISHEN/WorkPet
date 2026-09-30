import AppKit
import ApplicationServices
import Foundation

@MainActor
enum NotificationDiagnostics {
    private enum QueryResult {
        case success([[String]])
        case failure(String)
    }

    static func run() -> String {
        [
            notificationDatabaseSummary(),
            accessibilitySummary()
        ].joined(separator: "\n")
    }

    private static func notificationDatabaseSummary() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = SystemNotificationAdapter.notificationDatabaseCandidates(home: home)
        guard let dbPath = candidates.first(where: { FileManager.default.fileExists(atPath: $0.dbPath) })?.dbPath else {
            return "通知库：未找到"
        }

        let schema: NotificationRecordSchema
        do {
            schema = try NotificationRecordSchema(
                columns: Set(
                    try NotificationSQLiteReader
                        .query(dbPath: dbPath, sql: "PRAGMA table_info(record);")
                        .compactMap { $0.indices.contains(1) ? $0[1] : nil }
                )
            )
        } catch {
            return "通知库：schema 读取失败 \(error)"
        }

        switch sqliteQuery(
            dbPath: dbPath,
            sql: schema.selectCandidatesSQL(limit: 3)
        ) {
        case .success(let rows):
            let appMap = appIdentifierMap(dbPath: dbPath)
            if rows.isEmpty {
                return "通知库：可读，但最近没有微信/飞书记录\n最近记录：\(recentRecordsSummary(dbPath: dbPath, schema: schema, appMap: appMap))"
            }
            return "通知库：可读\n\(summarizeNotificationRows(rows, appMap: appMap))"
        case .failure(let error):
            return "通知库：读取失败 \(error)"
        }
    }

    private static func accessibilitySummary() -> String {
        let trusted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false
        ] as CFDictionary)
        guard trusted else {
            return "辅助功能：未授权"
        }

        let apps = NSWorkspace.shared.runningApplications
            .compactMap { app -> String? in
                guard let bundleIdentifier = app.bundleIdentifier else {
                    return nil
                }
                if bundleIdentifier.contains("xinWeChat") || bundleIdentifier.lowercased().contains("lark") {
                    return bundleIdentifier
                }
                return nil
            }

        return apps.isEmpty
            ? "辅助功能：已授权，但未发现微信/飞书进程"
            : "辅助功能：已授权，发现 \(apps.joined(separator: ", "))"
    }

    private static func sqliteQuery(dbPath: String, sql: String) -> QueryResult {
        do {
            return .success(try NotificationSQLiteReader.query(dbPath: dbPath, sql: sql))
        } catch {
            return .failure("\(error)")
        }
    }

    private static func summarizeNotificationRows(_ rows: [[String]], appMap: [String: String]) -> String {
        rows
            .prefix(3)
            .map { columns in
                let rawApp = columns.first ?? "unknown"
                let app = columns.indices.contains(1) && !columns[1].isEmpty ? columns[1] : (appMap[rawApp] ?? rawApp)
                let subtitle = columns.indices.contains(2) ? columns[2] : ""
                let body = columns.indices.contains(3) ? columns[3] : ""
                let data = columns.indices.contains(5) ? columns[5] : ""
                let payload = NotificationPayloadParser.parse(base64Data: data)
                let payloadText = payload.map {
                    [$0.sourceHint, $0.title, $0.body].filter { !$0.isEmpty }.joined(separator: " ")
                } ?? ""
                let displayBody = firstNonEmpty(body, payloadText, data)
                return "- \(app): \(subtitle) \(String(displayBody.prefix(80)))".trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .joined(separator: "\n")
    }

    private static func firstNonEmpty(_ values: String...) -> String {
        values.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
    }

    private static func recentRecordsSummary(dbPath: String, schema: NotificationRecordSchema, appMap: [String: String]) -> String {
        switch sqliteQuery(dbPath: dbPath, sql: schema.selectLatestSQL(limit: 5)) {
        case .success(let rows):
            guard !rows.isEmpty else {
                return "无记录"
            }
            return summarizeNotificationRows(rows, appMap: appMap)
        case .failure(let error):
            return "读取失败 \(error)"
        }
    }

    private static func appIdentifierMap(dbPath: String) -> [String: String] {
        guard
            let schemaRows = try? NotificationSQLiteReader.query(dbPath: dbPath, sql: "PRAGMA table_info(app);"),
            !schemaRows.isEmpty
        else {
            return [:]
        }

        let columns = Set(schemaRows.compactMap { $0.indices.contains(1) ? $0[1] : nil })
        guard
            let idColumn = ["app_id", "id", "rec_id"].first(where: { columns.contains($0) }),
            let identifierColumn = ["identifier", "bundle_id", "bundle_identifier", "app_identifier"].first(where: { columns.contains($0) })
        else {
            return [:]
        }

        let sql = "SELECT \"\(idColumn)\", \"\(identifierColumn)\" FROM app;"
        guard let rows = try? NotificationSQLiteReader.query(dbPath: dbPath, sql: sql) else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: rows.compactMap { row in
            guard row.count >= 2, !row[0].isEmpty, !row[1].isEmpty else {
                return nil
            }
            return (row[0], row[1])
        })
    }
}
