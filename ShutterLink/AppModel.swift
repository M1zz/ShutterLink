import Combine
import Foundation

/// Wires the camera to the BLE remote server and the Apple Watch remote.
final class AppModel: ObservableObject {
    /// 앱 화면과 Siri 인텐트가 같은 카메라를 쓴다 (→ ShutterIntents.swift).
    @MainActor static let shared = AppModel()

    let camera = CameraController()
    let remote: RemotePeripheral
    let watch = WatchRelay()
    let sessionCode: String

    private var cancellables = Set<AnyCancellable>()

    var invocationURL: URL { RemoteConfig.invocationURL(code: sessionCode) }

    init() {
        let code = String(format: "%04d", Int.random(in: 0 ... 9999))
        sessionCode = code
        remote = RemotePeripheral(sessionCode: code)

        remote.onCommand = { [weak self] command in
            self?.camera.handle(command)
        }

        watch.onCommand = { [weak self] command in
            self?.camera.handle(command)
        }
        watch.currentStatus = { [weak camera = self.camera] in camera?.status ?? RemoteStatus() }

        camera.onPreviewFrame = { [weak remote = self.remote, weak watch = self.watch] jpeg in
            DispatchQueue.main.async {
                remote?.sendPreviewFrame(jpeg)
                watch?.sendFrame(jpeg)
            }
        }

        camera.onReviewFrame = { [weak remote = self.remote] jpeg in
            remote?.sendReviewFrame(jpeg)
        }

        remote.$hasPreviewViewers
            .combineLatest(watch.$isWatching)
            .sink { [weak camera = self.camera] phone, wrist in camera?.previewDemand = phone || wrist }
            .store(in: &cancellables)

        // objectWillChange fires before the change lands, so debounce onto the next run loop pass.
        camera.objectWillChange
            .debounce(for: .milliseconds(40), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.pushStatus() }
            .store(in: &cancellables)

        // 워치는 앱이 뒤에 있어도 메시지로 앱을 깨운다 — 화면이 뜨기 전부터 받을 수 있게 바로 연다.
        watch.activate()
    }

    func start() {
        camera.start()
        remote.start()
        pushStatus()
    }

    private func pushStatus() {
        remote.updateStatus(camera.status)
        watch.sendStatus(camera.status)
    }
}
