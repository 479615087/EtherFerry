import SwiftUI

/// 根视图：底部两 Tab 导航（扫描 + 历史）
///
/// 对应 Android 端 `MainActivity` 的 BottomNavigationView 两个 Fragment。
struct RootView: View {

    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            ScanView()
                .tabItem {
                    Label("扫描", systemImage: "qrcode.viewfinder")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label("历史", systemImage: "list.bullet")
                }
                .tag(1)
        }
        .tint(Theme.purple)
    }
}
