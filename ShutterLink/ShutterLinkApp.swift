import SwiftUI
import LeeoKit

@main
struct ShutterLinkApp: App {
    @StateObject private var model = AppModel()

    init() {
        // 익명 사용 통계·크래시 진단을 피드백 허브(iCloud.com.Ysoup.FeedbackHub)로 올린다.
        // 그 컨테이너 권한은 Config/ShutterLink.entitlements 에 있다 — 없으면 CKContainer 에서 죽는다.
        LeeoKit.bootstrap(ShutterLinkSpec.self)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
    }
}
