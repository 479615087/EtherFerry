import Foundation
import SQLite3

/// sqlite3_bind_text 使用的析构回调（立即拷贝字符串内容）
let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// 扫描记录数据库帮助类（对应 Android 端 `ScanDatabaseHelper.java`）。
///
/// 数据库文件位于 `Application Support/ether_ferry.db`。
final class ScanDatabase {

    static let shared = ScanDatabase()

    static let table = "scan_records"
    static let colId = "id"
    static let colFileName = "file_name"
    static let colMimeType = "mime_type"
    static let colFileSize = "file_size"
    static let colTimestamp = "timestamp"
    static let colVerified = "verified"
    static let colFilePath = "file_path"
    static let colTextContent = "text_content"
    static let colTextPreview = "text_preview"

    private var db: OpaquePointer?

    private init() {
        let manager = FileManager.default
        guard let directory = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        if !manager.fileExists(atPath: directory.path) {
            try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let path = directory.appendingPathComponent("ether_ferry.db").path
        if sqlite3_open(path, &db) == SQLITE_OK {
            createTable()
        } else {
            print("[ScanDatabase] 打开数据库失败: \(path)")
        }
    }

    deinit {
        if let handle = db {
            sqlite3_close(handle)
        }
    }

    /// 数据库连接句柄
    var handle: OpaquePointer? { db }

    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS \(ScanDatabase.table) (
            \(ScanDatabase.colId) INTEGER PRIMARY KEY AUTOINCREMENT,
            \(ScanDatabase.colFileName) TEXT NOT NULL,
            \(ScanDatabase.colMimeType) TEXT,
            \(ScanDatabase.colFileSize) INTEGER DEFAULT 0,
            \(ScanDatabase.colTimestamp) INTEGER DEFAULT 0,
            \(ScanDatabase.colVerified) INTEGER DEFAULT 0,
            \(ScanDatabase.colFilePath) TEXT,
            \(ScanDatabase.colTextContent) TEXT,
            \(ScanDatabase.colTextPreview) TEXT
        );
        """
        if let handle = db {
            sqlite3_exec(handle, sql, nil, nil, nil)
        }
    }
}
