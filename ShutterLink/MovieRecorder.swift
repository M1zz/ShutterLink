import AVFoundation

/// Writes video + audio sample buffers to a .mov file. Use from a single serial queue.
final class MovieRecorder {
    let url: URL

    private let writer: AVAssetWriter
    private let audioSettings: [String: Any]?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var isStarted = false
    private var startFailed = false
    private var isFinishing = false

    init(url: URL, audioSettings: [String: Any]?) throws {
        self.url = url
        self.audioSettings = audioSettings
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    }

    func appendVideo(_ sampleBuffer: CMSampleBuffer) {
        guard !isFinishing, !startFailed else { return }
        if !isStarted { start(with: sampleBuffer) }
        guard isStarted, let input = videoInput, input.isReadyForMoreMediaData else { return }
        input.append(sampleBuffer)
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        guard isStarted, !isFinishing, let input = audioInput, input.isReadyForMoreMediaData else { return }
        input.append(sampleBuffer)
    }

    func finish(_ completion: @escaping (URL?) -> Void) {
        isFinishing = true
        guard isStarted, writer.status == .writing else {
            try? FileManager.default.removeItem(at: url)
            completion(nil)
            return
        }
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        let writer = self.writer
        let url = self.url
        writer.finishWriting {
            completion(writer.status == .completed ? url : nil)
        }
    }

    /// The writer starts on the first video frame so its dimensions match the (rotated) buffers.
    private func start(with sampleBuffer: CMSampleBuffer) {
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        let dimensions = CMVideoFormatDescriptionGetDimensions(format)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: Int(dimensions.width),
            AVVideoHeightKey: Int(dimensions.height)
        ]
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        video.expectsMediaDataInRealTime = true
        guard writer.canAdd(video) else {
            startFailed = true
            return
        }
        writer.add(video)
        videoInput = video

        if let audioSettings {
            let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audio.expectsMediaDataInRealTime = true
            if writer.canAdd(audio) {
                writer.add(audio)
                audioInput = audio
            }
        }

        guard writer.startWriting() else {
            startFailed = true
            print("AVAssetWriter failed to start: \(String(describing: writer.error))")
            return
        }
        writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        isStarted = true
    }
}
