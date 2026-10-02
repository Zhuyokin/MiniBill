import AppKit
import CoreGraphics
import Foundation

let sourceDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let root = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    : sourceDirectory.deletingLastPathComponent()
let selectedDevice = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : nil
let repository = sourceDirectory
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let iconURL = repository.appendingPathComponent(
    "ios/MiniBill/MiniBill/Assets.xcassets/BrandIcon.imageset/MiniBill-BrandIcon-1024.png"
)

let brand = NSColor(srgbRed: 7 / 255, green: 193 / 255, blue: 96 / 255, alpha: 1)
let deepGreen = NSColor(srgbRed: 5 / 255, green: 128 / 255, blue: 66 / 255, alpha: 1)
let ink = NSColor(srgbRed: 0.07, green: 0.10, blue: 0.085, alpha: 1)
let muted = NSColor(srgbRed: 0.37, green: 0.42, blue: 0.385, alpha: 1)

struct Poster {
    let slug: String
    let screenshot: String
    let title: String
    let emphasis: String
    let subtitle: String
    let tags: [(symbol: String, text: String)]
}

let posters = [
    Poster(
        slug: "01-everyday-ledger", screenshot: "home",
        title: "每笔收支", emphasis: "清清楚楚",
        subtitle: "日常账单与月度结余，一眼看清",
        tags: [("list.bullet.rectangle", "逐笔查看收支"), ("calendar", "月度汇总一览")]
    ),
    Poster(
        slug: "02-quick-entry", screenshot: "entry",
        title: "随手一记", emphasis: "轻松入账",
        subtitle: "记下金额与项目，收支随手记录",
        tags: [("plus.circle", "收入支出切换"), ("square.and.pencil", "项目快捷填写")]
    ),
    Poster(
        slug: "03-statistics", screenshot: "statistics",
        title: "收支变化", emphasis: "一眼看清",
        subtitle: "收支趋势与项目排行，清晰呈现",
        tags: [("chart.bar.xaxis", "月度年度统计"), ("chart.pie", "项目分类排行")]
    ),
    Poster(
        slug: "04-backup", screenshot: "backup",
        title: "账本备份", emphasis: "自由导入导出",
        subtitle: "JSON 与 CSV，让账本随你保存",
        tags: [("arrow.down.doc", "导入账本数据"), ("arrow.up.doc", "导出备份文件")]
    )
]

struct Canvas {
    let directory: String
    let width: Int
    let height: Int
    let isPad: Bool

    var size: NSSize { NSSize(width: width, height: height) }
    var margin: CGFloat { isPad ? 164 : 84 }
    var contentWidth: CGFloat { CGFloat(width) - margin * 2 }
    var deviceTop: CGFloat { isPad ? 934 : 870 }
    var deviceBottom: CGFloat { CGFloat(height) - (isPad ? 82 : 76) }
}

let canvases = [
    Canvas(directory: "iphone", width: 1284, height: 2778, isPad: false),
    Canvas(directory: "ipad", width: 2064, height: 2752, isPad: true)
]

func rounded(_ rect: NSRect, radius: CGFloat, fill: NSColor) {
    fill.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func gradient(_ path: NSBezierPath, colors: [NSColor], angle: CGFloat) {
    NSGradient(colors: colors)!.draw(in: path, angle: angle)
}

func label(
    _ text: String, rect: NSRect, size: CGFloat,
    weight: NSFont.Weight = .regular, color: NSColor = ink
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byClipping
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let naturalWidth = (text as NSString).size(withAttributes: [.font: font]).width
    let fittedSize = min(size, size * rect.width / max(naturalWidth, 1))
    (text as NSString).draw(in: rect, withAttributes: [
        .font: NSFont.systemFont(ofSize: fittedSize, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ])
}

func asset(_ image: NSImage, rect: NSRect, radius: CGFloat = 0) {
    NSGraphicsContext.saveGraphicsState()
    if radius > 0 {
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    }
    image.draw(
        in: rect, from: .zero, operation: .sourceOver, fraction: 1,
        respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()
}

func background(_ canvas: Canvas) {
    let w = CGFloat(canvas.width)
    let h = CGFloat(canvas.height)
    let bounds = NSRect(origin: .zero, size: canvas.size)
    gradient(NSBezierPath(rect: bounds), colors: [
        NSColor(srgbRed: 1, green: 0.995, blue: 0.977, alpha: 1),
        .white,
        NSColor(srgbRed: 0.91, green: 0.985, blue: 0.945, alpha: 1)
    ], angle: 75)

    let topArc = NSBezierPath()
    topArc.move(to: NSPoint(x: w * 0.38, y: -h * 0.10))
    topArc.curve(
        to: NSPoint(x: w * 1.09, y: h * 0.19),
        controlPoint1: NSPoint(x: w * 0.57, y: h * 0.21),
        controlPoint2: NSPoint(x: w * 0.94, y: h * 0.10)
    )
    topArc.lineWidth = canvas.isPad ? 108 : 84
    brand.withAlphaComponent(0.075).setStroke()
    topArc.stroke()

    let paleSweep = NSBezierPath()
    paleSweep.move(to: NSPoint(x: w, y: h * 0.28))
    paleSweep.curve(
        to: NSPoint(x: -w * 0.1, y: h * 0.55),
        controlPoint1: NSPoint(x: w * 0.64, y: h * 0.48),
        controlPoint2: NSPoint(x: w * 0.30, y: h * 0.42)
    )
    paleSweep.lineWidth = canvas.isPad ? 84 : 66
    brand.withAlphaComponent(0.055).setStroke()
    paleSweep.stroke()

    let ribbon = NSBezierPath()
    ribbon.move(to: NSPoint(x: w, y: h * 0.48))
    ribbon.curve(
        to: NSPoint(x: 0, y: h * 0.78),
        controlPoint1: NSPoint(x: w * 0.75, y: h * 0.68),
        controlPoint2: NSPoint(x: w * 0.35, y: h * 0.81)
    )
    ribbon.line(to: NSPoint(x: 0, y: h * 0.91))
    ribbon.curve(
        to: NSPoint(x: w, y: h * 0.65),
        controlPoint1: NSPoint(x: w * 0.43, y: h * 0.91),
        controlPoint2: NSPoint(x: w * 0.86, y: h * 0.86)
    )
    ribbon.close()
    gradient(ribbon, colors: [
        NSColor(srgbRed: 0.56, green: 0.91, blue: 0.72, alpha: 1),
        brand,
        deepGreen
    ], angle: 125)

    let lowerRibbon = NSBezierPath()
    lowerRibbon.move(to: NSPoint(x: 0, y: h * 0.62))
    lowerRibbon.curve(
        to: NSPoint(x: w, y: h * 0.91),
        controlPoint1: NSPoint(x: w * 0.30, y: h * 0.67),
        controlPoint2: NSPoint(x: w * 0.57, y: h * 0.97)
    )
    lowerRibbon.line(to: NSPoint(x: w, y: h * 0.965))
    lowerRibbon.curve(
        to: NSPoint(x: 0, y: h * 0.75),
        controlPoint1: NSPoint(x: w * 0.55, y: h * 1.005),
        controlPoint2: NSPoint(x: w * 0.21, y: h * 0.78)
    )
    lowerRibbon.close()
    gradient(lowerRibbon, colors: [
        brand.withAlphaComponent(0.94),
        NSColor(srgbRed: 0.74, green: 0.95, blue: 0.82, alpha: 0.87)
    ], angle: 25)

    let highlight = NSBezierPath()
    highlight.move(to: NSPoint(x: 0, y: h * 0.635))
    highlight.curve(
        to: NSPoint(x: w, y: h * 0.919),
        controlPoint1: NSPoint(x: w * 0.30, y: h * 0.685),
        controlPoint2: NSPoint(x: w * 0.57, y: h * 0.98)
    )
    highlight.lineWidth = canvas.isPad ? 6 : 4
    NSColor.white.withAlphaComponent(0.7).setStroke()
    highlight.stroke()
}

func pill(_ tag: (symbol: String, text: String), rect: NSRect, isPad: Bool) {
    let radius = rect.height / 2
    rounded(rect, radius: radius, fill: NSColor(srgbRed: 0.91, green: 0.975, blue: 0.93, alpha: 0.95))
    let border = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    border.lineWidth = isPad ? 2 : 1.5
    brand.withAlphaComponent(0.17).setStroke()
    border.stroke()

    let symbolSize: CGFloat = isPad ? 45 : 38
    let fontSize: CGFloat = isPad ? 42 : 35
    let symbol = NSImage(systemSymbolName: tag.symbol, accessibilityDescription: nil)!
        .withSymbolConfiguration(.init(pointSize: symbolSize, weight: .semibold))!
        .withSymbolConfiguration(.init(paletteColors: [deepGreen]))!
    let textWidth = (tag.text as NSString).size(withAttributes: [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold)
    ]).width
    let gap: CGFloat = isPad ? 20 : 16
    let contentWidth = symbolSize + gap + textWidth
    let startX = rect.midX - contentWidth / 2
    asset(symbol, rect: NSRect(
        x: startX, y: rect.midY - symbolSize / 2,
        width: symbolSize, height: symbolSize
    ))
    label(tag.text, rect: NSRect(
        x: startX + symbolSize + gap, y: rect.minY + (isPad ? 14 : 13),
        width: textWidth + 2, height: rect.height - 16
    ), size: fontSize, weight: .semibold, color: deepGreen)
}

func device(screenshotURL: URL, canvas: Canvas) throws {
    let data = try Data(contentsOf: screenshotURL)
    let bitmap = NSBitmapImageRep(data: data)!
    let screenshot = NSImage(data: data)!
    let ratio = CGFloat(bitmap.pixelsHigh) / CGFloat(bitmap.pixelsWide)
    let border: CGFloat = canvas.isPad ? 28 : 18
    let availableHeight = canvas.deviceBottom - canvas.deviceTop
    let innerWidth = (availableHeight - border * 2) / ratio
    let outerWidth = innerWidth + border * 2
    let rect = NSRect(
        x: (CGFloat(canvas.width) - outerWidth) / 2, y: canvas.deviceTop,
        width: outerWidth, height: availableHeight
    )
    let outerRadius: CGFloat = canvas.isPad ? 63 : 108

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = deepGreen.withAlphaComponent(0.24)
    shadow.shadowBlurRadius = canvas.isPad ? 38 : 32
    shadow.shadowOffset = NSSize(width: 0, height: 18)
    shadow.set()
    rounded(rect, radius: outerRadius, fill: NSColor(white: 0.18, alpha: 1))
    NSGraphicsContext.restoreGraphicsState()

    gradient(NSBezierPath(roundedRect: rect, xRadius: outerRadius, yRadius: outerRadius), colors: [
        NSColor(white: 0.67, alpha: 1), NSColor(white: 0.17, alpha: 1),
        NSColor(white: 0.55, alpha: 1), NSColor(white: 0.12, alpha: 1)
    ], angle: 24)
    rounded(rect.insetBy(dx: 3, dy: 3), radius: outerRadius - 3, fill: NSColor(white: 0.035, alpha: 1))
    let bezel = NSBezierPath(
        roundedRect: rect.insetBy(dx: 6, dy: 6),
        xRadius: outerRadius - 6, yRadius: outerRadius - 6
    )
    bezel.lineWidth = 1.5
    NSColor.white.withAlphaComponent(0.28).setStroke()
    bezel.stroke()

    let screen = NSRect(
        x: rect.minX + border, y: rect.minY + border,
        width: innerWidth, height: innerWidth * ratio
    )
    asset(screenshot, rect: screen, radius: canvas.isPad ? 36 : 90)

    if !canvas.isPad {
        for (offset, height) in [(155.0, 35.0), (232.0, 75.0), (327.0, 75.0)] {
            rounded(NSRect(x: rect.minX - 4, y: rect.minY + offset, width: 4, height: height),
                    radius: 2, fill: NSColor(white: 0.24, alpha: 1))
        }
        rounded(NSRect(x: rect.maxX, y: rect.minY + 270, width: 4, height: 115),
                radius: 2, fill: NSColor(white: 0.24, alpha: 1))
    }
}

func render(_ poster: Poster, canvas: Canvas, icon: NSImage) throws {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(
        data: nil, width: canvas.width, height: canvas.height,
        bitsPerComponent: 8, bytesPerRow: canvas.width * 4,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    context.translateBy(x: 0, y: CGFloat(canvas.height))
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)

    background(canvas)
    let margin = canvas.margin
    let contentWidth = canvas.contentWidth
    let iconSize: CGFloat = canvas.isPad ? 150 : 126
    asset(icon, rect: NSRect(x: margin, y: 76, width: iconSize, height: iconSize), radius: iconSize * 0.22)
    label("小微账单", rect: NSRect(
        x: margin + iconSize + 30, y: canvas.isPad ? 95 : 92,
        width: contentWidth - iconSize - 30, height: 118
    ), size: canvas.isPad ? 86 : 74, weight: .bold)

    let titleSize: CGFloat = canvas.isPad ? 174 : 156
    label(poster.title, rect: NSRect(
        x: margin - 5, y: canvas.isPad ? 268 : 260,
        width: contentWidth + 10, height: canvas.isPad ? 218 : 198
    ), size: titleSize, weight: .heavy)
    label(poster.emphasis, rect: NSRect(
        x: margin - 5, y: canvas.isPad ? 460 : 432,
        width: contentWidth + 10, height: canvas.isPad ? 218 : 198
    ), size: titleSize, weight: .heavy, color: deepGreen)
    label(poster.subtitle, rect: NSRect(
        x: margin, y: canvas.isPad ? 690 : 640,
        width: contentWidth, height: 76
    ), size: canvas.isPad ? 56 : 43, weight: .medium, color: muted)

    let pillGap: CGFloat = canvas.isPad ? 38 : 26
    let pillWidth = (contentWidth - pillGap) / 2
    for (index, tag) in poster.tags.enumerated() {
        pill(tag, rect: NSRect(
            x: margin + CGFloat(index) * (pillWidth + pillGap),
            y: canvas.isPad ? 792 : 730,
            width: pillWidth, height: canvas.isPad ? 88 : 78
        ), isPad: canvas.isPad)
    }

    let screenshotURL = root.appendingPathComponent(
        "screenshots/\(canvas.directory)/\(poster.screenshot).png"
    )
    try device(screenshotURL: screenshotURL, canvas: canvas)
    NSGraphicsContext.restoreGraphicsState()

    let outputDirectory = root.appendingPathComponent(canvas.directory, isDirectory: true)
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    let outputURL = outputDirectory.appendingPathComponent(
        "\(poster.slug)-\(canvas.width)x\(canvas.height).png"
    )
    let output = NSBitmapImageRep(cgImage: context.makeImage()!)
    try output.representation(using: .png, properties: [:])!.write(to: outputURL)
    print(outputURL.path)
}

func contactSheet(_ canvas: Canvas) throws {
    let gap = 20
    let thumbnailWidth = canvas.isPad ? 432 : 384
    let thumbnailHeight = Int((Double(thumbnailWidth) * Double(canvas.height) / Double(canvas.width)).rounded())
    let width = posters.count * thumbnailWidth + (posters.count + 1) * gap
    let height = thumbnailHeight + gap * 2
    let context = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    NSColor(white: 0.94, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    let directory = root.appendingPathComponent(canvas.directory, isDirectory: true)
    for (index, poster) in posters.enumerated() {
        let url = directory.appendingPathComponent("\(poster.slug)-\(canvas.width)x\(canvas.height).png")
        asset(NSImage(contentsOf: url)!, rect: NSRect(
            x: gap + index * (thumbnailWidth + gap), y: gap,
            width: thumbnailWidth, height: thumbnailHeight
        ))
    }
    NSGraphicsContext.restoreGraphicsState()
    let output = NSBitmapImageRep(cgImage: context.makeImage()!)
    let url = directory.appendingPathComponent("contact-sheet.jpg")
    try output.representation(using: .jpeg, properties: [.compressionFactor: 0.88])!.write(to: url)
    print(url.path)
}

let icon = NSImage(contentsOf: iconURL)!
for canvas in canvases where selectedDevice == nil || canvas.directory == selectedDevice {
    for poster in posters {
        try render(poster, canvas: canvas, icon: icon)
    }
    try contactSheet(canvas)
}
