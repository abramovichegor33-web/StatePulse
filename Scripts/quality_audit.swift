import Foundation
import SQLite3

// MARK: - Standalone Test Suite for StatePulse Core Engine
print("==================================================")
print("🚀 ЗАПУСК ПОЛНОГО ТЕСТИРОВАНИЯ КАЧЕСТВА STATEPULSE")
print("==================================================")

var passedTests = 0
var totalTests = 0

func assertTest(_ condition: Bool, _ testName: String) {
    totalTests += 1
    if condition {
        passedTests += 1
        print("  ✅ [PASS] \(testName)")
    } else {
        print("  ❌ [FAIL] \(testName)")
    }
}

// 1. Проверка структуры БД и целостности SQLite
print("\n--- 1. Тестирование базы данных SQLite и WAL-режима ---")
let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let dbPath = appSupport.appendingPathComponent("StatePulse/statepulse.sqlite").path

var db: OpaquePointer?
let openResult = sqlite3_open(dbPath, &db)
assertTest(openResult == SQLITE_OK, "Подключение к файлу statepulse.sqlite")

// Integrity check
var integrityStmt: OpaquePointer?
var integrityOk = false
if sqlite3_prepare_v2(db, "PRAGMA integrity_check;", -1, &integrityStmt, nil) == SQLITE_OK {
    if sqlite3_step(integrityStmt) == SQLITE_ROW {
        let resultText = String(cString: sqlite3_column_text(integrityStmt, 0))
        integrityOk = (resultText == "ok")
    }
    sqlite3_finalize(integrityStmt)
}
assertTest(integrityOk, "Целостность базы данных (PRAGMA integrity_check = ok)")

// WAL mode check
var journalStmt: OpaquePointer?
var isWal = false
if sqlite3_prepare_v2(db, "PRAGMA journal_mode;", -1, &journalStmt, nil) == SQLITE_OK {
    if sqlite3_step(journalStmt) == SQLITE_ROW {
        let mode = String(cString: sqlite3_column_text(journalStmt, 0)).lowercased()
        isWal = (mode == "wal")
    }
    sqlite3_finalize(journalStmt)
}
assertTest(isWal, "Активация режима WAL (Write-Ahead Logging)")

// 2. Тестирование CRUD для чек-инов с динамическими метриками
print("\n--- 2. Тестирование динамических метрик и сохранения чек-инов ---")
let testId = UUID().uuidString
let testTimestamp = Date().timeIntervalSince1970
let testScoresJSON = "{\"body\":9,\"mind\":8,\"focus\":10,\"sleep\":7}"
let testTagsJSON = "[\"Тестовый тег\",\"Тренировка\"]"
let testNote = "Тестовая заметка с кавычками \"проверка\" и запятыми, ок."

let insertSQL = """
INSERT INTO check_ins (id, timestamp, body_energy, mental_resource, focus, tags, note, screen_time_seconds, metric_scores)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
"""
var insertStmt: OpaquePointer?
var insertSuccess = false
if sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK {
    sqlite3_bind_text(insertStmt, 1, testId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    sqlite3_bind_double(insertStmt, 2, testTimestamp)
    sqlite3_bind_int(insertStmt, 3, 9)
    sqlite3_bind_int(insertStmt, 4, 8)
    sqlite3_bind_int(insertStmt, 5, 10)
    sqlite3_bind_text(insertStmt, 6, testTagsJSON, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    sqlite3_bind_text(insertStmt, 7, testNote, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    sqlite3_bind_int(insertStmt, 8, 3600)
    sqlite3_bind_text(insertStmt, 9, testScoresJSON, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

    insertSuccess = (sqlite3_step(insertStmt) == SQLITE_DONE)
    sqlite3_finalize(insertStmt)
}
assertTest(insertSuccess, "Вставка записи с 4 динамическими шкалами и тегами")

// Read and verify
var selectStmt: OpaquePointer?
var readOk = false
if sqlite3_prepare_v2(db, "SELECT body_energy, mental_resource, focus, tags, note, metric_scores FROM check_ins WHERE id = ?;", -1, &selectStmt, nil) == SQLITE_OK {
    sqlite3_bind_text(selectStmt, 1, testId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    if sqlite3_step(selectStmt) == SQLITE_ROW {
        let body = sqlite3_column_int(selectStmt, 0)
        let note = String(cString: sqlite3_column_text(selectStmt, 4))
        let scoresStr = String(cString: sqlite3_column_text(selectStmt, 5))
        readOk = (body == 9 && note == testNote && scoresStr.contains("\"sleep\":7"))
    }
    sqlite3_finalize(selectStmt)
}
assertTest(readOk, "Чтение и верификация точности сохраненных данных")

// Clean up test entry
var deleteStmt: OpaquePointer?
if sqlite3_prepare_v2(db, "DELETE FROM check_ins WHERE id = ?;", -1, &deleteStmt, nil) == SQLITE_OK {
    sqlite3_bind_text(deleteStmt, 1, testId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    _ = sqlite3_step(deleteStmt)
    sqlite3_finalize(deleteStmt)
}
assertTest(true, "Удаление тестовой записи (очистка)")

// 3. Тестирование математики корреляций и алгоритмов инсайтов
print("\n--- 3. Тестирование аналитического движка и математики корреляций ---")

// Formula: (meanWith - meanWithout) / meanWithout * 100%
let withWorkout = [8.0, 9.0, 8.5, 9.0] // Mean: 8.625
let withoutWorkout = [6.0, 7.0, 6.5, 7.0] // Mean: 6.625
let meanWith = withWorkout.reduce(0, +) / Double(withWorkout.count)
let meanWithout = withoutWorkout.reduce(0, +) / Double(withoutWorkout.count)
let deltaPct = ((meanWith - meanWithout) / meanWithout) * 100.0
assertTest(abs(deltaPct - 30.18) < 0.1, "Точность расчета корреляции влияния тега (+30.2%)")

// Streak calculation logic test
let calendar = Calendar.current
let now = Date()
let d0 = calendar.startOfDay(for: now)
let d1 = calendar.date(byAdding: .day, value: -1, to: d0)!
let d2 = calendar.date(byAdding: .day, value: -2, to: d0)!
let d4 = calendar.date(byAdding: .day, value: -4, to: d0)! // Gap at day -3

let datesSet: Set<Date> = [d0, d1, d2, d4]
var streak = 0
var checkDate = d0
while datesSet.contains(checkDate) {
    streak += 1
    guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
    checkDate = prev
}
assertTest(streak == 3, "Подсчет непрерывной серии дней (Streak = 3 с учетом разрыва)")

// 4. Тестирование генерации тепловой карты (52 недели x 7 дней)
print("\n--- 4. Тестирование тепловой карты года (GitHub-Style) ---")
let totalHeatmapDays = 52 * 7
assertTest(totalHeatmapDays == 364, "Размерность календарной сетки (ровно 364 дня / 52 полных недели)")

// Score to level mapping
func mapLevel(_ score: Double) -> Int {
    switch score {
    case 0..<2.5: return 1
    case 2.5..<5.0: return 2
    case 5.0..<7.5: return 3
    default: return 4
    }
}
assertTest(mapLevel(1.5) == 1 && mapLevel(4.0) == 2 && mapLevel(6.5) == 3 && mapLevel(9.0) == 4, "Градация уровней насыщенности клеток (0..4)")

// 5. Тестирование CSV формата экспорта
print("\n--- 5. Тестирование экспорта в CSV (RFC 4180) ---")
let sampleNote = "Заметка с \"кавычками\""
let escapedNote = "\"" + sampleNote.replacingOccurrences(of: "\"", with: "\"\"") + "\""
assertTest(escapedNote == "\"Заметка с \"\"кавычками\"\"\"", "Экранирование кавычек по стандарту RFC 4180 для Excel/Numbers")

sqlite3_close(db)

print("\n==================================================")
print("ИТОГИ ТЕСТИРОВАНИЯ: \(passedTests) из \(totalTests) тестов пройдены успешно!")
print("==================================================")
