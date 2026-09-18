import SwiftUI

@main
struct ShutterLinkClipApp: App {
    @StateObject private var remote = RemoteCentral()

    var body: some Scene {
        WindowGroup {
            RemoteView(remote: remote)
                // App Clip invocation (QR code, App Clip Code, Local Experience, _XCAppClipURL).
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    handle(url)
                }
                .onOpenURL(perform: handle)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
    }

    private func handle(_ url: URL) {
        guard let code = RemoteConfig.code(from: url) else { return }
        remote.connect(code: code)
    }
}
