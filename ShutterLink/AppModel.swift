import Combine
import Foundation

/// Wires the camera to the BLE remote server.
final class AppModel: ObservableObject {
    let camera = CameraController()
    let remote: RemotePeripheral
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

        camera.onPreviewFrame = { [weak remote = self.remote] jpeg in
            DispatchQueue.main.async { remote?.sendPreviewFrame(jpeg) }
        }

        remote.$hasPreviewViewers
            .sink { [weak camera = self.camera] hasViewers in camera?.previewDemand = hasViewers }
            .store(in: &cancellables)

        // objectWillChange fires before the change lands, so debounce onto the next run loop pass.
        camera.objectWillChange
            .debounce(for: .milliseconds(40), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.pushStatus() }
            .store(in: &cancellables)
    }

    func start() {
        camera.start()
        remote.start()
        pushStatus()
    }

    private func pushStatus() {
        remote.updateStatus(camera.status)
    }
}
