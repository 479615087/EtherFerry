import AVFoundation
import UIKit

/// 二维码识别回调
protocol QRScannerDelegate: AnyObject {
    func qrScanner(_ scanner: QRScanner, didDetect text: String)
    func qrScanner(_ scanner: QRScanner, didFailWithMessage message: String)
}

/// 摄像头 + 二维码识别。
///
/// 对应 Android 端的 `CameraX + ML Kit(BarcodeAnalyzer)` 组合。
/// iOS 原生 `AVCaptureMetadataOutput` 已提供毫秒级的 QR 码检测能力，无需第三方库。
final class QRScanner: NSObject, AVCaptureMetadataOutputObjectsDelegate {

    /// 预览图层绑定的采集会话
    let session = AVCaptureSession()

    weak var delegate: QRScannerDelegate?

    /// 是否处于识别状态(false 时丢弃画面上的二维码，等同于 Android 的 setActive(false))
    private(set) var active = true

    private let sessionQueue = DispatchQueue(label: "cn.nordrassil.myapp.capture")
    private var configured = false

    // MARK: - 会话配置

    /// 配置采集会话(幂等，可在任意线程调用)
    func configure() {
        sessionQueue.async {
            guard !self.configured else { return }
            self.configured = true
            self.setupSession()
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            notifyFailure("未找到后置摄像头")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                notifyFailure("无法添加摄像头输入")
                return
            }
            session.addInput(input)
        } catch {
            notifyFailure("摄像头不可用: \(error.localizedDescription)")
            return
        }

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            notifyFailure("无法添加二维码识别输出")
            return
        }
        session.addOutput(output)
        // 识别结果回调在主线程，便于直接刷新 SwiftUI 状态
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]
    }

    // MARK: - 生命周期

    func start() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    /// 暂停 / 恢复识别
    func setActive(_ value: Bool) {
        if Thread.isMainThread {
            active = value
        } else {
            DispatchQueue.main.async { self.active = value }
        }
    }

    private func notifyFailure(_ message: String) {
        DispatchQueue.main.async {
            self.delegate?.qrScanner(self, didFailWithMessage: message)
        }
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard active else { return }
        for object in metadataObjects {
            guard let code = object as? AVMetadataMachineReadableCodeObject,
                  let text = code.stringValue,
                  !text.isEmpty else { continue }
            delegate?.qrScanner(self, didDetect: text)
        }
    }
}
