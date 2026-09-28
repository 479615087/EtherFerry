import Foundation

/// 帧收集器回调（对应 Android 端 FrameCollector.Listener）
protocol FrameCollectorListener: AnyObject {
    /// 收到 Header 帧（多帧模式开始）
    func onHeader(_ header: Frame)
    /// 多帧模式进度更新
    func onProgress(received: Int, total: Int)
    /// 多帧模式接收完成
    func onComplete(data: Data, name: String, mime: String, verified: Bool?, isText: Bool)
    /// 单帧模式接收完成
    func onSingleFrame(data: Data, isText: Bool)
    /// 发生错误
    func onError(_ message: String)
    /// 多帧模式超时，已自动重置
    func onStale()
    /// 单帧模式收到第一帧
    func onFirstFrame()
}

/// 帧收集器：持续接收 QR 帧，收齐后自动拼合 → 解压 → SHA-256 校验。
///
/// 支持两种模式：
/// - 多帧模式：先收到 Header，再收齐 chunks 数量的数据帧
/// - 单帧模式：无 Header，收到 1 个数据帧后等待 2 秒无新帧则确认完成
///
/// 对应 Android 端 `FrameCollector.java`。
/// 所有回调在主线程执行（二维码识别回调本身就在主线程），因此无需额外同步。
final class FrameCollector {

    private weak var listener: FrameCollectorListener?

    private var header: Frame?
    private var chunks: [Int: Data] = [:]
    private var totalChunks = 0
    private var frameCount = 0
    private var frameIsText = false

    private var singleItem: DispatchWorkItem?
    private var staleItem: DispatchWorkItem?

    init(listener: FrameCollectorListener) {
        self.listener = listener
    }

    // MARK: - 帧处理

    func processFrame(_ frame: Frame) {
        if frame.isHeader {
            // 循环播放时同一传输的 Header 会重复出现，不清空已收数据
            if let existing = header, existing.sha256 == frame.sha256 {
                return
            }
            clearTimers()
            header = frame
            totalChunks = frame.chunks
            chunks.removeAll()
            listener?.onHeader(frame)
            return
        }

        guard frame.isData else { return }

        // 去重
        if chunks[frame.index] != nil {
            frameCount += 1
            return
        }

        chunks[frame.index] = frame.data
        frameCount += 1
        if frame.text { frameIsText = true }

        // 单帧标记：发送端已声明这是单帧，立即完成，无需等超时
        if frame.single {
            clearTimers()
            assembleSingle()
            return
        }

        if header != nil {
            // 多帧模式：已收到 Header，知道总帧数，无限等待缺失帧（发送端循环播放）
            listener?.onProgress(received: chunks.count, total: totalChunks)
            if chunks.count == totalChunks {
                clearTimers()
                assembleMulti()
            }
        } else {
            if chunks.count > 1 {
                // 收到多个不同索引的数据帧，说明是多帧传输，等待 Header
                clearTimers()
                restartStaleTimer()
            } else if frame.index == 1 {
                // 仅收到一个索引为 1 的帧，可能是单帧模式
                listener?.onFirstFrame()
                startSingleFrameTimer()
            }
        }
    }

    // MARK: - 计时器

    private func startSingleFrameTimer() {
        clearTimers()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.header == nil && !self.chunks.isEmpty {
                self.assembleSingle()
            }
        }
        singleItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + TransferProtocol.singleFrameTimeout, execute: item)
    }

    private func restartStaleTimer() {
        staleItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.listener?.onStale()
            self.reset()
        }
        staleItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + TransferProtocol.staleTimeout, execute: item)
    }

    private func clearTimers() {
        singleItem?.cancel()
        singleItem = nil
        staleItem?.cancel()
        staleItem = nil
    }

    // MARK: - 重组

    private func assembleSingle() {
        guard chunks.count <= 1 else { return }
        guard let data = chunks[1] else { return }
        listener?.onSingleFrame(data: data, isText: frameIsText)
    }

    private func assembleMulti() {
        guard let header = header else { return }

        // 按序号拼接
        var combined = Data()
        for key in chunks.keys.sorted() {
            combined.append(chunks[key] ?? Data())
        }

        // 解压
        let raw: Data?
        if header.compressed {
            raw = TransferProtocol.inflate(combined)
        } else {
            raw = combined
        }
        guard let rawData = raw else {
            listener?.onError("解压失败")
            return
        }

        // SHA-256 校验
        var verified: Bool?
        if !header.sha256.isEmpty {
            verified = TransferProtocol.sha256(rawData) == header.sha256
        }

        listener?.onComplete(data: rawData,
                             name: header.name,
                             mime: header.mime,
                             verified: verified,
                             isText: header.text)
    }

    // MARK: - 缺失帧

    /// 返回缺失帧索引列表(1-based)，仅在多帧模式下有意义
    func getMissingFrames() -> [Int] {
        var missing: [Int] = []
        if totalChunks <= 0 { return missing }
        for index in 1...totalChunks {
            if chunks[index] == nil { missing.append(index) }
        }
        return missing
    }

    /// 格式化缺失帧列表：连续范围合并。例：[3,4,5,10] → "3-5, 10"
    static func formatMissingFrames(_ missing: [Int]) -> String {
        guard let first = missing.first else { return "" }
        var parts: [String] = []
        var start = first
        var end = first

        for index in missing.dropFirst() {
            if index == end + 1 {
                end = index
            } else {
                parts.append(start == end ? "\(start)" : "\(start)-\(end)")
                start = index
                end = index
            }
        }
        parts.append(start == end ? "\(start)" : "\(start)-\(end)")
        return parts.joined(separator: ", ")
    }

    // MARK: - 状态

    /// 重置收集器状态
    func reset() {
        clearTimers()
        header = nil
        chunks.removeAll()
        totalChunks = 0
        frameCount = 0
        frameIsText = false
    }
}
