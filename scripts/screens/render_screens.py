#!/usr/bin/env python3
"""ShutterLink 화면 재현 → 원본 스크린샷(1320x2868, iPhone 6.9") 렌더링.

카메라와 BLE는 시뮬레이터에서 동작하지 않으므로, SwiftUI 화면(ContentView, PairingSheet,
RemoteView)의 레이아웃·크기·문구를 그대로 HTML로 옮겨 그린다. 카메라 미리보기 자리는
assets/scene.svg 일러스트를 쓴다. UI를 바꾸면 이 파일도 함께 맞출 것.

실행: python3 scripts/screens/render_screens.py   (레포 최상단에서)
출력: docs/screenshots/raw/*.png
"""
import pathlib, subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
HERE = pathlib.Path(__file__).resolve().parent
ASSETS = HERE / "assets"
OUT = ROOT / "docs" / "screenshots" / "raw"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PT_W, PT_H, SCALE = 440, 956, 3   # iPhone 17 Pro Max points @3x = 1320x2868

def a(name):
    return (ASSETS / name).as_uri()

CSS = f"""
* {{ margin:0; padding:0; box-sizing:border-box; }}
html, body {{ width:{PT_W}px; height:{PT_H}px; overflow:hidden; background:#000; color:#fff;
  font-family:-apple-system, "SF Pro Text", sans-serif; -webkit-font-smoothing:antialiased; }}
.screen {{ position:relative; width:{PT_W}px; height:{PT_H}px; overflow:hidden; background:#000; }}
.ic {{ display:inline-block; background:currentColor; -webkit-mask:var(--m) center/contain no-repeat; mask:var(--m) center/contain no-repeat; }}

/* status bar */
.status {{ position:absolute; top:0; left:0; right:0; height:59px; z-index:50; display:flex; align-items:center;
  justify-content:space-between; padding:6px 34px 0 52px; font-weight:600; font-size:17px; letter-spacing:-.2px; }}
.island {{ position:absolute; top:11px; left:50%; transform:translateX(-50%); width:126px; height:37px; background:#000; border-radius:20px; z-index:60; }}
.status .right {{ display:flex; gap:6px; align-items:center; }}

.fill {{ position:absolute; inset:0; }}
.scene {{ background:#000 url({a('scene.svg')}) center/contain no-repeat; }}  /* videoGravity = .resizeAspect */

/* safe-area content: top 59, bottom 34, then .padding(.horizontal 20, .vertical 12) */
.content {{ position:absolute; top:59px; bottom:34px; left:0; right:0; padding:12px 20px;
  display:flex; flex-direction:column; align-items:center; gap:16px; }}
.row {{ width:100%; display:flex; align-items:center; justify-content:space-between; }}
.spacer {{ flex:1; }}

.capsule-label {{ display:flex; align-items:center; gap:6px; font-size:13px; font-weight:600;
  padding:8px 12px; background:rgba(0,0,0,.5); border-radius:999px; }}
.capsule-label .ic {{ width:18px; height:14px; }}
.circle-btn {{ width:44px; height:44px; border-radius:50%; background:rgba(0,0,0,.5); display:grid; place-items:center; }}
.circle-btn .ic {{ width:22px; height:22px; }}
.rec {{ font:600 17px ui-monospace, "SF Mono", monospace; padding:6px 10px; background:#ff3b30; border-radius:999px; }}

.chips {{ display:flex; gap:8px; }}
.chip {{ min-width:40px; height:32px; padding:0 8px; display:grid; place-items:center; font-size:13px; font-weight:600;
  background:rgba(0,0,0,.45); border-radius:999px; }}
.chip.on {{ color:#ffcc00; }}

.seg {{ display:flex; width:220px; height:32px; padding:2px; border-radius:9px; background:rgba(118,118,128,.24); }}
.seg div {{ flex:1; display:grid; place-items:center; font-size:13px; font-weight:500; border-radius:7px; }}
.seg .sel {{ background:#636366; font-weight:600; box-shadow:0 3px 8px rgba(0,0,0,.12); }}
.seg.dim {{ opacity:.5; }}

.bottom {{ width:100%; display:flex; align-items:center; justify-content:space-between; }}
.timer {{ width:56px; height:56px; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:2px; }}
.timer .ic {{ width:26px; height:26px; }}
.timer span {{ font-size:11px; font-weight:600; }}
.timer.on {{ color:#ffcc00; }}
.flip {{ width:56px; height:56px; border-radius:50%; background:rgba(0,0,0,.4); display:grid; place-items:center; }}
.flip .ic {{ width:28px; height:24px; }}
.shutter {{ position:relative; border-radius:50%; border:4px solid #fff; display:grid; place-items:center; }}
.shutter i {{ display:block; background:#fff; border-radius:50%; }}
.shutter.video i {{ background:#ff3b30; }}
.shutter.stop i {{ border-radius:6px; }}

.countdown {{ position:absolute; inset:0; display:grid; place-items:center; z-index:5;
  font:700 140px ui-rounded, "SF Pro Rounded", -apple-system; text-shadow:0 0 10px rgba(0,0,0,.6); }}
.home {{ position:absolute; bottom:8px; left:50%; transform:translateX(-50%); width:144px; height:5px; border-radius:3px; background:#fff; z-index:60; }}

/* camera settings bar (CameraSettingsBar) */
.settings {{ display:flex; gap:4px; padding:0 8px; background:rgba(0,0,0,.45); border-radius:999px; }}
.setting {{ width:56px; height:56px; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:2px; }}
.setting .ic {{ width:26px; height:24px; }}
.setting span {{ font-size:11px; font-weight:600; }}
.setting.on {{ color:#ffcc00; }}
.setting.dim {{ opacity:.4; }}
/* ExposureControl */
.ev {{ display:flex; align-items:center; background:rgba(0,0,0,.45); border-radius:999px; height:32px; }}
.ev .step {{ width:40px; height:32px; display:grid; place-items:center; }}
.ev .step .ic {{ width:12px; height:12px; }}
.ev .val {{ min-width:84px; display:flex; align-items:center; justify-content:center; gap:5px; font-size:13px; font-weight:600; font-variant-numeric:tabular-nums; }}
.ev .val .ic {{ width:15px; height:15px; }}
.ev .val.on {{ color:#ffcc00; }}
.badge {{ display:flex; align-items:center; gap:5px; font-size:13px; font-weight:600; color:#000; background:#ffcc00; padding:5px 10px; border-radius:999px; }}
.badge .ic {{ width:15px; height:14px; }}
/* video area: 3:4 scene, aspect-fit inside its box (videoGravity = .resizeAspect) */
.vbox {{ position:absolute; inset:0; container-type:size; display:grid; place-items:center; }}
.video {{ position:relative; width:min(100cqw, 75cqh); height:min(100cqh, 133.333cqw);
  background:url({a('scene.svg')}) center/cover no-repeat; }}
.gl {{ position:absolute; background:rgba(255,255,255,.45); }}
.reticle {{ position:absolute; border:1.5px solid #ffcc00; border-radius:4px; transform:translate(-50%,-50%); }}
.thumb {{ width:52px; height:52px; margin:2px; border-radius:10px; border:1.5px solid rgba(255,255,255,.8);
  background:url({a('scene.svg')}) center/cover no-repeat; }}
"""

def status_bar():
    return f"""<div class="island"></div><div class="status"><span>9:41</span>
<span class="right"><i class="ic" style="--m:url({a('cell.png')});width:19px;height:12px"></i>
<i class="ic" style="--m:url({a('wifi.png')});width:17px;height:12px"></i>
<i class="ic" style="--m:url({a('battery.png')});width:28px;height:13px"></i></span></div><div class="home"></div>"""

def icon(name, cls=""):
    return f'<i class="ic {cls}" style="--m:url({a(name)})"></i>'

def chips(active=1):
    out = []
    for v in [0.5, 1, 2, 3, 5, 10]:
        label = (f"{v:g}") + "×"
        out.append(f'<div class="chip{" on" if v == active else ""}">{label}</div>')
    return f'<div class="chips">{"".join(out)}</div>'

def seg(mode="photo", dim=False):
    p, v = ("sel", "") if mode == "photo" else ("", "sel")
    return f'<div class="seg{" dim" if dim else ""}"><div class="{p}">Photo</div><div class="{v}">Video</div></div>'

def shutter(size=76, mode="photo", recording=False, counting=False):
    inner = size * 0.4 if recording else size - 14
    cls = ("stop " if recording else "") + ("video" if mode == "video" else "")
    return (f'<div class="shutter {cls}" style="width:{size}px;height:{size}px">'
            f'<i style="width:{inner}px;height:{inner}px;opacity:{0.5 if counting else 1}"></i></div>')

# ---------- shared controls ----------

FLASH = {"off": ("flash-off.png", "Off"), "auto": ("flash-auto.png", "Auto"), "on": ("flash-on.png", "On")}

def setting(icon_name, title, on=False, dim=False):
    cls = " on" if on else ""
    if dim:
        cls += " dim"
    return f'<div class="setting{cls}">{icon(icon_name)}<span>{title}</span></div>'

def settings_bar(flash="off", timer_s=0, burst=1, interval=0, grid=False, busy=False, video_mode=False):
    if interval:
        drive = setting("drive-interval.png", f"{interval}s", on=True, dim=busy)
    elif burst > 1:
        drive = setting("drive-burst.png", f"×{burst}", on=True, dim=busy or video_mode)
    else:
        drive = setting("drive-single.png", "Single", dim=busy or video_mode)
    f_icon, f_title = FLASH[flash]
    t = setting("timer-fill.png", f"{timer_s}s", on=True) if timer_s else setting("timer.png", "Off")
    return (f'<div class="settings">{setting(f_icon, f_title, on=flash != "off")}{t}{drive}'
            f'{setting("grid.png", "Grid", on=grid)}</div>')

def exposure(value=0.0):
    label = "±0.0" if value == 0 else f"{value:+.1f}"
    return (f'<div class="ev"><div class="step">{icon("minus.png")}</div>'
            f'<div class="val{" on" if value else ""}">{icon("exposure.png")}{label}</div>'
            f'<div class="step">{icon("plus.png")}</div></div>')

def interval_badge(next_s):
    return f'<div class="badge">{icon("drive-interval-sm.png")}Next shot in {next_s}s</div>'

def video(grid=False, reticle=None, reticle_size=72, countdown_px=140, countdown=None):
    """3:4 scene aspect-fit in its box. reticle = (x%, y%) inside the video."""
    lines = ""
    if grid:
        lines = "".join(f'<div class="gl" style="left:{p}%;top:0;bottom:0;width:1px"></div>'
                        f'<div class="gl" style="top:{p}%;left:0;right:0;height:1px"></div>' for p in (33.333, 66.667))
    ret = ""
    if reticle:
        ret = (f'<div class="reticle" style="left:{reticle[0]}%;top:{reticle[1]}%;'
               f'width:{reticle_size}px;height:{reticle_size}px"></div>')
    cd = ""
    if countdown:
        cd = (f'<div style="position:absolute;inset:0;display:grid;place-items:center;font:700 {countdown_px}px ui-rounded,'
              f'\'SF Pro Rounded\',-apple-system;text-shadow:0 0 10px rgba(0,0,0,.6)">{countdown}</div>')
    return f'<div class="vbox"><div class="video">{lines}{ret}</div>{cd}</div>'

# ---------- camera phone (ShutterLink) ----------

def camera_screen(connected=True, flash="auto", timer_s=0, burst=1, interval=0, grid=True, ev=0.0, reticle=None, zoom=1):
    label = ("Remote connected", "iphone-radiowaves.png", "#30d158") if connected else ("Waiting for a remote", "radiowaves.png", "#fff")
    return f"""<div class="screen"><div class="fill">{video(grid, reticle)}</div>{status_bar()}
<div class="content">
  <div class="row"><div class="capsule-label" style="color:{label[2]}">{icon(label[1])}{label[0]}</div>
    <div class="circle-btn">{icon("qrcode.png")}</div></div>
  {settings_bar(flash, timer_s, burst, interval, grid)}
  <div class="spacer"></div>
  {exposure(ev)}
  {chips(zoom)}
  {seg()}
  <div class="bottom"><div class="thumb"></div>{shutter()}<div class="flip">{icon("flip.png")}</div></div>
</div></div>"""

def pairing_screen():
    # Large-detent sheet over the camera screen.
    return f"""<div class="screen"><div class="fill scene" style="transform:scale(.92);border-radius:38px;filter:brightness(.55);top:6px"></div>
{status_bar()}
<div style="position:absolute;top:66px;left:0;right:0;bottom:0;background:#1c1c1e;border-radius:38px 38px 0 0;z-index:10">
  <div style="height:56px;display:flex;justify-content:flex-end;align-items:center;padding:0 20px">
    <span style="font-size:17px;font-weight:600;color:#ffcc00">Done</span></div>
  <div style="padding:8px 24px 24px;display:flex;flex-direction:column;align-items:center;gap:20px;text-align:center">
    <div style="font-size:22px;font-weight:700">Scan with another iPhone</div>
    <div style="background:#fff;border-radius:20px;padding:16px"><img src="{a('qr.png')}" style="width:260px;height:260px;image-rendering:pixelated;display:block"></div>
    <div style="display:flex;flex-direction:column;align-items:center;gap:4px">
      <div style="font-size:12px;color:rgba(235,235,245,.6)">Pairing code</div>
      <div style="font:700 44px ui-monospace,'SF Mono',monospace;letter-spacing:8px;margin-right:-8px">4827</div></div>
    <div style="font-size:16px;line-height:21px;color:rgba(235,235,245,.6)">Point the other iPhone's Camera at the QR code. The ShutterLink Remote App Clip opens without installing anything. Keep this app open while shooting.</div>
    <div style="display:flex;align-items:center;gap:8px;font-size:17px;font-weight:600;color:rgba(235,235,245,.6)">
      {icon("radiowaves.png")}<span>Waiting for a remote</span></div>
  </div>
</div>
<style>.screen [style*="radiowaves"] {{ width:24px; height:18px; }}</style></div>"""

# ---------- remote phone (ShutterLinkClip) ----------

def remote_screen(mode="photo", recording=False, rec_time="00:42", countdown=None, flash="off", timer_s=0,
                  burst=1, interval=0, interval_next=None, grid=False, ev=0.0, reticle=None, zoom=1):
    busy = recording or interval_next is not None
    if recording:
        mid = f'<div class="rec" style="padding:4px 10px">{rec_time}</div>'
    elif interval_next is not None:
        mid = interval_badge(interval_next)
    else:
        mid = ""
    return f"""<div class="screen">{status_bar()}
<div class="content" style="gap:14px">
  <div class="row"><div style="display:flex;align-items:center;gap:6px;font-size:13px;font-weight:600;color:#30d158">
      {icon("radiowaves.png")}<span>Connected</span></div>
    {mid}<span style="font-size:13px;color:#ffcc00">Disconnect</span></div>
  {settings_bar(flash, timer_s, burst, interval, grid, busy, mode == "video")}
  <div style="position:relative;flex:1;width:100%;border-radius:16px;overflow:hidden;background:rgba(255,255,255,.06)">
    {video(grid, reticle, 56, 96, countdown)}
  </div>
  {exposure(ev)}
  {chips(zoom)}
  <div style="width:240px;display:flex;justify-content:center">{seg(mode, dim=busy)}</div>
  <div style="width:100%;padding-bottom:8px"><div class="bottom"><div style="width:56px"></div>
    {shutter(88, mode, recording=busy, counting=countdown is not None)}
    <div class="flip" style="background:rgba(255,255,255,.12)">{icon("flip.png")}</div></div></div>
</div>
<style>.content .row [style*="radiowaves"] {{ width:18px; height:14px; }} .seg {{ width:240px; }}</style></div>"""

SCREENS = {
    "01-pairing.png": pairing_screen(),
    "02-focus.png": remote_screen(grid=True, reticle=(36, 60), ev=0.3, flash="auto"),
    "03-interval.png": remote_screen(interval=10, interval_next=7, grid=True),
    "04-burst.png": remote_screen(timer_s=3, burst=3, countdown=2),
    "05-camera.png": camera_screen(flash="auto", timer_s=3, grid=True, ev=-0.3, reticle=(62, 50)),
    "06-video.png": remote_screen(mode="video", recording=True, flash="on", zoom=2),
}

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    work = HERE / "build"
    work.mkdir(exist_ok=True)
    for name, body in SCREENS.items():
        html = work / name.replace(".png", ".html")
        html.write_text(f'<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head><body>{body}</body></html>', encoding="utf-8")
        subprocess.run([CHROME, "--headless=new", f"--screenshot={OUT / name}", f"--window-size={PT_W},{PT_H}",
                        f"--force-device-scale-factor={SCALE}", "--hide-scrollbars", "--disable-gpu",
                        "--allow-file-access-from-files", html.as_uri()], check=True, capture_output=True)
        print("rendered", OUT / name)

if __name__ == "__main__":
    main()
