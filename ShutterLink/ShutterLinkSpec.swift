//
//  ShutterLinkSpec.swift
//  ShutterLink
//
//  LeeoKit 계약(LeeoAppSpec) 준수 — 이 앱의 공통 기능 설정값 단일 소스.
//
//  피드백 허브(iCloud.com.Ysoup.FeedbackHub) 권한은 본 앱 entitlements 에만 있다.
//  앱 클립(ShutterLinkClip)은 LeeoKit 을 쓰지 않으므로 아무것도 보내지 않는다.
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

    /// 익명 사용 통계 — 설치 수·실행 일수·버전 분포를 피드백 허브로 보낸다.
    /// 기본값(LeeoNoopAnalytics)이면 부트스트랩이 아무것도 안 보낸다.
    static let analytics: any LeeoAnalytics = LeeoUsageAnalytics(spec: ShutterLinkSpec.self)

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
