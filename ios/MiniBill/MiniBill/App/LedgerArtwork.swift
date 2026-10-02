import SwiftUI

enum LedgerArtworkMotif {
    case leaves
    case bars
    case rings
}

struct LedgerCardArtwork: View {
    @Environment(\.appInterfaceStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    let motif: LedgerArtworkMotif

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width * 0.65, 240)
            LedgerArtworkDrawing.wash(
                in: &context,
                center: CGPoint(x: size.width, y: size.height * 0.6),
                radius: radius,
                color: AppTheme.expense.opacity(0.12)
            )
            LedgerArtworkDrawing.wash(
                in: &context,
                center: CGPoint(x: size.width * 0.7, y: size.height * 1.15),
                radius: radius * 0.65,
                color: AppTheme.income.opacity(0.09)
            )

            let scale = min(size.width * 0.45 / 150, size.height * 0.88 / 140, 1.15)
            context.translateBy(x: size.width - 150 * scale - 4, y: size.height - 140 * scale)
            context.scaleBy(x: scale, y: scale)

            switch motif {
            case .leaves:
                LedgerArtworkDrawing.leaves(in: &context)
            case .bars:
                LedgerArtworkDrawing.bars(in: &context)
            case .rings:
                LedgerArtworkDrawing.rings(in: &context)
            }
        }
        .opacity(style == .skeuomorphic ? 0.4 : (colorScheme == .dark ? 0.65 : 1))
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct LedgerScreenArtwork: View {
    @Environment(\.appInterfaceStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            LedgerArtworkDrawing.wash(
                in: &context,
                center: CGPoint(x: size.width * 0.96, y: size.height * 0.22),
                radius: size.width * 0.85,
                color: AppTheme.expense.opacity(0.1)
            )
            LedgerArtworkDrawing.wash(
                in: &context,
                center: CGPoint(x: size.width * 0.06, y: size.height * 0.76),
                radius: size.width * 0.75,
                color: AppTheme.income.opacity(0.08)
            )
        }
        .mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .white], startPoint: .top, endPoint: .bottom)
                    .frame(height: 120)
                Color.white
            }
        }
        .opacity(style == .skeuomorphic ? 0.3 : (colorScheme == .dark ? 0.6 : 1))
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct LedgerScreenModifier: ViewModifier {
    @Environment(\.appInterfaceStyle) private var style

    func body(content: Content) -> some View {
        let screen = content
            .background { LedgerScreenArtwork() }
            .themedScreen()
        if style == .modern {
            screen
                .toolbarBackground(AppTheme.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        } else {
            screen
        }
    }
}

extension View {
    func ledgerScreen() -> some View { modifier(LedgerScreenModifier()) }
}

private enum LedgerArtworkDrawing {
    static func wash(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
        let bounds = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(
            Path(ellipseIn: bounds),
            with: .radialGradient(
                Gradient(colors: [color, color.opacity(0)]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    static func leaves(in context: inout GraphicsContext) {
        var stem = Path()
        stem.move(to: CGPoint(x: 122, y: 145))
        stem.addCurve(
            to: CGPoint(x: 91, y: 24),
            control1: CGPoint(x: 78, y: 98),
            control2: CGPoint(x: 112, y: 66)
        )
        stem.move(to: CGPoint(x: 119, y: 137))
        stem.addQuadCurve(to: CGPoint(x: 139, y: 65), control: CGPoint(x: 120, y: 93))
        context.stroke(stem, with: .color(AppTheme.expense.opacity(0.2)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

        leaf(in: &context, from: CGPoint(x: 103, y: 113), to: CGPoint(x: 60, y: 77), width: 18, opacity: 0.12)
        leaf(in: &context, from: CGPoint(x: 99, y: 91), to: CGPoint(x: 128, y: 53), width: 17, opacity: 0.16)
        leaf(in: &context, from: CGPoint(x: 101, y: 72), to: CGPoint(x: 68, y: 37), width: 15, opacity: 0.14)
        leaf(in: &context, from: CGPoint(x: 99, y: 48), to: CGPoint(x: 110, y: 13), width: 11, opacity: 0.12)
        leaf(in: &context, from: CGPoint(x: 124, y: 110), to: CGPoint(x: 149, y: 90), width: 12, opacity: 0.1)
        leaf(in: &context, from: CGPoint(x: 130, y: 88), to: CGPoint(x: 126, y: 54), width: 10, opacity: 0.13)
    }

    static func leaf(in context: inout GraphicsContext, from start: CGPoint, to end: CGPoint, width: CGFloat, opacity: Double) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        let nx = -dy / length * width
        let ny = dx / length * width
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(
            to: end,
            control: CGPoint(x: start.x + dx * 0.32 + nx, y: start.y + dy * 0.32 + ny)
        )
        path.addQuadCurve(
            to: start,
            control: CGPoint(x: start.x + dx * 0.65 - nx, y: start.y + dy * 0.65 - ny)
        )
        context.fill(path, with: .color(AppTheme.expense.opacity(opacity)))
    }

    static func bars(in context: inout GraphicsContext) {
        let heights: [CGFloat] = [30, 48, 43, 72]
        for (index, height) in heights.enumerated() {
            let rect = CGRect(x: 49 + CGFloat(index) * 25, y: 123 - height, width: 16, height: height)
            let bar = Path(roundedRect: rect, cornerRadius: 5)
            context.fill(
                bar,
                with: .linearGradient(
                    Gradient(colors: [AppTheme.expense.opacity(0.16), AppTheme.expense.opacity(0.04)]),
                    startPoint: CGPoint(x: rect.midX, y: rect.minY),
                    endPoint: CGPoint(x: rect.midX, y: rect.maxY)
                )
            )
            context.stroke(bar, with: .color(AppTheme.expense.opacity(0.13)), lineWidth: 1)
        }

        var arc = Path()
        arc.move(to: CGPoint(x: 42, y: 81))
        arc.addCurve(
            to: CGPoint(x: 146, y: 33),
            control1: CGPoint(x: 78, y: 18),
            control2: CGPoint(x: 113, y: 67)
        )
        context.stroke(arc, with: .color(AppTheme.expense.opacity(0.14)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        context.fill(Path(ellipseIn: CGRect(x: 144, y: 29, width: 7, height: 7)), with: .color(AppTheme.income.opacity(0.24)))
    }

    static func rings(in context: inout GraphicsContext) {
        let center = CGPoint(x: 119, y: 92)
        let rings: [(CGFloat, Double)] = [(45, 0.12), (30, 0.09)]
        for (radius, opacity) in rings {
            var arc = Path()
            arc.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(150),
                endAngle: .degrees(450),
                clockwise: false
            )
            context.stroke(arc, with: .color(AppTheme.expense.opacity(opacity)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        }
        var accent = Path()
        accent.addArc(center: center, radius: 45, startAngle: .degrees(107), endAngle: .degrees(135), clockwise: false)
        context.stroke(accent, with: .color(AppTheme.income.opacity(0.16)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
    }
}
