#!/bin/sh
# Apple Watch 스토어 스크린샷을 언어마다 찍는다 (Apple Watch 46mm — 416x496, 원본이 곧 제출본).
#
# 사용법: scripts/make_watch_screenshots.sh <워치 시뮬레이터 UDID> [폴더 이름 ...]
#   폴더 이름은 docs/screenshots/marketing 과 같다(ko, en, de-DE …). 없으면 전부.
# 미리: ShutterLinkWatch 를 Debug 로 그 시뮬레이터에 설치한다(데모 인자 -watchDemo 는 DEBUG 전용).
#   시뮬레이터에는 카메라도 iPhone 도 없어서, 앱이 아이폰 데모와 같은 그림(DemoScene)을 미리보기 자리에 띄운다.
# 결과: docs/screenshots/watch/<폴더>/01-remote.png · 02-countdown.png
set -e
U=$1; shift
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE=com.devkoan.shutterlink.watchkitapp
[ $# -eq 0 ] && set -- $(ls "$ROOT/docs/screenshots/marketing")

app_lang() {  # 폴더 이름 → 앱 언어 · 지역
  case $1 in
    en) echo "en en_US";; en-GB) echo "en-GB en_GB";; de-DE) echo "de de_DE";; es-ES) echo "es es_ES";;
    fr-FR) echo "fr fr_FR";; nl-NL) echo "nl nl_NL";; zh-Hans) echo "zh-Hans zh_CN";; zh-Hant) echo "zh-Hant zh_TW";;
    pt-BR) echo "pt-BR pt_BR";; ja) echo "ja ja_JP";; ko) echo "ko ko_KR";; cs) echo "cs cs_CZ";; da) echo "da da_DK";;
    el) echo "el el_GR";; nb) echo "nb nb_NO";; sv) echo "sv sv_SE";; vi) echo "vi vi_VN";;
    *) echo "$1 $1_$(echo "$1" | tr a-z A-Z)";;
  esac
}

cap() {  # cap <언어> <지역> <파일> <장면>
  xcrun simctl terminate "$U" $BUNDLE >/dev/null 2>&1 || true
  perl -e 'alarm 60; exec @ARGV' xcrun simctl launch "$U" $BUNDLE -AppleLanguages "($1)" -AppleLocale "$2" -watchDemo "$4" >/dev/null
  sleep "${WAIT:-4}"
  perl -e 'alarm 120; exec @ARGV' xcrun simctl io "$U" screenshot "$3" >/dev/null 2>&1
}

for F in "$@"; do
  set -- $(app_lang "$F"); L=$1; R=$2
  W="$ROOT/docs/screenshots/watch/$F"; mkdir -p "$W"
  cap "$L" "$R" "$W/01-remote.png" main
  cap "$L" "$R" "$W/02-countdown.png" countdown
  echo "done $F"
done
xcrun simctl terminate "$U" $BUNDLE >/dev/null 2>&1 || true
