import AVFoundation
import Foundation
import SwiftUI
import UIKit

/// 扫描状态（对应 Android 端 ScanFragment.ScanState）
enum ScanState {
    case idle
    case scanning
    case paused
    case completed
}

/// 扫描界面视图模型：摄像头扫描 → 协议重组 → 展示结果 → 保存历史
final class ScanViewModel: ObservableObject, QRScannerDelegate, FrameCollectorListener {

    // MARK: - UI 状态

    @Published var state: ScanState = .idle
    @Published var statusText = "点击下方「开始扫描」按钮"
    @Published var statusColor: Color = Theme.purple
    @Published var cameraVisible = false

    @Published var showFileName = false
    @Published var fileNameText = ""

    @Published var showProgress = false
    @Published var progressText = ""
    @Published var progressFraction: Double = 0
    @Published var speedText = ""

    @Published var showMissing = false
    @Published var missingText = ""

    @Published var showElapsed = false
    @Published var elapsedText = ""

    @Published var showResult = false
    @Published var resultText = ""
    @Published var showActions = false
    @Published var showStopRow = false
    @Published var resultIsText = false

    @Published var toastMessage: String?

    // MARK: - 依赖

    let scanner = QRScanner()
    private var collector: FrameCollector!
    private let repository = ScanRepository()

    // MARK: - 内部状态

    private var resultShown = false
    private var lastNonProtocolQr = ""

    private var transferStartTime: TimeInterval = 0
    private var totalBytes: Int64 = 0
    private var receivedFrames = 0
    private var lastSpeedTime: TimeInterval = 0
    private var speedTimer: Timer?

    private var currentData: Data?
    private var currentName: String?
    private var currentMime: String?
    private var currentFilePath: String?
    private var currentIsText = false

    private var toastItem: DispatchWorkItem?

    init() {
        collector = FrameCollector(listener: self)
        scanner.delegate = self
        scanner.configure()
        startSpeedTimer()
    }

    deinit {
        speedTimer?.invalidate()
        toastItem?.cancel()
    }

    // MARK: - 界面生命周期

    func viewAppeared() {
        startSpeedTimer()
        if cameraVisible {
            scanner.start()
        }
    }

    func viewDisappeared() {
        stopSpeedTimer()
        scanner.stop()
    }

    // MARK: - 主按钮

    var mainButtonTitle: String {
        switch state {
        case .idle: return "开始扫描"
        case .scanning: return "暂停扫描"
        case .paused: return "继续扫描"
        case .completed: return "重新扫描"
        }
    }

    var mainButtonColor: Color {
        switch state {
        case .idle, .paused: return Theme.purple
        case .scanning: return Theme.btnPause
        case .completed: return Theme.btnRescan
        }
    }

    func tapMainButton() {
        switch state {
        case .idle: checkCameraPermission()
        case .scanning: pauseScanning()
        case .paused: resumeScanning()
        case .completed: resetForRescan()
        }
    }

    /// 终止扫描：释放摄像头回到初始态
    func stopScanning() {
        scanner.stop()
        scanner.setActive(false)
        cameraVisible = false
        state = .idle
        setStatus("已终止扫描，点击「开始扫描」重新启动", color: Theme.purple)
    }

    private func pauseScanning() {
        scanner.setActive(false)
        state = .paused
        setStatus("已暂停", color: Theme.purple)
    }

    private func resumeScanning() {
        resultShown = false
        scanner.setActive(true)
        state = .scanning
        setStatus("对准二维码", color: Theme.purple)
    }

    // MARK: - 权限

    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            startCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if granted {
                        self.startCamera()
                    } else {
                        self.setStatus("需要摄像头权限才能扫描", color: Theme.red)
                    }
                }
            }
        case .denied, .restricted:
            setStatus("需要摄像头权限才能扫描，请到「设置」中开启", color: Theme.red)
        @unknown default:
            setStatus("摄像头权限状态未知", color: Theme.red)
        }
    }

    private func startCamera() {
        scanner.configure()
        scanner.start()
        cameraVisible = true
        if state == .idle {
            state = .scanning
        }
        scanner.setActive(state == .scanning)
        setStatus("对准二维码", color: Theme.purple)
    }

    // MARK: - 结果操作

    func copyResult() {
        guard let data = currentData else { return }
        UIPasteboard.general.string = TransferProtocol.bytesToText(data)
        showToast("已复制到剪贴板")
    }

    /// 分享当前结果。asFile = true 时始终以文件形式分享
    func shareResult(asFile: Bool) {
        guard let data = currentData else { return }

        if !asFile && resultIsText {
            ShareHelper.present(items: [TransferProtocol.bytesToText(data)])
            return
        }

        if let path = currentFilePath, FileManager.default.fileExists(atPath: path) {
            ShareHelper.present(items: [URL(fileURLWithPath: path)])
            return
        }

        // 兜底：写入临时文件再分享
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(currentName ?? "received")
        do {
            try data.write(to: tempURL)
            ShareHelper.present(items: [tempURL])
        } catch {
            showToast("无法分享: \(error.localizedDescription)")
        }
    }

    private func resetForRescan() {
        collector.reset()
        resultShown = false
        lastNonProtocolQr = ""
        currentData = nil
        currentName = nil
        currentMime = nil
        currentFilePath = nil
        currentIsText = false

        showResult = false
        resultText = ""
        showFileName = false
        fileNameText = ""
        showActions = false
        resultIsText = false
        showProgress = false
        progressFraction = 0
        progressText = ""
        speedText = ""
        showMissing = false
        missingText = ""
        showElapsed = false
        elapsedText = ""
        showStopRow = false

        if cameraVisible {
            scanner.start()
            scanner.setActive(true)
            state = .scanning
            setStatus("对准二维码", color: Theme.purple)
        } else {
            state = .idle
            setStatus("点击下方「开始扫描」按钮", color: Theme.purple)
        }
    }

    // MARK: - QRScannerDelegate

    func qrScanner(_ scanner: QRScanner, didDetect text: String) {
        guard !resultShown else { return }
        if let frame = Frame.parse(text) {
            collector.processFrame(frame)
        } else {
            handleNonProtocolQr(text)
        }
    }

    func qrScanner(_ scanner: QRScanner, didFailWithMessage message: String) {
        setStatus("摄像头错误: \(message)", color: Theme.red)
    }

    // MARK: - 非协议 QR

    private func handleNonProtocolQr(_ text: String) {
        guard text != lastNonProtocolQr else { return }
        lastNonProtocolQr = text

        guard let data = text.data(using: .utf8) else { return }
        let name = "QR码.txt"

        currentData = data
        currentName = name
        currentMime = "text/plain"
        currentIsText = true
        currentFilePath = nil
        resultIsText = true

        currentFilePath = saveToHistory(name: name, mime: "text/plain", data: data, verified: true)

        resultText = TransferProtocol.bytesToText(data)
        showResult = true
        showActions = true
        showFileName = true
        fileNameText = "\(name) (\(TransferProtocol.formatBytes(Int64(data.count))))"
        setStatus("接收完成!", color: Theme.green)

        resultShown = true
        scanner.setActive(false)
        state = .completed
    }

    // MARK: - FrameCollectorListener

    func onHeader(_ header: Frame) {
        showFileName = true
        fileNameText = "\(header.name) (\(TransferProtocol.formatBytes(Int64(header.size))))"
        showProgress = true
        progressFraction = 0
        progressText = "0 / \(header.chunks)"
        speedText = ""
        setStatus("正在接收...", color: Theme.purple)
        transferStartTime = Date().timeIntervalSince1970
        totalBytes = Int64(header.size)
    }

    func onProgress(received: Int, total: Int) {
        progressText = "\(received) / \(total)"
        progressFraction = total > 0 ? Double(received) / Double(total) : 0
        receivedFrames += 1

        let missingCount = total - received
        if missingCount > 0 {
            let missing = collector.getMissingFrames()
            missingText = "缺失 \(missing.count) 帧: \(FrameCollector.formatMissingFrames(missing)) (可让发送端重传缺失帧)"
            showMissing = true
        } else {
            showMissing = false
        }
    }

    func onComplete(data: Data, name: String, mime: String, verified: Bool?, isText: Bool) {
        currentData = data
        currentName = name.isEmpty ? "received_file" : name
        currentMime = mime.isEmpty ? "application/octet-stream" : mime
        currentIsText = isText
        currentFilePath = nil
        resultShown = true // 同步设置，防止竞态期间新二维码触发重复回调

        currentFilePath = saveToHistory(name: currentName ?? "received_file",
                                        mime: currentMime ?? "application/octet-stream",
                                        data: data,
                                        verified: verified == nil || verified == true)

        showProgress = false
        showMissing = false

        if let verified = verified, !verified {
            setStatus("校验失败!数据可能不完整", color: Theme.red)
        } else {
            setStatus("接收完成!", color: Theme.green)
        }

        let isTextMime = currentMime?.hasPrefix("text/") ?? false
        if isTextMime {
            showTextPreview(TransferProtocol.bytesToText(data))
        }
        resultIsText = isTextMime
        showActions = true
        scanner.setActive(false)
        showElapsedTime()
        state = .completed
    }

    func onSingleFrame(data: Data, isText: Bool) {
        currentData = data
        currentName = "received.txt"
        currentMime = "text/plain"
        currentIsText = isText
        currentFilePath = nil
        resultShown = true

        currentFilePath = saveToHistory(name: "received.txt", mime: "text/plain", data: data, verified: true)

        showProgress = false
        showMissing = false
        setStatus("接收完成!", color: Theme.green)
        showTextPreview(TransferProtocol.bytesToText(data))
        resultIsText = true
        showActions = true
        scanner.setActive(false)
        showElapsedTime()
        state = .completed
    }

    func onError(_ message: String) {
        collector.reset()
        setStatus("错误: \(message)，请重新扫描", color: Theme.red)
        showProgress = false
        showFileName = false
        showActions = false
        state = .completed
    }

    func onStale() {
        setStatus("扫描超时，已重置，请重新对准", color: Theme.red)
        showProgress = false
        showFileName = false
        showActions = false
        state = .completed
    }

    func onFirstFrame() {
        transferStartTime = Date().timeIntervalSince1970
        totalBytes = 0
    }

    // MARK: - 展示辅助

    /// 显示文本预览（限制 MAX_TEXT_PREVIEW 字符）
    private func showTextPreview(_ text: String) {
        if text.count > TransferProtocol.maxTextPreview {
            let preview = String(text.prefix(TransferProtocol.maxTextPreview))
            resultText = preview + "\n\n... [内容过大，仅预览前 "
                + TransferProtocol.formatBytes(Int64(TransferProtocol.maxTextPreview))
                + "，完整内容请通过分享查看]"
        } else {
            resultText = text
        }
        showResult = true
    }

    private func showElapsedTime() {
        guard transferStartTime > 0 else { return }
        let elapsed = Date().timeIntervalSince1970 - transferStartTime
        var speed = ""
        if elapsed > 0 && totalBytes > 0 {
            let bytesPerSecond = Int64(Double(totalBytes) / elapsed)
            speed = "  速度: \(TransferProtocol.formatBytes(bytesPerSecond))/s"
        }
        elapsedText = String(format: "耗时: %.1f 秒%@", elapsed, speed)
        showElapsed = true
    }

    private func saveToHistory(name: String, mime: String, data: Data, verified: Bool) -> String? {
        let id = repository.insert(fileName: name, mimeType: mime, data: data, verified: verified)
        guard id > 0 else { return nil }
        return repository.getById(id)?.filePath
    }

    private func setStatus(_ text: String, color: Color) {
        statusText = text
        statusColor = color
    }

    func showToast(_ message: String) {
        toastMessage = message
        toastItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.toastMessage = nil
        }
        toastItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: item)
    }

    // MARK: - 帧速统计

    private func startSpeedTimer() {
        guard speedTimer == nil else { return }
        lastSpeedTime = Date().timeIntervalSince1970
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date().timeIntervalSince1970
            let elapsed = now - self.lastSpeedTime
            if self.showProgress, elapsed > 0, self.receivedFrames > 0 {
                let fps = Int(Double(self.receivedFrames) / elapsed)
                self.speedText = "~\(fps) 帧/秒"
            }
            self.lastSpeedTime = now
            self.receivedFrames = 0
        }
        RunLoop.main.add(timer, forMode: .common)
        speedTimer = timer
    }

    private func stopSpeedTimer() {
        speedTimer?.invalidate()
        speedTimer = nil
    }
}
