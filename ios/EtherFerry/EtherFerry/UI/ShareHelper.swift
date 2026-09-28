import UIKit

/// 系统分享面板（替代 Android 的 `Intent.createChooser` + `FileProvider`）
enum ShareHelper {

    /// 弹出系统分享面板，同时兼容 iPhone 与 iPad
    static func present(items: [Any]) {
        guard !items.isEmpty,
              let windowScene = UIApplication.shared.connectedScenes
                  .compactMap({ $0 as? UIWindowScene })
                  .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else {
            return
        }

        // 逐级取最上层的控制器
        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }

        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = presenter.view
        controller.popoverPresentationController?.sourceRect =
            CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
        controller.popoverPresentationController?.permittedArrowDirections = []
        presenter.present(controller, animated: true)
    }
}
