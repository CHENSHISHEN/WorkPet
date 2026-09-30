import AppKit
import Foundation

let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let root = currentDirectory
    .appendingPathComponent("WorkPet")
    .appendingPathComponent("Sources")
    .appendingPathComponent("WorkPet")
    .appendingPathComponent("Resources")
    .appendingPathComponent("PetPacks")
    .appendingPathComponent("orange-cat")
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

struct Pose {
    let name: String
    let eye: Eye
    let mouth: Mouth
    let yOffset: CGFloat
    let squash: CGFloat
    let blush: CGFloat
}

enum Eye {
    case open
    case happy
    case love
    case sleepy
    case alert
    case focused
}

enum Mouth {
    case smile
    case happy
    case small
    case sleep
    case alert
}

let poses = [
    Pose(name: "idle-1", eye: .open, mouth: .smile, yOffset: 0, squash: 1, blush: 0.28),
    Pose(name: "idle-2", eye: .open, mouth: .smile, yOffset: 2, squash: 0.985, blush: 0.28),
    Pose(name: "curious", eye: .open, mouth: .small, yOffset: 0, squash: 1, blush: 0.24),
    Pose(name: "happy", eye: .happy, mouth: .happy, yOffset: 3, squash: 1.02, blush: 0.36),
    Pose(name: "alert", eye: .alert, mouth: .alert, yOffset: 4, squash: 1.02, blush: 0.38),
    Pose(name: "love", eye: .love, mouth: .happy, yOffset: 2, squash: 1, blush: 0.48),
    Pose(name: "sleep", eye: .sleepy, mouth: .sleep, yOffset: -1, squash: 0.98, blush: 0.12),
    Pose(name: "focused", eye: .focused, mouth: .small, yOffset: 0, squash: 1, blush: 0.08),
    Pose(name: "squish", eye: .happy, mouth: .small, yOffset: -4, squash: 0.9, blush: 0.38)
]

for pose in poses {
    let image = NSImage(size: NSSize(width: 296, height: 296))
    image.lockFocus()
    NSGraphicsContext.current?.shouldAntialias = true
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: 296, height: 296).fill()
    drawPet(pose)
    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Failed to render \(pose.name)")
    }

    try data.write(to: root.appendingPathComponent("\(pose.name).png"))
}

func drawPet(_ pose: Pose) {
    let base = NSColor(red: 0.98, green: 0.66, blue: 0.31, alpha: 1)
    let light = NSColor(red: 1.0, green: 0.84, blue: 0.53, alpha: 1)
    let cream = NSColor(red: 1.0, green: 0.91, blue: 0.70, alpha: 1)
    let shade = NSColor(red: 0.67, green: 0.36, blue: 0.15, alpha: 1)
    let line = NSColor(red: 0.44, green: 0.25, blue: 0.13, alpha: 0.8)

    let y = pose.yOffset
    let head = CGRect(x: 58, y: 118 + y, width: 180, height: 138 * pose.squash)
    let body = CGRect(x: 82, y: 44, width: 132, height: 108 * pose.squash)

    drawShadow(CGRect(x: 72, y: 28, width: 152, height: 22))
    drawTail(base: base, shade: shade, body: body)
    drawBody(body, base: base, light: light, cream: cream, line: line)
    drawEars(head: head, base: base, light: light, line: line)
    drawHead(head, base: base, light: light, line: line)
    drawStripes(head: head, shade: shade)
    drawFace(head: head, pose: pose, line: line)
    drawPaws(body: body, cream: cream, line: line)
}

func drawShadow(_ rect: CGRect) {
    NSColor.black.withAlphaComponent(0.14).setFill()
    NSBezierPath(ovalIn: rect).fill()
}

func drawTail(base: NSColor, shade: NSColor, body: CGRect) {
    let tail = NSBezierPath()
    tail.move(to: CGPoint(x: body.maxX - 8, y: body.midY))
    tail.curve(
        to: CGPoint(x: body.maxX + 58, y: body.midY + 67),
        controlPoint1: CGPoint(x: body.maxX + 35, y: body.midY + 7),
        controlPoint2: CGPoint(x: body.maxX + 68, y: body.midY + 42)
    )
    tail.curve(
        to: CGPoint(x: body.maxX + 39, y: body.midY + 80),
        controlPoint1: CGPoint(x: body.maxX + 56, y: body.midY + 88),
        controlPoint2: CGPoint(x: body.maxX + 35, y: body.midY + 96)
    )
    tail.lineCapStyle = .round
    tail.lineWidth = 24
    shade.setStroke()
    tail.stroke()
    tail.lineWidth = 16
    base.setStroke()
    tail.stroke()
}

func drawBody(_ rect: CGRect, base: NSColor, light: NSColor, cream: NSColor, line: NSColor) {
    let body = NSBezierPath(roundedRect: rect, xRadius: 58, yRadius: 50)
    NSGradient(colors: [light, base])?.draw(in: body, angle: -90)
    line.setStroke()
    body.lineWidth = 3
    body.stroke()

    cream.withAlphaComponent(0.86).setFill()
    NSBezierPath(ovalIn: CGRect(x: rect.midX - 43, y: rect.minY + 18, width: 86, height: 70)).fill()
}

func drawEars(head: CGRect, base: NSColor, light: NSColor, line: NSColor) {
    let left = NSBezierPath()
    left.move(to: CGPoint(x: head.minX + 28, y: head.maxY - 34))
    left.curve(
        to: CGPoint(x: head.minX + 72, y: head.maxY - 10),
        controlPoint1: CGPoint(x: head.minX + 35, y: head.maxY + 36),
        controlPoint2: CGPoint(x: head.minX + 62, y: head.maxY + 20)
    )
    left.line(to: CGPoint(x: head.minX + 86, y: head.maxY - 48))
    left.close()

    let right = NSBezierPath()
    right.move(to: CGPoint(x: head.maxX - 28, y: head.maxY - 34))
    right.curve(
        to: CGPoint(x: head.maxX - 72, y: head.maxY - 10),
        controlPoint1: CGPoint(x: head.maxX - 35, y: head.maxY + 36),
        controlPoint2: CGPoint(x: head.maxX - 62, y: head.maxY + 20)
    )
    right.line(to: CGPoint(x: head.maxX - 86, y: head.maxY - 48))
    right.close()

    base.setFill()
    line.setStroke()
    [left, right].forEach {
        $0.fill()
        $0.lineWidth = 3
        $0.stroke()
    }

    NSColor.systemPink.withAlphaComponent(0.28).setFill()
    NSBezierPath(ovalIn: CGRect(x: head.minX + 47, y: head.maxY - 15, width: 28, height: 34)).fill()
    NSBezierPath(ovalIn: CGRect(x: head.maxX - 75, y: head.maxY - 15, width: 28, height: 34)).fill()
}

func drawHead(_ rect: CGRect, base: NSColor, light: NSColor, line: NSColor) {
    let head = NSBezierPath(roundedRect: rect, xRadius: 75, yRadius: 65)
    NSGradient(colors: [light, base])?.draw(in: head, angle: -90)
    line.setStroke()
    head.lineWidth = 3
    head.stroke()
}

func drawStripes(head: CGRect, shade: NSColor) {
    shade.withAlphaComponent(0.42).setStroke()
    for (x, h) in [(head.midX - 30, 27), (head.midX, 33), (head.midX + 30, 27)] as [(CGFloat, CGFloat)] {
        let stripe = NSBezierPath()
        stripe.move(to: CGPoint(x: x, y: head.maxY - 22))
        stripe.line(to: CGPoint(x: x, y: head.maxY - 22 - h))
        stripe.lineCapStyle = .round
        stripe.lineWidth = 5
        stripe.stroke()
    }

    drawSideStripe(head: head, left: true)
    drawSideStripe(head: head, left: false)
}

func drawSideStripe(head: CGRect, left: Bool) {
    let x = left ? head.minX + 22 : head.maxX - 22
    let direction: CGFloat = left ? 1 : -1
    let path = NSBezierPath()
    path.move(to: CGPoint(x: x, y: head.midY + 7))
    path.curve(
        to: CGPoint(x: x + 29 * direction, y: head.midY - 3),
        controlPoint1: CGPoint(x: x + 11 * direction, y: head.midY + 13),
        controlPoint2: CGPoint(x: x + 20 * direction, y: head.midY - 4)
    )
    path.lineWidth = 4
    path.lineCapStyle = .round
    path.stroke()
}

func drawFace(head: CGRect, pose: Pose, line: NSColor) {
    drawEyes(head: head, eye: pose.eye)
    drawNoseAndMouth(head: head, mouth: pose.mouth, line: line)
    drawWhiskers(head: head, line: line)

    NSColor.systemPink.withAlphaComponent(pose.blush).setFill()
    NSBezierPath(ovalIn: CGRect(x: head.midX - 71, y: head.midY - 11, width: 28, height: 13)).fill()
    NSBezierPath(ovalIn: CGRect(x: head.midX + 43, y: head.midY - 11, width: 28, height: 13)).fill()
}

func drawEyes(head: CGRect, eye: Eye) {
    let left = CGPoint(x: head.midX - 38, y: head.midY + 17)
    let right = CGPoint(x: head.midX + 38, y: head.midY + 17)

    switch eye {
    case .happy, .sleepy, .focused:
        drawClosedEye(left)
        drawClosedEye(right)
    case .love:
        drawHeartEye(left)
        drawHeartEye(right)
    case .alert:
        drawOpenEye(left, width: 24, height: 31)
        drawOpenEye(right, width: 24, height: 31)
    case .open:
        drawOpenEye(left, width: 25, height: 33)
        drawOpenEye(right, width: 25, height: 33)
    }
}

func drawOpenEye(_ center: CGPoint, width: CGFloat, height: CGFloat) {
    NSColor.white.setFill()
    NSBezierPath(ovalIn: CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)).fill()
    NSColor(red: 0.11, green: 0.08, blue: 0.05, alpha: 1).setFill()
    NSBezierPath(ovalIn: CGRect(x: center.x - 7, y: center.y - 10, width: 14, height: 21)).fill()
    NSColor.white.withAlphaComponent(0.92).setFill()
    NSBezierPath(ovalIn: CGRect(x: center.x - 3, y: center.y + 5, width: 5, height: 5)).fill()
}

func drawClosedEye(_ center: CGPoint) {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: center.x - 15, y: center.y))
    path.curve(
        to: CGPoint(x: center.x + 15, y: center.y),
        controlPoint1: CGPoint(x: center.x - 7, y: center.y - 11),
        controlPoint2: CGPoint(x: center.x + 7, y: center.y - 11)
    )
    path.lineCapStyle = .round
    path.lineWidth = 4
    NSColor(red: 0.22, green: 0.13, blue: 0.08, alpha: 0.9).setStroke()
    path.stroke()
}

func drawHeartEye(_ center: CGPoint) {
    NSColor.systemPink.setFill()
    let path = NSBezierPath()
    path.move(to: CGPoint(x: center.x, y: center.y - 10))
    path.curve(to: CGPoint(x: center.x - 15, y: center.y + 4), controlPoint1: CGPoint(x: center.x - 13, y: center.y - 1), controlPoint2: CGPoint(x: center.x - 19, y: center.y + 9))
    path.curve(to: CGPoint(x: center.x, y: center.y + 13), controlPoint1: CGPoint(x: center.x - 8, y: center.y + 18), controlPoint2: CGPoint(x: center.x, y: center.y + 11))
    path.curve(to: CGPoint(x: center.x + 15, y: center.y + 4), controlPoint1: CGPoint(x: center.x, y: center.y + 11), controlPoint2: CGPoint(x: center.x + 8, y: center.y + 18))
    path.curve(to: CGPoint(x: center.x, y: center.y - 10), controlPoint1: CGPoint(x: center.x + 19, y: center.y + 9), controlPoint2: CGPoint(x: center.x + 13, y: center.y - 1))
    path.fill()
}

func drawNoseAndMouth(head: CGRect, mouth: Mouth, line: NSColor) {
    NSColor.systemPink.withAlphaComponent(0.9).setFill()
    let nose = NSBezierPath()
    nose.move(to: CGPoint(x: head.midX, y: head.midY - 5))
    nose.line(to: CGPoint(x: head.midX - 9, y: head.midY + 5))
    nose.line(to: CGPoint(x: head.midX + 9, y: head.midY + 5))
    nose.close()
    nose.fill()

    line.setStroke()
    let path = NSBezierPath()
    path.lineWidth = 3
    path.lineCapStyle = .round

    switch mouth {
    case .alert:
        path.appendOval(in: CGRect(x: head.midX - 6, y: head.midY - 22, width: 12, height: 14))
    case .sleep:
        path.move(to: CGPoint(x: head.midX - 12, y: head.midY - 15))
        path.line(to: CGPoint(x: head.midX + 12, y: head.midY - 15))
    case .small:
        path.move(to: CGPoint(x: head.midX - 10, y: head.midY - 13))
        path.curve(to: CGPoint(x: head.midX + 10, y: head.midY - 13), controlPoint1: CGPoint(x: head.midX - 3, y: head.midY - 19), controlPoint2: CGPoint(x: head.midX + 3, y: head.midY - 19))
    case .smile, .happy:
        path.move(to: CGPoint(x: head.midX, y: head.midY - 6))
        path.line(to: CGPoint(x: head.midX, y: head.midY - 13))
        path.move(to: CGPoint(x: head.midX, y: head.midY - 13))
        path.curve(to: CGPoint(x: head.midX - 20, y: head.midY - 14), controlPoint1: CGPoint(x: head.midX - 4, y: head.midY - 25), controlPoint2: CGPoint(x: head.midX - 16, y: head.midY - 25))
        path.move(to: CGPoint(x: head.midX, y: head.midY - 13))
        path.curve(to: CGPoint(x: head.midX + 20, y: head.midY - 14), controlPoint1: CGPoint(x: head.midX + 4, y: head.midY - 25), controlPoint2: CGPoint(x: head.midX + 16, y: head.midY - 25))
    }

    if mouth == .alert {
        NSColor(red: 0.28, green: 0.15, blue: 0.1, alpha: 0.85).setFill()
        path.fill()
    } else {
        path.stroke()
    }
}

func drawWhiskers(head: CGRect, line: NSColor) {
    line.withAlphaComponent(0.38).setStroke()
    for offset in [-14, 0, 14] as [CGFloat] {
        drawWhisker(from: CGPoint(x: head.midX - 23, y: head.midY - 6 + offset * 0.25), to: CGPoint(x: head.minX + 24, y: head.midY - 10 + offset))
        drawWhisker(from: CGPoint(x: head.midX + 23, y: head.midY - 6 + offset * 0.25), to: CGPoint(x: head.maxX - 24, y: head.midY - 10 + offset))
    }
}

func drawWhisker(from: CGPoint, to: CGPoint) {
    let path = NSBezierPath()
    path.move(to: from)
    path.line(to: to)
    path.lineWidth = 2
    path.lineCapStyle = .round
    path.stroke()
}

func drawPaws(body: CGRect, cream: NSColor, line: NSColor) {
    cream.setFill()
    line.withAlphaComponent(0.38).setStroke()
    let left = NSBezierPath(roundedRect: CGRect(x: body.midX - 55, y: body.minY + 3, width: 46, height: 28), xRadius: 20, yRadius: 14)
    let right = NSBezierPath(roundedRect: CGRect(x: body.midX + 9, y: body.minY + 3, width: 46, height: 28), xRadius: 20, yRadius: 14)
    [left, right].forEach {
        $0.fill()
        $0.lineWidth = 2
        $0.stroke()
    }
}
