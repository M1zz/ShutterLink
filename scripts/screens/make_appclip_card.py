#!/usr/bin/env python3
"""App Clip 카드 헤더 이미지(1800x1200) 생성: HTML 생성 → 헤드리스 Chrome 렌더링.

Apple 가이드: 3:2, 투명 없음, 이미지 안에 글자 넣지 않기(카드 제목·부제가 아래에 따로 붙는다).
배경은 scene.svg 일러스트, 오른쪽에 리모컨(App Clip) 화면을 띄운 폰.
실행: python3 scripts/screens/make_appclip_card.py  (원본은 render_screens.py 가 만든다)
"""
import subprocess, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
ASSETS = pathlib.Path(__file__).parent / "assets"
SRC = ROOT / "docs" / "screenshots" / "raw" / "03-remote.png"
OUT = ROOT / "docs" / "screenshots" / "appclip" / "card.png"
WORK = pathlib.Path(__file__).parent / "build"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 1800, 1200

HTML = f"""<!doctype html><html><head><meta charset="utf-8"><style>
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:{W}px; height:{H}px; overflow:hidden; background:#1c1a33; }}
.scene {{ position:absolute; inset:0;
  background:url({(ASSETS / 'scene.svg').as_uri()}) no-repeat; background-size:1350px 1800px;
  background-position:-40px -470px;
  -webkit-mask-image:linear-gradient(90deg, #000 52%, transparent 71%); }}
.shade {{ position:absolute; inset:0;
  background:linear-gradient(90deg, rgba(28,26,51,0) 45%, rgba(28,26,51,.6) 100%); }}
.waves {{ position:absolute; left:1120px; top:300px; width:220px; height:220px; }}
.waves span {{ position:absolute; inset:0; border:6px solid rgba(255,255,255,.75); border-radius:50%;
  clip-path:polygon(0 0, 50% 50%, 0 100%); }}
.waves span:nth-child(2) {{ inset:-50px; opacity:.55; }}
.waves span:nth-child(3) {{ inset:-100px; opacity:.3; }}
.wrap {{ position:absolute; left:1230px; top:150px; perspective:2400px; }}
.phone {{ width:470px; background:#17171a; border-radius:76px; border:3px solid #3a3a3e; padding:16px;
  transform:rotate(-6deg) rotateY(-8deg);
  box-shadow: 40px 60px 90px rgba(0,0,0,.45), 12px 20px 36px rgba(0,0,0,.3); }}
.phone img {{ width:100%; display:block; border-radius:62px; }}
</style></head><body>
<div class="scene"></div><div class="shade"></div>
<div class="waves"><span></span><span></span><span></span></div>
<div class="wrap"><div class="phone"><img src="{SRC.as_uri()}"></div></div>
</body></html>"""

WORK.mkdir(exist_ok=True)
OUT.parent.mkdir(parents=True, exist_ok=True)
page = WORK / "appclip_card.html"
page.write_text(HTML)
subprocess.run([CHROME, "--headless=new", "--hide-scrollbars", "--force-device-scale-factor=1",
                "--allow-file-access-from-files", f"--screenshot={OUT}", f"--window-size={W},{H}",
                page.as_uri()], check=True, capture_output=True)
# 투명 채널 제거 (App Store Connect 는 알파 있는 PNG 를 거절한다)
subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "95", str(OUT),
                "--out", str(OUT.with_suffix(".jpg"))], check=True, capture_output=True)
OUT.unlink()
print(OUT.with_suffix(".jpg"))
