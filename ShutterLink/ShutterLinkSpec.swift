//
//  ShutterLinkSpec.swift
//  ShutterLink
//
//  LeeoKit 계약(LeeoAppSpec) 준수 — 이 앱의 공통 기능 설정값 단일 소스.
//
//  ⚠️ 피드백 허브(iCloud.com.Ysoup.FeedbackHub)는 아직 이 앱의 entitlements 에 없다.
//     피드백 화면·크래시 진단을 켜기 전에 그 컨테이너를 먼저 추가해야 한다.
//

import Foundation
import LeeoKit

enum ShutterLinkSpec: LeeoAppSpec {
    static let appName = "ShutterLink"
    static let developerEmail = "leeo@kakao.com"

    static let feedback = LeeoFeedbackConfig(
        containerIdentifier: "iCloud.com.Ysoup.FeedbackHub",
        appIdentifier: "com.devkoan.shutterlink"
    )

    /// App Store Connect 에 넣은 주소와 같다 (APPSTORE.md).
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: "https://m1zz.github.io/ShutterLink/privacy/")!,
        supportURL: URL(string: "https://m1zz.github.io/ShutterLink/support/")!,
        // 계정을 만들지 않는다.
        createsAccounts: false,
        marketingURL: URL(string: "https://m1zz.github.io/ShutterLink/")
    )

    /// 인앱 결제 없음.
    static let monetization = LeeoMonetization.free
}
