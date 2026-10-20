import RealityKit
import UIKit

/// The banner (plus optional carrying poles) as one gesture-able entity.
final class BannerEntity: Entity, HasModel, HasCollision {
    private var poles: [ModelEntity] = []
    private var shape: ClothShape?

    required init() { super.init() }

    convenience init(design: BannerDesign, texture: TextureResource) throws {
        self.init()
        try rebuild(design: design, texture: texture)
    }

    /// Rebuild mesh + material from the current design. Called on every design change.
    @MainActor
    func rebuild(design: BannerDesign, texture: TextureResource) throws {
        let w = design.widthMeters
        let h = design.heightMeters
        let style = design.material

        let shape = ClothShape(width: w, height: h, sag: style.sag, wrinkle: style.wrinkle,
                               wind: design.isFluttering ? 1 : 0)
        self.shape = shape
        let mesh = try MeshResource.generate(from: [shape.meshDescriptor()])

        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(texture: .init(texture))
        material.roughness = .init(floatLiteral: style.roughness)
        material.metallic = .init(floatLiteral: 0)
        material.clearcoat = .init(floatLiteral: style.clearcoat)
        if style != .paper, let weave = BannerRenderer.weaveNormalTexture(for: style) {
            material.normal = .init(texture: .init(weave))
        }
        if style == .fabric {
            // The soft rim glow woven cloth has at grazing angles.
            material.sheen = .init(tint: UIColor(white: 0.35, alpha: 1))
        }
        material.faceCulling = .none   // visible from behind, so people can walk around it

        model = ModelComponent(mesh: mesh, materials: [material])
        // A flat box is good enough for tap / gesture hit-testing.
        collision = CollisionComponent(shapes: [.generateBox(size: [w, h, 0.05])])

        poles.forEach { $0.removeFromParent() }
        poles.removeAll()
        if design.showPoles {
            let poleHeight = h + 0.3
            var poleMaterial = PhysicallyBasedMaterial()
            poleMaterial.baseColor = .init(tint: UIColor(white: 0.9, alpha: 1))
            poleMaterial.roughness = .init(floatLiteral: 0.35)
            poleMaterial.metallic = .init(floatLiteral: 0.6)
            for sign: Float in [-1, 1] {
                let pole = ModelEntity(
                    mesh: .generateBox(size: [0.028, poleHeight, 0.028], cornerRadius: 0.014),
                    materials: [poleMaterial]
                )
                pole.position = [sign * (w / 2 + 0.02), -0.12, -0.02]
                addChild(pole)
                poles.append(pole)
            }
        }
    }

    /// Moves the cloth to its breeze pose at `time`. No-op when the design doesn't flutter.
    @MainActor
    func flutter(at time: Float) {
        guard let shape, shape.wind > 0,
              let mesh = try? MeshResource.generate(from: [shape.meshDescriptor(time: time)]) else { return }
        model?.mesh = mesh
    }
}
