import SwiftUI
import WatchConnectivity

/// 워치 쪽 연결 — 카메라 iPhone 의 상태와 미리보기를 받고, 명령을 보낸다 (→ ShutterLink/WatchRelay.swift).
/// 미리보기는 화면에 떠 있을 때만 달라고 한다(`setWatching`). 프레임마다 답을 돌려줘 다음 장을 부른다.
@MainActor
final class WatchLink: NSObject, ObservableObject {
    static let shared = WatchLink()

    @Published private(set) var frame: UIImage?
    @Published private(set) var frameDate: Date?
    @Published private(set) var status: RemoteStatus?

    private var wantsPreview = false

    func activate() {
        guard WCSession.isSupported(), WCSession.default.activationState != .activated else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    var isReachable: Bool { WCSession.default.activationState == .activated && WCSession.default.isReachable }

    /// 화면에 떠 있는 동안만 미리보기를 받는다.
    func setWatching(_ on: Bool) {
        wantsPreview = on
        if !on { frameDate = nil }
        sendWatching()
    }

    func send(_ command: RemoteCommand) {
        guard isReachable, let data = RemoteWire.encode(command) else { return }
        WCSession.default.sendMessage([WatchKey.command: data], replyHandler: { reply in
            Task { @MainActor in self.apply(reply) }
        }, errorHandler: nil)
    }

    private func sendWatching() {
        guard isReachable else { return }
        WCSession.default.sendMessage([WatchKey.watching: wantsPreview], replyHandler: { reply in
            Task { @MainActor in self.apply(reply) }
        }, errorHandler: nil)
    }

    private func apply(_ message: [String: Any]) {
        if let data = message[WatchKey.status] as? Data,
           let status = RemoteWire.decode(RemoteStatus.self, from: data) {
            self.status = status
        }
    }

    private func receive(_ jpeg: Data) {
        guard wantsPreview, let image = UIImage(data: jpeg) else { return }
        frame = image
        frameDate = .now
    }

    #if DEBUG
    /// 스크린샷용 (`-watchDemo`): 카메라 없이 상태만 채운다.
    func applyDemo(_ status: RemoteStatus) {
        self.status = status
        frameDate = .distantFuture
    }
    #endif
}

extension WatchLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in self.sendWatching() }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            // 다시 닿으면 미리보기를 다시 청한다. 끊기면 마지막 장면은 흐리게 둔다.
            if session.isReachable { self.sendWatching() } else { self.frameDate = nil }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.apply(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data,
                             replyHandler: @escaping (Data) -> Void) {
        replyHandler(Data())
        Task { @MainActor in self.receive(messageData) }
    }
}
