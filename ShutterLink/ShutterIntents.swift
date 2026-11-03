//
//  ShutterIntents.swift
//  ShutterLink
//
//  "셔터링크로 찍어줘" — 폰을 세워 두고 말로 셔터를 누른다. 앱의 셔터 단추와 같다(타이머 설정을 따른다).
//  카메라가 막 켜지는 중이면 준비될 때까지 잠깐 기다렸다가 누른다.
//

import AppIntents
import Foundation

struct TakeShotIntent: AppIntent {
    static let title = LocalizedStringResource("Take a Shot", comment: "Siri: press the shutter")
    static let description = IntentDescription(
        LocalizedStringResource("Presses the shutter, using your timer setting.", comment: "Siri: take shot description")
    )
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let camera = AppModel.shared.camera
        // 앱이 막 열렸다면 세션이 돌기 시작할 때까지 최대 3초 기다린다.
        for _ in 0..<30 where !camera.session.isRunning {
            try? await Task.sleep(for: .milliseconds(100))
        }
        camera.handle(.shutter)
        return .result()
    }
}

struct ShutterLinkShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TakeShotIntent(),
            phrases: ["Take a photo with \(.applicationName)", "\(.applicationName) shoot"],
            shortTitle: "Take a Shot",
            systemImageName: "camera.shutter.button"
        )
    }
}
