import SwiftUI

struct ProgressBarView: View {
    let value: Double   // 0.0〜1.0
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.gray.opacity(0.2))
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.usage(value))
                    .frame(width: geo.size.width * value.clampedToUnit)
            }
        }
        .frame(height: height)
    }
}
