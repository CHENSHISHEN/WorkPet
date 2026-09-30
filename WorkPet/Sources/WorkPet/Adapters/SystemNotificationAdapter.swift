import Foundation

@MainActor
final class SystemNotificationAdapter: NotificationAdapter {
    let name = "System Notifications"

    private var fileSource: DispatchSourceFileSystemObject?
    private var pollTimer: Timer?
    private var lastSeenDateCreated: Double?
    private var hasReportedQueryFailure = false
    private var schema: NotificationRecordSchema?
    private var appIdentifierById: [String: String] = [:]
    private let dbPath: String
    private let dbDirectoryPath: String
    private let queue = DispatchQueue(label: "dev.workpet.notificationdb", qos: .utility)

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidate = Self.notificationDatabaseCandidates(home: home).first { candidate in
            FileManager.default.fileExists(atPath: candidate.dbPath)
        } ?? Self.notificationDatabaseCandidates(home: home)[0]
        self.dbDirectoryPath = candidate.directoryPath
        self.dbPath = candidate.dbPath
    }

    func start(emit: @escaping (WorkNotification) -> Void) {
        guard FileManager.default.fileExists(atPath: dbPath) else {
            let attemptedPaths = Self.notificationDatabaseCandidates(
                home: FileManager.default.homeDirectoryForCurrentUser.path
            )
                .map { $0.dbPath }
                .joined(separator: "、")
            emit(
                WorkNotification(
                    source: .demo,
                    title: "通知数据库未找到",
                    body: "无法访问 macOS 通知数据库。已尝试：\(attemptedPaths)",
                    metadata: ["adapter": "SystemNotification", "status": "dbNotFound"]
                )
            )
            return
        }

        startFileWatch(emit: emit)
    }

    func stop() {
        fileSource?.cancel()
        fileSource = nil
        pollTimer?.invalidate()
        pollTimer = nil
    }

    static func notificationDatabaseCandidates(home: String) -> [(directoryPath: String, dbPath: String)] {
        [
            "\(home)/Library/Group Containers/group.com.apple.usernoted/db2",
            "\(home)/Library/Group Containers/group.com.apple.usernoted/db"
        ].map { directory in
            (directoryPath: directory, dbPath: "\(directory)/db")
        }
    }

    // MARK: - File Watch

    private func startFileWatch(emit: @escaping (WorkNotification) -> Void) {
        let fd = open(dbDirectoryPath, O_EVTONLY)
        guard fd != -1 else {
            emit(
                WorkNotification(
                    source: .demo,
                    title: "通知数据库打开失败",
                    body: "无法监听 macOS 通知数据库目录。请给当前运行方式授予完全磁盘访问权限。",
                    metadata: ["adapter": "SystemNotification", "status": "openFailed"]
                )
            )
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: queue
        )

        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.pollNewNotifications(emit: emit)
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        self.fileSource = source
        source.resume()

        primeLastSeenCursor(emit: emit)
        startPollingFallback(emit: emit)
    }

    // MARK: - Query Notifications

    private func primeLastSeenCursor(emit: @escaping (WorkNotification) -> Void) {
        do {
            let schema = try loadSchema()
            self.schema = schema
            self.appIdentifierById = loadAppIdentifierMap()
            let rows = try NotificationSQLiteReader.query(dbPath: dbPath, sql: schema.selectMaxDateSQL())
            self.lastSeenDateCreated = rows.first?.first.flatMap(Double.init) ?? 0
        } catch {
            reportQueryFailure("\(error)", emit: emit)
        }
    }

    private func startPollingFallback(emit: @escaping (WorkNotification) -> Void) {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollNewNotifications(emit: emit)
            }
        }
    }

    private func pollNewNotifications(emit: @escaping (WorkNotification) -> Void) {
        let since = lastSeenDateCreated ?? 0
        do {
            let schema = try currentSchema()
            let rows = try NotificationSQLiteReader.query(
                dbPath: dbPath,
                sql: schema.selectRecentSQL(since: since, limit: 30)
            )
            hasReportedQueryFailure = false
            guard !rows.isEmpty else { return }
            parseAndEmit(rows, schema: schema, emit: emit)
        } catch {
            reportQueryFailure("\(error)", emit: emit)
        }
    }

    private func currentSchema() throws -> NotificationRecordSchema {
        if let schema {
            return schema
        }

        let loaded = try loadSchema()
        schema = loaded
        return loaded
    }

    private func loadSchema() throws -> NotificationRecordSchema {
        let rows = try NotificationSQLiteReader.query(dbPath: dbPath, sql: "PRAGMA table_info(record);")
        let columns = rows.compactMap { row in
            row.indices.contains(1) ? row[1] : nil
        }
        return try NotificationRecordSchema(columns: Set(columns))
    }

    private func reportQueryFailure(_ message: String, emit: @escaping (WorkNotification) -> Void) {
        guard !hasReportedQueryFailure else {
            return
        }

        hasReportedQueryFailure = true
        emit(
            WorkNotification(
                source: .workpet,
                title: "微信/飞书通知监听失败",
                body: "WorkPet 无法读取 macOS 通知数据库：\(message.trimmingCharacters(in: .whitespacesAndNewlines))\n请给当前运行的 WorkPet 或终端授予完全磁盘访问权限。",
                metadata: ["adapter": "SystemNotification", "status": "queryFailed"]
            )
        )
    }

    // MARK: - Parse

    private func parseAndEmit(
        _ rows: [[String]],
        schema: NotificationRecordSchema,
        emit: @escaping (WorkNotification) -> Void
    ) {
        for columns in rows {
            guard columns.count >= 6 else { continue }
            let appId = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let enclosingAppId = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let bodyText = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let subtitle = columns[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let dateCreated = Double(columns[4].trimmingCharacters(in: .whitespacesAndNewlines)) ?? lastSeenDateCreated ?? 0
            let dataText = columns[5].trimmingCharacters(in: .whitespacesAndNewlines)
            let titleText = columns.indices.contains(6) ? columns[6].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let payload = NotificationPayloadParser.parse(base64Data: dataText)
            lastSeenDateCreated = max(lastSeenDateCreated ?? 0, dateCreated)

            // 优先用 enclosing_app_id（实际发送通知的 App）
            let bundleId = bestBundleId(appId: appId, enclosingAppId: enclosingAppId, payload: payload)

            // 跳过自身通知
            guard !bundleId.contains("workpet") else { continue }

            let source = NotificationSource.from(bundleIdentifier: bundleId)
            let title = firstNonEmpty(subtitle, titleText, payload?.title, source.displayName)
            let body = firstNonEmpty(bodyText, payload?.body, schema.fallbackBody(appId: appId, subtitle: subtitle, dataText: payload?.flattenedText ?? dataText))
            let sender = firstNonEmpty(payload?.sender, subtitle, titleText)

            guard !body.isEmpty else { continue }

            emit(
                WorkNotification(
                    source: source,
                    title: title,
                    body: String(body.prefix(200)),
                    metadata: [
                        "rawAppId": bundleId,
                        "adapter": "SystemNotification",
                        "rawPayload": payload?.flattenedText ?? "",
                        "sender": sender,
                        "messageCategory": resolveMessageCategory(source: source, payload: payload, title: title, body: body).rawValue
                    ].filter { !$0.value.isEmpty }
                )
            )
        }
    }

    private func bestBundleId(appId: String, enclosingAppId: String, payload: NotificationPayload?) -> String {
        let candidates = [
            enclosingAppId,
            appIdentifierById[appId] ?? "",
            appId,
            payload?.sourceHint ?? "",
            payload?.flattenedText ?? ""
        ]

        for candidate in candidates where !candidate.isEmpty {
            let lowercased = candidate.lowercased()
            if lowercased.contains("xinwechat") || lowercased.contains("wechat") || lowercased.contains("tencent") {
                return NotificationSource.wechat.bundleIdentifier
            }
            if lowercased.contains("lark") || lowercased.contains("feishu") || lowercased.contains("bytedance") {
                return NotificationSource.feishu.bundleIdentifier
            }
        }

        return firstNonEmpty(enclosingAppId, appIdentifierById[appId], appId)
    }

    private func loadAppIdentifierMap() -> [String: String] {
        guard
            let rows = try? NotificationSQLiteReader.query(dbPath: dbPath, sql: "PRAGMA table_info(app);"),
            !rows.isEmpty
        else {
            return [:]
        }

        let columns = Set(rows.compactMap { $0.indices.contains(1) ? $0[1] : nil })
        let idColumn = ["app_id", "id", "rec_id"].first { columns.contains($0) }
        let identifierColumn = ["identifier", "bundle_id", "bundle_identifier", "app_identifier"].first { columns.contains($0) }

        guard let idColumn, let identifierColumn else {
            return [:]
        }

        let sql =
            """
            SELECT "\(idColumn)", "\(identifierColumn)"
            FROM app;
            """

        guard let appRows = try? NotificationSQLiteReader.query(dbPath: dbPath, sql: sql) else {
            return [:]
        }

        return Dictionary(
            uniqueKeysWithValues: appRows.compactMap { row in
                guard row.count >= 2, !row[0].isEmpty, !row[1].isEmpty else {
                    return nil
                }
                return (row[0], row[1])
            }
        )
    }

    private func firstNonEmpty(_ values: String?...) -> String {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
    }

    private func resolveMessageCategory(
        source: NotificationSource,
        payload: NotificationPayload?,
        title: String,
        body: String
    ) -> MessageCategory {
        let text = [
            payload?.flattenedText ?? "",
            title,
            body
        ].joined(separator: " ").lowercased()

        if text.contains("公众号") || text.contains("订阅号") || text.contains("服务号") || text.contains("official") {
            return .official
        }

        if text.contains("群") || text.contains("group") || text.contains("chatroom") || text.contains("@all") || text.contains("@所有人") {
            return .group
        }

        if text.contains("系统") || text.contains("安全") || text.contains("登录") || text.contains("system") || text.contains("security") {
            return .system
        }

        if source == .wechat || source == .feishu {
            return .direct
        }

        return .unknown
    }
}

struct NotificationRecordSchema {
    let columns: Set<String>
    let appColumn: String
    let enclosingAppColumn: String?
    let bodyColumn: String?
    let titleColumn: String?
    let subtitleColumn: String?
    let dataColumn: String?
    let dateColumn: String

    init(columns: Set<String>) throws {
        self.columns = columns
        self.appColumn = Self.firstExisting(["app_id", "bundle_id", "identifier"], in: columns) ?? "app_id"
        self.enclosingAppColumn = Self.firstExisting(["enclosing_app_id", "bundle_id", "app_identifier"], in: columns)
        self.bodyColumn = Self.firstExisting(["body_text", "message", "text", "informative_text"], in: columns)
        self.titleColumn = Self.firstExisting(["title_text", "title"], in: columns)
        self.subtitleColumn = Self.firstExisting(["subtitle_text"], in: columns)
        self.dataColumn = Self.firstExisting(["data"], in: columns)
        self.dateColumn = Self.firstExisting(["date_created", "delivered_date", "request_date", "request_last_date"], in: columns) ?? "date_created"

        guard columns.contains(appColumn), columns.contains(dateColumn) else {
            throw SchemaError.unsupported(columns.sorted().joined(separator: ", "))
        }
    }

    func selectRecentSQL(since: Double, limit: Int) -> String {
        let enclosingExpression = enclosingAppColumn.map { Self.quoted($0) } ?? "''"
        let bodyExpression = bodyColumn.map { "coalesce(\(Self.quoted($0)), '')" } ?? "''"
        let titleExpression = titleColumn.map { "coalesce(\(Self.quoted($0)), '')" } ?? "''"
        let subtitleExpression = subtitleColumn.map { "coalesce(\(Self.quoted($0)), '')" } ?? "''"
        let dataExpression = dataColumn.map { "coalesce(\(Self.quoted($0)), X'')" } ?? "''"

        return
            """
            SELECT \(Self.quoted(appColumn)), \(enclosingExpression), \(bodyExpression), \(subtitleExpression), \(Self.quoted(dateColumn)), \(dataExpression), \(titleExpression)
            FROM record
            WHERE \(Self.quoted(dateColumn)) > \(since)
            ORDER BY \(Self.quoted(dateColumn)) ASC
            LIMIT \(limit);
            """
    }

    func selectMaxDateSQL() -> String {
        "SELECT max(\(Self.quoted(dateColumn))) FROM record;"
    }

    func selectCandidatesSQL(limit: Int) -> String {
        let enclosingExpression = enclosingAppColumn.map { "coalesce(\(Self.quoted($0)), '')" } ?? "''"
        let bodyExpression = bodyColumn.map { "coalesce(\(Self.quoted($0)), '')" } ?? "''"
        let titleExpression = titleColumn.map { "coalesce(\(Self.quoted($0)), '')" } ?? "''"
        let subtitleExpression = subtitleColumn.map { "coalesce(\(Self.quoted($0)), '')" } ?? "''"
        let dataExpression = dataColumn.map { "coalesce(\(Self.quoted($0)), X'')" } ?? "''"

        return
            """
            SELECT \(Self.quoted(appColumn)), \(enclosingExpression), \(bodyExpression), \(subtitleExpression), \(Self.quoted(dateColumn)), \(dataExpression), \(titleExpression)
            FROM record
            ORDER BY \(Self.quoted(dateColumn)) DESC
            LIMIT \(limit);
            """
    }

    func selectLatestSQL(limit: Int) -> String {
        let enclosingExpression = enclosingAppColumn.map { "coalesce(\(Self.quoted($0)), '')" } ?? "''"
        let bodyExpression = bodyColumn.map { "coalesce(\(Self.quoted($0)), '')" } ?? "''"
        let titleExpression = titleColumn.map { "coalesce(\(Self.quoted($0)), '')" } ?? "''"
        let subtitleExpression = subtitleColumn.map { "coalesce(\(Self.quoted($0)), '')" } ?? "''"
        let dataExpression = dataColumn.map { "coalesce(\(Self.quoted($0)), X'')" } ?? "''"

        return
            """
            SELECT \(Self.quoted(appColumn)), \(enclosingExpression), \(bodyExpression), \(subtitleExpression), \(Self.quoted(dateColumn)), \(dataExpression), \(titleExpression)
            FROM record
            ORDER BY \(Self.quoted(dateColumn)) DESC
            LIMIT \(limit);
            """
    }

    func fallbackBody(appId: String, subtitle: String, dataText: String) -> String {
        let decoded = Self.readableSnippet(from: dataText)
        return [subtitle, decoded, appId].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func firstExisting(_ candidates: [String], in columns: Set<String>) -> String? {
        candidates.first { columns.contains($0) }
    }

    private static func quoted(_ name: String) -> String {
        "\"\(name.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func readableSnippet(from text: String) -> String {
        let cleanedScalars = text.unicodeScalars.map { scalar -> Character in
            if CharacterSet.controlCharacters.contains(scalar) {
                return " "
            }
            return Character(scalar)
        }
        let cleaned = String(cleanedScalars)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return String(cleaned.prefix(160))
    }

    enum SchemaError: Error, CustomStringConvertible {
        case unsupported(String)

        var description: String {
            switch self {
            case .unsupported(let columns):
                return "unsupported notification record schema: \(columns)"
            }
        }
    }
}
