import sys, os
from PIL import Image, ImageDraw, ImageFont

raw, out = sys.argv[1], sys.argv[2]
W, H = 1320, 2868
FONT = "/System/Library/Fonts/AppleSDGothicNeo.ttc"

CAPTIONS = {
 "ko": {
  "1_main": ("단체사진, 아무도 빠지지 않게", "인원 카운터 · 수평계 · 가장자리 잘림 경고"),
  "2_remote": ("설치 없이 QR 한 번으로 리모컨", "App Clip으로 미리보기 보며 줌 · 초점 · 셔터"),
  "3_reviews": ("찍은 사진은 리모컨 폰으로 바로", "앱 없는 친구도 사진을 저장하고 공유해요"),
  "4_countdown": ("손바닥 하나로 셔터", "손바닥 · 박수 · 미소로 찍고, 음성과 불빛으로 카운트다운"),
  "5_gallery": ("눈 감은 사진은 이제 그만", "연사 중 모두 눈 뜬 베스트샷을 자동으로 골라요"),
  "6_simple": ("누구나 쉬운 큰 버튼 모드", "어르신도 버튼 하나로 단체사진 완성"),
  "7_pairing": ("QR만 보여주면 준비 끝", "계정도, 페어링도, 추가 장비도 필요 없어요"),
  "8_onboarding": ("손 안 대고 찍는 단체사진", "타이머보다 똑똑한 핸즈프리 셔터"),
 },
 "en": {
  "1_main": ("Group photos, nobody left out", "People counter, level and edge warnings"),
  "2_remote": ("Scan once, control the camera", "App Clip remote with live preview, zoom and focus"),
  "3_reviews": ("Photos land on the remote", "Friends without the app can save and share them"),
  "4_countdown": ("Raise your palm to shoot", "Palm, clap or smile shutter with voice and light countdown"),
  "5_gallery": ("No more closed eyes", "Group shot picks the frame where everyone's eyes are open"),
  "6_simple": ("Big buttons for everyone", "One large shutter anyone can press"),
  "7_pairing": ("Show the QR and you're ready", "No account, no pairing, no extra hardware"),
  "8_onboarding": ("Hands-free group photos", "Smarter than a self-timer"),
 },
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
    for name, (title, sub) in caps.items():
        src = os.path.join(raw, f"{lang}_{name}.png")
        if not os.path.exists(src): print("missing", src); continue
        canvas = Image.new("RGB", (W, H), (16, 16, 18))
        d = ImageDraw.Draw(canvas)
        d.rectangle([0, 0, W, 16], fill=(255, 214, 10))
        tf, sf = font(92, True), font(50, False)
        y = 150
        for line in wrap(d, title, tf, W - 160):
            d.text((W / 2, y), line, font=tf, fill=(255, 214, 10), anchor="mt"); y += 112
        y += 14
        for line in wrap(d, sub, sf, W - 180):
            d.text((W / 2, y), line, font=sf, fill=(225, 225, 230), anchor="mt"); y += 66
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
print("done")
