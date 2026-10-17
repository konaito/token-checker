import SwiftUI
import AppKit

/// メニューバーに表示する「2 つのドーナツ + %」。
///
/// SwiftUI ビューを `ImageRenderer` で NSImage に焼いて、
/// `Image(nsImage:)` でメニューバーに渡す。
/// `MenuBarExtra` の label に SwiftUI ビューを直接渡すとフォント等が制限されるため。
struct MenuBarLabel: View {
    let viewModel: UsageViewModel

    var body: some View {
        if let image = renderedImage {
            Image(nsImage: image)
        } else {
            Text("TC ⏳")
        }
    }

    private var renderedImage: NSImage? {
        let content = HStack(spacing: 6) {
            item(for: .claude)
            item(for: .codex)
        }
        .padding(.horizontal, 2)
        // ImageRenderer はメニューバーの外観を引き継がずライトモードの黒で焼くため、
        // 暗いメニューバーで見えるよう白に固定する。
        .foregroundStyle(Color.white)

        let renderer = ImageRenderer(content: content)
        // ビットマップは高 DPI で焼いておく．image.size には触らない
        // （触ると point 単位として誤認されて表示サイズまで縮んでしまう）．
        let maxScale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
        renderer.scale = max(maxScale, 3)
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = false
        return image
    }

    private func item(for brand: ServiceBrand) -> some View {
        let value = utilization(from: viewModel.snapshot.result(for: brand))
        return HStack(spacing: 3) {
            DonutChartView(value: value ?? 0, size: 20, lineWidth: 3, symbolName: brand.symbolName)
            Text(percentLabel(value))
                .font(.system(size: 11, weight: .semibold))
        }
    }

    private func utilization(from result: Result<ServiceUsage, DomainError>?) -> Double? {
        guard case .success(let usage) = result else { return nil }
        return usage.fiveHour?.utilization
    }

    private func percentLabel(_ value: Double?) -> String {
        guard let v = value else { return "--%" }
        // メニューバーは横幅が限られるため 100% で頭打ちにし、超過は "+" で示す。
        // RateLimit.utilization は仕様上 1.0 を超えうる（Anthropic API 既知挙動）。
        if v > 1.0 { return "100%+" }
        let clamped = max(0, v)
        return "\(Int((clamped * 100).rounded()))%"
    }
}
