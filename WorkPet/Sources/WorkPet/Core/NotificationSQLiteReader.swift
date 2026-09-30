import Foundation
import SQLite3

enum NotificationSQLiteReader {
    enum ReadError: Error, CustomStringConvertible {
        case open(String)
        case prepare(String)
        case step(String)

        var description: String {
            switch self {
            case .open(let message):
                return message
            case .prepare(let message):
                return message
            case .step(let message):
                return message
            }
        }
    }

    static func query(dbPath: String, sql: String) throws -> [[String]] {
        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(dbPath, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil)

        guard openResult == SQLITE_OK, let database else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "sqlite open failed: \(openResult)"
            if let database {
                sqlite3_close(database)
            }
            throw ReadError.open(message)
        }

        defer {
            sqlite3_close(database)
        }

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
        guard prepareResult == SQLITE_OK, let statement else {
            throw ReadError.prepare(String(cString: sqlite3_errmsg(database)))
        }

        defer {
            sqlite3_finalize(statement)
        }

        var rows: [[String]] = []
        while true {
            let stepResult = sqlite3_step(statement)

            if stepResult == SQLITE_ROW {
                let columnCount = sqlite3_column_count(statement)
                var row: [String] = []

                for index in 0..<columnCount {
                    if sqlite3_column_type(statement, index) == SQLITE_BLOB,
                       let blob = sqlite3_column_blob(statement, index) {
                        let byteCount = Int(sqlite3_column_bytes(statement, index))
                        let data = Data(bytes: blob, count: byteCount)
                        row.append(data.base64EncodedString())
                    } else if let text = sqlite3_column_text(statement, index) {
                        row.append(String(cString: text))
                    } else {
                        row.append("")
                    }
                }

                rows.append(row)
                continue
            }

            if stepResult == SQLITE_DONE {
                break
            }

            throw ReadError.step(String(cString: sqlite3_errmsg(database)))
        }

        return rows
    }
}
