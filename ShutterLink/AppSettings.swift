import Foundation

/// User preferences for the camera iPhone, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var voiceCountdown: Bool { didSet { save(voiceCountdown, Keys.voiceCountdown) } }
    @Published var flashCountdown: Bool { didSet { save(flashCountdown, Keys.flashCountdown) } }
    @Published var showGrid: Bool { didSet { save(showGrid, Keys.showGrid) } }
    @Published var showLevel: Bool { didSet { save(showLevel, Keys.showLevel) } }
    @Published var showFaceCount: Bool { didSet { save(showFaceCount, Keys.showFaceCount) } }
    @Published var saveToPhotos: Bool { didSet { save(saveToPhotos, Keys.saveToPhotos) } }
    @Published var sendPhotosToRemote: Bool { didSet { save(sendPhotosToRemote, Keys.sendPhotosToRemote) } }
    @Published var hasSeenOnboarding: Bool { didSet { save(hasSeenOnboarding, Keys.hasSeenOnboarding) } }

    private let defaults: UserDefaults

    private enum Keys {
        static let voiceCountdown = "voiceCountdown"
        static let flashCountdown = "flashCountdown"
        static let showGrid = "showGrid"
        static let showLevel = "showLevel"
        static let showFaceCount = "showFaceCount"
        static let saveToPhotos = "saveToPhotos"
        static let sendPhotosToRemote = "sendPhotosToRemote"
        static let hasSeenOnboarding = "hasSeenOnboarding"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.voiceCountdown: true,
            Keys.flashCountdown: true,
            Keys.showGrid: false,
            Keys.showLevel: true,
            Keys.showFaceCount: true,
            Keys.saveToPhotos: true,
            Keys.sendPhotosToRemote: true,
            Keys.hasSeenOnboarding: false
        ])
        voiceCountdown = defaults.bool(forKey: Keys.voiceCountdown)
        flashCountdown = defaults.bool(forKey: Keys.flashCountdown)
        showGrid = defaults.bool(forKey: Keys.showGrid)
        showLevel = defaults.bool(forKey: Keys.showLevel)
        showFaceCount = defaults.bool(forKey: Keys.showFaceCount)
        saveToPhotos = defaults.bool(forKey: Keys.saveToPhotos)
        sendPhotosToRemote = defaults.bool(forKey: Keys.sendPhotosToRemote)
        hasSeenOnboarding = defaults.bool(forKey: Keys.hasSeenOnboarding)
    }

    private func save(_ value: Bool, _ key: String) {
        defaults.set(value, forKey: key)
    }
}
