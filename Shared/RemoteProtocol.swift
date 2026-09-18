import CoreBluetooth
import Foundation

// MARK: - Configuration

enum RemoteConfig {
    /// Base URL encoded in the pairing QR code.
    /// Register this URL prefix as an Advanced App Clip Experience in App Store Connect,
    /// or as a Local Experience (Settings > Developer) while developing.
    static let invocationBaseURL = "https://shutterlink.example.com/r"
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

    var id: String { rawValue }
    var title: String { self == .photo ? "Photo" : "Video" }
}

enum CameraPosition: String, Codable {
    case back
    case front
}

enum RemoteCommand: Codable, Equatable {
    case hello(code: String)
    case shutter
    case setMode(CaptureMode)
    case setTimer(seconds: Int)
    case setZoom(Double)
    case flipCamera
}

/// Kept deliberately compact (short coding keys) so it fits in a single BLE notification.
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

enum Format {
    static func duration(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    static func zoom(_ value: Double) -> String {
        let v = value.rounded2
        if v.truncatingRemainder(dividingBy: 1) == 0 { return "\(Int(v))×" }
        return String(format: "%.1f×", v)
    }
}
