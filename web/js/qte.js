/** 警察抓小偷 · 打字追逐（整句容错，静室考验） */
(function (global) {
  const SENTENCES = [
    "run for the cabin door now",
    "keep your boots quiet please",
    "dash past the rusted gate",
    "the hallway still bites hard",
    "slip through the mud and go",
    "climb the attic stair fast",
    "hide behind the salt line",
    "kick open the back door",
  ];

  const TRACK_LEN = 14;
  const PLAYER_START = 5;
  const POLICE_START = 0;
  const POLICE_SPEED = 0.12; // 格/秒；整句留给打字时间
  const SENTENCE_STEP = 10; // 打完一句基本到门（偶发第二句）
  const MISS_FLASH_MS = 220;
  const COUNTDOWN = [3, 2, 1, "跑！"];

  let active = false;
  let phase = "idle"; // idle | ready | countdown | race | done
  let onDone = null;
  let raf = 0;
  let sentence = "";
  let typed = 0;
  let playerPos = PLAYER_START;
  let policePos = POLICE_START;
  let lastTs = 0;
  let missUntil = 0;
  let usedSentences = new Set();
  let countdownIdx = 0;
  let countdownTimer = 0;

  function $(id) {
    return document.getElementById(id);
  }

  function pickSentence() {
    const pool = SENTENCES.filter((s) => !usedSentences.has(s));
    const bag = pool.length ? pool : SENTENCES.slice();
    const s = bag[Math.floor(Math.random() * bag.length)];
    usedSentences.add(s);
    if (usedSentences.size >= SENTENCES.length) usedSentences.clear();
    return s;
  }

  function setStatus(msg, tone) {
    const el = $("qte-status");
    if (!el) return;
    el.textContent = msg;
    el.className = "qte-status" + (tone ? ` ${tone}` : "");
  }

  function escapeHtml(ch) {
    if (ch === " ") return "&nbsp;";
    if (ch === "<") return "&lt;";
    if (ch === ">") return "&gt;";
    if (ch === "&") return "&amp;";
    return ch;
  }

  function renderSentence() {
    const el = $("qte-word");
    if (!el) return;
    if (!sentence) {
      el.innerHTML = "";
      return;
    }
    el.innerHTML = sentence
      .split("")
      .map((ch, i) => {
        let cls = i < typed ? "is-done" : i === typed ? "is-next" : "";
        if (i === typed && performance.now() < missUntil) cls += " is-miss";
        return `<span class="${cls}">${escapeHtml(ch)}</span>`;
      })
      .join("");
  }

  function renderTrack() {
    const track = $("qte-track");
    const meta = $("qte-meta");
    if (!track) return;
    const cells = [];
    for (let i = 0; i <= TRACK_LEN; i += 1) {
      let mark = "·";
      let cls = "qte-cell";
      if (i === TRACK_LEN) {
        mark = "门";
        cls += " is-goal";
      }
      const pHere = Math.round(playerPos) === i;
      const cHere = Math.round(policePos) === i;
      if (pHere && cHere) {
        mark = "抓";
        cls += " is-caught";
      } else if (pHere) {
        mark = "你";
        cls += " is-thief";
      } else if (cHere) {
        mark = "警";
        cls += " is-cop";
      }
      cells.push(`<span class="${cls}">${mark}</span>`);
    }
    track.innerHTML = cells.join("");
    if (meta) {
      const gap = Math.max(0, playerPos - policePos).toFixed(1);
      const left = Math.max(0, sentence.length - typed);
      meta.textContent = `间距 ${gap} · 终点 ${TRACK_LEN} · 本句剩 ${left} 字`;
    }
  }

  function setMissVisual(on) {
    const stage = $("qte-stage");
    const stun = $("qte-stun");
    if (stage) stage.classList.toggle("is-miss", on);
    if (stun) {
      stun.classList.toggle("hidden", !on);
      if (on) stun.textContent = "错字";
    }
  }

  function setCountdownVisual(text) {
    const el = $("qte-countdown");
    if (!el) return;
    if (text == null) {
      el.classList.add("hidden");
      el.textContent = "";
      return;
    }
    el.classList.remove("hidden");
    el.textContent = String(text);
    el.classList.remove("qte-pop");
    void el.offsetWidth;
    el.classList.add("qte-pop");
  }

  function showReady(show) {
    const btn = $("btn-qte-go");
    if (btn) btn.classList.toggle("hidden", !show);
    const hint = $("qte-ready-hint");
    if (hint) hint.classList.toggle("hidden", !show);
  }

  function nextSentence() {
    sentence = pickSentence();
    typed = 0;
    missUntil = 0;
    setMissVisual(false);
    renderSentence();
  }

  function finish(ok, message) {
    if (phase === "done") return;
    phase = "done";
    active = false;
    cancelAnimationFrame(raf);
    raf = 0;
    window.removeEventListener("keydown", onKey, true);
    setMissVisual(false);
    setCountdownVisual(null);
    showReady(false);
    setStatus(message, ok ? "ok" : "bad");
    const cb = onDone;
    onDone = null;
    setTimeout(() => {
      if (typeof cb === "function") cb({ ok, message, mode: "chase" });
    }, 520);
  }

  function caught() {
    finish(false, "警察抓住了你——节目组大笑。");
  }

  function escaped() {
    finish(true, "你踹开门溜进雾里——速度涨了一截。");
  }

  function raceTick(ts) {
    if (phase !== "race") return;
    if (!lastTs) lastTs = ts;
    const dt = Math.min(0.05, (ts - lastTs) / 1000);
    lastTs = ts;

    const now = performance.now();
    setMissVisual(now < missUntil);
    if (now >= missUntil) {
      // 错字闪过后刷新当前字样式
      renderSentence();
    }

    policePos = Math.min(TRACK_LEN, policePos + POLICE_SPEED * dt);
    if (policePos >= playerPos - 0.05) {
      renderTrack();
      caught();
      return;
    }
    renderTrack();
    raf = requestAnimationFrame(raceTick);
  }

  function startCountdown() {
    phase = "countdown";
    showReady(false);
    countdownIdx = 0;
    setStatus("盯着倒计时，准备打一整句。", "");
    const step = () => {
      if (phase !== "countdown") return;
      if (countdownIdx >= COUNTDOWN.length) {
        setCountdownVisual(null);
        phase = "race";
        nextSentence();
        setStatus("打完整句往前跑。打错只闪一下，进度不清空。", "");
        lastTs = 0;
        raf = requestAnimationFrame(raceTick);
        return;
      }
      setCountdownVisual(COUNTDOWN[countdownIdx]);
      countdownIdx += 1;
      countdownTimer = setTimeout(step, countdownIdx === COUNTDOWN.length ? 550 : 750);
    };
    step();
  }

  function onKey(e) {
    if (!active || phase !== "race") return;
    if (["Tab", "Escape"].includes(e.key)) return;
    // 空格要吃掉；忽略组合修饰单独按下
    if (e.key.length !== 1) return;
    e.preventDefault();

    const now = performance.now();
    const expect = sentence[typed];
    if (!expect) return;
    const got = e.key;
    const match =
      expect === " "
        ? got === " "
        : got.toLowerCase() === expect.toLowerCase();

    if (match) {
      typed += 1;
      missUntil = 0;
      setMissVisual(false);
      renderSentence();
      renderTrack();
      if (typed >= sentence.length) {
        playerPos = Math.min(TRACK_LEN, playerPos + SENTENCE_STEP);
        renderTrack();
        if (playerPos >= TRACK_LEN - 0.01) {
          escaped();
          return;
        }
        nextSentence();
        setStatus("一句打完，继续下一句！", "ok");
      }
      return;
    }

    // 打错：进度保留，仅短闪提示，可马上再打当前字
    missUntil = now + MISS_FLASH_MS;
    setMissVisual(true);
    renderSentence();
    setStatus("打错了——进度还在，再打这个字。", "bad");
    const stage = $("qte-stage");
    if (stage) {
      stage.classList.remove("qte-shake");
      void stage.offsetWidth;
      stage.classList.add("qte-shake");
    }
  }

  /**
   * @param {{ title?: string, lead?: string, onDone?: Function }} opts
   */
  function start(opts = {}) {
    stop();
    const title = $("qte-title");
    const lead = $("qte-lead");
    if (title) title.textContent = opts.title || "泥靴间 · 警察抓小偷";
    if (lead) {
      lead.textContent =
        opts.lead ||
        "你是小偷：打完整句英文往门口跑。警察匀速追（偏慢）。打错只闪一下、不清空进度。先点「开始追逐」，倒计时后再打字。";
    }
    onDone = opts.onDone || null;
    active = true;
    phase = "ready";
    playerPos = PLAYER_START;
    policePos = POLICE_START;
    sentence = "";
    typed = 0;
    usedSentences = new Set();
    missUntil = 0;
    setMissVisual(false);
    setCountdownVisual(null);
    setStatus("用鼠标点开始——倒计时后再碰键盘。", "");
    renderSentence();
    renderTrack();
    showReady(true);
    const go = $("btn-qte-go");
    if (go) {
      go.onclick = () => {
        if (phase !== "ready") return;
        window.addEventListener("keydown", onKey, true);
        startCountdown();
      };
    }
  }

  function stop() {
    active = false;
    phase = "idle";
    cancelAnimationFrame(raf);
    raf = 0;
    clearTimeout(countdownTimer);
    countdownTimer = 0;
    window.removeEventListener("keydown", onKey, true);
    onDone = null;
    setMissVisual(false);
    setCountdownVisual(null);
    showReady(false);
    sentence = "";
    typed = 0;
    renderSentence();
  }

  function isRunning() {
    return active && phase !== "done" && phase !== "idle";
  }

  function forfeit(message) {
    if (!active || phase === "done") return;
    finish(false, message || "你举手投降——警察给节目组鞠躬。");
  }

  global.CabinQte = { start, stop, isRunning, forfeit };
})(window);
