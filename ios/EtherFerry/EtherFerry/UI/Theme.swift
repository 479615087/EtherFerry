import SwiftUI

/// 主题色：与 Android 端 `res/values/colors.xml` 保持一致
enum Theme {
    static let purple = Color(hex: "#8b5cf6")
    static let purpleDark = Color(hex: "#7c3aed")
    static let purpleLight = Color(hex: "#ede9fe")

    static let green = Color(hex: "#16a34a")
    static let red = Color(hex: "#dc2626")
    static let orange = Color(hex: "#f97316")

    static let btnPause = Color(hex: "#EC4899")
    static let btnRescan = Color(hex: "#4ADE80")

    static let background = Color(hex: "#faf5ff")
    static let textPrimary = Color(hex: "#1f1f1f")
    static let textSecondary = Color(hex: "#666666")
    static let textHint = Color(hex: "#999999")
    static let divider = Color(hex: "#e0e0e0")
}

extension Color {
    /// 支持 "#RRGGBB" / "RRGGBB" 格式
    init(hex: String) {
        var value: UInt64 = 0
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text = String(text.dropFirst()) }
        Scanner(string: text).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}
