import CoreBluetooth
import Foundation

/// Camera side: pushes length-prefixed JPEG frames over an L2CAP channel.
/// Holds at most one frame in flight; new frames are dropped while busy (latest-wins).
final class PreviewStreamSender: NSObject, StreamDelegate {
    private let channel: CBL2CAPChannel
    private let onClose: () -> Void
    private var pending = Data()
    private(set) var isClosed = false

    var peerIdentifier: UUID { channel.peer.identifier }
    var isIdle: Bool { pending.isEmpty && !isClosed }

    init(channel: CBL2CAPChannel, onClose: @escaping () -> Void) {
        self.channel = channel
        self.onClose = onClose
        super.init()
        for stream in [channel.inputStream! as Stream, channel.outputStream! as Stream] {
            stream.delegate = self
            stream.schedule(in: .main, forMode: .default)
            stream.open()
        }
    }

    func send(_ framedData: Data) {
        guard isIdle else { return }
        pending = framedData
        flush()
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        pending.removeAll()
        for stream in [channel.inputStream! as Stream, channel.outputStream! as Stream] {
            stream.delegate = nil
            stream.remove(from: .main, forMode: .default)
            stream.close()
        }
        let onClose = onClose
        DispatchQueue.main.async { onClose() }
    }

    private func flush() {
        guard let output = channel.outputStream else { return }
        while !pending.isEmpty, output.hasSpaceAvailable {
            let written = pending.withUnsafeBytes { raw -> Int in
                guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return output.write(base, maxLength: raw.count)
            }
            if written < 0 {
                close()
                return
            }
            if written == 0 { return }
            pending = Data(pending.dropFirst(written))
        }
    }

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasSpaceAvailable:
            flush()
        case .hasBytesAvailable:
            // The remote never sends data on this channel; drain defensively.
            if let input = aStream as? InputStream {
                var scratch = [UInt8](repeating: 0, count: 512)
                while input.hasBytesAvailable, input.read(&scratch, maxLength: scratch.count) > 0 {}
            }
        case .errorOccurred, .endEncountered:
            close()
        default:
            break
        }
    }
}

/// Remote side: reassembles frames from the L2CAP channel and delivers the newest one.
final class PreviewStreamReceiver: NSObject, StreamDelegate {
    private let channel: CBL2CAPChannel
    private let onFrame: (Data) -> Void
    private let onClose: () -> Void
    private var assembler = FrameAssembler()
    private var isClosed = false

    init(channel: CBL2CAPChannel, onFrame: @escaping (Data) -> Void, onClose: @escaping () -> Void) {
        self.channel = channel
        self.onFrame = onFrame
        self.onClose = onClose
        super.init()
        for stream in [channel.inputStream! as Stream, channel.outputStream! as Stream] {
            stream.delegate = self
            stream.schedule(in: .main, forMode: .default)
            stream.open()
        }
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        for stream in [channel.inputStream! as Stream, channel.outputStream! as Stream] {
            stream.delegate = nil
            stream.remove(from: .main, forMode: .default)
            stream.close()
        }
        let onClose = onClose
        DispatchQueue.main.async { onClose() }
    }

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
            readAvailable()
        case .errorOccurred, .endEncountered:
            close()
        default:
            break
        }
    }

    private func readAvailable() {
        guard let input = channel.inputStream else { return }
        var buffer = [UInt8](repeating: 0, count: 16_384)
        var latest: Data?
        while input.hasBytesAvailable {
            let count = input.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            if let frame = assembler.append(Data(buffer[0 ..< count])).last {
                latest = frame
            }
        }
        if let latest { onFrame(latest) }
    }
}
