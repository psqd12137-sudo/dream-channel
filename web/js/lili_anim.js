/** Lili idle frame animator — shared clock for title / HUD / map tokens. */
(function (global) {
  const FRAME_COUNT = 12;
  const FPS = 8;
  const FRAMES = Array.from({ length: FRAME_COUNT }, (_, i) => {
    const n = String(i + 1).padStart(2, "0");
    return `assets/ui/chars/lili_idle/frame_${n}.png`;
  });
  const STAND = "assets/ui/chars/SP_Lili_Stand.png";

  let idx = 0;
  let timer = null;
  const imgs = new Set();

  function frameSrc(i = idx) {
    return FRAMES[((i % FRAME_COUNT) + FRAME_COUNT) % FRAME_COUNT];
  }

  function paint() {
    const src = frameSrc();
    for (const img of imgs) {
      if (!img.isConnected) {
        imgs.delete(img);
        continue;
      }
      if (img.getAttribute("src") !== src) img.setAttribute("src", src);
    }
  }

  function tick() {
    idx = (idx + 1) % FRAME_COUNT;
    paint();
  }

  function start() {
    if (timer != null) return;
    paint();
    timer = global.setInterval(tick, Math.round(1000 / FPS));
  }

  function stop() {
    if (timer == null) return;
    global.clearInterval(timer);
    timer = null;
  }

  function register(img) {
    if (!img) return;
    imgs.add(img);
    img.setAttribute("src", frameSrc());
    start();
  }

  function registerAll(root = document) {
    root.querySelectorAll("[data-lili-anim] img, img[data-lili-anim]").forEach(register);
  }

  /** Markup for map / battle pawns (re-rendered often). */
  function tokenHtml({ cls = "char-token map-token", alt = "你", width = 34, height = 34 } = {}) {
    return (
      `<span class="lili-anim lili-anim-token" data-lili-anim="idle">` +
      `<img class="${cls}" data-lili-anim="idle" src="${frameSrc()}" alt="${alt}" width="${width}" height="${height}" draggable="false" />` +
      `</span>`
    );
  }

  function preload() {
    FRAMES.forEach((src) => {
      const im = new Image();
      im.src = src;
    });
    const stand = new Image();
    stand.src = STAND;
  }

  function boot() {
    preload();
    registerAll(document);
    // Re-scan when battle/map DOM is rebuilt
    const mo = new MutationObserver((mutations) => {
      for (const m of mutations) {
        for (const node of m.addedNodes) {
          if (node.nodeType !== 1) continue;
          if (node.matches?.("[data-lili-anim] img, img[data-lili-anim]")) register(node);
          else if (node.querySelectorAll) registerAll(node);
        }
      }
    });
    mo.observe(document.documentElement, { childList: true, subtree: true });
    start();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }

  global.LiliAnim = {
    FRAMES,
    STAND,
    frameSrc,
    register,
    registerAll,
    tokenHtml,
    start,
    stop,
  };
})(window);
