import SwiftUI

/// 扫描界面：摄像头预览 + 二维码识别 + 协议帧重组 + 结果展示。
///
/// 对应 Android 端 `ScanFragment`（activity_scan.xml）。
struct ScanView: View {

    @StateObject private var viewModel = ScanViewModel()
    @State private var showStopConfirm = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    cameraArea
                        .frame(height: max(CGFloat(220), geometry.size.height * 0.42))
                    Divider()
                    infoArea
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("以太渡轮")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: viewModel.viewAppeared)
            .onDisappear(perform: viewModel.viewDisappeared)
            .overlay(alignment: .bottom) { toastOverlay }
            .alert("终止扫描", isPresented: $showStopConfirm) {
                Button("确定") { viewModel.stopScanning() }
                Button("取消", role: .cancel) { }
            } message: {
                Text("确定要终止当前扫描吗？")
            }
        }
    }

    // MARK: - 摄像头区域

    private var cameraArea: some View {
        ZStack {
            if viewModel.cameraVisible {
                CameraPreview(session: viewModel.scanner.session)
            } else {
                Color(.systemBackground)
            }

            if viewModel.cameraVisible {
                ScanFrameOverlay(running: viewModel.state == .scanning)
            } else {
                Text("点击下方「开始扫描」按钮")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textHint)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    // MARK: - 信息区域

    private var infoArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.statusText)
                    .font(.system(size: 14))
                    .foregroundColor(viewModel.statusColor)

                if viewModel.showFileName {
                    Text(viewModel.fileNameText)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }

                if viewModel.showProgress {
                    ProgressView(value: viewModel.progressFraction)
                        .tint(Theme.purple)
                    HStack {
                        Text(viewModel.progressText)
                        Spacer()
                        Text(viewModel.speedText)
                    }
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textHint)
                }

                if viewModel.showMissing {
                    Text(viewModel.missingText)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.orange)
                }

                if viewModel.showElapsed {
                    Text(viewModel.elapsedText)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textHint)
                }

                if viewModel.showResult {
                    resultBox
                }

                buttonsArea
            }
            .padding(12)
        }
    }

    private var resultBox: some View {
        Text(viewModel.resultText)
            .font(.system(size: 13, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(6)
            .padding(.top, 4)
    }

    private var buttonsArea: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button { viewModel.tapMainButton() } label: {
                    buttonLabel(viewModel.mainButtonTitle)
                }
                .tint(viewModel.mainButtonColor)
            }
            .buttonStyle(.borderedProminent)

            if viewModel.state == .paused {
                Button { showStopConfirm = true } label: {
                    buttonLabel("终止扫描")
                }
                .tint(Theme.red)
                .buttonStyle(.bordered)
            }

            if viewModel.showActions {
                HStack(spacing: 8) {
                    if viewModel.resultIsText {
                        Button { viewModel.copyResult() } label: {
                            buttonLabel("复制")
                        }
                    }
                    Button { viewModel.shareResult(asFile: false) } label: {
                        buttonLabel("分享")
                    }
                    Button { viewModel.shareResult(asFile: true) } label: {
                        buttonLabel("文件分享")
                    }
                }
                .buttonStyle(.bordered)
                .tint(Theme.purple)
            }
        }
        .padding(.top, 8)
    }

    private func buttonLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }

    // MARK: - Toast

    private var toastOverlay: some View {
        VStack {
            if let message = viewModel.toastMessage {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.75)))
                    .padding(.bottom, 30)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.toastMessage)
    }
}

/// 扫描框 + 扫描线动画（对应 Android 的 scan_frame.xml / scan_line_anim）
private struct ScanFrameOverlay: View {

    let running: Bool
    @State private var animating = false

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.purple, lineWidth: 3)

            if running {
                Rectangle()
                    .fill(Theme.purple)
                    .frame(width: 220, height: 3)
                    .offset(y: animating ? 232 : 8)
                    .animation(.linear(duration: 1.6).repeatForever(autoreverses: true),
                               value: animating)
            }
        }
        .frame(width: 240, height: 240)
        .onAppear { animating = true }
    }
}
