/** Simple timed key QTE — placeholder for puzzle / event trials. */
(function (global) {
  const POOL = [
    { key: "a", label: "A", match: (e) => e.key.toLowerCase() === "a" },
    { key: "d", label: "D", match: (e) => e.key.toLowerCase() === "d" },
    { key: "w", label: "W", match: (e) => e.key.toLowerCase() === "w" || e.key === "ArrowUp" },
    { key: "s", label: "S", match: (e) => e.key.toLowerCase() === "s" || e.key === "ArrowDown" },
    { key: "j", label: "J", match: (e) => e.key.toLowerCase() === "j" },
    { key: "k", label: "K", match: (e) => e.key.toLowerCase() === "k" },
    { key: "space", label: "空格", match: (e) => e.code === "Space" || e.key === " " },
  ];

  const STEP_MS = 1100;
  const STEPS = 4;

  let active = false;
  let sequence = [];
  let index = 0;
  let deadline = 0;
  let raf = 0;
  let onDone = null;
  let ignoreUntil = 0;

  function $(id) {
    return document.getElementById(id);
  }

  function pickSequence(n) {
    const out = [];
    let last = -1;
    for (let i = 0; i < n; i++) {
      let idx = Math.floor(Math.random() * POOL.length);
      if (idx === last) idx = (idx + 1) % POOL.length;
      last = idx;
      out.push(POOL[idx]);
    }
    return out;
  }

  function setPrompt(step) {
    const el = $("qte-prompt");
    const meta = $("qte-meta");
    const fill = $("qte-timer-fill");
    if (!el) return;
    if (!step) {
      el.textContent = "—";
      if (meta) meta.textContent = "";
      if (fill) fill.style.transform = "scaleX(0)";
      return;
    }
    el.textContent = step.label;
    el.classList.remove("qte-flash");
    void el.offsetWidth;
    el.classList.add("qte-flash");
    if (meta) meta.textContent = `${index + 1} / ${sequence.length}`;
    if (fill) fill.style.transform = "scaleX(1)";
  }

  function tick() {
    if (!active) return;
    const left = Math.max(0, deadline - performance.now());
    const fill = $("qte-timer-fill");
    if (fill) fill.style.transform = `scaleX(${left / STEP_MS})`;
    if (left <= 0) {
      finish(false, "慢了半拍——信号溜走了。");
      return;
    }
    raf = requestAnimationFrame(tick);
  }

  function advance() {
    index += 1;
    if (index >= sequence.length) {
      finish(true, "咬住了节奏。考验过关。");
      return;
    }
    deadline = performance.now() + STEP_MS;
    setPrompt(sequence[index]);
  }

  function onKey(e) {
    if (!active) return;
    if (performance.now() < ignoreUntil) return;
    if (["Tab", "Escape"].includes(e.key)) return;
    e.preventDefault();
    const step = sequence[index];
    if (!step) return;
    if (step.match(e)) {
      advance();
    } else {
      finish(false, "按错了——回声嘲笑了一下。");
    }
  }

  function finish(ok, message) {
    if (!active) return;
    active = false;
    cancelAnimationFrame(raf);
    raf = 0;
    window.removeEventListener("keydown", onKey, true);
    const status = $("qte-status");
    if (status) {
      status.textContent = message;
      status.className = "qte-status " + (ok ? "ok" : "bad");
    }
    const prompt = $("qte-prompt");
    if (prompt) prompt.classList.toggle("qte-fail", !ok);
    const fill = $("qte-timer-fill");
    if (fill) fill.style.transform = "scaleX(0)";
    const cb = onDone;
    onDone = null;
    // brief beat so player reads result
    setTimeout(() => {
      if (typeof cb === "function") cb({ ok, message });
    }, 420);
  }

  /**
   * @param {{ title?: string, lead?: string, onDone?: (r:{ok:boolean,message:string})=>void }} opts
   */
  function start(opts = {}) {
    stop();
    const title = $("qte-title");
    const lead = $("qte-lead");
    const status = $("qte-status");
    if (title) title.textContent = opts.title || "信号咬合";
    if (lead) {
      lead.textContent =
        opts.lead ||
        "按屏幕提示的键，在时间条耗尽前跟上节奏。解谜事件的临时玩具——有点金山打字的年代味，以后可换成拼图 / 微缩搜物。";
    }
    if (status) {
      status.textContent = "准备…";
      status.className = "qte-status";
    }
    sequence = pickSequence(STEPS);
    index = 0;
    onDone = opts.onDone || null;
    active = true;
    ignoreUntil = performance.now() + 280;
    deadline = performance.now() + STEP_MS + 280;
    setPrompt(sequence[0]);
    window.addEventListener("keydown", onKey, true);
    raf = requestAnimationFrame(tick);
  }

  function stop() {
    active = false;
    cancelAnimationFrame(raf);
    raf = 0;
    window.removeEventListener("keydown", onKey, true);
    onDone = null;
    setPrompt(null);
  }

  function isRunning() {
    return active;
  }

  global.CabinQte = { start, stop, isRunning };
})(window);
