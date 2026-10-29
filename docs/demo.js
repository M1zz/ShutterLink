// ShutterLink 웹 체험: 문구를 쓰고 테마를 고르면 단체사진 앞에 현수막이 놓이고, 3초 타이머로 찍는다.
// 테마 값은 앱과 같다 (BannerDesign.swift 의 BannerTheme.all). 현수막 배치는 BannerCanvasView 의 비율을 따른다.
(() => {
  const root = document.getElementById("demo");
  if (!root) return;
  const T = JSON.parse(root.dataset.text);

  // id, 배경, 배경색, 강조색, 윗줄 색, 가운데 줄 색, 아랫줄 색, 글꼴, 장식
  const THEMES = [
    ["classic", "solid", "#fff", "#cc1a1f", "#cc1a1f", "#1a1a1a", "#4c4c4c", "bold", ""],
    ["autumn", "solid", "#fff", "#db4c1f", "#db4c1f", "#1f1f1f", "#4c4c4c", "rounded", "🍂🍁🍃"],
    ["spring", "gradient", "#fff2f5", "#ed6b99", "#d94c80", "#592e42", "#80596b", "rounded", "🌸🌼🌷"],
    ["summer", "gradient", "#e0f7ff", "#008ccc", "#0080bf", "#053359", "#265980", "rounded", "🌊🐚☀️"],
    ["winter", "gradient", "#edf7ff", "#4c8cd9", "#4080cc", "#1a3366", "#4c668c", "rounded", "❄️⛄️✨"],
    ["party", "solid", "#141a40", "#f2c74c", "#f2c74c", "#fff", "#ccd1eb", "bold", "🎉✨🎊"],
    ["yearEnd", "bands", "#9e0f1a", "#edc259", "#f5d173", "#fff", "#fae0cc", "serif", "🎄🎁⭐️"],
    ["birthday", "solid", "#fff7cc", "#e6408c", "#e6408c", "#4c1a59", "#734c73", "rounded", "🎈🎁🎈"],
    ["sports", "bands", "#fff", "#0d59cc", "#0d59cc", "#0d1433", "#404c66", "condensed", "⚽️🏅🏆"],
    ["cheer", "diagonal", "#ffd91a", "#1a1a1a", "#1a1a1a", "#1a1a1a", "#404040", "condensed", "⭐️✨🌟"],
    ["graduation", "stripe", "#fcf7e8", "#1a5940", "#1a5940", "#1f1f1f", "#595447", "serif", "🎓💐📜"],
    ["wedding", "solid", "#fffcf7", "#c79e66", "#b28c59", "#403833", "#736659", "serif", "💖💕💗"],
    ["workshop", "stripe", "#fff", "#0f2659", "#0f2659", "#0f2659", "#596173", "condensed", ""],
  ];
  // 장식 자리: 위아래 가장자리에 흩어 놓는다 (BannerCanvasView.slot)
  const SLOTS = [0.07, 0.14, 0.23, 0.77, 0.86, 0.93, 0.10, 0.30, 0.70, 0.90].map((x, i) => [x,
    i < 6 ? (i % 2 ? 0.86 : 0.14) : (i % 2 ? 0.10 : 0.90), ((i * 37) % 60) - 30, i % 3 ? 0.9 : 1.2]);
  const PEOPLE = ["#f28c28", "#1fb5b0", "#e8455f", "#6a5ae0", "#3cb85c"];
  const SKIN = ["#f6d2b0", "#e0a982", "#f3c9a1", "#9a6844", "#f1c39c"];
  const esc = s => s.replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

  root.innerHTML = `
    <div class="sl-stage" aria-hidden="true">
      <div class="sl-sun"></div><div class="sl-hill a"></div><div class="sl-hill b"></div>
      <div class="sl-people">${PEOPLE.map((c, i) => `<i style="--c:${c};--s:${SKIN[i]}"></i>`).join("")}</div>
      <div class="sl-banner"><div class="sl-deco"></div>
        <div class="sl-text"><b></b><strong></strong><small></small></div></div>
      <div class="sl-count"></div><div class="sl-flash"></div>
    </div>
    <div class="sl-controls">
      <fieldset class="sl-lines"><legend>${esc(T.textLabel)}</legend>
        ${T.lines.map((l, i) => `<input type="text" maxlength="40" value="${esc(l)}" aria-label="${esc(T.fields[i])}" data-line="${i}">`).join("")}
      </fieldset>
      <fieldset class="sl-themes"><legend>${esc(T.themeLabel)}</legend>
        ${THEMES.map((t, i) => `<button type="button" class="chip" data-theme="${i}" aria-pressed="false">${esc(T.themes[i])}</button>`).join("")}
      </fieldset>
      <button type="button" class="sl-shutter"><span class="dot" aria-hidden="true"></span>${esc(T.shutter)}</button>
      <p class="sl-status" aria-live="polite"></p>
      <p class="muted small">${esc(T.note)}</p>
    </div>`;

  const $ = s => root.querySelector(s);
  const banner = $(".sl-banner"), deco = $(".sl-deco"), stage = $(".sl-stage");
  const [top, mid, foot] = banner.querySelectorAll(".sl-text > *");
  const count = $(".sl-count"), flash = $(".sl-flash"), shutter = $(".sl-shutter"), status = $(".sl-status");
  let theme = 1;   // 앱의 기본 테마: 가을 야유회

  function render() {
    const [, bg, base, accent, c1, c2, c3, font, symbols] = THEMES[theme];
    banner.className = `sl-banner bg-${bg} font-${font}`;
    banner.style.cssText = `--bg:${base};--ac:${accent};--c1:${c1};--c2:${c2};--c3:${c3}`;
    const sym = [...symbols.matchAll(/\p{Extended_Pictographic}️?/gu)].map(m => m[0]);
    deco.innerHTML = sym.length ? SLOTS.map(([x, y, r, s], i) =>
      `<span style="left:${x * 100}%;top:${y * 100}%;--r:${r}deg;--k:${s}">${sym[i % sym.length]}</span>`).join("") : "";
    const v = [...root.querySelectorAll("[data-line]")].map(el => el.value);
    top.textContent = v[0]; mid.textContent = v[1]; foot.textContent = v[2];
    root.querySelectorAll("[data-theme]").forEach(b => b.setAttribute("aria-pressed", String(+b.dataset.theme === theme)));
  }

  root.addEventListener("input", e => { if (e.target.dataset.line) render(); });
  root.addEventListener("click", e => {
    const b = e.target.closest("[data-theme]");
    if (b) { theme = +b.dataset.theme; render(); }
  });

  // 3초 타이머: 앱처럼 숫자를 세고 플래시가 같이 깜빡인 뒤 찍는다.
  const blink = () => { flash.classList.remove("on"); void flash.offsetWidth; flash.classList.add("on"); };
  shutter.addEventListener("click", () => {
    if (shutter.disabled) return;
    shutter.disabled = true; status.textContent = "";
    let n = 3;
    const tick = () => {
      if (n > 0) { count.textContent = n; count.classList.add("on"); blink(); n--; setTimeout(tick, 1000); return; }
      count.classList.remove("on"); count.textContent = "";
      blink(); stage.classList.add("shot");
      status.textContent = T.shot;
      setTimeout(() => { stage.classList.remove("shot"); shutter.disabled = false; }, 1600);
    };
    tick();
  });

  render();
})();
