import SwiftUI

enum Brand {
    static let accent = Color(red: 0.13, green: 0.55, blue: 0.48)
    static let cornerRadius: CGFloat = 16
}

struct BrandMark: View {
    var size: CGFloat = 34
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.29)
                .fill(Brand.accent.gradient)
            Image(systemName: "arrow.up.right")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
