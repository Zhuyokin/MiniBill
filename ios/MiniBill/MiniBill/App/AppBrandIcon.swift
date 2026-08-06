import SwiftUI

struct AppBrandIcon: View {
    let size: CGFloat
    var cornerRadius: CGFloat? = nil

    var body: some View {
        Image("BrandIcon")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: cornerRadius ?? size * 0.2,
                    style: .continuous
                )
            )
            .accessibilityHidden(true)
    }
}
