#!/bin/zsh
# 실제 앱 화면으로 App Store 스크린샷 원본을 찍는다 (Debug 빌드의 -screenshots 모드, Shared/DemoMode.swift).
# 실행: scripts/screens/capture_simulator.sh [시뮬레이터 UDID]   (레포 최상단에서)
# 출력: scripts/screens/build/sim/{ko,en,ja}_<화면>.png → compose_simulator.py 가 docs/screenshots/marketing 으로 합성
set -u
ROOT=${0:A:h:h:h}
OUT=$ROOT/scripts/screens/build/sim
DD=$ROOT/scripts/screens/build/DerivedData
D=${1:-$(xcrun simctl list devices available | grep -m1 "iPhone .* Pro Max" | grep -oE '[0-9A-F-]{36}')}
P=$DD/Build/Products/Debug-iphonesimulator
mkdir -p $OUT
cd $ROOT
xcodebuild -project ShutterLink.xcodeproj -scheme ShutterLink -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath $DD build 2>&1 | grep -E "error:|BUILD" | sort -u
xcrun simctl boot $D 2>/dev/null
xcrun simctl bootstatus $D >/dev/null
xcrun simctl status_bar $D override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4

shot() { # lang bundle screen name [launch args...]
  local lang=$1 bundle=$2 screen=$3 name=$4; shift 4
  xcrun simctl terminate $D $bundle 2>/dev/null
  xcrun simctl launch $D $bundle -AppleLanguages "($lang)" -screenshots $screen "$@" >/dev/null || echo "launch failed: $name"
  sleep 6
  xcrun simctl io $D screenshot $OUT/${lang}_$name.png >/dev/null 2>&1
}

xcrun simctl install $D $P/ShutterLink.app
for L in ko en ja zh-Hans zh-Hant ru es de fr it pt-BR th vi cs; do
  shot $L com.devkoan.shutterlink main 01-main -hasSeenOnboarding YES
  shot $L com.devkoan.shutterlink banner banner -hasSeenOnboarding YES
  shot $L com.devkoan.shutterlink cloth cloth -hasSeenOnboarding YES
  shot $L com.devkoan.shutterlink bannerDesign bannerDesign -hasSeenOnboarding YES
  shot $L com.devkoan.shutterlink bannerAdjust bannerAdjust -hasSeenOnboarding YES
  shot $L com.devkoan.shutterlink countdown 04-countdown -hasSeenOnboarding YES
  shot $L com.devkoan.shutterlink gallery 05-gallery -hasSeenOnboarding YES
  shot $L com.devkoan.shutterlink pairing 07-pairing -hasSeenOnboarding YES
  shot $L com.devkoan.shutterlink onboarding 08-onboarding -hasSeenOnboarding NO
done

# 부모 앱이 깔려 있으면 시뮬레이터가 App Clip 을 지운다 — 부모 앱을 내리고 App Clip 만 설치.
xcrun simctl uninstall $D com.devkoan.shutterlink
xcrun simctl install $D $P/ShutterLinkClip.app
for L in ko en ja zh-Hans zh-Hant ru es de fr it pt-BR th vi cs; do
  shot $L com.devkoan.shutterlink.Clip remote 02-remote -simpleMode NO
  shot $L com.devkoan.shutterlink.Clip reviews 03-reviews -simpleMode NO
  shot $L com.devkoan.shutterlink.Clip simple 06-simple -simpleMode YES
done
xcrun simctl uninstall $D com.devkoan.shutterlink.Clip
echo "captured to $OUT"
