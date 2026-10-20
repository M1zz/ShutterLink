# App Review 대응 메모

DeployBar 가 읽어 가는 파일이 아니다. App Store Connect 에 사람이 붙여 넣는다.

## 4.3(a) 스팸 거절 (v1.0, 2026-10)

애플이 본 것: 스토어에 올라가 있던 문구가 "멀리서도 카메라를 컨트롤하는 앱" 한 줄뿐이었고,
키워드도 "카메라, 카메라 리모컨, 리모컨" 이라 흔한 리모컨 셔터 앱과 구별되지 않았다.
앱 자체는 다른 리모컨 앱과 구조가 다르다(아래). 그 차이를 문구·스크린샷·답변에서 처음부터 보여 준다.

### 1. Resolution Center 답장 (영어, 그대로 붙여 넣기)

```
Hello App Review team,

Thank you for the review. We'd like to explain how ShutterLink differs from other remote shutter apps, since our first submission's description was too short to show it. We have now rewritten the description, keywords and screenshots.

1. Only one iPhone installs the app. The second iPhone becomes the remote through an App Clip (ShutterLink Remote): the camera iPhone shows a QR code, the other iPhone scans it with the system Camera, and the App Clip opens and connects. A friend can join without installing anything. Most remote shutter apps require the full app on both devices.

2. It works with no network. App Clips cannot use Bonjour or Multipeer Connectivity, so we built our own Bluetooth LE protocol: a GATT service for commands and status, and an L2CAP channel that streams a live preview (about 12 frames per second) to the remote. No Wi-Fi, cellular, account or server is used.

3. The remote is a full camera controller, not just a shutter button: live view, tap to focus and expose, flash and torch, exposure compensation, grid, 3/10 second timer, 3 or 5 shot bursts, interval shooting (3 s to 1 min) with a countdown on both screens, zoom from 0.5x to 10x, front/back switching, and video recording. The camera iPhone also accepts the volume buttons, Camera Control and AirPods as shutter triggers.

4. All code and assets were written by us for this app. It is not based on a template, it is not a copy of another app, and we have no other remote camera app on the App Store.

How to test (two iPhones are required, iOS 17 or later):
1. On iPhone A, open ShutterLink and allow camera, microphone, Bluetooth and Photos access.
2. Tap the QR button at the top right. A QR code and a 4-digit pairing code appear.
3. On iPhone B, scan the QR code with the Camera app and tap Open on the App Clip card. If the card doesn't appear, the same App Clip can be opened from https://m1zz.github.io/ShutterLink/r?c=<code>, or by typing the 4-digit code in the App Clip.
4. The live view appears on iPhone B. Tap the preview to focus, then try the shutter, timer, burst and interval controls.

Thank you for taking another look.
```

### 2. 심사 정보 ▸ 메모 (App Review Information ▸ Notes)

위 답장의 "How to test" 부분과 2번 문단을 그대로 넣는다. 로그인이 없으므로 데모 계정은 비워 둔다.
가능하면 두 기기로 찍은 30초 시연 영상 링크를 같이 넣는다(애플은 기기 두 대가 필요한 앱의 영상을 반긴다).

### 3. 다시 제출하기 전 확인

- [ ] DeployBar 로 문구·스크린샷을 올려, App Store Connect 의 설명이 레포 `APPSTORE.md` 와 같아졌는지 본다
      (거절 당시 스토어에는 한 줄짜리 설명이 올라가 있었다)
- [ ] App Clip 기본 경험(헤더 이미지·부제)과 고급 경험 URL 이 등록돼 있는지 본다 — README 의 "App Clip 연결"
- [ ] 같은 거절이 다시 오면 답장에서 App Review Board 에 이의 제기(appeal)를 고려한다

## 4.3(a) 두 번째 거절 → App Review Board 이의 제기 (2026-10-13)

두 번째도 같은 4.3(a) + "Extended Review" 경고가 붙었다. 같은 빌드를 그대로 다시 내면 심사가 더 길어지고
계정에도 기록이 쌓이니, **다시 제출하지 말고 이의 제기로 간다.**

- 제출하는 곳: https://developer.apple.com/contact/app-store/?topic=appeal
  (앱 ▸ ShutterLink, 거절 사유 ▸ 4.3(a). 아래 글을 붙여 넣는다)
- 가능하면 두 기기로 찍은 30초 시연 영상 링크(유튜브 비공개 등)를 마지막 줄에 넣는다 — 기기 두 대가 필요한 앱이라
  심사자가 직접 못 돌려 봤을 가능성이 크다.
- 통화(App Review 전화 상담)를 요청하는 칸이 있으면 요청한다.

```
Hello App Review Board,

We are appealing the Guideline 4.3(a) rejection of ShutterLink (v1.0). We believe the app was judged by its category ("remote shutter") rather than by what it does, and we would like to show the concrete differences.

1. Only one iPhone installs anything. The second iPhone becomes the remote through an App Clip. The camera iPhone shows a QR code, the other person scans it with the system Camera, and the remote opens and connects within seconds. A friend or a passer-by can take part without downloading an app or creating an account. We are not aware of another remote camera app built this way.

2. It works with no network at all. App Clips cannot use Multipeer Connectivity or Bonjour, so we designed our own Bluetooth LE protocol: a GATT service for commands and status, and an L2CAP channel that streams a live preview (about 12 frames per second) to the remote. No Wi-Fi, cellular data, server or account is involved, so it works on a mountain, at sea or abroad, and no photo or preview ever leaves the camera iPhone.

3. The remote is a full camera controller: live view, tap to focus and expose, flash and torch, exposure compensation, grid, 3 and 10 second timers, 3 or 5 shot bursts, interval shooting from 3 seconds to 1 minute with a countdown on both screens, 0.5x to 10x zoom, front and back cameras, and video recording. On the camera iPhone, the volume buttons, Camera Control and AirPods also work as shutter triggers.

4. The code and assets were written by us for this app. It is not built from a template or a purchased codebase. We have no other remote camera app on the App Store, and our other apps do not share this app's functionality. The only shared code is our own small library for privacy policy and support links.

Because the app needs two iPhones, it may not have been possible to try the App Clip flow during review. Steps:
1. iPhone A: open ShutterLink, allow Camera, Microphone, Bluetooth and Photos.
2. Tap the QR button at the top right. A QR code and a 4-digit code appear.
3. iPhone B: scan the QR code with the Camera app and tap Open on the App Clip card. The App Clip can also be opened at https://m1zz.github.io/ShutterLink/r?c=<code>, or by entering the 4-digit code.
4. The live view appears on iPhone B. Tap to focus, then try the shutter, timer, burst and interval controls.

We would be glad to provide a demo video or to discuss the app by phone.

Thank you for your time.
```

## 현수막 모드를 더해 다시 제출 (2026-10-20)

10/13 이의 제기 계획 이후 앱이 크게 바뀌었다 — 현수막 모드(AR 단체사진 현수막), 베스트샷, 손 안 대고 찍기,
리모컨으로 사진 전달. 같은 빌드를 다시 내는 게 아니므로 **이의 제기 대신 새 빌드로 다시 제출**하고,
스토어 문구·스크린샷·헤더·검색 결과 그림을 모두 "현수막 든 단체사진" 중심으로 바꿨다.
(이의 제기를 이미 냈다면 결과를 기다린 뒤, 아래 답장을 Resolution Center 에 붙인다.)

### Resolution Center 답장 (영어, 그대로 붙여 넣기)

```
Hello App Review team,

Thank you for your earlier feedback. Since our last submission we have substantially changed ShutterLink, and the new build is built around a feature we believe no other camera app on the App Store offers: the "everyone holding the banner" group photo, without a printed banner.

1. Banner mode. In the camera, choose Banner and tap the ground. A banner the user designed appears in augmented reality at the height people would hold it, in front of the group, so the photo looks like everyone is holding a real banner. Tapping a wall hangs it on the wall instead. Users write up to three lines of text, pick one of 13 event themes (company retreat, reunion, graduation, wedding, birthday, sports day and more), and change the background, font, decorations, colors, aspect ratio and logo. The banner is rendered as fabric, vinyl or paper; the fabric version sags, wrinkles and moves in the wind using a mesh we generate and update ourselves in RealityKit.

2. Built for the photographer to be in the photo. Banner mode works with the self-timer, a hands-free shutter (raise a palm, smile together, or clap), a spoken countdown with the flash blinking, and the remote. A people counter warns when someone is cut off at the edge, and bursts pick the frame where everyone's eyes are open.

3. A remote with nothing to install. A second iPhone scans a QR code with the system Camera and becomes the remote through an App Clip, connected over our own Bluetooth LE protocol (GATT for commands, an L2CAP channel for the live preview). In Banner mode the remote's live view includes the banner. Each photo taken is sent to the remote so a friend without the app can save it. No network, account or server is involved.

4. All code and assets were written by us for this app. It is not based on a template and we have no other app with this functionality.

How to test (one iPhone is enough for Banner mode; iOS 17 or later):
1. Open ShutterLink and allow Camera, Microphone, Bluetooth and Photos access.
2. In the mode row above the shutter, choose Banner. Tap the brush button at the top right to edit the text or pick a theme, then tap Done.
3. Point the camera at the floor a few meters away and tap it. The banner appears. Drag it, or use Adjust Position.
4. Press the shutter, or set a 3 second timer and raise your palm toward the camera.
Remote (optional, needs a second iPhone): tap the phone symbol at the top left of the camera iPhone, scan the QR code with the other iPhone's Camera and tap Open on the App Clip card. The App Clip can also be opened at https://m1zz.github.io/ShutterLink/r?c=<code>, or by entering the 4-digit code.

Thank you for taking another look.
```

### 심사 정보 ▸ 메모 (App Review Information ▸ Notes)

위 답장의 1번 문단과 "How to test" 를 그대로 넣는다. 현수막 모드는 iPhone 한 대로 확인할 수 있다는 점이 핵심 —
지난 두 번은 기기 두 대가 필요해 심사자가 차별점을 직접 못 봤을 수 있다.
가능하면 현수막 모드로 단체사진을 찍는 20~30초 시연 영상 링크를 같이 넣는다.

### 다시 제출하기 전 확인

- [ ] 실기기에서 현수막 모드 진입 · 배치 · 촬영 · 사진 앱 저장까지 한 번 돌려 본다 (todo.md 의 실기기 항목)
- [ ] DeployBar 로 배포한 뒤 App Store Connect 의 이름·부제·설명·스크린샷이 레포와 같은지 본다
- [ ] 심사 메모에 위 글을 넣는다
