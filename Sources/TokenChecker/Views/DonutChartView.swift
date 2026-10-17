import SwiftUI

/// 5h usage 1 本ぶんの円形プログレス。CCMeter の二重ドーナツから内側 7d を削除した版。
///
/// 中央にどのサービスかを示す SF Symbol を表示する（メニューバーで Claude / Codex を一目で区別）。
struct DonutChartView: View {
    let value: Double   // 0.0 〜 1.0
    var size: CGFloat = 18
    var lineWidth: CGFloat = 4
    let symbolName: String

    var body: some View {
        ZStack {
            // 背景のリング（未使用部分）
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: lineWidth)
                .frame(width: size - lineWidth, height: size - lineWidth)
            // 使用率に応じて色付き
            Circle()
                .trim(from: 0, to: value.clampedToUnit)
                .stroke(
                    Color.usage(value),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size - lineWidth, height: size - lineWidth)
                .rotationEffect(.degrees(-90))
            // 中央のロゴ
            Image(systemName: symbolName)
                .font(.system(size: size * 0.48, weight: .semibold))
        }
        .frame(width: size, height: size)
    }
}
