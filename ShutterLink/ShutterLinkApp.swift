import SwiftUI
import LeeoKit

@main
struct ShutterLinkApp: App {
    @StateObject private var model = AppModel.shared

    init() {
        // 익명 사용 통계·크래시 진단을 피드백 허브(iCloud.com.Ysoup.FeedbackHub)로 올린다.
        // 그 컨테이너 권한은 Config/ShutterLink.entitlements 에 있다 — 없으면 CKContainer 에서 죽는다.
        LeeoKit.bootstrap(ShutterLinkSpec.self)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // 개발자가 보낸 의견에 답장하면, 앱이 앞으로 올 때 답장을 시트로 보여 준다 (LeeoKit).
                .leeoFeedbackReplyNotice(ShutterLinkSpec.self)
                .environmentObject(model)
                // 팁 상품을 불러오고 끝나지 않은 팁을 마저 센다.
                .task { await ShutterLinkSpec.tipJar.startStandalone() }
                // 창 크기로 접힘을 재서 아래로 흘린다. 시트 · 알림창도 접힌 선을 비킨다 (LeeoKit Fold).
                .foldAware()
        }
    }
}
