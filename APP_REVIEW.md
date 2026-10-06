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
