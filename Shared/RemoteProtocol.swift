import CoreBluetooth
import Foundation

// MARK: - Configuration

enum RemoteConfig {
    /// Base URL encoded in the pairing QR code.
    /// Register this URL prefix as an Advanced App Clip Experience in App Store Connect,
    /// or as a Local Experience (Settings > Developer) while developing.
    static let invocationBaseURL = "https://m1zz.github.io/ShutterLink/r"
    static let codeQueryItem = "c"
    static let localNamePrefix = "SL-"
    static let codeLength = 4

    static func invocationURL(code: String) -> URL {
        var components = URLComponents(string: invocationBaseURL)!
        components.queryItems = [URLQueryItem(name: codeQueryItem, value: code)]
        return components.url!
    }

    static func code(from url: URL) -> String? {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let value = items.first(where: { $0.name == codeQueryItem })?.value,
              isValidCode(value) else { return nil }
        return value
    }

    static func isValidCode(_ code: String) -> Bool {
        code.count == codeLength && code.allSatisfy { $0.isASCII && $0.isNumber }
    }

    static func localName(for code: String) -> String {
        localNamePrefix + code
    }
}

enum RemoteUUID {
    static let service = CBUUID(string: "8C1F0000-6F2A-4F4B-9C4E-5B7A2D1E0A01")
    /// Remote -> camera. JSON-encoded `RemoteCommand`, write with response.
    static let command = CBUUID(string: "8C1F0001-6F2A-4F4B-9C4E-5B7A2D1E0A01")
    /// Camera -> remote. JSON-encoded `RemoteStatus`, read + notify.
    static let status = CBUUID(string: "8C1F0002-6F2A-4F4B-9C4E-5B7A2D1E0A01")
    /// Camera -> remote. Little-endian UInt16 L2CAP PSM for the preview stream (authorized remotes only).
    static let previewPSM = CBUUID(string: "8C1F0003-6F2A-4F4B-9C4E-5B7A2D1E0A01")
}

// MARK: - Models

enum CaptureMode: String, Codable, CaseIterable, Identifiable {
    case photo
    case video
    /// A designed banner floats in the scene (ARKit); shots are photos of the AR view.
    case banner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photo: return String(localized: "Photo")
        case .video: return String(localized: "Video")
        case .banner: return String(localized: "Banner")
        }
    }

    /// Flash, zoom, exposure, burst and the front camera only exist on the regular capture session.
    var usesCaptureSession: Bool { self != .banner }
}

enum CameraPosition: String, Codable {
    case back
    case front
}

enum FlashMode: String, Codable, CaseIterable {
    case off
    case auto
    case on

    var next: FlashMode {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

/// Hands-free triggers evaluated on the camera iPhone.
enum AutoCapture: String, Codable, CaseIterable, Identifiable {
    case off
    /// Raise an open palm toward the camera.
    case palm
    /// Fires when every face in the frame is smiling with eyes open.
    case smile
    /// Fires on a loud clap.
    case clap

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .off: return "hand.raised.slash"
        case .palm: return "hand.raised.fill"
        case .smile: return "face.smiling.inverse"
        case .clap: return "hands.clap.fill"
        }
    }

    var title: String {
        switch self {
        case .off: return String(localized: "Auto capture off")
        case .palm: return String(localized: "Palm gesture")
        case .smile: return String(localized: "Smile shutter")
        case .clap: return String(localized: "Clap shutter")
        }
    }

    var hint: String {
        switch self {
        case .off: return String(localized: "Shoot only with the shutter button.")
        case .palm: return String(localized: "Raise an open palm toward the camera to start the timer.")
        case .smile: return String(localized: "Shoots automatically when everyone is smiling with eyes open.")
        case .clap: return String(localized: "Clap loudly once to start the timer.")
        }
    }
}

enum TimerOptions {
    /// Long timers give a large group (or someone who walks slowly) time to get into place.
    static let all = [0, 3, 5, 10, 20, 30]
}

/// How many photos one shutter press takes.
/// `burstCount` photos one second apart, or — when `intervalSeconds > 0` — one photo every
/// `intervalSeconds` until the shutter is pressed again. The two are mutually exclusive.
enum DriveOptions {
    static let burstCounts = [1, 3, 5]
    static let intervals = [0, 3, 10, 30, 60]
    static let burstSpacing: TimeInterval = 1
}

enum ExposureOptions {
    static let range: ClosedRange<Double> = -2 ... 2
    static let step = 1.0 / 3
}

enum RemoteCommand: Codable, Equatable {
    case hello(code: String)
    case shutter
    case setMode(CaptureMode)
    case setTimer(seconds: Int)
    case setZoom(Double)
    case flipCamera
    case setFlash(FlashMode)
    case setExposure(Double)
    /// Focus and expose at a point in the upright preview image, normalized to 0...1.
    case focus(x: Double, y: Double)
    case setGrid(Bool)
    case setBurst(count: Int)
    case setInterval(seconds: Int)
    case setAutoCapture(AutoCapture)
    /// Plays a voice prompt on the camera iPhone so the group looks at the lens.
    case attention
}

/// Kept deliberately compact (short coding keys). If it ever outgrows a single BLE
/// notification, the camera notifies `StatusMarker.readFull` and the remote reads the full value.
struct RemoteStatus: Codable, Equatable {
    var mode: CaptureMode = .photo
    var isRecording = false
    var recordingSeconds = 0
    var timerSeconds = 0
    var countdown: Int?
    var zoom: Double = 1
    var minZoom: Double = 1
    var maxZoom: Double = 1
    var position: CameraPosition = .back
    /// Increments every time a photo/video is saved, so the remote can show feedback.
    var captureCount = 0
    var flash: FlashMode = .off
    /// False on cameras without a flash/torch (e.g. the front camera).
    var flashAvailable = false
    var exposureBias: Double = 0
    var showsGrid = false
    var burstCount = 1
    var intervalSeconds = 0
    var isIntervalRunning = false
    /// Seconds until the next interval shot while an interval run is active.
    var nextIntervalShot: Int?
    var autoCapture: AutoCapture = .off
    /// Faces currently detected in the frame.
    var faces = 0
    /// A face is touching the edge of the frame (someone may be cut off).
    var edgeWarning = false
    /// Deviation from level in whole degrees; nil when the phone is lying flat.
    var tilt: Int?

    /// Recording or running an interval — mode, camera and drive changes are locked.
    var isBusy: Bool { isRecording || isIntervalRunning }

    enum CodingKeys: String, CodingKey {
        case mode = "m"
        case isRecording = "r"
        case recordingSeconds = "s"
        case timerSeconds = "t"
        case countdown = "c"
        case zoom = "z"
        case minZoom = "zn"
        case maxZoom = "zx"
        case position = "p"
        case captureCount = "n"
        case flash = "f"
        case flashAvailable = "fa"
        case exposureBias = "e"
        case showsGrid = "g"
        case burstCount = "b"
        case intervalSeconds = "i"
        case isIntervalRunning = "ir"
        case nextIntervalShot = "nx"
        case autoCapture = "a"
        case faces = "fc"
        case edgeWarning = "ew"
        case tilt = "l"
    }
}

enum RemoteWire {
    static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Preview stream framing

/// Payload kinds on the preview channel. The first payload byte carries the kind.
enum StreamFrameKind: UInt8 {
    /// Low-resolution live view, dropped when the link is busy.
    case preview = 0
    /// Copy of a photo that was just saved, always delivered.
    case review = 1
}

/// Frames on the L2CAP preview channel: [UInt32 big-endian length][JPEG bytes].
struct FrameAssembler {
    static let maxFrameSize = 2_000_000

    private var buffer = Data()

    static func frame(_ payload: Data) -> Data {
        var length = UInt32(payload.count).bigEndian
        var data = withUnsafeBytes(of: &length) { Data($0) }
        data.append(payload)
        return data
    }

    static func frame(kind: StreamFrameKind, jpeg: Data) -> Data {
        var payload = Data([kind.rawValue])
        payload.append(jpeg)
        return frame(payload)
    }

    static func split(_ payload: Data) -> (StreamFrameKind, Data)? {
        guard let first = payload.first, let kind = StreamFrameKind(rawValue: first) else { return nil }
        return (kind, Data(payload.dropFirst()))
    }

    /// Appends received bytes and returns every complete frame.
    mutating func append(_ data: Data) -> [Data] {
        buffer.append(data)
        var frames: [Data] = []
        while buffer.count >= 4 {
            let start = buffer.startIndex
            let length = buffer[start ..< start + 4].reduce(0) { ($0 << 8) | Int($1) }
            guard length > 0, length <= Self.maxFrameSize else {
                buffer.removeAll()
                break
            }
            guard buffer.count >= 4 + length else { break }
            frames.append(Data(buffer[start + 4 ..< start + 4 + length]))
            buffer.removeSubrange(start ..< start + 4 + length)
        }
        return frames
    }
}

// MARK: - Helpers

extension Double {
    var rounded2: Double { (self * 100).rounded() / 100 }
}

enum StatusMarker {
    /// Sent instead of the status when it doesn't fit in one notification; the remote then reads it.
    static let readFull = Data([0x21])
}

enum Format {
    static func duration(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    static func interval(_ seconds: Int) -> String {
        seconds >= 60 && seconds % 60 == 0 ? String(localized: "\(seconds / 60)m") : String(localized: "\(seconds)s")
    }

    static func timer(_ seconds: Int) -> String {
        seconds == 0 ? String(localized: "Off") : String(localized: "\(seconds)s")
    }

    static func exposure(_ value: Double) -> String {
        let v = (value * 10).rounded() / 10
        if v == 0 { return "±0.0" }
        return String(format: "%+.1f", v)
    }

    static func zoom(_ value: Double) -> String {
        let v = value.rounded2
        if v.truncatingRemainder(dividingBy: 1) == 0 { return "\(Int(v))×" }
        return String(format: "%.1f×", v)
    }
}
