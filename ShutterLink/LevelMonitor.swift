import CoreMotion
import SwiftUI
import UIKit

/// Which way the phone is held. The screen stays portrait like the system Camera, so this comes from gravity,
/// not the interface — it works with Portrait Orientation Lock on, too.
enum DeviceTurn: Equatable {
    case portrait
    /// Turned a quarter counterclockwise: the right edge is up.
    case landscapeLeft
    /// Turned a quarter clockwise: the left edge is up.
    case landscapeRight
    case upsideDown

    var isSideways: Bool { self == .landscapeLeft || self == .landscapeRight }

    /// How far to turn on-screen icons and text so they stay upright.
    var angle: Angle {
        switch self {
        case .portrait: return .zero
        case .landscapeLeft: return .degrees(90)
        case .landscapeRight: return .degrees(-90)
        case .upsideDown: return .degrees(180)
        }
    }

    /// Orientation of an ARKit camera image, which arrives in the sensor's landscape layout.
    var arFrameOrientation: CGImagePropertyOrientation {
        switch self {
        case .portrait: return .right
        case .landscapeLeft: return .up
        case .landscapeRight: return .down
        case .upsideDown: return .left
        }
    }

    /// Centre of this orientation in `LevelMonitor`'s roll angle.
    fileprivate var roll: Double {
        switch self {
        case .portrait: return 0
        case .landscapeLeft: return -90
        case .landscapeRight: return 90
        case .upsideDown: return 180
        }
    }
}

extension UIImage {
    /// The image turned so the scene is upright for a phone held `turn` — screenshots of a portrait screen
    /// come out sideways when the phone is on its side.
    func upright(for turn: DeviceTurn) -> UIImage {
        guard turn != .portrait else { return self }
        let size = turn.isSideways ? CGSize(width: self.size.height, height: self.size.width) : self.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            switch turn {
            case .landscapeLeft:
                cg.translateBy(x: 0, y: size.height)
                cg.rotate(by: -.pi / 2)
            case .landscapeRight:
                cg.translateBy(x: size.width, y: 0)
                cg.rotate(by: .pi / 2)
            case .upsideDown:
                cg.translateBy(x: size.width, y: size.height)
                cg.rotate(by: .pi)
            case .portrait:
                break
            }
            draw(in: CGRect(origin: .zero, size: self.size))
        }
    }
}

/// Reports how far the phone is rolled away from the nearest upright/landscape orientation,
/// so it can be leveled on a tripod, and which way it is held. Lying flat reports nil and keeps the last turn.
final class LevelMonitor {
    var onChange: ((Int?) -> Void)?
    var onTurn: ((DeviceTurn) -> Void)?

    private let motion = CMMotionManager()
    private var last: Int?? = .none
    private var turn = DeviceTurn.portrait

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 10
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let gravity = data?.gravity else { return }
            let value = Self.tilt(x: gravity.x, y: gravity.y, z: gravity.z)
            if self.last != .some(value) {
                self.last = .some(value)
                self.onChange?(value)
            }
            if let next = Self.turn(x: gravity.x, y: gravity.y, z: gravity.z, current: self.turn), next != self.turn {
                self.turn = next
                self.onTurn?(next)
            }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }

    static func tilt(x: Double, y: Double, z: Double) -> Int? {
        guard abs(z) < 0.85 else { return nil }
        let angle = atan2(x, -y) * 180 / .pi
        let snapped = (angle / 90).rounded() * 90
        return Int((angle - snapped).rounded())
    }

    /// Switches only once the phone is well past the halfway point, so a tripod near 45° doesn't flicker.
    static func turn(x: Double, y: Double, z: Double, current: DeviceTurn) -> DeviceTurn? {
        guard abs(z) < 0.85 else { return nil }
        let angle = atan2(x, -y) * 180 / .pi
        let candidates: [DeviceTurn] = [.portrait, .landscapeLeft, .landscapeRight, .upsideDown]
        return candidates.first { candidate in
            var difference = abs(angle - candidate.roll).truncatingRemainder(dividingBy: 360)
            if difference > 180 { difference = 360 - difference }
            return difference < (candidate == current ? 45 : 30)
        } ?? current
    }
}
