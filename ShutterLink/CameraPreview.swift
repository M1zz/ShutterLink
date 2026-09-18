import AVFoundation
import AVKit
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let camera: CameraController

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = camera.session
        view.previewLayer.videoGravity = .resizeAspect
        camera.attachPreviewLayer(view.previewLayer)

        // Volume buttons, Camera Control and AirPods stem presses trigger the shutter.
        if #available(iOS 17.2, *) {
            let camera = self.camera
            let interaction = AVCaptureEventInteraction { [weak camera] event in
                if event.phase == .ended {
                    camera?.shutter()
                }
            }
            view.addInteraction(interaction)
        }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // swiftlint:disable:next force_cast
        layer as! AVCaptureVideoPreviewLayer
    }
}
