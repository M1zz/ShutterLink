import SwiftUI
import RealityKit
import UIKit

enum BannerRenderer {
    /// Rasterize the SwiftUI banner into a bitmap. Fabric gets a faint weave printed into it.
    @MainActor
    static func renderImage(_ design: BannerDesign) -> UIImage? {
        let size = design.aspect.renderSize
        let renderer = ImageRenderer(content: BannerCanvasView(design: design, size: size))
        renderer.scale = 1
        renderer.isOpaque = true
        guard let image = renderer.uiImage else { return nil }
        return design.material == .fabric ? woven(image) : image
    }

    /// Rasterize and upload as a RealityKit texture.
    @MainActor
    static func renderTexture(_ design: BannerDesign) throws -> TextureResource {
        guard let cgImage = renderImage(design)?.cgImage else {
            throw RenderError.rasterizationFailed
        }
        var options = TextureResource.CreateOptions(semantic: .color)
        options.mipmapsMode = .allocateAndGenerateAll
        return try TextureResource.generate(from: cgImage, options: options)
    }

    /// Thread-level bumps for the cloth weave. Built once per material and reused.
    @MainActor
    static func weaveNormalTexture(for material: BannerMaterialStyle) -> TextureResource? {
        if let cached = normalCache[material] { return cached }
        guard let image = weaveNormalMap(strength: material == .fabric ? 1 : 0.25),
              let texture = try? TextureResource.generate(from: image, options: .init(semantic: .normal)) else { return nil }
        normalCache[material] = texture
        return texture
    }

    enum RenderError: Error { case rasterizationFailed }

    @MainActor private static var normalCache: [BannerMaterialStyle: TextureResource] = [:]

    /// Size of one over-under thread crossing, in texture pixels (≈ 5 mm on a 4 m banner).
    private static let threadPixels = 3

    /// Multiplies a fine crosshatch over the print, the way ink sits on woven polyester.
    private static func woven(_ image: UIImage) -> UIImage {
        let size = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            image.draw(at: .zero)
            let cg = context.cgContext
            cg.setBlendMode(.multiply)
            let step = CGFloat(threadPixels)
            cg.setFillColor(UIColor(white: 0.96, alpha: 1).cgColor)
            var y: CGFloat = 0
            while y < size.height {
                cg.fill(CGRect(x: 0, y: y, width: size.width, height: 1))
                y += step
            }
            cg.setFillColor(UIColor(white: 0.975, alpha: 1).cgColor)
            var x: CGFloat = 0
            while x < size.width {
                cg.fill(CGRect(x: x, y: 0, width: 1, height: size.height))
                x += step
            }
        }
    }

    /// Tangent-space normal map of a plain weave: warp and weft threads bulging over and under each other.
    /// Drawn at the banner's full texture width, since RealityKit can't tile one texture over another.
    private static func weaveNormalMap(strength: Float) -> CGImage? {
        let width = 2400, height = 600
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let period = Float(threadPixels * 2)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let u = Float(x) / period * 2 * .pi
                let v = Float(y) / period * 2 * .pi
                // Which thread is on top flips every crossing (checkerboard of over/under).
                let over: Float = (x / (threadPixels * 2) + y / (threadPixels * 2)) % 2 == 0 ? 1 : -1
                let nx = -cos(u) * 0.35 * over * strength
                let ny = -cos(v) * 0.35 * -over * strength
                let length = (nx * nx + ny * ny + 1).squareRoot()
                let i = (y * width + x) * 4
                pixels[i] = UInt8(((nx / length) * 0.5 + 0.5) * 255)
                pixels[i + 1] = UInt8(((ny / length) * 0.5 + 0.5) * 255)
                pixels[i + 2] = UInt8(((1 / length) * 0.5 + 0.5) * 255)
                pixels[i + 3] = 255
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
