# ShutterLink

삼각대에 세운 iPhone을 **다른 iPhone의 App Clip**으로 원격 조종하는 카메라 앱입니다.
카메라 폰 화면의 QR을 스캔하면 App Clip이 설치 없이 열리고, BLE로 연결돼 셔터·녹화·타이머·연속/인터벌 촬영·플래시·노출 보정·탭 초점·격자·줌·전후면 전환과 저화질 실시간 미리보기를 제공합니다.

```
┌──────────── 카메라 폰 (ShutterLink.app) ────────────┐        ┌──── 리모컨 폰 (ShutterLinkClip) ────┐
│ AVCaptureSession (사진 / HEVC 동영상 + 오디오)       │        │ QR 스캔 → App Clip 실행               │
│ CBPeripheralManager                                  │  BLE   │ CBCentralManager                      │
│  ├ command  (write)   ◀─────────────────────────────┼────────┤  hello(code) → shutter / zoom / …    │
│  ├ status   (notify)  ─────────────────────────────▶┼────────┤  상태 표시 (녹화 시간, 카운트다운…)   │
│  └ previewPSM (read)  → L2CAP 채널: JPEG 400px ~12fps ─────────▶  미리보기                           │
└──────────────────────────────────────────────────────┘        └───────────────────────────────────────┘
```

## 구성

| 폴더 | 내용 |
|---|---|
| `ShutterLink/` | 카메라 앱 (AVFoundation, BLE peripheral, QR 페어링 시트, AirPods/볼륨 버튼 셔터) |
| `ShutterLinkClip/` | App Clip 리모컨 (BLE central, 미리보기, 컨트롤 UI, 코드 수동 입력) |
| `Shared/` | 두 타깃 공용: BLE UUID·명령/상태 프로토콜, L2CAP 프레이밍, 공용 SwiftUI 컴포넌트 |
| `Config/` | App Clip entitlements, Info.plist (`NSAppClip`) |
| `project.yml` | (선택) XcodeGen 백업 정의 — `.xcodeproj`가 문제가 생기면 `xcodegen generate` |

요구사항: **Xcode 16 이상**(폴더 동기화 그룹 사용), iOS 17.0+, 실기기 2대 (BLE·카메라는 시뮬레이터 불가)

## 처음 실행하기

1. `ShutterLink.xcodeproj` 열기
2. 두 타깃(ShutterLink, ShutterLinkClip) 모두 **Signing & Capabilities → Team** 선택
3. Bundle ID를 바꾸려면 세 곳을 함께 바꿉니다
   - ShutterLink: `com.devkoan.shutterlink`
   - ShutterLinkClip: `com.devkoan.shutterlink.Clip` (반드시 부모 ID + `.Clip` 형태)
   - `Config/ShutterLinkClip.entitlements`의 `parent-application-identifiers`
4. 카메라 폰에 **ShutterLink** 스킴으로 실행 → 우상단 QR 버튼에 4자리 코드와 QR 표시

### 리모컨 폰 테스트 (3가지 방법)

- **가장 빠름**: 리모컨 폰에 **ShutterLinkClip** 스킴을 Run → 카메라 폰의 4자리 코드 입력
- **URL 주입**: ShutterLinkClip 스킴 → Edit Scheme → Run → Environment Variables에
  `_XCAppClipURL` = `https://m1zz.github.io/ShutterLink/r?c=1234` (카메라에 표시된 코드)
- **실제 QR 흐름**: 리모컨 폰에 App Clip을 한 번 설치한 뒤
  설정 → 개발자 → App Clips 테스트 → **로컬 경험**에 등록
  (URL 접두사 `https://m1zz.github.io/ShutterLink/r`, 번들 ID `com.devkoan.shutterlink.Clip`)
  → 카메라 앱을 켜고 기본 카메라 앱으로 QR 스캔하면 App Clip 카드가 뜹니다

## App Clip 연결 (설정 완료)

- QR 주소: `https://m1zz.github.io/ShutterLink/r?c=1234` (`RemoteConfig.invocationBaseURL`)
- AASA: 루트 레포 `M1zz/m1zz.github.io` 의 `/.well-known/apple-app-site-association` 에
  `QGAQ3AY3R3.com.devkoan.shutterlink.Clip` 등록 (FindMe·toki·moa 와 같은 파일을 공유)
- 두 타깃 Associated Domains: `appclips:m1zz.github.io`
- 폴백 페이지: `docs/r/index.html` (Safari 에서 열면 App Clip 카드 배너)
- 카드 헤더 이미지: `docs/screenshots/appclip/card.jpg` (1800×1200, `scripts/screens/make_appclip_card.py`)

App Store Connect 에서 사람이 할 일:
1. 버전 페이지 ▸ App Clip ▸ 기본 경험: 헤더 이미지·부제·동작(열기)
2. 앱 ▸ App Clip 경험 ▸ 고급 경험 추가: URL `https://m1zz.github.io/ShutterLink/r` (접두사 매칭 — 세션마다 `?c=` 가 달라짐)
3. App Clip 용량: QR로 여는 App Clip은 **압축 해제 15MB** 제한 (현재 구조는 외부 의존성 없음)

## 설계 메모

- **왜 BLE인가**: App Clip은 Bonjour/Multipeer Connectivity를 쓸 수 없습니다(Apple 문서). CoreBluetooth는 사용 가능하고 Wi-Fi·셀룰러 없이도 동작합니다.
- **보안**: 광고 이름은 `SL-<코드>`. 리모컨이 `hello(code)`를 먼저 써야 명령과 미리보기 PSM을 받을 수 있습니다. 코드는 앱 실행마다 새로 만들어집니다.
  (`.insufficientAuthentication` 응답은 iOS 페어링 팝업을 띄우므로 쓰지 않습니다)
- **미리보기**: `AVCaptureVideoDataOutput` 프레임을 400px JPEG(q0.4)로 줄여 L2CAP로 보냅니다. 전송 중이면 새 프레임은 버립니다(latest-wins). L2CAP이 실패해도 제어는 GATT만으로 동작합니다.
- **녹화**: `AVCaptureMovieFileOutput` 대신 `AVAssetWriter`를 사용합니다. 녹화하면서 미리보기 프레임을 계속 뽑기 위해서입니다.
- **회전**: `AVCaptureDevice.RotationCoordinator`로 수평 기준 각도를 맞춥니다. 녹화 중에는 버퍼 회전을 고정합니다.
- **줌**: 멀티 카메라 가상 디바이스에서 광각 렌즈를 1×로 정규화합니다(0.5×~10×).
- **추가 셔터**: 카메라 폰에서 볼륨 버튼, Camera Control, AirPods 스템(iOS 26)을 `AVCaptureEventInteraction`으로 지원합니다.

## 알려진 한계 / 다음 단계

- 카메라 앱은 포그라운드에 있어야 합니다(화면 자동 잠금은 꺼 둠).
- 리모컨 폰은 App Clip을 **처음 받을 때 인터넷이 필요**합니다.
- BLE 미리보기는 저해상도입니다 → 같은 Wi-Fi/핫스팟이면 `Network` 프레임워크로 IP 직결 고화질 미리보기 추가
  (QR에 `ip:port` 포함; App Clip의 로컬 네트워크 권한 동작은 실기기 검증 필요)
- 프레임레이트/해상도 선택, 리모컨으로 사진 원본 전송은 미구현
