// Frames a raw screenshot for the App Store: teal background, headline on top, screenshot
// below with rounded corners. iPad captures become 2064×2752 (13" iPad), everything else
// 1320×2868 (6.9" iPhone). Output is opaque.
// Usage: swift assets/screenshots/make_screenshot.swift <raw.png> <out.png> "<headline>"
import AppKit

let args = CommandLine.arguments
guard args.count == 4 else {
  print("usage: make_screenshot.swift <raw.png> <out.png> \"<headline>\"")
  exit(1)
}
// A literal "\\n" in the headline forces a line break where the automatic wrap reads badly.
let (input, output) = (args[1], args[2])
let headline = args[3].replacingOccurrences(of: "\\n", with: "\n")

let teal = NSColor(srgbRed: 15 / 255, green: 118 / 255, blue: 110 / 255, alpha: 1)

guard let shot = NSImage(contentsOfFile: input),
  let pixels = shot.representations.first?.pixelsWide
else {
  print("can't read \(input)")
  exit(1)
}
let isPad = pixels >= 2000
let width = isPad ? 2064 : 1320
let height = isPad ? 2752 : 2868
// Sizes below were tuned on the iPhone canvas; scale them to this one.
let unit = CGFloat(width) / 1320 * (isPad ? 0.8 : 1)

// Opaque RGB canvas (App Store screenshots must not have transparency).
let cg = CGContext(
  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
  space: CGColorSpace(name: CGColorSpace.sRGB)!,
  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)

teal.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

// Headline, centred in the top band. AppKit's origin is bottom-left.
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
paragraph.lineSpacing = 8
let attributes: [NSAttributedString.Key: Any] = [
  .font: NSFont.systemFont(ofSize: 104 * unit, weight: .bold),
  .foregroundColor: NSColor.white,
  .paragraphStyle: paragraph,
]
let text = NSAttributedString(string: headline, attributes: attributes)
let textBox = NSRect(x: 90, y: CGFloat(height) - 560, width: CGFloat(width) - 180, height: 420)
let measured = text.boundingRect(
  with: textBox.size, options: [.usesLineFragmentOrigin, .usesFontLeading])
text.draw(
  with: NSRect(
    x: textBox.minX, y: textBox.minY + (textBox.height - measured.height) / 2,
    width: textBox.width, height: measured.height),
  options: [.usesLineFragmentOrigin, .usesFontLeading])

// Screenshot, scaled to fit below the headline, with rounded corners and a thin frame.
let scale: CGFloat = 0.74
let shotWidth = CGFloat(width) * scale
let shotHeight = CGFloat(height) * scale
let shotRect = NSRect(
  x: (CGFloat(width) - shotWidth) / 2, y: 110, width: shotWidth, height: shotHeight)
let corner: CGFloat = isPad ? 64 : 96
let frame = NSBezierPath(roundedRect: shotRect.insetBy(dx: -14, dy: -14), xRadius: corner + 14, yRadius: corner + 14)
NSColor(srgbRed: 8 / 255, green: 80 / 255, blue: 65 / 255, alpha: 1).setFill()
frame.fill()
NSGraphicsContext.saveGraphicsState()
NSBezierPath(roundedRect: shotRect, xRadius: corner, yRadius: corner).addClip()
shot.draw(in: shotRect)
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()
let rep = NSBitmapImageRep(cgImage: cg.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("wrote \(output)")
