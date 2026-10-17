import SwiftUI

extension Color {
    /// 使用率 (0.0〜1.0+) に応じた色。70% 未満は緑、85% 未満はオレンジ、それ以上は赤。
    static func usage(_ utilization: Double) -> Color {
        if utilization < 0.7 { return .green }
        if utilization < 0.85 { return .orange }
        return .red
    }
}

extension Double {
    /// 描画用に 0.0〜1.0 へ収める。
    var clampedToUnit: Double { min(max(self, 0), 1) }
}
