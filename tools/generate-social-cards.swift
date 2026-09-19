import AppKit
import Foundation

struct Article {
    let source: URL
    let title: String
    let date: String
    let tags: [String]
    let isEnglish: Bool
    let outputName: String
}

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let contentDir = root.appendingPathComponent("content/blogs")
let outputDir = root.appendingPathComponent("static/img/share")
try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)

func parseFrontMatter(_ url: URL) throws -> Article? {
    let raw = try String(contentsOf: url, encoding: .utf8)
    let lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    guard lines.first == "---" else { return nil }

    var title = ""
    var date = ""
    var tags: [String] = []
    var inTags = false

    for line in lines.dropFirst() {
        if line == "---" { break }
        if line.hasPrefix("title:") {
            title = line.dropFirst("title:".count).trimmingCharacters(in: .whitespaces)
            if title.hasPrefix("\""), title.hasSuffix("\""), title.count >= 2 {
                title.removeFirst()
                title.removeLast()
            }
            inTags = false
        } else if line.hasPrefix("date:") {
            date = String(line.dropFirst("date:".count)).trimmingCharacters(in: .whitespaces)
            inTags = false
        } else if line == "tags:" {
            inTags = true
        } else if inTags && line.trimmingCharacters(in: .whitespaces).hasPrefix("- ") {
            tags.append(String(line.trimmingCharacters(in: .whitespaces).dropFirst(2)))
        } else if !line.hasPrefix(" ") && line.contains(":") {
            inTags = false
        }
    }

    guard !title.isEmpty else { return nil }

    let name = url.deletingPathExtension().lastPathComponent
    let isEnglish = name.hasSuffix(".en")
    guard name.lowercased().contains("wcode") else { return nil }

    return Article(
        source: url,
        title: title,
        date: String(date.prefix(10)),
        tags: tags,
        isEnglish: isEnglish,
        outputName: name + ".png"
    )
}

func textAttributes(font: NSFont, color: NSColor, lineSpacing: CGFloat = 0, kern: CGFloat = 0) -> [NSAttributedString.Key: Any] {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineSpacing = lineSpacing
    return [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
        .kern: kern
    ]
}

func drawText(_ text: String, in rect: NSRect, font: NSFont, color: NSColor, lineSpacing: CGFloat = 0, kern: CGFloat = 0) {
    NSAttributedString(
        string: text,
        attributes: textAttributes(font: font, color: color, lineSpacing: lineSpacing, kern: kern)
    ).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
}

func fittedTitleFont(for title: String, maxWidth: CGFloat, maxHeight: CGFloat) -> NSFont {
    var size: CGFloat = title.count > 42 ? 58 : 70
    while size >= 44 {
        let font = NSFont.systemFont(ofSize: size, weight: .bold)
        let box = NSAttributedString(
            string: title,
            attributes: textAttributes(font: font, color: .white, lineSpacing: 7, kern: -1.0)
        ).boundingRect(
            with: NSSize(width: maxWidth, height: 1000),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        if box.height <= maxHeight { return font }
        size -= 2
    }
    return NSFont.systemFont(ofSize: 44, weight: .bold)
}

func pill(_ text: String, x: CGFloat, y: CGFloat) -> CGFloat {
    let font = NSFont.systemFont(ofSize: 16, weight: .semibold)
    let attrs = textAttributes(font: font, color: NSColor(calibratedRed: 0.90, green: 0.86, blue: 0.94, alpha: 1))
    let width = ceil(NSAttributedString(string: text, attributes: attrs).size().width) + 34
    let rect = NSRect(x: x, y: y, width: width, height: 42)
    let path = NSBezierPath(roundedRect: rect, xRadius: 13, yRadius: 13)
    NSColor(calibratedRed: 0.13, green: 0.10, blue: 0.17, alpha: 1).setFill()
    path.fill()
    NSColor(calibratedRed: 0.30, green: 0.23, blue: 0.37, alpha: 1).setStroke()
    path.lineWidth = 1
    path.stroke()
    drawText(text.uppercased(), in: NSRect(x: x + 17, y: y + 10, width: width - 34, height: 24), font: font, color: NSColor(calibratedRed: 0.90, green: 0.86, blue: 0.94, alpha: 1), kern: 0.2)
    return width
}

func drawCard(_ article: Article, to url: URL) throws {
    let width = 1200
    let height = 630
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "SocialCard", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create bitmap"])
    }

    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics

    let canvas = NSRect(x: 0, y: 0, width: width, height: height)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.035, green: 0.028, blue: 0.055, alpha: 1),
        NSColor(calibratedRed: 0.105, green: 0.066, blue: 0.135, alpha: 1)
    ])!.draw(in: canvas, angle: -18)

    NSColor(calibratedRed: 0.50, green: 0.40, blue: 0.95, alpha: 0.11).setFill()
    NSBezierPath(ovalIn: NSRect(x: 900, y: 360, width: 420, height: 420)).fill()
    NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.68, alpha: 0.07).setFill()
    NSBezierPath(ovalIn: NSRect(x: 1010, y: -90, width: 330, height: 330)).fill()

    let accentRect = NSRect(x: 72, y: 548, width: 160, height: 7)
    let accent = NSBezierPath(roundedRect: accentRect, xRadius: 3.5, yRadius: 3.5)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.62, green: 0.51, blue: 1.0, alpha: 1),
        NSColor(calibratedRed: 1.0, green: 0.48, blue: 0.72, alpha: 1)
    ])!.draw(in: accent, angle: 0)

    drawText(
        "FRANCIS.RUN / WCODE",
        in: NSRect(x: 72, y: 492, width: 600, height: 34),
        font: NSFont.systemFont(ofSize: 21, weight: .bold),
        color: NSColor(calibratedRed: 0.79, green: 0.73, blue: 1.0, alpha: 1),
        kern: 2.4
    )

    let titleFont = fittedTitleFont(for: article.title, maxWidth: 1010, maxHeight: 250)
    drawText(
        article.title,
        in: NSRect(x: 72, y: 222, width: 1010, height: 250),
        font: titleFont,
        color: NSColor(calibratedWhite: 0.985, alpha: 1),
        lineSpacing: 7,
        kern: -1.0
    )

    var tagX: CGFloat = 72
    let tagY: CGFloat = 116
    for tag in article.tags.prefix(3) {
        let next = pill(tag, x: tagX, y: tagY)
        tagX += next + 12
        if tagX > 940 { break }
    }

    let footer = [article.date, article.isEnglish ? "Engineering notes" : "工程笔记"].filter { !$0.isEmpty }.joined(separator: "  ·  ")
    drawText(
        footer,
        in: NSRect(x: 72, y: 58, width: 760, height: 30),
        font: NSFont.systemFont(ofSize: 18, weight: .medium),
        color: NSColor(calibratedRed: 0.63, green: 0.59, blue: 0.68, alpha: 1)
    )
    drawText(
        "francis.run",
        in: NSRect(x: 930, y: 58, width: 198, height: 30),
        font: NSFont.systemFont(ofSize: 18, weight: .semibold),
        color: NSColor(calibratedRed: 0.77, green: 0.70, blue: 0.82, alpha: 1)
    )

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "SocialCard", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot encode PNG"])
    }
    try png.write(to: url, options: .atomic)
}


func drawDefaultCard(to url: URL) throws {
    let width = 1200
    let height = 630
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "SocialCard", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot create default bitmap"])
    }

    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics

    let canvas = NSRect(x: 0, y: 0, width: width, height: height)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.055, green: 0.070, blue: 0.065, alpha: 1),
        NSColor(calibratedRed: 0.105, green: 0.085, blue: 0.070, alpha: 1)
    ])!.draw(in: canvas, angle: -15)

    NSColor(calibratedRed: 0.30, green: 0.78, blue: 0.58, alpha: 0.10).setFill()
    NSBezierPath(ovalIn: NSRect(x: -130, y: 360, width: 470, height: 390)).fill()
    NSColor(calibratedRed: 0.94, green: 0.68, blue: 0.34, alpha: 0.08).setFill()
    NSBezierPath(ovalIn: NSRect(x: 930, y: -100, width: 390, height: 390)).fill()

    let accent = NSBezierPath(roundedRect: NSRect(x: 72, y: 548, width: 146, height: 7), xRadius: 3.5, yRadius: 3.5)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.33, green: 0.78, blue: 0.57, alpha: 1),
        NSColor(calibratedRed: 0.91, green: 0.67, blue: 0.37, alpha: 1)
    ])!.draw(in: accent, angle: 0)

    drawText(
        "FRANCIS.RUN / FIELD NOTES",
        in: NSRect(x: 72, y: 492, width: 650, height: 34),
        font: NSFont.systemFont(ofSize: 21, weight: .bold),
        color: NSColor(calibratedRed: 0.60, green: 0.88, blue: 0.73, alpha: 1),
        kern: 2.1
    )
    drawText(
        "francis.run",
        in: NSRect(x: 72, y: 310, width: 700, height: 130),
        font: NSFont.systemFont(ofSize: 104, weight: .bold),
        color: NSColor(calibratedWhite: 0.98, alpha: 1),
        kern: -3
    )
    drawText(
        "Engineering notes · systems · agents · photography",
        in: NSRect(x: 77, y: 264, width: 760, height: 42),
        font: NSFont.systemFont(ofSize: 27, weight: .medium),
        color: NSColor(calibratedRed: 0.69, green: 0.70, blue: 0.66, alpha: 1)
    )

    let labels = ["DATA", "RUST", "AGENTS", "PHOTO"]
    let startX: CGFloat = 77
    let y: CGFloat = 136
    let boxWidth: CGFloat = 168
    let gap: CGFloat = 18
    for (index, label) in labels.enumerated() {
        let x = startX + CGFloat(index) * (boxWidth + gap)
        let rect = NSRect(x: x, y: y, width: boxWidth, height: 68)
        let path = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
        NSColor(calibratedRed: 0.095, green: 0.115, blue: 0.105, alpha: 0.94).setFill()
        path.fill()
        NSColor(calibratedRed: 0.25, green: 0.34, blue: 0.29, alpha: 1).setStroke()
        path.lineWidth = 1
        path.stroke()
        drawText(
            label,
            in: NSRect(x: x + 20, y: y + 22, width: boxWidth - 40, height: 25),
            font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            color: NSColor(calibratedRed: 0.86, green: 0.87, blue: 0.82, alpha: 1),
            kern: 1
        )
    }

    let line = NSBezierPath()
    line.move(to: NSPoint(x: 77, y: 94))
    line.line(to: NSPoint(x: 1128, y: 94))
    NSColor(calibratedRed: 0.25, green: 0.29, blue: 0.26, alpha: 1).setStroke()
    line.lineWidth = 1
    line.stroke()

    drawText(
        "BUILD · WRITE · SHOOT",
        in: NSRect(x: 77, y: 51, width: 440, height: 27),
        font: NSFont.systemFont(ofSize: 17, weight: .semibold),
        color: NSColor(calibratedRed: 0.55, green: 0.61, blue: 0.56, alpha: 1),
        kern: 1.2
    )

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "SocialCard", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cannot encode default PNG"])
    }
    try png.write(to: url, options: .atomic)
}

for stale in try fm.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: nil) where stale.pathExtension.lowercased() == "png" {
    try fm.removeItem(at: stale)
}

try drawDefaultCard(to: root.appendingPathComponent("static/img/share-default.png"))
print("default -> static/img/share-default.png")

let files = try fm.contentsOfDirectory(at: contentDir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "md" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

var generated = 0
for source in files {
    guard let article = try parseFrontMatter(source) else { continue }
    let output = outputDir.appendingPathComponent(article.outputName)
    try drawCard(article, to: output)
    print("\(article.source.lastPathComponent) -> static/img/share/\(article.outputName)")
    generated += 1
}

print("generated=\(generated)")
