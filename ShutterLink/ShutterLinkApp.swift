import SwiftUI
import LeeoKit

@main
struct ShutterLinkApp: App {
    @StateObject private var model = AppModel()

    init() {
        // 크래시 진단 업로드는 피드백 허브(iCloud.com.Ysoup.FeedbackHub) 권한이 있어야 한다.
        // 아직 그 컨테이너가 entitlements 에 없으므로 진단은 끈다 — 넣은 뒤 켤 것.
        LeeoKit.bootstrap(ShutterLinkSpec.self, diagnostics: false)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
    }
}
