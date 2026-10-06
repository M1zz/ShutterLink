#!/usr/bin/env python3
"""마케팅 스크린샷 목업 생성: HTML 생성 → 헤드리스 Chrome 렌더링.

슬라이드마다 layout 이 달라 배치가 다양함:
  hero-bleed  : 헤드라인 상단 중앙 + 정면 대형 폰, 하단 블리드
  left-text   : 좌측 정렬 텍스트 + 오른쪽으로 기운 폰
  text-bottom : 폰 상단 + 텍스트 하단
  flat-rotate : 평면 회전(-5°) 폰, 하단 블리드
  dark        : 다크 배경 반전 + 정면 폰
"""
import subprocess, sys, pathlib

# 원본은 render_screens.py 가 docs/screenshots/raw/ 에 만든다. 실행: python3 scripts/screens/make_marketing_screenshots.py
ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "docs" / "screenshots" / "raw"
OUT_ROOT = ROOT / "docs" / "screenshots" / "marketing"
WORK = pathlib.Path(__file__).parent / "build"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 1242, 2688   # App Store Connect 제출 규격 (iPhone 6.5")

LAYOUT = {
    "01-pairing.png": "hero-bleed",
    "02-focus.png": "left-text",
    "03-interval.png": "text-bottom",
    "04-burst.png": "flat-rotate",
    "05-camera.png": "hero-bleed",
    "06-video.png": "dark",
}

COPY = {
    "ko": {
        "01-pairing.png": ("리모컨 폰은<br>설치 없이 QR로", "다른 iPhone이 App Clip으로 바로 열려요"),
        "02-focus.png": ("탭 한 번에<br>초점과 노출", "리모컨 미리보기를 눌러 맞춰요"),
        "03-interval.png": ("인터벌 촬영", "3초부터 1분까지 정해 둔 간격으로"),
        "04-burst.png": ("단체 사진은<br>연속 촬영으로", "타이머가 끝나면 1초 간격으로 3장, 5장"),
        "05-camera.png": ("삼각대 위에서도<br>꼼꼼하게", "플래시, 노출 보정, 3분할 격자"),
        "06-video.png": ("동영상도 원격으로", "조명, 줌, 전후면 전환까지"),
    },
    "en": {
        "01-pairing.png": ("Nothing to install<br>on the remote", "Scan the QR. It opens as an App Clip"),
        "02-focus.png": ("Tap to focus<br>from afar", "Set focus and exposure on the remote"),
        "03-interval.png": ("Interval shooting", "One shot every 3 seconds to 1 minute"),
        "04-burst.png": ("Group shots,<br>no blinks", "After the timer, a burst of 3 or 5"),
        "05-camera.png": ("A real camera<br>on the tripod", "Flash, exposure and a thirds grid"),
        "06-video.png": ("Record video remotely", "Light, zoom and camera flip too"),
    },
}

BASE_CSS = f"""
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:{W}px; height:{H}px; overflow:hidden; }}
body {{ background:#f4f4f5; font-family:-apple-system, "Apple SD Gothic Neo", sans-serif; position:relative; }}
.headline {{ font-size:100px; font-weight:800; color:#141416; letter-spacing:-2px; line-height:1.25; }}
.sub {{ font-size:52px; font-weight:500; color:#9a9aa0; letter-spacing:-1px; }}
.phone {{ background:#17171a; border-radius:116px; border:3px solid #3a3a3e; padding:25px;
  box-shadow: 60px 90px 120px rgba(0,0,0,.28), 20px 30px 50px rgba(0,0,0,.18); }}
.phone img {{ width:100%; display:block; border-radius:110px; }}
"""

LAYOUTS = {
    # 1) 정면 대형, 하단 블리드
    "hero-bleed": """
.headline { text-align:center; margin-top:290px; padding:0 70px; }
.sub { text-align:center; margin-top:52px; }
.wrap { display:flex; justify-content:center; margin-top:150px; }
.phone { width:1000px; }
""",
    # 2) 좌측 정렬 텍스트 + 오른쪽 기울기, 오른쪽 블리드
    "left-text": """
.headline { text-align:left; margin:300px 0 0 110px; }
.sub { text-align:left; margin:48px 0 0 114px; }
.wrap { perspective:2600px; perspective-origin:30% 30%; position:absolute; left:300px; top:990px; }
.phone { width:840px; transform:rotateY(16deg) rotateX(2deg); }
""",
    # 3) 폰 상단, 텍스트 하단
    "text-bottom": """
.wrap { perspective:2800px; perspective-origin:50% 40%; display:flex; justify-content:center; margin-top:170px; }
.phone { width:880px; transform:rotateY(-10deg) rotateX(2deg); }
.headline { text-align:center; margin-top:120px; padding:0 70px; }
.sub { text-align:center; margin-top:48px; }
""",
    # 4) 평면 회전, 좌측 치우침 + 하단 블리드
    "flat-rotate": """
.headline { text-align:center; margin-top:270px; padding:0 70px; }
.sub { text-align:center; margin-top:52px; }
.wrap { position:absolute; left:120px; top:1010px; }
.phone { width:1010px; transform:rotate(-6deg); }
""",
    # 5) 다크 배경 반전 + 정면
    "dark": """
body { background:#131316; }
.headline { color:#f5f5f7; text-align:center; margin-top:290px; padding:0 70px; }
.sub { color:#77777d; text-align:center; margin-top:52px; }
.wrap { display:flex; justify-content:center; margin-top:150px; }
.phone { width:930px; border-color:#48484e;
  box-shadow: 0 0 160px rgba(80,140,255,.22), 40px 70px 110px rgba(0,0,0,.55); }
""",
}

# text-bottom 은 폰이 먼저 오는 DOM 순서
BODY_TEXT_FIRST = '<div class="headline">{headline}</div><div class="sub">{sub}</div><div class="wrap"><div class="phone"><img src="{img}"></div></div>'
BODY_PHONE_FIRST = '<div class="wrap"><div class="phone"><img src="{img}"></div></div><div class="headline">{headline}</div><div class="sub">{sub}</div>'

HTML = """<!doctype html><html><head><meta charset="utf-8"><style>
{base}{layout}
</style></head><body>{body}</body></html>"""

def main(only=None):
    WORK.mkdir(exist_ok=True)
    for lang, copy in COPY.items():
        out_dir = OUT_ROOT / lang
        out_dir.mkdir(parents=True, exist_ok=True)
        for fname, (headline, sub) in copy.items():
            if only and fname != only:
                continue
            layout = LAYOUT[fname]
            body_tpl = BODY_PHONE_FIRST if layout == "text-bottom" else BODY_TEXT_FIRST
            body = body_tpl.format(headline=headline, sub=sub, img=(SRC / fname).as_uri())
            html_path = WORK / f"marketing-{lang}-{fname.replace('.png', '.html')}"
            html_path.write_text(HTML.format(base=BASE_CSS, layout=LAYOUTS[layout], body=body), encoding="utf-8")
            out_png = out_dir / fname
            subprocess.run([CHROME, "--headless=new", f"--screenshot={out_png}",
                            f"--window-size={W},{H}", "--force-device-scale-factor=1",
                            "--hide-scrollbars", "--disable-gpu", "--allow-file-access-from-files",
                            html_path.as_uri()], check=True, capture_output=True)
            print(f"rendered {out_png}")

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)
