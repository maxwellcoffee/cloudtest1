//  Database.swift
//  SQLite persistence for the Mac companion.
//
//  - SQLite3 C API, one connection in WAL mode, every call serialised by a lock.
//  - Schema migrations are driven by PRAGMA user_version.
//  - Utterances are full-text indexed with an external-content FTS5 table kept
//    in sync by triggers; if FTS5 is unavailable, search falls back to LIKE.
//  - Nested values (arrays, payloads, status reports) are stored as JSON text,
//    dates as REAL seconds since 1970.
//  - No method throws (except `init`): failures are logged and reads return
//    empty results.

import Foundation
import SQLite3

/// SQLITE_TRANSIENT: makes SQLite copy bound text before the call returns.
private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - Low-level SQLite helpers

private enum SQLValue {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)

    static func string(_ value: String?) -> SQLValue {
        guard let value else { return .null }
        return .text(value)
    }

    static func date(_ value: Date?) -> SQLValue {
        guard let value else { return .null }
        return .real(value.timeIntervalSince1970)
    }

    static func bool(_ value: Bool) -> SQLValue { .integer(value ? 1 : 0) }

    static func int(_ value: Int) -> SQLValue { .integer(Int64(value)) }

    /// SQLite treats a negative LIMIT as "no limit".
    static func limit(_ value: Int) -> SQLValue { .integer(value > 0 ? Int64(value) : -1) }
}

private struct SQLRow {
    let statement: OpaquePointer

    func isNull(_ index: Int32) -> Bool {
        sqlite3_column_type(statement, index) == SQLITE_NULL
    }

    func string(_ index: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: pointer)
    }

    func optionalString(_ index: Int32) -> String? {
        isNull(index) ? nil : string(index)
    }

    func double(_ index: Int32) -> Double {
        sqlite3_column_double(statement, index)
    }

    func optionalDouble(_ index: Int32) -> Double? {
        isNull(index) ? nil : double(index)
    }

    func int64(_ index: Int32) -> Int64 {
        sqlite3_column_int64(statement, index)
    }

    func optionalInt64(_ index: Int32) -> Int64? {
        isNull(index) ? nil : int64(index)
    }

    func int(_ index: Int32) -> Int {
        Int(sqlite3_column_int64(statement, index))
    }

    func bool(_ index: Int32) -> Bool {
        sqlite3_column_int64(statement, index) != 0
    }

    func date(_ index: Int32) -> Date {
        Date(timeIntervalSince1970: double(index))
    }

    func optionalDate(_ index: Int32) -> Date? {
        isNull(index) ? nil : date(index)
    }
}

private struct SQLiteError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Owns the raw `sqlite3*` handle. Not thread-safe by itself; `Database` serialises access.
private final class SQLiteConnection {
    let handle: OpaquePointer

    init(url: URL) throws {
        var opened: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let rc = sqlite3_open_v2(url.path, &opened, flags, nil)
        guard rc == SQLITE_OK, let db = opened else {
            var message = "SQLite error \(rc)"
            if let opened, let cMessage = sqlite3_errmsg(opened) {
                message = String(cString: cMessage)
            }
            sqlite3_close_v2(opened)
            throw SQLiteError(message: "Could not open the database at \(url.path): \(message)")
        }
        handle = db
    }

    deinit {
        sqlite3_close_v2(handle)
    }

    var errorMessage: String {
        guard let cMessage = sqlite3_errmsg(handle) else { return "unknown SQLite error" }
        return String(cString: cMessage)
    }

    var lastInsertRowID: Int64 { sqlite3_last_insert_rowid(handle) }

    /// Rows changed by the most recent INSERT/UPDATE/DELETE on this connection.
    var changes: Int { Int(sqlite3_changes(handle)) }

    var userVersion: Int32 {
        Int32(truncatingIfNeeded: scalarInt64("PRAGMA user_version") ?? 0)
    }

    /// Runs one or more SQL statements without parameters.
    @discardableResult
    func exec(_ sql: String, logFailure: Bool = true) -> Bool {
        var errorPointer: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(handle, sql, nil, nil, &errorPointer)
        guard rc == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? errorMessage
            sqlite3_free(errorPointer)
            if logFailure {
                Log.error("Database: exec failed (\(rc)): \(message) — \(Self.excerpt(sql))")
            }
            return false
        }
        return true
    }

    /// Runs a single parameterised statement to completion.
    @discardableResult
    func run(_ sql: String, _ arguments: [SQLValue] = []) -> Bool {
        guard let statement = prepare(sql, arguments) else { return false }
        defer { sqlite3_finalize(statement) }
        while true {
            let rc = sqlite3_step(statement)
            if rc == SQLITE_DONE { return true }
            if rc == SQLITE_ROW { continue }
            Log.error("Database: step failed (\(rc)): \(errorMessage) — \(Self.excerpt(sql))")
            return false
        }
    }

    /// Runs a query; returns nil if it could not be prepared or failed while stepping.
    func queryChecked<T>(_ sql: String, _ arguments: [SQLValue], _ map: (SQLRow) -> T?) -> [T]? {
        guard let statement = prepare(sql, arguments) else { return nil }
        defer { sqlite3_finalize(statement) }
        let row = SQLRow(statement: statement)
        var results: [T] = []
        while true {
            let rc = sqlite3_step(statement)
            if rc == SQLITE_ROW {
                if let value = map(row) { results.append(value) }
                continue
            }
            if rc == SQLITE_DONE { return results }
            Log.error("Database: query failed (\(rc)): \(errorMessage) — \(Self.excerpt(sql))")
            return nil
        }
    }

    func query<T>(_ sql: String, _ arguments: [SQLValue] = [], _ map: (SQLRow) -> T?) -> [T] {
        queryChecked(sql, arguments, map) ?? []
    }

    func scalarInt64(_ sql: String, _ arguments: [SQLValue] = []) -> Int64? {
        let values: [Int64] = query(sql, arguments) { row in row.optionalInt64(0) }
        return values.first
    }

    func scalarDouble(_ sql: String, _ arguments: [SQLValue] = []) -> Double? {
        let values: [Double] = query(sql, arguments) { row in row.optionalDouble(0) }
        return values.first
    }

    /// Runs `body` inside BEGIN IMMEDIATE … COMMIT; rolls back when it returns false.
    func transaction(_ body: () -> Bool) -> Bool {
        guard exec("BEGIN IMMEDIATE") else { return false }
        if body() {
            if exec("COMMIT") { return true }
            exec("ROLLBACK", logFailure: false)
            return false
        }
        exec("ROLLBACK", logFailure: false)
        return false
    }

    private func prepare(_ sql: String, _ arguments: [SQLValue]) -> OpaquePointer? {
        var prepared: OpaquePointer?
        let rc = sqlite3_prepare_v2(handle, sql, -1, &prepared, nil)
        guard rc == SQLITE_OK, let statement = prepared else {
            Log.error("Database: prepare failed (\(rc)): \(errorMessage) — \(Self.excerpt(sql))")
            sqlite3_finalize(prepared)
            return nil
        }
        for (offset, value) in arguments.enumerated() {
            let index = Int32(offset + 1)
            let bindResult: Int32
            switch value {
            case .null:
                bindResult = sqlite3_bind_null(statement, index)
            case .integer(let number):
                bindResult = sqlite3_bind_int64(statement, index, number)
            case .real(let number):
                bindResult = sqlite3_bind_double(statement, index, number)
            case .text(let text):
                bindResult = sqlite3_bind_text(statement, index, text, -1, sqliteTransient)
            }
            if bindResult != SQLITE_OK {
                Log.error("Database: bind \(index) failed (\(bindResult)): \(errorMessage) — \(Self.excerpt(sql))")
                sqlite3_finalize(statement)
                return nil
            }
        }
        return statement
    }

    private static func excerpt(_ sql: String) -> String {
        let flat = sql.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return flat.count > 160 ? String(flat.prefix(160)) + "…" : flat
    }
}

// MARK: - Database

final class Database: @unchecked Sendable {
    private let connection: SQLiteConnection
    private let lock = NSRecursiveLock()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    /// Guarded by `lock`.
    private var ftsEnabled = false

    init(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let connection = try SQLiteConnection(url: url)
        _ = sqlite3_busy_timeout(connection.handle, 5_000)
        connection.exec("PRAGMA journal_mode = WAL")
        connection.exec("PRAGMA synchronous = NORMAL")
        connection.exec("PRAGMA temp_store = MEMORY")
        try Database.migrate(connection)
        self.connection = connection
        self.encoder = EarshotAPI.makeEncoder()
        self.decoder = EarshotAPI.makeDecoder()
        let fts = Database.setUpFullTextSearch(connection)
        self.ftsEnabled = fts
        Log.info("Database ready at \(url.path) (schema v\(connection.userVersion), search: \(fts ? "FTS5" : "LIKE fallback"))")
    }

    // MARK: Segments

    func upsertSegment(_ s: Segment) {
        withConnection { c in
            Database.upsert(c, table: "segments", key: "id", columns: Database.segmentColumns, values: [
                .text(s.id), .text(s.device), .date(s.startedAt), .real(s.duration), .string(s.filePath),
                .text(s.status.rawValue), .real(Double(s.avgPower)), .real(Double(s.speechRatio)),
                .text(s.reason), .string(s.error), .date(s.createdAt),
            ])
        }
    }

    func segment(id: String) -> Segment? {
        withConnection { c in
            c.query("SELECT \(Database.columnList(Database.segmentColumns)) FROM segments WHERE id = ?",
                    [.text(id)]) { self.makeSegment($0) }.first
        }
    }

    func segments(from start: Date, to end: Date) -> [Segment] {
        withConnection { c in
            c.query("""
                SELECT \(Database.columnList(Database.segmentColumns)) FROM segments
                WHERE started_at >= ? AND started_at < ? ORDER BY started_at ASC
                """, [.date(start), .date(end)]) { self.makeSegment($0) }
        }
    }

    func segments(statuses: [SegmentStatus], limit: Int) -> [Segment] {
        guard !statuses.isEmpty else { return [] }
        return withConnection { c in
            var arguments: [SQLValue] = statuses.map { SQLValue.text($0.rawValue) }
            arguments.append(.limit(limit))
            return c.query("""
                SELECT \(Database.columnList(Database.segmentColumns)) FROM segments
                WHERE status IN (\(Database.placeholders(statuses.count)))
                ORDER BY started_at ASC, created_at ASC LIMIT ?
                """, arguments) { self.makeSegment($0) }
        }
    }

    func segmentsWithAudio(olderThan date: Date) -> [Segment] {
        withConnection { c in
            c.query("""
                SELECT \(Database.columnList(Database.segmentColumns)) FROM segments
                WHERE file_path IS NOT NULL AND started_at < ? ORDER BY started_at ASC
                """, [.date(date)]) { self.makeSegment($0) }
        }
    }

    func recordedSeconds(from start: Date, to end: Date) -> Double {
        withConnection { c in
            c.scalarDouble("SELECT COALESCE(SUM(duration), 0) FROM segments WHERE started_at >= ? AND started_at < ?",
                           [.date(start), .date(end)]) ?? 0
        }
    }

    // MARK: Utterances

    @discardableResult
    func insertUtterances(_ items: [Utterance]) -> [Utterance] {
        guard !items.isEmpty else { return [] }
        return withConnection { c in
            let first = self.insertUtteranceRows(c, items)
            if let rows = first.rows { return rows }
            let failure = first.failure.lowercased()
            if self.ftsEnabled && (failure.contains("fts") || failure.contains("malformed") || failure.contains("vtable")) {
                Log.error("Database: utterance insert failed with the full-text index enabled (\(first.failure)); disabling FTS5 and retrying")
                self.disableFullTextSearch(c)
                if let rows = self.insertUtteranceRows(c, items).rows { return rows }
            }
            Log.error("Database: could not insert \(items.count) utterance(s): \(first.failure)")
            return []
        }
    }

    func utterances(from start: Date, to end: Date, limit: Int) -> [Utterance] {
        withConnection { c in
            c.query("""
                SELECT \(Database.columnList(Database.utteranceColumns)) FROM utterances
                WHERE started_at >= ? AND started_at < ? ORDER BY started_at ASC, id ASC LIMIT ?
                """, [.date(start), .date(end), .limit(limit)]) { self.makeUtterance($0) }
        }
    }

    func utterances(afterID: Int64, limit: Int) -> [Utterance] {
        withConnection { c in
            c.query("""
                SELECT \(Database.columnList(Database.utteranceColumns)) FROM utterances
                WHERE id > ? ORDER BY id ASC LIMIT ?
                """, [.integer(afterID), .limit(limit)]) { self.makeUtterance($0) }
        }
    }

    func utterances(segmentID: String) -> [Utterance] {
        withConnection { c in
            c.query("""
                SELECT \(Database.columnList(Database.utteranceColumns)) FROM utterances
                WHERE segment_id = ? ORDER BY started_at ASC, id ASC
                """, [.text(segmentID)]) { self.makeUtterance($0) }
        }
    }

    func latestUtteranceID() -> Int64 {
        withConnection { c in
            c.scalarInt64("SELECT COALESCE(MAX(id), 0) FROM utterances") ?? 0
        }
    }

    /// Best match first. Uses FTS5 (bm25) when available, LIKE otherwise.
    func searchUtterances(_ query: String, limit: Int) -> [Utterance] {
        let terms = Database.searchTerms(from: query)
        guard !terms.isEmpty else { return [] }
        return withConnection { c in
            if self.ftsEnabled {
                let match = terms
                    .map { $0.count >= 3 ? "\"\($0)\"*" : "\"\($0)\"" }
                    .joined(separator: " OR ")
                let columns = Database.columnList(Database.utteranceColumns, prefix: "u.")
                let sql = """
                    SELECT \(columns) FROM utterances_fts
                    JOIN utterances u ON u.id = utterances_fts.rowid
                    WHERE utterances_fts MATCH ? ORDER BY bm25(utterances_fts) ASC, u.started_at DESC LIMIT ?
                    """
                let ranked = c.queryChecked(sql, [.text(match), .limit(limit)], { self.makeUtterance($0) })
                if let ranked, !ranked.isEmpty { return ranked }
            }
            return self.likeSearch(c, terms: terms, limit: limit)
        }
    }

    func wordCount(from start: Date, to end: Date) -> Int {
        withConnection { c in
            let count = c.scalarInt64("""
                SELECT COALESCE(SUM(LENGTH(TRIM(text)) - LENGTH(REPLACE(TRIM(text), ' ', '')) + 1), 0)
                FROM utterances WHERE started_at >= ? AND started_at < ? AND LENGTH(TRIM(text)) > 0
                """, [.date(start), .date(end)]) ?? 0
            return Int(count)
        }
    }

    func deleteUtterances(from start: Date, to end: Date) {
        withConnection { c in
            if c.run("DELETE FROM utterances WHERE started_at >= ? AND started_at < ?", [.date(start), .date(end)]) {
                Log.info("Database: deleted utterances between \(start) and \(end)")
            }
        }
    }

    // MARK: Insights

    func upsertInsight(_ i: Insight) {
        withConnection { c in
            Database.upsert(c, table: "insights", key: "id", columns: Database.insightColumns, values: [
                .text(i.id), .text(i.kind.rawValue), .text(i.title), .text(i.detail), .date(i.dueAt),
                .text(self.json(i.people)), .date(i.sourceFrom), .date(i.sourceTo), .text(i.status.rawValue),
                .real(i.confidence), .date(i.createdAt),
            ])
        }
    }

    func insight(id: String) -> Insight? {
        withConnection { c in
            c.query("SELECT \(Database.columnList(Database.insightColumns)) FROM insights WHERE id = ?",
                    [.text(id)]) { self.makeInsight($0) }.first
        }
    }

    func insights(statuses: [InsightStatus]?, kinds: [InsightKind]?, since: Date?, limit: Int) -> [Insight] {
        if let statuses, statuses.isEmpty { return [] }
        if let kinds, kinds.isEmpty { return [] }
        var clauses: [String] = []
        var arguments: [SQLValue] = []
        if let statuses {
            clauses.append("status IN (\(Database.placeholders(statuses.count)))")
            arguments += statuses.map { SQLValue.text($0.rawValue) }
        }
        if let kinds {
            clauses.append("kind IN (\(Database.placeholders(kinds.count)))")
            arguments += kinds.map { SQLValue.text($0.rawValue) }
        }
        if let since {
            clauses.append("created_at >= ?")
            arguments.append(.date(since))
        }
        arguments.append(.limit(limit))
        let whereSQL = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
        let sql = """
            SELECT \(Database.columnList(Database.insightColumns)) FROM insights
            \(whereSQL) ORDER BY created_at DESC LIMIT ?
            """
        return withConnection { c in
            c.query(sql, arguments) { self.makeInsight($0) }
        }
    }

    // MARK: Prompts

    func upsertPrompt(_ p: StoredPrompt) {
        withConnection { c in
            Database.upsert(c, table: "prompts", key: "id", columns: Database.promptColumns, values: [
                .text(p.id), .text(p.kind.rawValue), .text(p.title), .text(p.body), .text(self.json(p.choices)),
                .bool(p.allowsFreeText), .bool(p.allowsVoice), .int(p.priority), .text(p.status.rawValue),
                .text(p.rationale), .string(p.relatedID), .string(p.answerText), .string(p.answerChoiceID),
                .date(p.createdAt), .date(p.releasedAt), .date(p.deliveredAt), .date(p.answeredAt),
                .date(p.expiresAt), .date(p.notBefore),
            ])
        }
    }

    /// Marks a prompt delivered only while it is still pending (never overwrites a newer status
    /// such as answered). Keeps an existing delivered_at. Returns true if the row changed.
    @discardableResult
    func markPromptDelivered(id: String, at date: Date) -> Bool {
        withConnection { c in
            let ok = c.run("""
                UPDATE prompts SET status = ?, delivered_at = COALESCE(delivered_at, ?)
                WHERE id = ? AND status = ?
                """, [.text(PromptStatus.delivered.rawValue), .date(date), .text(id),
                      .text(PromptStatus.pending.rawValue)])
            return ok && c.changes > 0
        }
    }

    /// Expires a prompt only while its status is one of `statuses` and its expiry is before `now`
    /// (never overwrites a prompt that was answered in the meantime). Returns true if the row changed.
    @discardableResult
    func expirePrompt(id: String, ifStatusIn statuses: [PromptStatus], expiredBefore now: Date) -> Bool {
        guard !statuses.isEmpty else { return false }
        return withConnection { c in
            var arguments: [SQLValue] = [.text(PromptStatus.expired.rawValue), .text(id)]
            arguments += statuses.map { SQLValue.text($0.rawValue) }
            arguments.append(.date(now))
            let ok = c.run("""
                UPDATE prompts SET status = ?
                WHERE id = ? AND status IN (\(Database.placeholders(statuses.count)))
                AND expires_at IS NOT NULL AND expires_at < ?
                """, arguments)
            return ok && c.changes > 0
        }
    }

    func prompt(id: String) -> StoredPrompt? {
        withConnection { c in
            c.query("SELECT \(Database.columnList(Database.promptColumns)) FROM prompts WHERE id = ?",
                    [.text(id)]) { self.makePrompt($0) }.first
        }
    }

    func prompts(statuses: [PromptStatus], limit: Int) -> [StoredPrompt] {
        guard !statuses.isEmpty else { return [] }
        return withConnection { c in
            var arguments: [SQLValue] = statuses.map { SQLValue.text($0.rawValue) }
            arguments.append(.limit(limit))
            return c.query("""
                SELECT \(Database.columnList(Database.promptColumns)) FROM prompts
                WHERE status IN (\(Database.placeholders(statuses.count)))
                ORDER BY created_at DESC LIMIT ?
                """, arguments) { self.makePrompt($0) }
        }
    }

    func prompts(since: Date, limit: Int) -> [StoredPrompt] {
        withConnection { c in
            c.query("""
                SELECT \(Database.columnList(Database.promptColumns)) FROM prompts
                WHERE created_at >= ? ORDER BY created_at DESC LIMIT ?
                """, [.date(since), .limit(limit)]) { self.makePrompt($0) }
        }
    }

    /// Prompts of `kinds` (all kinds when empty) released at or after `since`.
    func countPromptsReleased(kinds: [PromptKind], since: Date) -> Int {
        var sql = "SELECT COUNT(*) FROM prompts WHERE released_at IS NOT NULL AND released_at >= ?"
        var arguments: [SQLValue] = [.date(since)]
        if !kinds.isEmpty {
            sql += " AND kind IN (\(Database.placeholders(kinds.count)))"
            arguments += kinds.map { SQLValue.text($0.rawValue) }
        }
        return withConnection { c in
            Int(c.scalarInt64(sql, arguments) ?? 0)
        }
    }

    /// Latest release time among prompts of `kinds` (all kinds when empty).
    func lastPromptRelease(kinds: [PromptKind]) -> Date? {
        var sql = "SELECT MAX(released_at) FROM prompts WHERE released_at IS NOT NULL"
        var arguments: [SQLValue] = []
        if !kinds.isEmpty {
            sql += " AND kind IN (\(Database.placeholders(kinds.count)))"
            arguments += kinds.map { SQLValue.text($0.rawValue) }
        }
        return withConnection { c in
            c.scalarDouble(sql, arguments).map { Date(timeIntervalSince1970: $0) }
        }
    }

    // MARK: Actions

    func upsertAction(_ a: ProposedAction) {
        withConnection { c in
            Database.upsert(c, table: "actions", key: "id", columns: Database.actionColumns, values: [
                .text(a.id), .text(a.kind.rawValue), .text(a.title), .text(a.rationale), .text(self.json(a.payload)),
                .text(a.status.rawValue), .string(a.result), .string(a.sourceInsightID), .date(a.createdAt),
                .date(a.executedAt),
            ])
        }
    }

    func action(id: String) -> ProposedAction? {
        withConnection { c in
            c.query("SELECT \(Database.columnList(Database.actionColumns)) FROM actions WHERE id = ?",
                    [.text(id)]) { self.makeAction($0) }.first
        }
    }

    func actions(statuses: [ActionStatus]?, limit: Int) -> [ProposedAction] {
        if let statuses, statuses.isEmpty { return [] }
        var arguments: [SQLValue] = []
        var whereSQL = ""
        if let statuses {
            whereSQL = "WHERE status IN (\(Database.placeholders(statuses.count)))"
            arguments += statuses.map { SQLValue.text($0.rawValue) }
        }
        arguments.append(.limit(limit))
        let sql = """
            SELECT \(Database.columnList(Database.actionColumns)) FROM actions
            \(whereSQL) ORDER BY created_at DESC LIMIT ?
            """
        return withConnection { c in
            c.query(sql, arguments) { self.makeAction($0) }
        }
    }

    // MARK: Goals

    func upsertGoal(_ g: Goal) {
        withConnection { c in
            Database.upsert(c, table: "goals", key: "id", columns: Database.goalColumns, values: [
                .text(g.id), .text(g.title), .text(g.why), .text(g.status.rawValue), .date(g.createdAt),
                .date(g.lastCheckIn), .text(self.json(g.notes)),
            ])
        }
    }

    func goal(id: String) -> Goal? {
        withConnection { c in
            c.query("SELECT \(Database.columnList(Database.goalColumns)) FROM goals WHERE id = ?",
                    [.text(id)]) { self.makeGoal($0) }.first
        }
    }

    func goals(statuses: [GoalStatus]?) -> [Goal] {
        if let statuses, statuses.isEmpty { return [] }
        var arguments: [SQLValue] = []
        var whereSQL = ""
        if let statuses {
            whereSQL = "WHERE status IN (\(Database.placeholders(statuses.count)))"
            arguments += statuses.map { SQLValue.text($0.rawValue) }
        }
        let sql = """
            SELECT \(Database.columnList(Database.goalColumns)) FROM goals
            \(whereSQL) ORDER BY created_at DESC
            """
        return withConnection { c in
            c.query(sql, arguments) { self.makeGoal($0) }
        }
    }

    func deleteGoal(id: String) {
        withConnection { c in
            c.run("DELETE FROM goals WHERE id = ?", [.text(id)])
        }
    }

    // MARK: Digests

    func upsertDigest(_ d: Digest) {
        withConnection { c in
            Database.upsert(c, table: "digests", key: "day", columns: Database.digestColumns, values: [
                .text(d.day), .text(d.markdown), .date(d.createdAt),
            ])
        }
    }

    func digest(day: String) -> Digest? {
        withConnection { c in
            c.query("SELECT \(Database.columnList(Database.digestColumns)) FROM digests WHERE day = ?",
                    [.text(day)]) { self.makeDigest($0) }.first
        }
    }

    func digests(limit: Int) -> [Digest] {
        withConnection { c in
            c.query("""
                SELECT \(Database.columnList(Database.digestColumns)) FROM digests
                ORDER BY created_at DESC LIMIT ?
                """, [.limit(limit)]) { self.makeDigest($0) }
        }
    }

    // MARK: Devices

    func upsertDevice(_ d: PairedDevice) {
        withConnection { c in
            let status: SQLValue = d.lastStatus.map { SQLValue.text(self.json($0)) } ?? .null
            Database.upsert(c, table: "devices", key: "token", columns: Database.deviceColumns, values: [
                .text(d.token), .text(d.name), .text(d.kind), .date(d.pairedAt), .date(d.lastSeen), status,
            ])
        }
    }

    func device(token: String) -> PairedDevice? {
        withConnection { c in
            c.query("SELECT \(Database.columnList(Database.deviceColumns)) FROM devices WHERE token = ?",
                    [.text(token)]) { self.makeDevice($0) }.first
        }
    }

    func devices() -> [PairedDevice] {
        withConnection { c in
            c.query("SELECT \(Database.columnList(Database.deviceColumns)) FROM devices ORDER BY paired_at ASC") {
                self.makeDevice($0)
            }
        }
    }

    func deleteDevice(token: String) {
        withConnection { c in
            c.run("DELETE FROM devices WHERE token = ?", [.text(token)])
        }
    }

    // MARK: Bookmarks

    func insertBookmark(_ b: StoredBookmark) {
        withConnection { c in
            Database.upsert(c, table: "bookmarks", key: "id", columns: Database.bookmarkColumns, values: [
                .text(b.id), .text(b.kind.rawValue), .date(b.at), .string(b.note), .text(b.device),
            ])
        }
    }

    func bookmarks(from start: Date, to end: Date) -> [StoredBookmark] {
        withConnection { c in
            c.query("""
                SELECT \(Database.columnList(Database.bookmarkColumns)) FROM bookmarks
                WHERE at >= ? AND at < ? ORDER BY at ASC
                """, [.date(start), .date(end)]) { self.makeBookmark($0) }
        }
    }

    // MARK: Chat

    func insertChatMessage(_ m: ChatMessage) {
        withConnection { c in
            Database.upsert(c, table: "chat", key: "id", columns: Database.chatColumns, values: [
                .text(m.id), .text(m.role.rawValue), .text(m.text), .text(self.json(m.citations)), .date(m.createdAt),
            ])
        }
    }

    /// The last `limit` messages, oldest first.
    func chatMessages(limit: Int) -> [ChatMessage] {
        let newestFirst: [ChatMessage] = withConnection { c in
            c.query("""
                SELECT \(Database.columnList(Database.chatColumns)) FROM chat
                ORDER BY created_at DESC, rowid DESC LIMIT ?
                """, [.limit(limit)]) { self.makeChatMessage($0) }
        }
        return Array(newestFirst.reversed())
    }

    func clearChat() {
        withConnection { c in
            c.run("DELETE FROM chat")
        }
    }

    // MARK: Key-value store

    func kvGet(_ key: String) -> String? {
        withConnection { c in
            c.query("SELECT v FROM kv WHERE k = ?", [.text(key)]) { $0.optionalString(0) }.first
        }
    }

    func kvSet(_ key: String, _ value: String?) {
        withConnection { c in
            if let value {
                Database.upsert(c, table: "kv", key: "k", columns: ["k", "v"], values: [.text(key), .text(value)])
            } else {
                c.run("DELETE FROM kv WHERE k = ?", [.text(key)])
            }
        }
    }

    /// Deletes every row in every table (Settings → Erase all data) and compacts the file.
    func wipeAll() {
        withConnection { c in
            let tables = ["utterances", "segments", "insights", "prompts", "actions", "goals",
                          "digests", "devices", "bookmarks", "chat", "kv"]
            let wiped = c.transaction {
                tables.allSatisfy { c.run("DELETE FROM \($0)") }
            }
            guard wiped else {
                Log.error("Database: erase failed: \(c.errorMessage)")
                return
            }
            if self.ftsEnabled {
                c.exec("INSERT INTO utterances_fts(utterances_fts) VALUES('rebuild')")
            }
            c.exec("VACUUM")
            c.exec("PRAGMA wal_checkpoint(TRUNCATE)")
            Log.info("Database: all data erased")
        }
    }

    // MARK: - Private: locking

    @discardableResult
    private func withConnection<T>(_ body: (SQLiteConnection) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(connection)
    }

    // MARK: - Private: schema

    private static let segmentColumns = ["id", "device", "started_at", "duration", "file_path", "status",
                                         "avg_power", "speech_ratio", "reason", "error", "created_at"]
    private static let utteranceColumns = ["id", "segment_id", "started_at", "ended_at", "text", "speaker"]
    private static let insightColumns = ["id", "kind", "title", "detail", "due_at", "people", "source_from",
                                         "source_to", "status", "confidence", "created_at"]
    private static let promptColumns = ["id", "kind", "title", "body", "choices", "allows_free_text", "allows_voice",
                                        "priority", "status", "rationale", "related_id", "answer_text",
                                        "answer_choice_id", "created_at", "released_at", "delivered_at",
                                        "answered_at", "expires_at", "not_before"]
    private static let actionColumns = ["id", "kind", "title", "rationale", "payload", "status", "result",
                                        "source_insight_id", "created_at", "executed_at"]
    private static let goalColumns = ["id", "title", "why", "status", "created_at", "last_check_in", "notes"]
    private static let digestColumns = ["day", "markdown", "created_at"]
    private static let deviceColumns = ["token", "name", "kind", "paired_at", "last_seen", "last_status"]
    private static let bookmarkColumns = ["id", "kind", "at", "note", "device"]
    private static let chatColumns = ["id", "role", "text", "citations", "created_at"]

    private static let schemaV1 = """
        CREATE TABLE IF NOT EXISTS segments (
            id TEXT PRIMARY KEY NOT NULL,
            device TEXT NOT NULL DEFAULT '',
            started_at REAL NOT NULL,
            duration REAL NOT NULL DEFAULT 0,
            file_path TEXT,
            status TEXT NOT NULL,
            avg_power REAL NOT NULL DEFAULT -160,
            speech_ratio REAL NOT NULL DEFAULT 0,
            reason TEXT NOT NULL DEFAULT '',
            error TEXT,
            created_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_segments_started ON segments(started_at);
        CREATE INDEX IF NOT EXISTS idx_segments_status ON segments(status, started_at);

        CREATE TABLE IF NOT EXISTS utterances (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            segment_id TEXT NOT NULL,
            started_at REAL NOT NULL,
            ended_at REAL NOT NULL,
            text TEXT NOT NULL,
            speaker TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_utterances_started ON utterances(started_at);
        CREATE INDEX IF NOT EXISTS idx_utterances_segment ON utterances(segment_id);

        CREATE TABLE IF NOT EXISTS insights (
            id TEXT PRIMARY KEY NOT NULL,
            kind TEXT NOT NULL,
            title TEXT NOT NULL,
            detail TEXT NOT NULL DEFAULT '',
            due_at REAL,
            people TEXT NOT NULL DEFAULT '[]',
            source_from REAL,
            source_to REAL,
            status TEXT NOT NULL,
            confidence REAL NOT NULL DEFAULT 0,
            created_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_insights_created ON insights(created_at);
        CREATE INDEX IF NOT EXISTS idx_insights_status ON insights(status, created_at);

        CREATE TABLE IF NOT EXISTS prompts (
            id TEXT PRIMARY KEY NOT NULL,
            kind TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL DEFAULT '',
            choices TEXT NOT NULL DEFAULT '[]',
            allows_free_text INTEGER NOT NULL DEFAULT 1,
            allows_voice INTEGER NOT NULL DEFAULT 1,
            priority INTEGER NOT NULL DEFAULT 3,
            status TEXT NOT NULL,
            rationale TEXT NOT NULL DEFAULT '',
            related_id TEXT,
            answer_text TEXT,
            answer_choice_id TEXT,
            created_at REAL NOT NULL,
            released_at REAL,
            delivered_at REAL,
            answered_at REAL,
            expires_at REAL,
            not_before REAL
        );
        CREATE INDEX IF NOT EXISTS idx_prompts_status ON prompts(status, created_at);
        CREATE INDEX IF NOT EXISTS idx_prompts_created ON prompts(created_at);
        CREATE INDEX IF NOT EXISTS idx_prompts_released ON prompts(released_at);

        CREATE TABLE IF NOT EXISTS actions (
            id TEXT PRIMARY KEY NOT NULL,
            kind TEXT NOT NULL,
            title TEXT NOT NULL,
            rationale TEXT NOT NULL DEFAULT '',
            payload TEXT NOT NULL DEFAULT '{}',
            status TEXT NOT NULL,
            result TEXT,
            source_insight_id TEXT,
            created_at REAL NOT NULL,
            executed_at REAL
        );
        CREATE INDEX IF NOT EXISTS idx_actions_status ON actions(status, created_at);
        CREATE INDEX IF NOT EXISTS idx_actions_created ON actions(created_at);

        CREATE TABLE IF NOT EXISTS goals (
            id TEXT PRIMARY KEY NOT NULL,
            title TEXT NOT NULL,
            why TEXT NOT NULL DEFAULT '',
            status TEXT NOT NULL,
            created_at REAL NOT NULL,
            last_check_in REAL,
            notes TEXT NOT NULL DEFAULT '[]'
        );

        CREATE TABLE IF NOT EXISTS digests (
            day TEXT PRIMARY KEY NOT NULL,
            markdown TEXT NOT NULL,
            created_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS devices (
            token TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            kind TEXT NOT NULL,
            paired_at REAL NOT NULL,
            last_seen REAL,
            last_status TEXT
        );

        CREATE TABLE IF NOT EXISTS bookmarks (
            id TEXT PRIMARY KEY NOT NULL,
            kind TEXT NOT NULL,
            at REAL NOT NULL,
            note TEXT,
            device TEXT NOT NULL DEFAULT ''
        );
        CREATE INDEX IF NOT EXISTS idx_bookmarks_at ON bookmarks(at);

        CREATE TABLE IF NOT EXISTS chat (
            id TEXT PRIMARY KEY NOT NULL,
            role TEXT NOT NULL,
            text TEXT NOT NULL,
            citations TEXT NOT NULL DEFAULT '[]',
            created_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_chat_created ON chat(created_at);

        CREATE TABLE IF NOT EXISTS kv (
            k TEXT PRIMARY KEY NOT NULL,
            v TEXT NOT NULL
        );
        """

    /// Ordered list of (version, SQL). Append new migrations; never edit shipped ones.
    private static let migrations: [(version: Int32, sql: String)] = [
        (version: 1, sql: schemaV1),
    ]

    private static func migrate(_ c: SQLiteConnection) throws {
        let current = c.userVersion
        for migration in migrations where migration.version > current {
            let applied = c.transaction {
                c.exec(migration.sql) && c.exec("PRAGMA user_version = \(migration.version)")
            }
            guard applied else {
                throw SQLiteError(message: "Database migration to schema v\(migration.version) failed: \(c.errorMessage)")
            }
            Log.info("Database migrated to schema v\(migration.version)")
        }
    }

    private static let ftsTriggerNames = ["utterances_fts_ai", "utterances_fts_ad", "utterances_fts_au"]

    private static let ftsTableSQL = """
        CREATE VIRTUAL TABLE IF NOT EXISTS utterances_fts USING fts5(
            text, content='utterances', content_rowid='id', tokenize='unicode61'
        );
        """

    private static let ftsTriggersSQL = """
        CREATE TRIGGER IF NOT EXISTS utterances_fts_ai AFTER INSERT ON utterances BEGIN
            INSERT INTO utterances_fts(rowid, text) VALUES (new.id, new.text);
        END;
        CREATE TRIGGER IF NOT EXISTS utterances_fts_ad AFTER DELETE ON utterances BEGIN
            INSERT INTO utterances_fts(utterances_fts, rowid, text) VALUES ('delete', old.id, old.text);
        END;
        CREATE TRIGGER IF NOT EXISTS utterances_fts_au AFTER UPDATE ON utterances BEGIN
            INSERT INTO utterances_fts(utterances_fts, rowid, text) VALUES ('delete', old.id, old.text);
            INSERT INTO utterances_fts(rowid, text) VALUES (new.id, new.text);
        END;
        """

    /// Creates the FTS5 index and its triggers if needed. Returns false when FTS5 is unusable.
    private static func setUpFullTextSearch(_ c: SQLiteConnection) -> Bool {
        let tableExists = (c.scalarInt64(
            "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'utterances_fts'") ?? 0) > 0
        if tableExists {
            let names = ftsTriggerNames.map { "'\($0)'" }.joined(separator: ", ")
            let triggerCount = c.scalarInt64(
                "SELECT COUNT(*) FROM sqlite_master WHERE type = 'trigger' AND name IN (\(names))") ?? 0
            if triggerCount == Int64(ftsTriggerNames.count) { return true }
        }
        let ready = c.transaction {
            c.exec(ftsTableSQL, logFailure: false)
                && c.exec(ftsTriggersSQL, logFailure: false)
                && c.exec("INSERT INTO utterances_fts(utterances_fts) VALUES('rebuild')", logFailure: false)
        }
        if !ready {
            Log.info("Database: FTS5 is unavailable (\(c.errorMessage)); transcript search uses LIKE")
            dropFullTextSearch(c)
        }
        return ready
    }

    private static func dropFullTextSearch(_ c: SQLiteConnection) {
        for name in ftsTriggerNames {
            c.exec("DROP TRIGGER IF EXISTS \(name)", logFailure: false)
        }
        c.exec("DROP TABLE IF EXISTS utterances_fts", logFailure: false)
    }

    /// Call with the lock held.
    private func disableFullTextSearch(_ c: SQLiteConnection) {
        Database.dropFullTextSearch(c)
        ftsEnabled = false
    }

    // MARK: - Private: SQL building

    private static func columnList(_ columns: [String], prefix: String = "") -> String {
        columns.map { prefix + $0 }.joined(separator: ", ")
    }

    private static func placeholders(_ count: Int) -> String {
        Array(repeating: "?", count: max(count, 1)).joined(separator: ", ")
    }

    /// INSERT … ON CONFLICT(key) DO UPDATE (keeps rowid stable, unlike INSERT OR REPLACE).
    @discardableResult
    private static func upsert(_ c: SQLiteConnection, table: String, key: String,
                               columns: [String], values: [SQLValue]) -> Bool {
        let updates = columns.filter { $0 != key }.map { "\($0) = excluded.\($0)" }.joined(separator: ", ")
        let sql = """
            INSERT INTO \(table) (\(columns.joined(separator: ", "))) VALUES (\(placeholders(columns.count)))
            ON CONFLICT(\(key)) DO UPDATE SET \(updates)
            """
        return c.run(sql, values)
    }

    // MARK: - Private: utterance helpers

    private func insertUtteranceRows(_ c: SQLiteConnection, _ items: [Utterance]) -> (rows: [Utterance]?, failure: String) {
        var stored: [Utterance] = []
        stored.reserveCapacity(items.count)
        var failure = ""
        let committed = c.transaction {
            for item in items {
                let inserted = c.run("""
                    INSERT INTO utterances (segment_id, started_at, ended_at, text, speaker)
                    VALUES (?, ?, ?, ?, ?)
                    """, [.text(item.segmentID), .date(item.startedAt), .date(item.endedAt),
                          .text(item.text), .string(item.speaker)])
                guard inserted else {
                    failure = c.errorMessage
                    return false
                }
                var row = item
                row.id = c.lastInsertRowID
                stored.append(row)
            }
            return true
        }
        if committed { return (rows: stored, failure: "") }
        return (rows: nil, failure: failure.isEmpty ? c.errorMessage : failure)
    }

    private static let searchStopWords: Set<String> = [
        "a", "an", "the", "and", "or", "but", "of", "to", "in", "on", "at", "for", "from", "by", "with",
        "is", "are", "was", "were", "be", "been", "it", "its", "this", "that", "these", "those",
        "i", "me", "my", "we", "us", "our", "you", "your", "he", "she", "they", "them",
        "what", "when", "where", "who", "whom", "which", "why", "how",
        "do", "does", "did", "about", "say", "said", "tell", "told", "any", "some",
    ]

    /// Lower-cased, de-duplicated alphanumeric words; stop words dropped when anything else remains.
    private static func searchTerms(from query: String) -> [String] {
        let words = query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        var seen = Set<String>()
        var unique: [String] = []
        for word in words where !seen.contains(word) {
            seen.insert(word)
            unique.append(word)
        }
        let meaningful = unique.filter { !searchStopWords.contains($0) }
        return Array((meaningful.isEmpty ? unique : meaningful).prefix(24))
    }

    /// Fallback search: rows matching more terms rank first, then newest.
    private func likeSearch(_ c: SQLiteConnection, terms: [String], limit: Int) -> [Utterance] {
        let columns = Database.columnList(Database.utteranceColumns)
        let score = terms.map { _ in "(text LIKE ?)" }.joined(separator: " + ")
        let sql = """
            SELECT \(columns) FROM (
                SELECT \(columns), (\(score)) AS score FROM utterances
            ) WHERE score > 0 ORDER BY score DESC, started_at DESC LIMIT ?
            """
        var arguments: [SQLValue] = terms.map { SQLValue.text("%\($0)%") }
        arguments.append(.limit(limit))
        return c.query(sql, arguments) { self.makeUtterance($0) }
    }

    // MARK: - Private: JSON columns

    private func json<T: Encodable>(_ value: T) -> String {
        do {
            let data = try encoder.encode(value)
            return String(decoding: data, as: UTF8.self)
        } catch {
            Log.error("Database: could not encode \(T.self): \(error.localizedDescription)")
            return "null"
        }
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, _ text: String?) -> T? {
        guard let text, !text.isEmpty, text != "null" else { return nil }
        do {
            return try decoder.decode(T.self, from: Data(text.utf8))
        } catch {
            Log.error("Database: could not decode \(T.self): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private: row mapping

    private func makeSegment(_ r: SQLRow) -> Segment {
        Segment(id: r.string(0),
                device: r.string(1),
                startedAt: r.date(2),
                duration: r.double(3),
                filePath: r.optionalString(4),
                status: SegmentStatus(rawValue: r.string(5)) ?? .failed,
                avgPower: Float(r.double(6)),
                speechRatio: Float(r.double(7)),
                reason: r.string(8),
                error: r.optionalString(9),
                createdAt: r.date(10))
    }

    private func makeUtterance(_ r: SQLRow) -> Utterance {
        Utterance(id: r.int64(0),
                  segmentID: r.string(1),
                  startedAt: r.date(2),
                  endedAt: r.date(3),
                  text: r.string(4),
                  speaker: r.optionalString(5))
    }

    private func makeInsight(_ r: SQLRow) -> Insight {
        Insight(id: r.string(0),
                kind: InsightKind(rawValue: r.string(1)) ?? .fact,
                title: r.string(2),
                detail: r.string(3),
                dueAt: r.optionalDate(4),
                people: decodeJSON([String].self, r.optionalString(5)) ?? [],
                sourceFrom: r.optionalDate(6),
                sourceTo: r.optionalDate(7),
                status: InsightStatus(rawValue: r.string(8)) ?? .open,
                confidence: r.double(9),
                createdAt: r.date(10))
    }

    private func makePrompt(_ r: SQLRow) -> StoredPrompt {
        StoredPrompt(id: r.string(0),
                     kind: PromptKind(rawValue: r.string(1)) ?? .info,
                     title: r.string(2),
                     body: r.string(3),
                     choices: decodeJSON([PromptChoice].self, r.optionalString(4)) ?? [],
                     allowsFreeText: r.bool(5),
                     allowsVoice: r.bool(6),
                     priority: r.int(7),
                     status: PromptStatus(rawValue: r.string(8)) ?? .expired,
                     rationale: r.string(9),
                     relatedID: r.optionalString(10),
                     answerText: r.optionalString(11),
                     answerChoiceID: r.optionalString(12),
                     createdAt: r.date(13),
                     releasedAt: r.optionalDate(14),
                     deliveredAt: r.optionalDate(15),
                     answeredAt: r.optionalDate(16),
                     expiresAt: r.optionalDate(17),
                     notBefore: r.optionalDate(18))
    }

    private func makeAction(_ r: SQLRow) -> ProposedAction {
        ProposedAction(id: r.string(0),
                       kind: ActionKind(rawValue: r.string(1)) ?? .note,
                       title: r.string(2),
                       rationale: r.string(3),
                       payload: decodeJSON(ActionPayload.self, r.optionalString(4)) ?? ActionPayload(),
                       status: ActionStatus(rawValue: r.string(5)) ?? .rejected,
                       result: r.optionalString(6),
                       sourceInsightID: r.optionalString(7),
                       createdAt: r.date(8),
                       executedAt: r.optionalDate(9))
    }

    private func makeGoal(_ r: SQLRow) -> Goal {
        Goal(id: r.string(0),
             title: r.string(1),
             why: r.string(2),
             status: GoalStatus(rawValue: r.string(3)) ?? .active,
             createdAt: r.date(4),
             lastCheckIn: r.optionalDate(5),
             notes: decodeJSON([GoalNote].self, r.optionalString(6)) ?? [])
    }

    private func makeDigest(_ r: SQLRow) -> Digest {
        Digest(day: r.string(0), markdown: r.string(1), createdAt: r.date(2))
    }

    private func makeDevice(_ r: SQLRow) -> PairedDevice {
        PairedDevice(token: r.string(0),
                     name: r.string(1),
                     kind: r.string(2),
                     pairedAt: r.date(3),
                     lastSeen: r.optionalDate(4),
                     lastStatus: decodeJSON(WatchStatusReport.self, r.optionalString(5)))
    }

    private func makeBookmark(_ r: SQLRow) -> StoredBookmark {
        StoredBookmark(id: r.string(0),
                       kind: BookmarkKind(rawValue: r.string(1)) ?? .bookmark,
                       at: r.date(2),
                       note: r.optionalString(3),
                       device: r.string(4))
    }

    private func makeChatMessage(_ r: SQLRow) -> ChatMessage {
        ChatMessage(id: r.string(0),
                    role: ChatRole(rawValue: r.string(1)) ?? .assistant,
                    text: r.string(2),
                    citations: decodeJSON([Citation].self, r.optionalString(3)) ?? [],
                    createdAt: r.date(4))
    }
}
