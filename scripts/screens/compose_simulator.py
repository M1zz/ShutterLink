#!/usr/bin/env python3
"""시뮬레이터에서 찍은 실제 화면(capture_simulator.sh)에 헤드라인을 얹어 App Store 스크린샷을 만든다.

실행: python3 scripts/screens/compose_simulator.py   (레포 최상단에서, Pillow 필요)
입력: scripts/screens/build/sim/{ko,en}_<화면>.png
출력: docs/screenshots/marketing/{ko,en}/<화면>.png  (1242x2688, iPhone 6.5")
"""
import os, pathlib
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
raw = str(ROOT / "scripts" / "screens" / "build" / "sim")
out = str(ROOT / "docs" / "screenshots" / "marketing")
W, H = 1242, 2688   # App Store Connect 제출 규격 (iPhone 6.5")
FONT = "/System/Library/Fonts/AppleSDGothicNeo.ttc"

# (출력 파일, 원본 캡처, 헤드라인, 부제) — 번호 순서가 스토어 순서다. 1·2장은 현수막 단체사진.
CAPTIONS = {
 "ko": [
  ("01-banner", "banner", "현수막 든 단체사진, 현수막 없이", "바닥을 탭하면 모두의 앞에 현수막이 놓여요"),
  ("02-banner-design", "bannerDesign", "테마 고르고 문구만 적으면 끝", "야유회 · 동창회 · 졸업 · 생일 등 테마 13가지"),
  ("03-remote", "02-remote", "친구 iPhone이 설치 없이 리모컨", "QR 한 번이면 미리보기 보며 셔터"),
  ("04-countdown", "04-countdown", "손바닥 하나로 셔터", "손바닥 · 박수 · 미소로 찍고, 음성과 불빛으로 카운트다운"),
  ("05-bestshot", "01-main", "눈 감은 사진은 이제 그만", "연사 중 모두 눈 뜬 베스트샷을 골라 두고, 잘리는 사람도 알려 줘요"),
  ("06-reviews", "03-reviews", "찍은 사진은 리모컨 폰으로 바로", "앱 없는 친구도 사진을 저장하고 공유해요"),
  ("07-gallery", "05-gallery", "베스트샷만 모아 보기", "연사 중 다른 장으로 바꾸고 AirDrop으로 나눠요"),
  ("08-pairing", "07-pairing", "QR만 보여 주면 준비 끝", "계정도, 페어링도, 추가 장비도 필요 없어요"),
  ("09-simple", "06-simple", "누구나 쉬운 큰 버튼 모드", "어르신도 버튼 하나로 단체사진 완성"),
 ],
 "en": [
  ("01-banner", "banner", "The banner group photo, no printing", "Tap the ground and a banner appears in front of everyone"),
  ("02-banner-design", "bannerDesign", "Pick a theme, add your words", "13 themes for reunions, parties, graduations and more"),
  ("03-remote", "02-remote", "Any iPhone becomes the remote", "Scan one QR code, nothing to install"),
  ("04-countdown", "04-countdown", "Raise your palm to shoot", "Palm, clap or smile shutter with voice and light countdown"),
  ("05-bestshot", "01-main", "No more closed eyes", "Bursts keep the shot where everyone's eyes are open"),
  ("06-reviews", "03-reviews", "Photos land on the remote", "Friends without the app can save and share them"),
  ("07-gallery", "05-gallery", "Best shots, all in one place", "Swap in another frame and share with AirDrop"),
  ("08-pairing", "07-pairing", "Show the QR and you're ready", "No account, no pairing, no extra hardware"),
  ("09-simple", "06-simple", "Big buttons for everyone", "One large shutter anyone can press"),
 ],
 "ja": [
  ("01-banner", "banner", "横断幕なしで横断幕の集合写真", "床をタップすると、みんなの前に横断幕が置かれます"),
  ("02-banner-design", "bannerDesign", "テーマを選んで文字を入れるだけ", "同窓会、パーティー、卒業など13種類のテーマ"),
  ("03-remote", "02-remote", "どのiPhoneもリモコンに", "QRコードを読み取るだけ。インストール不要"),
  ("04-countdown", "04-countdown", "手のひらをかざして撮影", "手のひら、拍手、笑顔で撮影。音声と光のカウントダウン付き"),
  ("05-bestshot", "01-main", "目を閉じた写真とさよなら", "連写から、全員が目を開けている1枚を選びます"),
  ("06-reviews", "03-reviews", "撮った写真はリモコンにも届く", "アプリのないお友だちも保存・共有できます"),
  ("07-gallery", "05-gallery", "ベストショットをまとめて見る", "別のコマに差し替えて、AirDropで共有"),
  ("08-pairing", "07-pairing", "QRを見せれば準備完了", "アカウントもペアリング設定も追加の機器も不要です"),
  ("09-simple", "06-simple", "だれでも押せる大きなボタン", "大きなシャッターボタンがひとつだけ"),
 ],
 "zh-Hans": [
 ("01-banner", "banner", "不用印横幅，也能拍横幅合影", "点一下地面，横幅就出现在大家面前"),
 ("02-banner-design", "bannerDesign", "选个主题，写上文字就好", "同学聚会、派对、毕业等 13 种主题"),
 ("03-remote", "02-remote", "朋友的 iPhone 就是遥控器", "扫一下二维码，无需安装"),
 ("04-countdown", "04-countdown", "举起手掌就能拍", "手掌、拍手、微笑都能触发，还有语音和灯光倒计时"),
 ("05-bestshot", "01-main", "告别闭眼的照片", "从连拍中选出所有人都睁眼的一张"),
 ("06-reviews", "03-reviews", "拍好的照片直接发到遥控器", "没有装 App 的朋友也能保存和分享"),
 ("07-gallery", "05-gallery", "集中查看最佳照片", "换成连拍中的另一张，再用隔空投送分享"),
 ("08-pairing", "07-pairing", "亮出二维码就能开拍", "无需账号，无需配对设置，无需额外设备"),
 ("09-simple", "06-simple", "人人都会按的大按钮", "只有一个大快门，谁都能按"),
 ],
 "zh-Hant": [
 ("01-banner", "banner", "不用印布條，也能拍布條團體照", "點一下地面，布條就出現在大家面前"),
 ("02-banner-design", "bannerDesign", "選個主題，寫上文字就好", "同學會、派對、畢業等 13 種主題"),
 ("03-remote", "02-remote", "朋友的 iPhone 就是遙控器", "掃一下 QR code，不需安裝"),
 ("04-countdown", "04-countdown", "舉起手掌就能拍", "手掌、拍手、微笑都能觸發，還有語音和燈光倒數"),
 ("05-bestshot", "01-main", "告別閉眼的照片", "從連拍中挑出所有人都睜眼的一張"),
 ("06-reviews", "03-reviews", "拍好的照片直接傳到遙控器", "沒有安裝 App 的朋友也能儲存和分享"),
 ("07-gallery", "05-gallery", "集中查看最佳照片", "換成連拍中的另一張，再用 AirDrop 分享"),
 ("08-pairing", "07-pairing", "亮出 QR code 就能開拍", "不需帳號，不需配對設定，不需額外設備"),
 ("09-simple", "06-simple", "人人都會按的大按鈕", "只有一個大快門，誰都能按"),
 ],
}

def font(size, bold):
    return ImageFont.truetype(FONT, size, index=6 if bold else 2)  # Bold / Regular faces in the collection

def wrap(draw, text, f, maxw):
    words, lines, cur = text.split(" "), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if draw.textlength(t, font=f) <= maxw: cur = t
        else: lines.append(cur); cur = w
    lines.append(cur)
    return lines

for lang, caps in CAPTIONS.items():
    os.makedirs(os.path.join(out, lang), exist_ok=True)
    for name, source, title, sub in caps:
        src = os.path.join(raw, f"{lang}_{source}.png")
        if not os.path.exists(src): print("missing", src); continue
        canvas = Image.new("RGB", (W, H), (16, 16, 18))
        d = ImageDraw.Draw(canvas)
        d.rectangle([0, 0, W, 16], fill=(255, 214, 10))
        tf, sf = font(86, True), font(48, False)
        y = 150
        for line in wrap(d, title, tf, W - 160):
            d.text((W / 2, y), line, font=tf, fill=(255, 214, 10), anchor="mt"); y += 104
        y += 14
        for line in wrap(d, sub, sf, W - 180):
            d.text((W / 2, y), line, font=sf, fill=(225, 225, 230), anchor="mt"); y += 62
        top = y + 50
        shot = Image.open(src).convert("RGB")
        maxh = H - top - 70
        scale = min((W - 200) / shot.width, maxh / shot.height)
        sw, sh = int(shot.width * scale), int(shot.height * scale)
        shot = shot.resize((sw, sh), Image.LANCZOS)
        mask = Image.new("L", (sw, sh), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw, sh], radius=70, fill=255)
        x = (W - sw) // 2
        d.rounded_rectangle([x - 12, top - 12, x + sw + 12, top + sh + 12], radius=82, fill=(60, 60, 66))
        canvas.paste(shot, (x, top), mask)
        canvas.save(os.path.join(out, lang, f"{name}.png"))
print("done →", out)
