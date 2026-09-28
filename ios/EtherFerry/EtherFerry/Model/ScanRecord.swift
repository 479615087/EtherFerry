import Foundation

/// 扫描记录数据模型（对应 SQLite 表 scan_records 的一行）。
///
/// 文件数据本体存储在沙盒 Documents/received 目录，数据库仅保存元信息与文本内容。
struct ScanRecord: Identifiable, Hashable {

    let id: Int64
    let fileName: String
    let mimeType: String
    let fileSize: Int64
    let timestamp: Int64
    let verified: Bool
    let filePath: String?
    let textContent: String?
    let textPreview: String?

    var isText: Bool { mimeType.hasPrefix("text/") }
    var isImage: Bool { mimeType.hasPrefix("image/") }
    var isNonProtocol: Bool { mimeType == "non-protocol" }
}
