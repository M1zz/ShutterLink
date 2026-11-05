import Combine
import Foundation
import WatchConnectivity

/// Apple Watch 리모컨 중계 — 워치가 보낸 명령은 카메라로, 카메라 상태와 미리보기는 워치로.
///
/// 블루투스 리모컨(`RemotePeripheral`)과 같은 `RemoteCommand` · `RemoteStatus` 를 쓴다.
/// 미리보기는 워치 앱이 화면에 떠 있을 때만(`isWatching`) 보내고, 한 장이 도착했다는 답을 받아야
/// 다음 장을 보낸다 — 손목이 따라가는 만큼만, 늘 가장 최근 장면으로.
final class WatchRelay: NSObject, ObservableObject, WCSessionDelegate {
    /// 워치 리모컨이 화면에 떠 있다. 카메라는 이때 미리보기 프레임을 만든다.
    @Published private(set) var isWatching = false

    /// Called on main with each command from the watch.
    var onCommand: ((RemoteCommand) -> Void)?
    /// The camera's status right now, sent back when the watch opens.
    var currentStatus: (() -> RemoteStatus)?

    private var frameInFlight = false
    private var lastSentStatus: RemoteStatus?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Call on main. Drops the frame while the previous one is still on its way.
    func sendFrame(_ jpeg: Data) {
        guard isWatching, !frameInFlight, WCSession.default.isReachable else { return }
        frameInFlight = true
        let done: () -> Void = { DispatchQueue.main.async { self.frameInFlight = false } }
        WCSession.default.sendMessageData(jpeg, replyHandler: { _ in done() }, errorHandler: { _ in done() })
    }

    /// Call on main.
    func sendStatus(_ status: RemoteStatus) {
        guard isWatching, status != lastSentStatus, WCSession.default.isReachable,
              let data = RemoteWire.encode(status) else { return }
        lastSentStatus = status
        WCSession.default.sendMessage([WatchKey.status: data], replyHandler: nil, errorHandler: nil)
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            if let watching = message[WatchKey.watching] as? Bool {
                self.isWatching = watching
                self.frameInFlight = false
                self.lastSentStatus = nil
            }
            if let data = message[WatchKey.command] as? Data,
               let command = RemoteWire.decode(RemoteCommand.self, from: data) {
                self.onCommand?(command)
            }
            var reply: [String: Any] = [:]
            if let status = self.currentStatus?(), let data = RemoteWire.encode(status) {
                reply[WatchKey.status] = data
                self.lastSentStatus = status
            }
            replyHandler(reply)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        DispatchQueue.main.async {
            if !reachable { self.isWatching = false }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
