#!/usr/bin/env python3
"""App Store 크리에이티브 자산(제품 페이지 헤더 · 검색 결과) 생성: HTML → 헤드리스 Chrome.

사용법: python3 scripts/make_creative_assets.py [언어 ...]     (없으면 전부)

자리
  docs/screenshots/creative/<스토어 로케일>/header.png   3840x1646  제품 페이지 맨 위
  docs/screenshots/creative/<스토어 로케일>/search.png   3840x2560  검색 결과 (없으면 스크린샷이 대신 보인다)

⚠️ 안전 영역 밖은 기기에 따라 잘린다. 글은 **반드시** 안전 영역 안에 둔다(배경 · 기기 그림은 넘쳐도 된다).
   수치는 Apple 공식 PSD 템플릿에서 잰 값이다(https://developer.apple.com/app-store/asset-best-practices/).
   아이폰에서 헤더는 가운데만 남고, 검색 결과는 약 385pt 폭으로 줄어 보인다. 그래서 글이 크다.

⚠️ 가격 · 할인 · 주소(URL) · 수상 · 다른 플랫폼 이름은 넣지 않는다(Apple 가이드).
"""
import os, signal, subprocess, sys, pathlib, tempfile, time

ROOT = pathlib.Path(__file__).resolve().parent.parent
# 기기 화면 재료: 레포의 원본 캡처. 언어마다 그 언어 화면을 쓴다(docs/screenshots/raw/<언어>/).
# capture_simulator.sh 가 찍은 scripts/screens/build/sim/<언어>_<화면>.png 에서 옮겨 둔다.
RAW = ROOT / "docs" / "screenshots" / "raw"
OUT = ROOT / "docs" / "screenshots" / "creative"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# 앱 언어 코드 → App Store Connect 로케일 (deploy.env LOCALES=ko,en-US,ja,en-GB,zh-Hans,zh-Hant,ru,es-ES,de-DE,fr-FR,it,pt-BR,th,vi,cs,da,el,fi,id,no,nl-NL)
STORE = {"en": "en-US", "ja": "ja", "zh-Hans": "zh-Hans", "zh-Hant": "zh-Hant", "ru": "ru", "es": "es-ES", "de": "de-DE", "fr": "fr-FR", "it": "it", "pt-BR": "pt-BR", "th": "th", "vi": "vi", "cs": "cs", "da": "da", "el": "el", "fi": "fi", "id": "id", "nb": "no", "nl": "nl-NL"}

# (가로, 세로, 안전 영역 left, top, right, bottom)
SPEC = {
    "header": (3840, 1646, (1097, 493, 2743, 1154)),
    "search": (3840, 2560, (836, 765, 3004, 1795)),
}

# 검색 결과는 스크린샷 1장(01-banner "현수막 든 단체사진, 현수막 없이")과 같은 이야기다.
# 눈썹글은 그 나라 사람이 검색창에 칠 말.
SEARCH = {
    "ko": ("단체사진 현수막", "현수막 든 단체사진<br>현수막 없이", "바닥을 탭하면 모두의 앞에 현수막이 놓여요"),
    "en": ("Group photo banner", "The banner photo,<br>no printing", "Tap the ground and everyone's holding it"),
    "ja": ("集合写真 横断幕", "横断幕なしで<br>横断幕の集合写真", "床をタップすると、みんなの前に横断幕が置かれます"),
    "zh-Hans": ("合影 横幅", "不用印横幅，<br>也能拍横幅合影", "点一下地面，横幅就出现在大家面前"),
    "zh-Hant": ("團體照 布條", "不用印布條，<br>也能拍布條團體照", "點一下地面，布條就出現在大家面前"),
    "ru": ("Групповое фото с баннером", "Групповое фото<br>с баннером без печати", "Коснитесь пола — и баннер у всех в руках"),
    "es": ("Pancarta foto de grupo", "La foto de grupo con<br>pancarta, sin imprimir", "Toca el suelo y todos la sujetan"),
    "de": ("Gruppenfoto Banner", "Das Gruppenfoto mit Banner,<br>ohne Druck", "Tippe auf den Boden — alle halten es"),
    "fr": ("Banderole photo de groupe", "La photo de groupe avec<br>banderole, sans impression", "Touchez le sol : tout le monde la tient"),
    "it": ("Striscione foto di gruppo", "La foto di gruppo con<br>striscione, senza stampa", "Tocca il pavimento e tutti lo reggono"),
    "pt-BR": ("Faixa foto em grupo", "A foto em grupo com faixa,<br>sem imprimir", "Toque no chão e todos seguram a faixa"),
    "th": ("แบนเนอร์ ภาพหมู่", "ภาพหมู่ถือแบนเนอร์<br>ไม่ต้องสั่งพิมพ์", "แตะที่พื้น ทุกคนก็ถือแบนเนอร์"),
    "vi": ("Băng rôn ảnh nhóm", "Ảnh nhóm có băng rôn,<br>không cần in", "Chạm vào sàn, ai cũng cầm băng rôn"),
    "cs": ("Banner skupinová fotka", "Skupinová fotka s bannerem<br>bez tisku", "Klepněte na podlahu a všichni ho drží"),
    "da": ("Banner gruppebillede", "Gruppebilledet med banner,<br>uden at printe", "Tryk på gulvet, så holder alle det"),
    "el": ("Πανό ομαδική φωτογραφία", "Η ομαδική φωτογραφία με πανό<br>χωρίς εκτύπωση", "Πατήστε στο δάπεδο και όλοι το κρατούν"),
    "fi": ("Banneri ryhmäkuva", "Ryhmäkuva bannerilla,<br>ilman painatusta", "Napauta lattiaa, niin kaikki pitelevät sitä"),
    "id": ("Spanduk foto grup", "Foto grup bersama spanduk,<br>tanpa cetak", "Ketuk lantai, semua ikut memegangnya"),
    "nb": ("Banner gruppebilde", "Gruppebildet med banner,<br>uten å skrive ut", "Trykk på gulvet, så holder alle det"),
    "nl": ("Spandoek groepsfoto", "De groepsfoto met spandoek,<br>zonder te printen", "Tik op de vloer en iedereen houdt het vast"),
}

# 헤더는 한 가지 약속: 우리 모임 현수막을 들고 찍는 단체사진.
# ⚠️ 기계번역하지 않는다. 언어마다 따로 쓴다.
HEADER = {
    "ko": ("현수막 단체사진", "우리 모임 현수막,<br>화면에 띄워 찰칵"),
    "en": ("Group photo banner", "Your banner,<br>in every group shot"),
    "ja": ("集合写真 横断幕", "みんなの横断幕を<br>そのまま写真に"),
    "zh-Hans": ("横幅合影", "把你们的横幅，<br>带进每张合影"),
    "zh-Hant": ("布條團體照", "把你們的布條，<br>帶進每張團體照"),
    "ru": ("Фото с баннером", "Ваш баннер —<br>в каждом кадре"),
    "es": ("Foto de grupo con pancarta", "Tu pancarta,<br>en cada foto de grupo"),
    "de": ("Gruppenfoto mit Banner", "Euer Banner<br>auf jedem Gruppenfoto"),
    "fr": ("Photo de groupe banderole", "Votre banderole,<br>sur chaque photo de groupe"),
    "it": ("Foto di gruppo con striscione", "Il vostro striscione<br>in ogni foto di gruppo"),
    "pt-BR": ("Foto em grupo com faixa", "A faixa de vocês<br>em toda foto em grupo"),
    "th": ("ภาพหมู่ถือแบนเนอร์", "แบนเนอร์ของพวกเรา<br>อยู่ในทุกภาพหมู่"),
    "vi": ("Ảnh nhóm cầm băng rôn", "Băng rôn của nhóm bạn<br>trong mọi bức ảnh"),
    "cs": ("Skupinová fotka s bannerem", "Váš banner<br>na každé společné fotce"),
    "da": ("Gruppebillede med banner", "Jeres banner<br>på alle gruppebilleder"),
    "el": ("Ομαδική φωτογραφία με πανό", "Το πανό της παρέας σας<br>σε κάθε ομαδική φωτογραφία"),
    "fi": ("Ryhmäkuva bannerilla", "Teidän banneri<br>jokaisessa ryhmäkuvassa"),
    "id": ("Foto grup dengan spanduk", "Spanduk kalian<br>di setiap foto grup"),
    "nb": ("Gruppebilde med banner", "Deres banner<br>i hvert gruppebilde"),
    "nl": ("Groepsfoto met spandoek", "Jullie spandoek<br>op elke groepsfoto"),
}

# ⚠️ 바탕 · 글자색은 마케팅 스크린샷(scripts/screens/make_marketing_screenshots.py)과 같다.
#    눈썹글은 앱 액센트(노랑 #FFCC00) 알약.
BASE_CSS = """
* { margin:0; padding:0; box-sizing:border-box; }
html,body { width:%(W)dpx; height:%(H)dpx; overflow:hidden; }
body { background:#f4f4f5; position:relative; -webkit-font-smoothing:antialiased;
  font-family:-apple-system, "SF Pro Display", "Apple SD Gothic Neo", sans-serif; }
.glow { position:absolute; border-radius:50%%; filter:blur(170px); pointer-events:none; }
.text { position:absolute; display:flex; flex-direction:column; justify-content:center; align-items:flex-start; }
.eyebrow { font-weight:700; color:#141416; background:#FFCC00; border-radius:999px; padding:.28em .8em;
  letter-spacing:-0.01em; line-height:1.15; }
.headline { font-weight:800; color:#141416; letter-spacing:-0.025em; line-height:1.2; text-wrap:balance; }
.sub { font-weight:500; color:#8a8a90; letter-spacing:-0.01em; line-height:1.4; text-wrap:balance; }
:lang(ko) .headline, :lang(ko) .sub, :lang(ko) .eyebrow { word-break:keep-all; }
.phone { position:absolute; background:#17171a; border:6px solid #3a3a3e;
  box-shadow:0 60px 160px rgba(0,0,0,.28); }
.phone img { display:block; width:100%%; }
"""

# 글이 상자를 넘지 않을 때까지 줄인다. 잘리는 글은 없다 - 끝까지 안 맞으면 표시하고 멈춘다.
FIT_JS = """
<script>
// 문구에 적은 줄(<br>)보다 더 쪼개지면 "Rispondi / con un / tocco" 처럼 읽기가 끊긴다.
// 적은 줄 수를 지킬 때까지 줄인다.
function lines(el) {
  return Math.round(el.getBoundingClientRect().height / parseFloat(getComputedStyle(el).lineHeight));
}
function fit(box, el, max, min) {
  const want = el.querySelectorAll('br').length + 1;
  let size = max;
  el.style.fontSize = size + 'px';
  while (size > min && (box.scrollHeight > box.clientHeight + 1 || box.scrollWidth > box.clientWidth + 1 ||
         lines(el) > want)) {
    size -= 4; el.style.fontSize = size + 'px';
  }
  if (box.scrollHeight > box.clientHeight + 1 || box.scrollWidth > box.clientWidth + 1 || lines(el) > want)
    document.body.dataset.overflow = '1';
}
document.fonts.ready.then(() => {
  const box = document.querySelector('.text');
  const h = document.querySelector('.headline');
  fit(box, h, +h.dataset.max, +h.dataset.min);
  document.body.dataset.done = '1';
});
</script>
"""


TMP = pathlib.Path(tempfile.gettempdir()) / "shutterlink-creative"
# ⚠️ 프로필을 따로 쓴다. 기본 프로필을 다른 Chrome 과 같이 쓰면 잠금에 걸려 멈춘다.
PROFILE = TMP / "chrome-profile"


def phone(img, left, top, width, rotate=0):
    pad = round(width * 0.04)
    return (f'<div class="phone" style="left:{left}px;top:{top}px;width:{width}px;padding:{pad}px;'
            f'border-radius:{round(width * 0.19)}px;transform:rotate({rotate}deg)">'
            f'<img src="{(RAW / img).as_uri()}" style="border-radius:{round(width * 0.155)}px"></div>')


def search_html(lang):
    W, H, (l, t, r, b) = SPEC["search"]
    eyebrow, headline, sub = SEARCH[lang]
    sw, sh = r - l, b - t
    col = int(sw * 0.58)
    x = l + col + 40
    # 현수막 디자인 뒤, 현수막을 띄운 카메라 화면 앞
    return f"""
<div class="glow" style="left:{x - 200}px;top:500px;width:1800px;height:1800px;background:rgba(255,204,0,.22)"></div>
{phone(f"{lang}/bannerDesign.png", x + 680, t - 300, 820, 8)}
{phone(f"{lang}/banner.png", x + 110, t - 200, 860, -4)}
<div class="text" style="left:{l}px;top:{t}px;width:{col}px;height:{sh}px">
  <div class="eyebrow" style="font-size:84px">{eyebrow}</div>
  <div class="headline" data-max="230" data-min="130" style="margin-top:56px">{headline}</div>
  <div class="sub" style="font-size:78px;margin-top:56px">{sub}</div>
</div>"""


def header_html(lang):
    W, H, (l, t, r, b) = SPEC["header"]
    eyebrow, headline = HEADER[lang]
    sw, sh = r - l, b - t
    return f"""
<div class="glow" style="left:{l - 200}px;top:{t - 400}px;width:{sw + 400}px;height:{sh + 800}px;background:rgba(255,204,0,.14)"></div>
{phone(f"{lang}/banner.png", 330, 330, 640, -8)}
{phone(f"{lang}/bannerDesign.png", 2870, 330, 640, 8)}
<div class="text" style="left:{l}px;top:{t}px;width:{sw}px;height:{sh}px;align-items:center;text-align:center">
  <div class="eyebrow" style="font-size:72px">{eyebrow}</div>
  <div class="headline" data-max="200" data-min="110" style="margin-top:36px">{headline}</div>
</div>"""


def html_lang(lang):
    return lang


def chrome(args, log, done, timeout=300):
    """헤드리스 Chrome 을 띄우고 done() 이 참이 되면 끈다.
    ⚠️ 이 맥에서는 Chrome 이 일을 다 하고도 끝나지 않고 매달려 있는 일이 있다(업데이터 자식 프로세스).
       그래서 끝나기를 기다리지 않고 결과(DOM 출력·PNG 파일)가 나오면 프로세스 묶음을 통째로 끈다."""
    TMP.mkdir(exist_ok=True)
    with open(log, "w") as out:
        proc = subprocess.Popen([CHROME, "--headless=new", f"--user-data-dir={PROFILE}", "--no-first-run",
                                 "--disable-component-update", *args],
                                stdout=out, stderr=subprocess.DEVNULL, start_new_session=True)
        ok = False
        end = time.time() + timeout
        while time.time() < end:
            time.sleep(1)
            if done():
                ok = True
                break
            if proc.poll() is not None:
                ok = done()
                break
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except OSError:
            proc.kill()
        # 이 프로필을 쓰는 남은 Chrome 프로세스(렌더러 등)도 끈다
        subprocess.run(["pkill", "-9", "-f", f"--user-data-dir={PROFILE}"], capture_output=True)
        proc.wait()
    return ok


def render(lang, kind):
    W, H, _ = SPEC[kind]
    body = search_html(lang) if kind == "search" else header_html(lang)
    page = (f'<!doctype html><html lang="{html_lang(lang)}"><head><meta charset="utf-8"><style>'
            f'{BASE_CSS % {"W": W, "H": H}}</style></head><body>{body}{FIT_JS}</body></html>')
    html_path = pathlib.Path(tempfile.gettempdir()) / f"shutterlink-creative-{lang}-{kind}.html"
    html_path.write_text(page, encoding="utf-8")
    # 글이 끝까지 안 맞으면 그림을 만들지 않는다(잘린 글이 스토어에 올라가는 것보다 낫다).
    flags = [f"--window-size={W},{H}", "--force-device-scale-factor=1", "--disable-gpu",
             "--virtual-time-budget=3000", "--allow-file-access-from-files"]
    dom_txt = TMP / f"{lang}-{kind}.dom"
    chrome(["--dump-dom", *flags, html_path.as_uri()], dom_txt,
           lambda: "</html>" in dom_txt.read_text(errors="ignore"))
    dom = dom_txt.read_text(errors="ignore")
    if 'data-done="1"' not in dom:
        raise SystemExit(f"글 맞추기가 끝나지 않았다: {lang} {kind}")
    if 'data-overflow="1"' in dom:
        raise SystemExit(f"글이 안전 영역을 넘는다: {lang} {kind} - 문구를 줄일 것")
    out_dir = OUT / STORE.get(lang, lang)
    out_dir.mkdir(parents=True, exist_ok=True)
    out_png = out_dir / f"{kind}.png"
    out_png.unlink(missing_ok=True)
    sizes = []

    def written():
        sizes.append(out_png.stat().st_size if out_png.exists() else 0)
        return len(sizes) > 2 and sizes[-1] > 0 and sizes[-1] == sizes[-2] == sizes[-3]
    if not chrome([f"--screenshot={out_png}", "--hide-scrollbars", *flags, html_path.as_uri()],
                  TMP / f"{lang}-{kind}.log", written):
        raise SystemExit(f"Chrome 이 그리지 못했다: {out_png}")
    print(f"rendered {out_png}")


if __name__ == "__main__":
    langs = sys.argv[1:] or list(SEARCH)
    for lang in langs:
        if lang not in SEARCH:
            raise SystemExit(f"모르는 언어: {lang} (아는 것: {', '.join(SEARCH)})")
        for kind in ("header", "search"):
            render(lang, kind)
