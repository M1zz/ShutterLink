import CoreMotion
import Foundation

/// Reports how far the phone is rolled away from the nearest upright/landscape orientation,
/// so it can be leveled on a tripod. Lying flat reports nil.
final class LevelMonitor {
    var onChange: ((Int?) -> Void)?

    private let motion = CMMotionManager()
    private var last: Int?? = .none

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
}
