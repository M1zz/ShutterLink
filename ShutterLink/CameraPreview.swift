import AVFoundation
import AVKit
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let camera: CameraController
    var showsGrid = false

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = camera.session
        view.previewLayer.videoGravity = .resizeAspect
        camera.attachPreviewLayer(view.previewLayer)
        camera.onPreviewGeometryChange = { [weak view] in view?.setNeedsLayout() }

        // Tap to focus and expose at a point.
        let camera = self.camera
        view.onTap = { [weak camera] point in camera?.focus(atLayerPoint: point) }

        // Volume buttons, Camera Control and AirPods stem presses trigger the shutter.
        if #available(iOS 17.2, *) {
            let interaction = AVCaptureEventInteraction { [weak camera] event in
                if event.phase == .ended {
                    camera?.shutter()
                }
            }
            view.addInteraction(interaction)
        }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.showsGrid = showsGrid
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // swiftlint:disable:next force_cast
        layer as! AVCaptureVideoPreviewLayer
    }

    var onTap: ((CGPoint) -> Void)?

    var showsGrid = false {
        didSet {
            guard showsGrid != oldValue else { return }
            gridLayer.isHidden = !showsGrid
            setNeedsLayout()
        }
    }

    private let gridLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor.white.withAlphaComponent(0.45).cgColor
        layer.lineWidth = 1 / UIScreen.main.scale * 2
        layer.fillColor = nil
        layer.isHidden = true
        return layer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(gridLayer)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard showsGrid else { return }
        // The grid follows the visible video area, which changes with the rotation angle.
        let videoRect = previewLayer.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))
        gridLayer.frame = bounds
        gridLayer.path = GridLines().path(in: videoRect).cgPath
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        onTap?(recognizer.location(in: self))
    }
}
