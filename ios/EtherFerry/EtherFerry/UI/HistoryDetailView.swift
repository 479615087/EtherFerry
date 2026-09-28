import SwiftUI
import ImageIO
import UIKit

/// 扫描记录详情（对应 Android 端 `HistoryDetailActivity`）
struct HistoryDetailView: View {

    @ObservedObject var viewModel: HistoryViewModel
    let record: ScanRecord

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var previewImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(record.fileName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Text(metaText)
                    .font(.system(size: 13))
                    .foregroundColor(record.verified ? Theme.green : Theme.red)

                Divider()

                contentView
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { actionBar }
        .alert("删除记录", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) {
                viewModel.delete(record.id)
                dismiss()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("确定要删除这条扫描记录吗？")
        }
        .onAppear(perform: loadImageIfNeeded)
    }

    // MARK: - 内容

    @ViewBuilder
    private var contentView: some View {
        if record.isText, let text = record.textContent {
            Text(text)
                .font(.system(size: 14, design: .monospaced))
                .textSelection(.enabled)
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if record.isImage {
            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(8)
            } else if record.filePath == nil || !FileManager.default.fileExists(atPath: record.filePath ?? "") {
                Text("文件不存在")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textHint)
            }
        } else {
            Text("二进制文件，请通过分享按钮打开")
                .font(.system(size: 14))
                .foregroundColor(Theme.textHint)
        }
    }

    private var metaText: String {
        let time = ScanRepository.formatTime(record.timestamp)
        let verified = record.verified ? "✓ 校验通过" : "✗ 校验失败"
        return "\(TransferProtocol.formatBytes(record.fileSize)) · \(record.mimeType)\n\(time) · \(verified)"
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            Button { shareRecord() } label: {
                Text("分享")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.purple)

            Button { showDeleteConfirm = true } label: {
                Text("删除")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(Theme.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - 行为

    private func shareRecord() {
        if record.isText, let text = record.textContent {
            ShareHelper.present(items: [text])
            return
        }
        guard let path = record.filePath, FileManager.default.fileExists(atPath: path) else { return }
        ShareHelper.present(items: [URL(fileURLWithPath: path)])
    }

    /// 图片降采样加载（对应 Android 的 BitmapFactory.inSampleSize）
    private func loadImageIfNeeded() {
        guard record.isImage, previewImage == nil, let path = record.filePath else { return }
        let url = URL(fileURLWithPath: path)
        DispatchQueue.global(qos: .userInitiated).async {
            let image = HistoryDetailView.downsample(url: url, maxPixel: 1080)
            DispatchQueue.main.async {
                self.previewImage = image
            }
        }
    }

    private static func downsample(url: URL, maxPixel: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
