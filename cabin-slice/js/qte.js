/** 警察抓小偷 · 打字追逐（金山式节拍玩具，静室考验） */
(function (global) {
  const WORDS = [
    "run", "hide", "fog", "door", "key", "lamp", "lock", "step", "dash", "jump",
    "climb", "escape", "signal", "channel", "dream", "cabin", "mud", "boot",
    "chase", "quick", "quiet", "shadow", "corner", "attic", "radio", "static",
    "snow", "frame", "pulse", "ghost", "wire", "rust", "altar", "host",
    "tape", "reel", "noise", "crawl", "vault", "flare", "guard", "focus",
  ];

  const TRACK_LEN = 14;
  const PLAYER_START = 3;
  const POLICE_START = 0;
  const POLICE_SPEED = 0.42; // 格/秒，恒速
  const WORD_STEP = 1.15; // 打对一词前进
  const STUN_MS = 1100;
  const COUNTDOWN = [3, 2, 1, "跑！"];

  let active = false;
  let phase = "idle"; // idle | ready | countdown | race | done
  let onDone = null;
  let raf = 0;
  let word = "";
  let typed = 0;
  let playerPos = PLAYER_START;
  let policePos = POLICE_START;
  let lastTs = 0;
  let stunUntil = 0;
  let usedWords = new Set();
  let countdownIdx = 0;
  let countdownTimer = 0;

  function $(id) {
    return document.getElementById(id);
  }

  function pickWord() {
    const pool = WORDS.filter((w) => !usedWords.has(w));
    const bag = pool.length ? pool : WORDS.slice();
    const w = bag[Math.floor(Math.random() * bag.length)];
    usedWords.add(w);
    if (usedWords.size > WORDS.length - 4) usedWords.clear();
    return w;
  }

  function setStatus(msg, tone) {
    const el = $("qte-status");
    if (!el) return;
    el.textContent = msg;
    el.className = "qte-status" + (tone ? ` ${tone}` : "");
  }

  function renderWord() {
    const el = $("qte-word");
    if (!el) return;
    if (!word) {
      el.innerHTML = "";
      return;
    }
    el.innerHTML = word
      .split("")
      .map((ch, i) => {
        const cls = i < typed ? "is-done" : i === typed ? "is-next" : "";
        return `<span class="${cls}">${ch}</span>`;
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
      meta.textContent = `间距 ${gap} · 终点 ${TRACK_LEN}`;
    }
  }

  function setStunVisual(on) {
    const stage = $("qte-stage");
    const stun = $("qte-stun");
    if (stage) stage.classList.toggle("is-stunned", on);
    if (stun) {
      stun.classList.toggle("hidden", !on);
      if (on) stun.textContent = "硬直！";
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

  function nextWord() {
    word = pickWord();
    typed = 0;
    renderWord();
  }

  function finish(ok, message) {
    if (phase === "done") return;
    phase = "done";
    active = false;
    cancelAnimationFrame(raf);
    raf = 0;
    window.removeEventListener("keydown", onKey, true);
    setStunVisual(false);
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
    const stunned = now < stunUntil;
    setStunVisual(stunned);

    // 警察恒速前进（硬直时警察不停——这才叫惩罚）
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
    setStatus("盯着倒计时，准备打字。", "");
    const step = () => {
      if (phase !== "countdown") return;
      if (countdownIdx >= COUNTDOWN.length) {
        setCountdownVisual(null);
        phase = "race";
        nextWord();
        setStatus("打出单词往前跑！打错会硬直。", "");
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
    if (e.key.length !== 1) return;
    e.preventDefault();

    if (performance.now() < stunUntil) return;

    const expect = word[typed];
    if (!expect) return;
    const got = e.key.toLowerCase();
    if (got === expect.toLowerCase()) {
      typed += 1;
      renderWord();
      if (typed >= word.length) {
        playerPos = Math.min(TRACK_LEN, playerPos + WORD_STEP);
        renderTrack();
        if (playerPos >= TRACK_LEN - 0.01) {
          escaped();
          return;
        }
        nextWord();
      }
      return;
    }

    // 打错：明显硬直，当前词进度清零
    typed = 0;
    renderWord();
    stunUntil = performance.now() + STUN_MS;
    setStunVisual(true);
    setStatus("打错了——腿一软！", "bad");
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
        "你是小偷：打对单词往门口跑。警察匀速追。打错会硬直停手。先点「开始追逐」，倒计时后再打字。";
    }
    onDone = opts.onDone || null;
    active = true;
    phase = "ready";
    playerPos = PLAYER_START;
    policePos = POLICE_START;
    word = "";
    typed = 0;
    usedWords = new Set();
    stunUntil = 0;
    setStunVisual(false);
    setCountdownVisual(null);
    setStatus("用鼠标点开始——倒计时后再碰键盘。", "");
    renderWord();
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
    setStunVisual(false);
    setCountdownVisual(null);
    showReady(false);
    word = "";
    typed = 0;
    renderWord();
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
