import CoreImage
import QuartzCore
import ImageIO
import Vision

/// Looks at live frames (a few per second) to count people, warn when someone is cut off at the edge,
/// and detect the hands-free triggers: an open palm or everyone smiling.
final class SceneAnalyzer {
    struct Result {
        var faces = 0
        var edgeWarning = false
        var palmRaised = false
        var everyoneSmiling = false
    }

    /// Delivered on the main thread.
    var onResult: ((Result) -> Void)?

    private let queue = DispatchQueue(label: "shutterlink.analysis", qos: .userInitiated)
    private let lock = NSLock()
    private var isBusy = false
    private var lastSubmit: CFTimeInterval = 0

    private static let interval: CFTimeInterval = 0.2
    /// Faces whose box comes this close to the frame edge (normalized) trigger the warning.
    private static let edgeMargin: CGFloat = 0.015

    private lazy var smileDetector = CIDetector(ofType: CIDetectorTypeFace,
                                                context: nil,
                                                options: [CIDetectorAccuracy: CIDetectorAccuracyLow,
                                                          CIDetectorTracking: true])

    /// Call from the capture data queue. Frames are dropped while the previous one is being analyzed.
    func submit(_ pixelBuffer: CVPixelBuffer, detectPalm: Bool, detectSmiles: Bool) {
        let now = CACurrentMediaTime()
        let accepted = lock.withLock { () -> Bool in
            guard !isBusy, now - lastSubmit >= Self.interval else { return false }
            isBusy = true
            lastSubmit = now
            return true
        }
        guard accepted else { return }

        queue.async {
            let result = self.analyze(pixelBuffer, detectPalm: detectPalm, detectSmiles: detectSmiles)
            self.lock.withLock { self.isBusy = false }
            DispatchQueue.main.async { self.onResult?(result) }
        }
    }

    private func analyze(_ pixelBuffer: CVPixelBuffer, detectPalm: Bool, detectSmiles: Bool) -> Result {
        var result = Result()
        let faceRequest = VNDetectFaceRectanglesRequest()
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 4

        var requests: [VNRequest] = [faceRequest]
        if detectPalm { requests.append(handRequest) }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform(requests)

        let faces = faceRequest.results ?? []
        result.faces = faces.count
        result.edgeWarning = faces.contains { face in
            let box = face.boundingBox
            return box.minX < Self.edgeMargin || box.minY < Self.edgeMargin
                || box.maxX > 1 - Self.edgeMargin || box.maxY > 1 - Self.edgeMargin
        }

        if detectPalm {
            result.palmRaised = (handRequest.results ?? []).contains(where: Self.isOpenPalm)
        }

        if detectSmiles, !faces.isEmpty {
            let image = CIImage(cvPixelBuffer: pixelBuffer)
            let features = smileDetector?.features(in: image, options: [CIDetectorSmile: true,
                                                                        CIDetectorEyeBlink: true])
                .compactMap { $0 as? CIFaceFeature } ?? []
            result.everyoneSmiling = !features.isEmpty
                && features.count >= faces.count
                && features.allSatisfy { $0.hasSmile && !$0.leftEyeClosed && !$0.rightEyeClosed }
        }
        return result
    }

    /// All four fingers extended well beyond their knuckles, measured from the wrist.
    private static func isOpenPalm(_ hand: VNHumanHandPoseObservation) -> Bool {
        guard let points = try? hand.recognizedPoints(.all),
              let wrist = points[.wrist], wrist.confidence > 0.3 else { return false }
        let fingers: [(VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName)] = [
            (.indexTip, .indexMCP), (.middleTip, .middleMCP), (.ringTip, .ringMCP), (.littleTip, .littleMCP)
        ]
        var extended = 0
        for (tipName, knuckleName) in fingers {
            guard let tip = points[tipName], let knuckle = points[knuckleName],
                  tip.confidence > 0.3, knuckle.confidence > 0.3 else { continue }
            if distance(tip.location, wrist.location) > 1.6 * distance(knuckle.location, wrist.location) {
                extended += 1
            }
        }
        return extended == fingers.count
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    // MARK: Best shot

    /// Scores a photo for a group shot: open eyes matter most, smiles next. Higher is better.
    static func score(photoData: Data) -> Double {
        guard let source = CGImageSourceCreateWithData(photoData as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 1600
              ] as CFDictionary) else { return 0 }
        let detector = CIDetector(ofType: CIDetectorTypeFace, context: nil,
                                  options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: CIImage(cgImage: cgImage),
                                          options: [CIDetectorSmile: true, CIDetectorEyeBlink: true])
            .compactMap { $0 as? CIFaceFeature } ?? []
        guard !features.isEmpty else { return 0 }
        var score = Double(features.count)
        for face in features {
            if !face.leftEyeClosed { score += 2 }
            if !face.rightEyeClosed { score += 2 }
            if face.hasSmile { score += 1.5 }
        }
        return score
    }
}
