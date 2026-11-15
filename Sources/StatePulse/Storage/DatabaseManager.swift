import Foundation
import SQLite3

final class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.statepulse.database", qos: .userInitiated)

    private init() {
        openDatabase()
        createTables()
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    private func getDatabaseURL() -> URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("StatePulse", isDirectory: true)

        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }

        return appDir.appendingPathComponent("statepulse.sqlite")
    }

    private func openDatabase() {
        let dbURL = getDatabaseURL()
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            print("Failed to open SQLite database at \(dbURL.path)")
        } else {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, "PRAGMA journal_mode = WAL;", -1, &statement, nil) == SQLITE_OK {
                _ = sqlite3_step(statement)
                sqlite3_finalize(statement)
            }
        }
    }

    private func createTables() {
        let createCheckInsSQL = """
        CREATE TABLE IF NOT EXISTS check_ins (
            id TEXT PRIMARY KEY,
            timestamp REAL NOT NULL,
            body_energy INTEGER NOT NULL,
            mental_resource INTEGER NOT NULL,
            focus INTEGER NOT NULL,
            tags TEXT,
            note TEXT,
            screen_time_seconds INTEGER DEFAULT 0,
            metric_scores TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_check_ins_timestamp ON check_ins(timestamp);
        """

        let createTagsSQL = """
        CREATE TABLE IF NOT EXISTS custom_tags (
            name TEXT PRIMARY KEY,
            created_at REAL NOT NULL
        );
        """

        let createDailyContextSQL = """
        CREATE TABLE IF NOT EXISTS daily_context (
            date_string TEXT PRIMARY KEY,
            active_seconds INTEGER NOT NULL,
            wake_time REAL,
            sleep_time REAL
        );
        """

        queue.sync {
            executeSQL(createCheckInsSQL)
            // Attempt migration if table was already created without metric_scores
            executeSQL("ALTER TABLE check_ins ADD COLUMN metric_scores TEXT;")
            executeSQL(createTagsSQL)
            executeSQL(createDailyContextSQL)
        }
    }

    private func executeSQL(_ sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        _ = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if let error = errMsg {
            sqlite3_free(error)
        }
    }

    // MARK: - CheckIns CRUD
    func saveCheckIn(_ record: CheckInRecord) {
        queue.sync {
            let sql = """
            INSERT OR REPLACE INTO check_ins (id, timestamp, body_energy, mental_resource, focus, tags, note, screen_time_seconds, metric_scores)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                let tagsData = (try? JSONEncoder().encode(record.tags)) ?? Data()
                let tagsJSON = String(data: tagsData, encoding: .utf8) ?? "[]"

                let scoresData = (try? JSONEncoder().encode(record.metricScores)) ?? Data()
                let scoresJSON = String(data: scoresData, encoding: .utf8) ?? "{}"

                sqlite3_bind_text(statement, 1, record.id.uuidString, -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(statement, 2, record.timestamp.timeIntervalSince1970)
                sqlite3_bind_int(statement, 3, Int32(record.bodyEnergy))
                sqlite3_bind_int(statement, 4, Int32(record.mentalResource))
                sqlite3_bind_int(statement, 5, Int32(record.focus))
                sqlite3_bind_text(statement, 6, tagsJSON, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 7, record.note, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(statement, 8, Int32(record.screenTimeSeconds))
                sqlite3_bind_text(statement, 9, scoresJSON, -1, SQLITE_TRANSIENT)

                _ = sqlite3_step(statement)
                sqlite3_finalize(statement)
            }
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .databaseDidChange, object: nil)
        }
    }

    func deleteCheckIn(id: UUID) {
        queue.sync {
            let sql = "DELETE FROM check_ins WHERE id = ?;"
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, id.uuidString, -1, SQLITE_TRANSIENT)
                _ = sqlite3_step(statement)
                sqlite3_finalize(statement)
            }
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .databaseDidChange, object: nil)
        }
    }

    func fetchAllCheckIns() -> [CheckInRecord] {
        queue.sync {
            var records: [CheckInRecord] = []
            let sql = "SELECT id, timestamp, body_energy, mental_resource, focus, tags, note, screen_time_seconds, metric_scores FROM check_ins ORDER BY timestamp DESC;"
            var statement: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    let idStr = String(cString: sqlite3_column_text(statement, 0))
                    let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
                    let body = Int(sqlite3_column_int(statement, 2))
                    let mental = Int(sqlite3_column_int(statement, 3))
                    let focus = Int(sqlite3_column_int(statement, 4))

                    let tagsStr = sqlite3_column_text(statement, 5).map { String(cString: $0) } ?? "[]"
                    let noteStr = sqlite3_column_text(statement, 6).map { String(cString: $0) } ?? ""
                    let screenSeconds = Int(sqlite3_column_int(statement, 7))

                    var scores: [String: Int] = ["body": body, "mind": mental, "focus": focus]
                    if let scoresText = sqlite3_column_text(statement, 8) {
                        let scoresStr = String(cString: scoresText)
                        if let decoded = try? JSONDecoder().decode([String: Int].self, from: Data(scoresStr.utf8)), !decoded.isEmpty {
                            scores = decoded
                        }
                    }

                    let tags: [String] = (try? JSONDecoder().decode([String].self, from: Data(tagsStr.utf8))) ?? []
                    let uuid = UUID(uuidString: idStr) ?? UUID()

                    let record = CheckInRecord(
                        id: uuid,
                        timestamp: timestamp,
                        metricScores: scores,
                        tags: tags,
                        note: noteStr,
                        screenTimeSeconds: screenSeconds
                    )
                    records.append(record)
                }
                sqlite3_finalize(statement)
            }
            return records
        }
    }

    // MARK: - Custom Tags CRUD
    func saveCustomTag(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        queue.sync {
            let sql = "INSERT OR IGNORE INTO custom_tags (name, created_at) VALUES (?, ?);"
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, trimmed, -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
                _ = sqlite3_step(statement)
                sqlite3_finalize(statement)
            }
        }
    }

    func deleteCustomTag(name: String) {
        queue.sync {
            let sql = "DELETE FROM custom_tags WHERE name = ?;"
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, name, -1, SQLITE_TRANSIENT)
                _ = sqlite3_step(statement)
                sqlite3_finalize(statement)
            }
        }
    }

    func fetchCustomTags() -> [TagModel] {
        queue.sync {
            var tags: [TagModel] = []
            let sql = "SELECT name, created_at FROM custom_tags ORDER BY created_at ASC;"
            var statement: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    let name = String(cString: sqlite3_column_text(statement, 0))
                    let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
                    tags.append(TagModel(name: name, isDefault: false, createdAt: createdAt))
                }
                sqlite3_finalize(statement)
            }
            return tags
        }
    }

    // MARK: - Daily Screen Time Context
    func saveDailyContext(_ context: DailyContext) {
        queue.sync {
            let sql = """
            INSERT OR REPLACE INTO daily_context (date_string, active_seconds, wake_time, sleep_time)
            VALUES (?, ?, ?, ?);
            """
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, context.dateString, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(statement, 2, Int32(context.activeSeconds))
                if let wake = context.wakeTime {
                    sqlite3_bind_double(statement, 3, wake.timeIntervalSince1970)
                } else {
                    sqlite3_bind_null(statement, 3)
                }
                if let sleep = context.sleepTime {
                    sqlite3_bind_double(statement, 4, sleep.timeIntervalSince1970)
                } else {
                    sqlite3_bind_null(statement, 4)
                }
                _ = sqlite3_step(statement)
                sqlite3_finalize(statement)
            }
        }
    }

    func fetchDailyContext(for dateString: String) -> DailyContext? {
        queue.sync {
            let sql = "SELECT date_string, active_seconds, wake_time, sleep_time FROM daily_context WHERE date_string = ?;"
            var statement: OpaquePointer?
            var result: DailyContext?

            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, dateString, -1, SQLITE_TRANSIENT)
                if sqlite3_step(statement) == SQLITE_ROW {
                    let dateStr = String(cString: sqlite3_column_text(statement, 0))
                    let activeSecs = Int(sqlite3_column_int(statement, 1))
                    let wakeTime: Date? = sqlite3_column_type(statement, 2) != SQLITE_NULL ? Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)) : nil
                    let sleepTime: Date? = sqlite3_column_type(statement, 3) != SQLITE_NULL ? Date(timeIntervalSince1970: sqlite3_column_double(statement, 3)) : nil

                    result = DailyContext(dateString: dateStr, activeSeconds: activeSecs, wakeTime: wakeTime, sleepTime: sleepTime)
                }
                sqlite3_finalize(statement)
            }
            return result
        }
    }

    func clearAllData() {
        queue.sync {
            executeSQL("DELETE FROM check_ins;")
            executeSQL("DELETE FROM custom_tags;")
            executeSQL("DELETE FROM daily_context;")
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .databaseDidChange, object: nil)
        }
    }
}

extension Notification.Name {
    static let databaseDidChange = Notification.Name("StatePulseDatabaseDidChange")
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
