import AVFoundation

/// Speaks countdowns and prompts out loud so a group standing away from the phone knows when the shot happens.
final class VoicePrompter {
    private let synthesizer = AVSpeechSynthesizer()

    private var voice: AVSpeechSynthesisVoice? {
        let language = Bundle.main.preferredLocalizations.first ?? "en"
        return AVSpeechSynthesisVoice(language: language == "ko" ? "ko-KR" : "en-US")
    }

    func speakCount(_ number: Int) {
        speak("\(number)", rate: 0.55)
    }

    func speakAttention() {
        speak(String(localized: "Everyone, please look at the camera!"), rate: 0.5)
    }

    func speakStarting(seconds: Int) {
        speak(String(localized: "Taking a photo in \(seconds) seconds."), rate: 0.5)
    }

    private func speak(_ text: String, rate: Float) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = rate
        utterance.volume = 1
        synthesizer.speak(utterance)
    }
}
