import Foundation

/// QR 协议帧数据结构。
///
/// 两种帧类型：
/// - header：文件元信息(名称、大小、SHA-256、分片数、压缩标记等)
/// - data：分片数据(索引 + base64 编码的字节)
///
/// 对应 Android 端 `Frame.java`。
struct Frame {

    /// 帧类型
    var type: String = ""

    // ─── header 字段 ───
    var name: String = ""
    var size: Int = 0
    var sha256: String = ""
    var chunks: Int = 0
    var compressed: Bool = false
    var compSize: Int = 0
    var mime: String = "application/octet-stream"

    // ─── data 字段 ───
    var index: Int = 0
    var data: Data = Data()

    // ─── 通用字段 ───
    var text: Bool = false
    var single: Bool = false

    var isHeader: Bool { type == "header" }
    var isData: Bool { type == "data" }

    /// 解析 QR 码文本为帧对象；非本协议帧返回 nil
    static func parse(_ payload: String) -> Frame? {
        guard let raw = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: raw),
              let json = object as? [String: Any] else {
            return nil
        }

        let version = json["v"] as? Int ?? 0
        guard version == TransferProtocol.version else { return nil }

        guard let type = json["type"] as? String, type == "header" || type == "data" else {
            return nil
        }

        var frame = Frame()
        frame.type = type

        if type == "header" {
            frame.name = json["name"] as? String ?? ""
            frame.size = json["size"] as? Int ?? 0
            frame.sha256 = json["sha256"] as? String ?? ""
            frame.chunks = json["chunks"] as? Int ?? 0
            frame.compressed = json["compressed"] as? Bool ?? false
            frame.compSize = json["compSize"] as? Int ?? 0
            frame.mime = json["mime"] as? String ?? "application/octet-stream"
            frame.text = json["text"] as? Bool ?? false
        } else {
            frame.index = json["i"] as? Int ?? 0
            frame.data = TransferProtocol.base64Decode(json["data"] as? String ?? "") ?? Data()
            frame.text = json["text"] as? Bool ?? false
            frame.single = json["single"] as? Bool ?? false
        }

        return frame
    }
}
