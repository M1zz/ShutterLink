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
