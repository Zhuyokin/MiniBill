import SwiftUI

private struct AppInterfaceStyleEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppInterfaceStyle.modern
}

extension EnvironmentValues {
    var appInterfaceStyle: AppInterfaceStyle {
        get { self[AppInterfaceStyleEnvironmentKey.self] }
        set { self[AppInterfaceStyleEnvironmentKey.self] = newValue }
    }
}

extension AppInterfaceStyle {
    var title: LocalizedStringKey {
        switch self {
        case .modern: return "Modern Minimalist"
        case .skeuomorphic: return "Retro Skeuomorphic"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .modern: return "Teal-toned minimalist texture"
        case .skeuomorphic: return "Retro skeuomorphic texture"
        }
    }
}

private struct RootTabHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
#if compiler(>=6.2)
                if #available(iOS 26.0, *) {
                    logoToolbarItem.sharedBackgroundVisibility(.hidden)
                } else {
                    logoToolbarItem
                }
#else
                logoToolbarItem
#endif
            }
    }

    private var logoToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            AppBrandIcon(size: 32)
                .allowsHitTesting(false)
        }
    }
}

enum SkeuomorphicPalette {
    static let accent = Color(red: 48 / 255, green: 103 / 255, blue: 143 / 255)
    static let accentActive = Color(red: 33 / 255, green: 76 / 255, blue: 108 / 255)
    static let ink = Color(red: 35 / 255, green: 43 / 255, blue: 49 / 255)
    static let bodyText = Color(red: 83 / 255, green: 94 / 255, blue: 101 / 255)
    static let mutedText = Color(red: 119 / 255, green: 126 / 255, blue: 130 / 255)
    static let canvas = Color(red: 220 / 255, green: 221 / 255, blue: 216 / 255)
    static let surface = Color(red: 248 / 255, green: 247 / 255, blue: 240 / 255)
    static let mutedSurface = Color(red: 232 / 255, green: 231 / 255, blue: 223 / 255)
    static let surfaceStrong = Color(red: 202 / 255, green: 207 / 255, blue: 207 / 255)
    static let hairline = Color.black.opacity(0.18)
    static let hairlineStrong = Color(red: 111 / 255, green: 119 / 255, blue: 122 / 255)

    static let pageStyle = LinearGradient(
        colors: [
            Color(red: 196 / 255, green: 201 / 255, blue: 201 / 255),
            canvas,
            Color(red: 235 / 255, green: 234 / 255, blue: 228 / 255),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardStyle = LinearGradient(
        colors: [.white, surface, mutedSurface],
        startPoint: .top,
        endPoint: .bottom
    )

    static let controlStyle = LinearGradient(
        colors: [.white, surfaceStrong.opacity(0.72)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let primaryButtonStyle = LinearGradient(
        colors: [
            Color(red: 104 / 255, green: 158 / 255, blue: 194 / 255),
            accent,
            accentActive,
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct ThemedScreenBackground: View {
    @Environment(\.appInterfaceStyle) private var style

    var body: some View {
        if style == .modern {
            AppTheme.background
        } else {
            Rectangle().fill(SkeuomorphicPalette.pageStyle)
        }
    }
}

private struct ThemedScreenModifier: ViewModifier {
    @Environment(\.appInterfaceStyle) private var style

    func body(content: Content) -> some View {
        content
            .background(ThemedScreenBackground().ignoresSafeArea())
            .tint(style == .modern ? AppTheme.brand : SkeuomorphicPalette.accent)
    }
}

private struct ThemedSplashModifier: ViewModifier {
    @Environment(\.appInterfaceStyle) private var style

    @ViewBuilder
    func body(content: Content) -> some View {
        if style == .modern {
            content.background(Color(uiColor: .systemBackground))
        } else {
            content
                .foregroundStyle(SkeuomorphicPalette.ink)
                .background(ThemedScreenBackground().ignoresSafeArea())
        }
    }
}

private struct RetroScreenOnlyModifier: ViewModifier {
    @Environment(\.appInterfaceStyle) private var style

    @ViewBuilder
    func body(content: Content) -> some View {
        if style == .modern {
            content
        } else {
            content
                .foregroundStyle(SkeuomorphicPalette.ink)
                .background(ThemedScreenBackground().ignoresSafeArea())
        }
    }
}

private struct ThemedFormModifier: ViewModifier {
    @Environment(\.appInterfaceStyle) private var style

    @ViewBuilder
    func body(content: Content) -> some View {
        if style == .modern {
            content
        } else {
            content
                .scrollContentBackground(.hidden)
                .background(ThemedScreenBackground().ignoresSafeArea())
                .listRowSeparatorTint(SkeuomorphicPalette.hairline)
                .tint(SkeuomorphicPalette.accent)
        }
    }
}

private struct ThemedPanelModifier: ViewModifier {
    @Environment(\.appInterfaceStyle) private var style
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if style == .modern {
            content.background(AppTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            let shape = RoundedRectangle(cornerRadius: max(cornerRadius, 12), style: .continuous)
            content
                .foregroundStyle(SkeuomorphicPalette.ink)
                .background(SkeuomorphicPalette.cardStyle, in: shape)
                .overlay { shape.stroke(SkeuomorphicPalette.hairline, lineWidth: 1) }
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        }
    }
}

private struct ThemedListRowModifier: ViewModifier {
    @Environment(\.appInterfaceStyle) private var style

    @ViewBuilder
    func body(content: Content) -> some View {
        if style == .modern {
            content.listRowBackground(AppTheme.surface)
        } else {
            content.listRowBackground(SkeuomorphicPalette.cardStyle)
        }
    }
}

private struct ThemedNavigationChromeModifier: ViewModifier {
    @Environment(\.appInterfaceStyle) private var style

    @ViewBuilder
    func body(content: Content) -> some View {
        if style == .modern {
            content
        } else {
            content
                .toolbarBackground(SkeuomorphicPalette.surfaceStrong, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.light, for: .navigationBar)
                .tint(SkeuomorphicPalette.accent)
        }
    }
}

private struct ThemedTabChromeModifier: ViewModifier {
    @Environment(\.appInterfaceStyle) private var style

    @ViewBuilder
    func body(content: Content) -> some View {
        if style == .modern {
            content.tint(AppTheme.brand)
        } else {
            content
                .tint(SkeuomorphicPalette.accent)
                .toolbarBackground(SkeuomorphicPalette.canvas, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.light, for: .tabBar)
        }
    }
}

private struct SkeuomorphicPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .fontWeight(.semibold)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(SkeuomorphicPalette.primaryButtonStyle, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.52), lineWidth: 1)
                    .padding(1)
            }
            .brightness(configuration.isPressed ? -0.08 : 0)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.10 : 0.28), radius: 1.5, y: configuration.isPressed ? 0 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ThemedPrimaryButtonModifier: ViewModifier {
    @Environment(\.appInterfaceStyle) private var style
    let tint: Color
    let colorOnlyInRetro: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if style == .modern {
            content.buttonStyle(.borderedProminent).tint(tint)
        } else if colorOnlyInRetro {
            content.buttonStyle(.borderedProminent).tint(SkeuomorphicPalette.accent)
        } else {
            content.buttonStyle(SkeuomorphicPrimaryButtonStyle())
        }
    }
}

private struct ThemedSecondaryButtonModifier: ViewModifier {
    @Environment(\.appInterfaceStyle) private var style
    let tint: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if style == .modern {
            content.buttonStyle(.bordered).tint(tint)
        } else {
            content.buttonStyle(.bordered).tint(SkeuomorphicPalette.accent)
        }
    }
}

private struct ThemedActionButtonModifier: ViewModifier {
    @Environment(\.appInterfaceStyle) private var style
    let colorOnlyInRetro: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if style == .modern {
            content
        } else if colorOnlyInRetro {
            content.tint(SkeuomorphicPalette.accent)
        } else {
            content.buttonStyle(SkeuomorphicPrimaryButtonStyle())
        }
    }
}

private struct ThemedInputWellModifier: ViewModifier {
    @Environment(\.appInterfaceStyle) private var style

    @ViewBuilder
    func body(content: Content) -> some View {
        if style == .modern {
            content
        } else {
            content
                .foregroundStyle(SkeuomorphicPalette.ink)
                .tint(SkeuomorphicPalette.accent)
        }
    }
}

struct ThemedFloatingButtonBackground: View {
    @Environment(\.appInterfaceStyle) private var style

    var body: some View {
        if style == .modern {
            Circle()
                .fill(AppTheme.brand)
                .shadow(color: .black.opacity(0.16), radius: 10, y: 5)
        } else {
            Circle()
                .fill(SkeuomorphicPalette.primaryButtonStyle)
                .overlay(alignment: .top) {
                    Ellipse()
                        .fill(Color.white.opacity(0.32))
                        .frame(width: 36, height: 16)
                        .blur(radius: 1)
                        .padding(.top, 6)
                }
                .overlay { Circle().stroke(Color.white.opacity(0.62), lineWidth: 1).padding(2) }
                .overlay { Circle().stroke(Color.black.opacity(0.42), lineWidth: 1) }
                .shadow(color: .black.opacity(0.32), radius: 3, y: 2)
        }
    }
}

struct ThemedLedgerKindBadgeBackground: View {
    @Environment(\.appInterfaceStyle) private var style
    let kind: LedgerKind

    var body: some View {
        if style == .modern {
            Circle().fill(AppTheme.softColor(for: kind))
        } else {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white, AppTheme.softColor(for: kind)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay { Circle().stroke(SkeuomorphicPalette.hairline, lineWidth: 1) }
                .shadow(color: .black.opacity(0.14), radius: 1, y: 1)
        }
    }
}

struct InterfaceStyleOption: View {
    let style: AppInterfaceStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(style == .modern ? AnyShapeStyle(AppTheme.brand) : AnyShapeStyle(SkeuomorphicPalette.primaryButtonStyle))
                    .frame(width: 28, height: 28)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(style == .skeuomorphic ? 0.55 : 0), lineWidth: 1)
                            .padding(1)
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text(style.title)
                        .font(.subheadline.weight(.semibold))
                    Text(style.subtitle)
                        .font(.caption2)
                        .opacity(0.72)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }
            }
            .foregroundStyle(isSelected ? Color.white : SkeuomorphicPalette.ink)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 48)
            .background(
                isSelected ? AnyShapeStyle(SkeuomorphicPalette.primaryButtonStyle) : AnyShapeStyle(SkeuomorphicPalette.controlStyle),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension View {
    func rootTabHeader() -> some View { modifier(RootTabHeaderModifier()) }
    func themedScreen() -> some View { modifier(ThemedScreenModifier()) }
    func themedSplash() -> some View { modifier(ThemedSplashModifier()) }
    func retroScreenOnly() -> some View { modifier(RetroScreenOnlyModifier()) }
    func themedForm() -> some View { modifier(ThemedFormModifier()) }
    func themedPanel(cornerRadius: CGFloat = 8) -> some View { modifier(ThemedPanelModifier(cornerRadius: cornerRadius)) }
    func themedListRowBackground() -> some View { modifier(ThemedListRowModifier()) }
    func themedNavigationChrome() -> some View { modifier(ThemedNavigationChromeModifier()) }
    func themedTabChrome() -> some View { modifier(ThemedTabChromeModifier()) }
    func themedPrimaryButton(tint: Color = AppTheme.brand, colorOnlyInRetro: Bool = false) -> some View {
        modifier(ThemedPrimaryButtonModifier(tint: tint, colorOnlyInRetro: colorOnlyInRetro))
    }
    func themedSecondaryButton(tint: Color = AppTheme.brandDark) -> some View { modifier(ThemedSecondaryButtonModifier(tint: tint)) }
    func themedActionButton(colorOnlyInRetro: Bool = false) -> some View {
        modifier(ThemedActionButtonModifier(colorOnlyInRetro: colorOnlyInRetro))
    }
    func themedInputWell() -> some View { modifier(ThemedInputWellModifier()) }
}
