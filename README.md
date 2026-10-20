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

## 단체사진 특화 기능

| 기능 | 카메라 폰 | 리모컨(App Clip) |
|---|---|---|
| 연속 촬영(3/5장) 후 베스트샷 자동 선택 (눈 뜸·미소 점수) | O | 설정·결과 수신 |
| 핸즈프리 셔터: 손바닥 제스처(Vision 손 포즈) / 미소 셔터 / 박수 셔터 | O | O |
| 인원 카운터 + 화면 가장자리 잘림 경고, 수평계 | O | O |
| 음성 카운트다운 + 플래시 불빛 깜빡임 카운트다운 | O | 손 진동 카운트다운 |
| "카메라 봐 주세요" 음성 안내 | O | O |
| 타이머 0/3/5/10/20/30초 | O | O |
| 앱 내 갤러리 (베스트샷 필터, 연사 중 베스트 재지정, AirDrop 공유, 삭제) | O | |
| 찍힌 사진 1024px 사본을 리모컨으로 전송 → 리모컨에서 저장/공유 | | O |
| 간편 모드(큰 버튼) | | O |
| 온보딩, 설정, QR 공유, 한국어/영어 String Catalog | O | O |
| 현수막 모드: 문구·색·로고로 디자인한 현수막을 AR로 띄우고 사람 가림(People Occlusion)으로 "들고 있는" 단체사진 | O | 셔터 |

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

## 현수막 모드 (`ShutterLink/Banner/`, BannerAR 에서 흡수)

`CaptureMode.banner` — 사진·동영상과 같은 카메라 모드입니다. 카메라 앱과 리모컨(App Clip) 모드 줄 모두에 `현수막` 이 있고, 고르면 같은 화면에서 뷰파인더가 AR 로 바뀝니다.
바닥을 탭하면 들고 있는 높이에, 벽을 탭하면 벽에 붙여 배치. 현수막을 직접 끌기 · 두 손가락 회전/크기, 또는 `위치 조정` 패널(셔터 자리에 뜸): 이동 패드(앞뒤·좌우) · 높이 · 방향 · 크기 · 정면. 패널이 열려 있는 동안은 탭해도 다시 배치되지 않습니다.
- 기본은 현수막이 항상 사람 앞 (사람이 뚫고 나오지 않음). 옵션의 `앞에 선 사람 보이기` 를 켜야 ARKit 사람 깊이 가림(personSegmentationWithDepth)을 씁니다 — 깊이 추정이 거칠어 현수막 바로 뒤 사람이 비칠 수 있음.
오른쪽 위 붓 버튼 = 현수막 디자인(미리보기 + 테마 13종 카드, 문구 3줄, 비율, 배경 5종, 글꼴 4종, 장식 12종, 색, 로고, 재질, 막대, 바람, 가로 길이).

- 테마(`BannerTheme.all`)는 배경·색·글꼴·장식만 바꾸고 문구·로고는 그대로 둡니다.
- 천 재질: `ClothShape` 가 처짐 · 세로 주름 · 모서리 당김 주름 · 바람(24fps로 메시 갱신)을 만들고 실제 표면 법선을 계산합니다. 재질은 직조 노멀맵 + sheen, 텍스처에 직조 무늬 · 박음질 단 · 쇠고리를 넣습니다. 비닐은 주름이 약하고, 종이는 평평합니다.
- 시뮬레이터 확인용: `-screenshots cloth` (AR 없이 RealityKit 으로 현수막만 렌더, `-closeUp` 추가하면 근접), `-screenshots bannerDesign`.

- 촬영 흐름은 `CameraController` 하나: 화면 셔터·리모컨 셔터·손 안 대고 찍기 → 타이머 · 음성/불빛 카운트다운 → `fire()` 가 `.banner` 면 `onBannerShot` → AR 스냅샷 → `addBannerPhoto` (사진 앱 · 갤러리 · 리모컨 사본).
- ARKit 과 AVCaptureSession 은 카메라를 같이 못 씀: `setMode(.banner)` 가 세션을 멈춘 뒤 `onBannerStart`, 다른 모드로 갈 때 `onBannerEnd` 로 AR 을 먼저 멈추고 세션 재시작.
- AR 카메라 프레임 → `analyzeBannerFrame` (인원 수 · 가장자리 경고 · 손바닥/미소 셔터), AR 마이크 → `analyzeBannerAudio` (박수 셔터), AR 화면 스냅샷 6fps → `addBannerPreviewFrame` (리모컨 미리보기에 현수막까지 보임).
- 현수막 모드에서 쓸 수 없는 것: 플래시 · 연사/인터벌 · 노출 · 줌 · 전면 카메라 (카메라·리모컨 모두 숨기거나 비활성).
- 스크린샷 모드: `-screenshots banner` (옵션 펼친 상태는 `-showOptions` 추가).

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

## 스크린샷 다시 만들기

시뮬레이터에는 카메라·Bluetooth가 없어서 Debug 빌드에 스크린샷 모드가 있습니다 (`Shared/DemoMode.swift`, Release에는 포함 안 됨).
`-screenshots main|countdown|gallery|pairing|onboarding` (카메라 앱), `-screenshots remote|reviews|simple` (App Clip).

```
scripts/screens/capture_simulator.sh          # 실제 화면 캡처 (부모 앱/App Clip 순서 처리 포함)
python3 scripts/screens/compose_simulator.py  # 문구 합성 → docs/screenshots/marketing/{ko,en}
```
