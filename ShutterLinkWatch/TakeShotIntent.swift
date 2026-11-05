//
//  TakeShotIntent.swift
//  동작 버튼 · Siri · 단축어로 셔터 — 손목을 보지 않고 iPhone 이 찍는다(iPhone 의 타이머 설정을 따른다).
//  (Apple Watch Ultra: 설정 ▸ 동작 버튼 ▸ 단축어 ▸ ShutterLink 찍기)
//  워치 앱이 열리며 미리보기도 함께 뜬다. iPhone 쪽 같은 이름의 인텐트와 문구를 같이 쓴다.
//

import AppIntents

struct TakeShotIntent: AppIntent {
    static let title = LocalizedStringResource("Take a Shot", comment: "Siri: press the shutter")
    static let description = IntentDescription(
        LocalizedStringResource("Presses the shutter, using your timer setting.", comment: "Siri: take shot description")
    )
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let link = WatchLink.shared
        link.activate()
        // 막 열렸다면 iPhone 과 닿을 때까지 최대 3초 기다린다.
        for _ in 0..<30 where !link.isReachable {
            try? await Task.sleep(for: .milliseconds(100))
        }
        link.send(.shutter)
        return .result()
    }
}

struct ShutterLinkWatchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TakeShotIntent(),
            phrases: ["Take a photo with \(.applicationName)", "\(.applicationName) shoot"],
            shortTitle: "Take a Shot",
            systemImageName: "camera.shutter.button"
        )
    }
}
