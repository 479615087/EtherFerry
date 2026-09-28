import CryptoKit
import Foundation

/// 以太渡轮协议常量与工具函数。
///
/// 对应 Android 端 `Protocol.java`。协议走屏幕通道：发送端把文件编码为 QR 码序列循环播放，
/// 接收端用摄像头逐帧扫描后重组为完整文件。
///
/// - Note: zlib 的 C API 通过 `EtherFerry-Bridging-Header.h` 暴露，因此这里不需要 `import zlib`。
enum TransferProtocol {

    /// 协议版本
    static let version = 1

    /// 文本预览上限(字符)，超出部分截断以避免 UI 卡顿
    static let maxTextPreview = 10000

    /// 历史记录上限
    static let maxHistory = 100

    /// 单帧等待超时(秒)，无新帧到达则按单帧处理
    static let singleFrameTimeout: TimeInterval = 2.0

    /// 多帧模式超时(秒)，无新帧则自动重置
    static let staleTimeout: TimeInterval = 30.0

    // MARK: - 工具函数

    /// Base64 解码
    static func base64Decode(_ text: String) -> Data? {
        Data(base64Encoded: text, options: .ignoreUnknownCharacters)
    }

    /// 计算 SHA-256，返回 hex 字符串
    static func sha256(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// ZLIB 解压。先尝试标准 ZLIB 格式，失败则回退尝试 raw DEFLATE 格式
    static func inflate(_ compressed: Data) -> Data? {
        if let result = tryInflate(compressed, windowBits: 15 + 32) {
            return result
        }
        return tryInflate(compressed, windowBits: -15)
    }

    /// 按指定窗口位尝试解压：>0 表示带 zlib 头，-15 表示 raw DEFLATE
    private static func tryInflate(_ compressed: Data, windowBits: Int32) -> Data? {
        var stream = z_stream()
        guard zlib.inflateInit2_(&stream,
                            windowBits,
                            zlib.zlibVersion(),
                            Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            return nil
        }
        defer { zlib.inflateEnd(&stream) }

        // 拷贝一份可写的输入缓冲区
        var input = [UInt8](compressed)
        let chunkSize = 4096
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        var output = Data()
        var failed = false

        input.withUnsafeMutableBufferPointer { inputBuffer in
            stream.next_in = inputBuffer.baseAddress
            stream.avail_in = UInt32(input.count)

            while true {
                let written = buffer.withUnsafeMutableBufferPointer { outputBuffer -> Int in
                    stream.next_out = outputBuffer.baseAddress
                    stream.avail_out = UInt32(chunkSize)
                    let status = zlib.inflate(&stream, Z_NO_FLUSH)
                    if status == Z_STREAM_END || status == Z_OK || status == Z_BUF_ERROR {
                        return chunkSize - Int(stream.avail_out)
                    }
                    // Z_DATA_ERROR / Z_NEED_DICT / Z_MEM_ERROR 等
                    return -1
                }

                if written < 0 {
                    failed = true
                    return
                }
                if written > 0 {
                    output.append(buffer, count: written)
                }
                if written < chunkSize {
                    break
                }
            }
        }

        return failed ? nil : output
    }

    /// 字节流转 UTF-8 文本
    static func bytesToText(_ data: Data) -> String {
        String(decoding: data, as: UTF8.self)
    }

    /// 格式化字节数
    static func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024.0) }
        return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
    }

    /// 清理文件名，移除路径分隔符等非法字符
    static func sanitizeFileName(_ name: String) -> String {
        if name.isEmpty { return "unknown" }
        let illegal = "[^a-zA-Z0-9._\\-]"
        let cleaned = name.replacingOccurrences(of: illegal, with: "_", options: .regularExpression)
        return cleaned.isEmpty ? "unknown" : cleaned
    }
}
