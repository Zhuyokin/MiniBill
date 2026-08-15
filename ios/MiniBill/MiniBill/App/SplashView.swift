import SwiftUI

struct SplashView: View {
    var body: some View {
        VStack(spacing: 22) {
            Image("BrandIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 116, height: 116)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 16, y: 8)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("MiniBill")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Simple offline bills, effortless bookkeeping for small business")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themedSplash()
        .accessibilityElement(children: .combine)
    }
}
