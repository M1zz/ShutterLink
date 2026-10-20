#if DEBUG
import Combine
import RealityKit
import SwiftUI

/// Screenshot mode `-screenshots cloth`: the banner entity rendered without AR (works in the simulator),
/// to check the cloth shape and material.
struct BannerClothPreview: UIViewRepresentable {
    let design: BannerDesign

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(UIColor(red: 0.55, green: 0.70, blue: 0.85, alpha: 1))
        guard let texture = try? BannerRenderer.renderTexture(design),
              let banner = try? BannerEntity(design: design, texture: texture) else { return view }
        let anchor = AnchorEntity(world: .zero)
        banner.orientation = simd_quatf(angle: -0.35, axis: [0, 1, 0])
        anchor.addChild(banner)

        let sun = DirectionalLight()
        sun.light.intensity = 2500
        sun.look(at: .zero, from: [3.5, 1.8, 1.4], relativeTo: nil)
        anchor.addChild(sun)

        let camera = PerspectiveCamera()
        camera.look(at: [0, -0.05, 0], from: [0.6, 0.35, ProcessInfo.processInfo.arguments.contains("-closeUp") ? 1.6 : 6.5], relativeTo: nil)
        anchor.addChild(camera)
        view.scene.addAnchor(anchor)

        context.coordinator.updates = view.scene.subscribe(to: SceneEvents.Update.self) { event in
            context.coordinator.time += Float(event.deltaTime)
            banner.flutter(at: context.coordinator.time)
        }
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var updates: Cancellable?
        var time: Float = 0
    }
}
#endif
