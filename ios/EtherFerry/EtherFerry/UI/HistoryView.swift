import SwiftUI

/// 历史列表视图模型
final class HistoryViewModel: ObservableObject {

    @Published var records: [ScanRecord] = []

    private let repository = ScanRepository()

    func load() {
        records = repository.getAll()
    }

    func delete(_ id: Int64) {
        repository.delete(id)
        load()
    }

    func clearAll() {
        repository.clearAll()
        load()
    }
}

/// 扫描历史列表（对应 Android 端 `HistoryFragment`）
struct HistoryView: View {

    @StateObject private var viewModel = HistoryViewModel()
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.records.isEmpty {
                    emptyView
                } else {
                    List {
                        ForEach(viewModel.records) { record in
                            NavigationLink(value: record) {
                                HistoryRow(record: record)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Theme.background)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("扫描历史")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ScanRecord.self) { record in
                HistoryDetailView(viewModel: viewModel, record: record)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.records.isEmpty {
                        Button("清空") { showClearConfirm = true }
                    }
                }
            }
            .alert("清空历史", isPresented: $showClearConfirm) {
                Button("删除", role: .destructive) { viewModel.clearAll() }
                Button("取消", role: .cancel) { }
            } message: {
                Text("确定要删除所有扫描记录吗？此操作不可撤销。")
            }
            .onAppear(perform: viewModel.load)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(Theme.textHint)
            Text("暂无扫描记录")
                .foregroundColor(Theme.textHint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 历史列表项（对应 Android 的 item_history.xml）
private struct HistoryRow: View {

    let record: ScanRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(record.verified ? "✓" : "✗")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(record.verified ? Theme.green : Theme.red)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.fileName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                Text("\(TransferProtocol.formatBytes(record.fileSize)) · \(ScanRepository.formatTime(record.timestamp))")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textHint)

                if let preview = record.textPreview, !preview.isEmpty {
                    Text(preview)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
