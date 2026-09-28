import Foundation
import SQLite3

/// 扫描记录数据仓库（对应 Android 端 `ScanRepository.java`）。
///
/// 负责把接收到的文件写入沙盒 `Documents/received`，并把元信息写入 SQLite。
/// 自动保留最近 `TransferProtocol.maxHistory` 条记录，超出的旧记录及其文件一并删除。
final class ScanRepository {

    private static let receivedDirName = "received"

    init() {
        // 确保数据库已初始化
        _ = ScanDatabase.shared
    }

    // MARK: - 目录

    private var receivedDirectory: URL {
        let manager = FileManager.default
        let directory = manager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(ScanRepository.receivedDirName, isDirectory: true)
        if !manager.fileExists(atPath: directory.path) {
            try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    // MARK: - 写入

    /// 存储接收到的数据，返回新记录的 id；失败返回 -1
    @discardableResult
    func insert(fileName: String, mimeType: String?, data: Data, verified: Bool) -> Int64 {
        let directory = receivedDirectory
        let safeName = TransferProtocol.sanitizeFileName(fileName)
        let storedName = ScanRepository.uniqueFileName(in: directory, name: safeName)
        let fileURL = directory.appendingPathComponent(storedName)

        do {
            try data.write(to: fileURL)
        } catch {
            print("[ScanRepository] 写入文件失败: \(error)")
            return -1
        }

        // 文本内容（仅文本类型才存库）
        var textContent: String?
        var textPreview: String?
        if let mimeType = mimeType, mimeType.hasPrefix("text/") {
            textContent = TransferProtocol.bytesToText(data)
            if let content = textContent {
                textPreview = String(content.prefix(100))
            }
        }

        guard let db = ScanDatabase.shared.handle else { return -1 }
        let sql = """
        INSERT INTO \(ScanDatabase.table)
        (\(ScanDatabase.colFileName), \(ScanDatabase.colMimeType), \(ScanDatabase.colFileSize),
         \(ScanDatabase.colTimestamp), \(ScanDatabase.colVerified), \(ScanDatabase.colFilePath),
         \(ScanDatabase.colTextContent), \(ScanDatabase.colTextPreview))
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("[ScanRepository] prepare 失败")
            return -1
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (fileName as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if let mimeType = mimeType {
            sqlite3_bind_text(statement, 2, (mimeType as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 2)
        }
        sqlite3_bind_int64(statement, 3, Int64(data.count))
        sqlite3_bind_int64(statement, 4, Int64(Date().timeIntervalSince1970 * 1000))
        sqlite3_bind_int(statement, 5, verified ? 1 : 0)
        sqlite3_bind_text(statement, 6, (fileURL.path as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if let textContent = textContent {
            sqlite3_bind_text(statement, 7, (textContent as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 7)
        }
        if let textPreview = textPreview {
            sqlite3_bind_text(statement, 8, (textPreview as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 8)
        }

        guard sqlite3_step(statement) == SQLITE_DONE else { return -1 }

        let rowId = sqlite3_last_insert_rowid(db)
        if rowId > 0 {
            trimToMax(db: db)
        }
        return rowId
    }

    // MARK: - 查询

    /// 获取所有记录（按时间倒序）
    func getAll() -> [ScanRecord] {
        guard let db = ScanDatabase.shared.handle else { return [] }
        let sql = "SELECT * FROM \(ScanDatabase.table) ORDER BY \(ScanDatabase.colTimestamp) DESC;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }

        var records: [ScanRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            records.append(ScanRepository.record(from: statement))
        }
        return records
    }

    /// 按 id 获取单条记录
    func getById(_ id: Int64) -> ScanRecord? {
        guard let db = ScanDatabase.shared.handle else { return nil }
        let sql = "SELECT * FROM \(ScanDatabase.table) WHERE \(ScanDatabase.colId) = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, id)

        if sqlite3_step(statement) == SQLITE_ROW {
            return ScanRepository.record(from: statement)
        }
        return nil
    }

    // MARK: - 删除

    /// 删除指定记录及其文件
    func delete(_ id: Int64) {
        guard let db = ScanDatabase.shared.handle else { return }
        let path = filePath(of: id, db: db)
        if let path = path {
            try? FileManager.default.removeItem(atPath: path)
        }
        let sql = "DELETE FROM \(ScanDatabase.table) WHERE \(ScanDatabase.colId) = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, id)
        sqlite3_step(statement)
    }

    /// 清空所有记录及其文件
    func clearAll() {
        guard let db = ScanDatabase.shared.handle else { return }
        let sql = "SELECT \(ScanDatabase.colFilePath) FROM \(ScanDatabase.table);"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        while sqlite3_step(statement) == SQLITE_ROW {
            if let value = ScanRepository.string(statement, index: 0) {
                try? FileManager.default.removeItem(atPath: value)
            }
        }
        sqlite3_finalize(statement)
        sqlite3_exec(db, "DELETE FROM \(ScanDatabase.table);", nil, nil, nil)
    }

    // MARK: - 内部方法

    private func filePath(of id: Int64, db: OpaquePointer) -> String? {
        let sql = "SELECT \(ScanDatabase.colFilePath) FROM \(ScanDatabase.table) WHERE \(ScanDatabase.colId) = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, id)
        if sqlite3_step(statement) == SQLITE_ROW {
            return ScanRepository.string(statement, index: 0)
        }
        return nil
    }

    /// 裁剪：保留最近 `maxHistory` 条，删除更早的记录及其文件
    private func trimToMax(db: OpaquePointer) {
        let sql = """
        SELECT \(ScanDatabase.colId), \(ScanDatabase.colFilePath)
        FROM \(ScanDatabase.table)
        ORDER BY \(ScanDatabase.colTimestamp) DESC
        LIMIT -1 OFFSET \(TransferProtocol.maxHistory);
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }

        var idsToDelete: [Int64] = []
        var pathsToDelete: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            idsToDelete.append(sqlite3_column_int64(statement, 0))
            if let value = ScanRepository.string(statement, index: 1) {
                pathsToDelete.append(value)
            }
        }
        sqlite3_finalize(statement)

        for path in pathsToDelete {
            try? FileManager.default.removeItem(atPath: path)
        }

        guard !idsToDelete.isEmpty else { return }
        let deleteSQL = "DELETE FROM \(ScanDatabase.table) WHERE \(ScanDatabase.colId) = ?;"
        var deleteStatement: OpaquePointer?
        guard sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStatement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(deleteStatement) }
        for id in idsToDelete {
            sqlite3_bind_int64(deleteStatement, 1, id)
            sqlite3_step(deleteStatement)
            sqlite3_reset(deleteStatement)
        }
    }

    /// 生成不冲突的文件名：若已存在则追加 (1)、(2)… 后缀
    private static func uniqueFileName(in directory: URL, name: String) -> String {
        let manager = FileManager.default
        if !manager.fileExists(atPath: directory.appendingPathComponent(name).path) {
            return name
        }
        let dotIndex = name.lastIndex(of: ".") ?? name.endIndex
        let hasDot = dotIndex != name.endIndex
        let base = String(name[name.startIndex..<(hasDot ? dotIndex : name.endIndex)])
        let ext = hasDot ? String(name[dotIndex...]) : ""

        var counter = 1
        var candidate = ""
        repeat {
            candidate = "\(base)(\(counter))\(ext)"
            counter += 1
        } while manager.fileExists(atPath: directory.appendingPathComponent(candidate).path)
        return candidate
    }

    /// 游标 → ScanRecord（依赖 SELECT * 的列顺序与建表顺序一致）
    private static func record(from statement: OpaquePointer?) -> ScanRecord {
        ScanRecord(
            id: sqlite3_column_int64(statement, 0),
            fileName: ScanRepository.string(statement, index: 1) ?? "",
            mimeType: ScanRepository.string(statement, index: 2) ?? "",
            fileSize: sqlite3_column_int64(statement, 3),
            timestamp: sqlite3_column_int64(statement, 4),
            verified: sqlite3_column_int(statement, 5) == 1,
            filePath: ScanRepository.string(statement, index: 6),
            textContent: ScanRepository.string(statement, index: 7),
            textPreview: ScanRepository.string(statement, index: 8)
        )
    }

    private static func string(_ statement: OpaquePointer?, index: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: pointer)
    }

    /// 格式化时间戳为可读字符串
    static func formatTime(_ timestamp: Int64) -> String {
        let diff = Int64(Date().timeIntervalSince1970 * 1000) - timestamp
        if diff < 60000 { return "刚刚" }
        if diff < 3600000 { return "\(diff / 60000) 分钟前" }
        if diff < 86400000 { return "\(diff / 3600000) 小时前" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000))
    }
}
