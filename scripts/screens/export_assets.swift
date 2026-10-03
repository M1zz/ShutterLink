// Exports SF Symbols and the pairing QR used by the HTML screen recreations.
// Run: swift scripts/screens/export_assets.swift
import AppKit
import CoreImage.CIFilterBuiltins

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "scripts/screens/assets")

func save(_ rep: NSBitmapImageRep, _ name: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(name + ".png"))
}

func symbol(_ name: String, file: String, pt: CGFloat = 160, weight: NSFont.Weight = .regular) {
    let config = NSImage.SymbolConfiguration(pointSize: pt, weight: weight)  // template: alpha is the mask
    guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else {
        print("missing \(name)"); return
    }
    let size = img.size
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    save(rep, file)
}

symbol("qrcode", file: "qrcode")
symbol("dot.radiowaves.left.and.right", file: "radiowaves", weight: .semibold)
symbol("iphone.radiowaves.left.and.right", file: "iphone-radiowaves", weight: .semibold)
symbol("timer", file: "timer")
symbol("timer.circle.fill", file: "timer-fill")
symbol("arrow.triangle.2.circlepath.camera", file: "flip")
symbol("checkmark.circle.fill", file: "check", weight: .semibold)
symbol("wifi", file: "wifi", weight: .semibold)
symbol("cellularbars", file: "cell", weight: .semibold)
symbol("battery.100percent", file: "battery")
symbol("camera.aperture", file: "aperture")

let filter = CIFilter.qrCodeGenerator()
filter.message = Data("https://shutterlink.example.com/r?c=4827".utf8)
filter.correctionLevel = "M"
let qr = filter.outputImage!.transformed(by: CGAffineTransform(scaleX: 20, y: 20))
let cg = CIContext().createCGImage(qr, from: qr.extent)!
save(NSBitmapImageRep(cgImage: cg), "qr")
print("done")
