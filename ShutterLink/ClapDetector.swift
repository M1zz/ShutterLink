import AVFoundation
import QuartzCore

/// Detects a sharp, loud sound (a clap) in microphone sample buffers. Use from the capture data queue.
final class ClapDetector {
    /// Called on the data queue.
    var onClap: (() -> Void)?

    private var ambient: Float = 0.02
    private var lastClap: CFTimeInterval = 0

    private static let minimumPeak: Float = 0.45
    private static let peakToAmbient: Float = 6
    private static let cooldown: CFTimeInterval = 3

    func process(_ sampleBuffer: CMSampleBuffer) {
        guard let (peak, rms) = Self.levels(of: sampleBuffer) else { return }
        let now = CACurrentMediaTime()
        if peak > Self.minimumPeak, peak > ambient * Self.peakToAmbient, now - lastClap > Self.cooldown {
            lastClap = now
            onClap?()
        }
        // Slow-moving background level, so steady noise (music, talking) doesn't trigger.
        ambient = ambient * 0.95 + rms * 0.05
    }

    private static func levels(of sampleBuffer: CMSampleBuffer) -> (peak: Float, rms: Float)? {
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee,
              asbd.mFormatID == kAudioFormatLinearPCM else { return nil }

        var blockBuffer: CMBlockBuffer?
        var bufferList = AudioBufferList()
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &bufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer)
        guard status == noErr, let data = bufferList.mBuffers.mData else { return nil }

        let byteCount = Int(bufferList.mBuffers.mDataByteSize)
        let isFloat = asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0
        var peak: Float = 0
        var sumSquares: Float = 0
        var count = 0

        if isFloat, asbd.mBitsPerChannel == 32 {
            let samples = data.bindMemory(to: Float.self, capacity: byteCount / 4)
            count = byteCount / 4
            for i in 0 ..< count {
                let v = abs(samples[i])
                peak = max(peak, v)
                sumSquares += v * v
            }
        } else if asbd.mBitsPerChannel == 16 {
            let samples = data.bindMemory(to: Int16.self, capacity: byteCount / 2)
            count = byteCount / 2
            for i in 0 ..< count {
                let v = abs(Float(samples[i]) / Float(Int16.max))
                peak = max(peak, v)
                sumSquares += v * v
            }
        }
        guard count > 0 else { return nil }
        return (peak, (sumSquares / Float(count)).squareRoot())
    }
}
