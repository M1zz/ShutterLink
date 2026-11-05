//
//  ShutterLinkRoadmap.swift
//  ShutterLink
//
//  **앞으로 만들 것**의 원본. 설정 ▸ 앞으로 만들 기능(`LeeoRoadmapView`)이 이 목록을 그대로 보여 준다.
//
//  ⚠️ 개발하다 "이건 다음에" 가 생기면 **여기에 한 줄을 더한다.** 코드의 TODO 주석으로만 남기지 않는다.
//     - 새 항목: `.planned`. 손대기 시작하면 `.building`. 내보내면 `.shipped("1.1.0")`.
//     - id 는 한 번 정하면 바꾸지 않는다(문구는 바꿔도 된다).
//     - 문구는 사용자 말로 쓴다(기술 용어 금지). 키는 영어, 번역은 Shared/Localizable.xcstrings 에 모든 언어로.
//     - 사용자에게 보일 만한 것만 적는다. 리팩터링 · 시험 · 빌드 설정은 `.sprintcommander/tasks.json` 의 몫이다.
//

import Foundation
import LeeoKit

extension ShutterLinkSpec {
    static var roadmap: [LeeoRoadmapItem] {[
        .init(id: "watch.remote", status: .shipped("1.1.0"),
              title: NSLocalizedString("Apple Watch remote", comment: "Roadmap item: watch.remote"),
              detail: NSLocalizedString("See what the camera sees on your wrist and take the photo with one tap, so you can be in the group photo too.", comment: "Roadmap item detail: watch.remote")),
        .init(id: "ipad.tripod", status: .planned,
              title: NSLocalizedString("Big iPad camera screen", comment: "Roadmap item: ipad.tripod"),
              detail: NSLocalizedString("Set an iPad on a tripod and line up the banner and the group on its big screen.", comment: "Roadmap item detail: ipad.tripod")),
    ]}
}
