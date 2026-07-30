/** 八数码滑块拼图 — 静室解密事件（Haunt 式考验占位） */
(function (global) {
  const SIZE = 3;
  const N = SIZE * SIZE;
  /** 从已还原局面滑乱的步数区间：保证可解且不太难 */
  const SHUFFLE_MIN = 18;
  const SHUFFLE_MAX = 26;
  /** 玩家可用步数（略宽于乱步，允许绕路） */
  const MOVE_BUDGET = 42;

  let active = false;
  let board = [];
  let movesLeft = 0;
  let onDone = null;
  let ignoreUntil = 0;

  function $(id) {
    return document.getElementById(id);
  }

  function keyOf(i) {
    return i;
  }

  function emptyIndex(b) {
    return b.indexOf(0);
  }

  function neighborsOf(idx) {
    const r = Math.floor(idx / SIZE);
    const c = idx % SIZE;
    const out = [];
    if (r > 0) out.push(idx - SIZE);
    if (r < SIZE - 1) out.push(idx + SIZE);
    if (c > 0) out.push(idx - 1);
    if (c < SIZE - 1) out.push(idx + 1);
    return out;
  }

  function isSolved(b) {
    for (let i = 0; i < N - 1; i += 1) {
      if (b[i] !== i + 1) return false;
    }
    return b[N - 1] === 0;
  }

  function solvedBoard() {
    const b = [];
    for (let i = 1; i < N; i += 1) b.push(i);
    b.push(0);
    return b;
  }

  function slide(b, from) {
    const empty = emptyIndex(b);
    if (!neighborsOf(empty).includes(from)) return false;
    const next = b.slice();
    next[empty] = next[from];
    next[from] = 0;
    return next;
  }

  function shuffleFromSolved() {
    let b = solvedBoard();
    const steps = SHUFFLE_MIN + Math.floor(Math.random() * (SHUFFLE_MAX - SHUFFLE_MIN + 1));
    let lastEmpty = emptyIndex(b);
    for (let i = 0; i < steps; i += 1) {
      const opts = neighborsOf(emptyIndex(b)).filter((x) => x !== lastEmpty);
      const pick = opts[Math.floor(Math.random() * opts.length)] ?? neighborsOf(emptyIndex(b))[0];
      lastEmpty = emptyIndex(b);
      b = slide(b, pick) || b;
    }
    // 极少情况仍是还原：再滑一步
    if (isSolved(b)) {
      const pick = neighborsOf(emptyIndex(b))[0];
      b = slide(b, pick) || b;
    }
    return b;
  }

  function setStatus(msg, tone) {
    const status = $("puzzle-status");
    if (!status) return;
    status.textContent = msg;
    status.className = "puzzle-status" + (tone ? ` ${tone}` : "");
  }

  function setMeta() {
    const meta = $("puzzle-meta");
    if (meta) meta.textContent = `剩余步数 ${movesLeft}`;
  }

  function renderBoard() {
    const grid = $("puzzle-grid");
    if (!grid) return;
    grid.innerHTML = "";
    grid.style.setProperty("--puzzle-size", String(SIZE));
    board.forEach((val, idx) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "puzzle-tile" + (val === 0 ? " is-empty" : "");
      btn.textContent = val === 0 ? "" : String(val);
      btn.disabled = !active || val === 0;
      btn.setAttribute("aria-label", val === 0 ? "空格" : `滑块 ${val}`);
      if (val !== 0) {
        btn.onclick = () => tryMove(idx);
      }
      grid.appendChild(btn);
    });
    setMeta();
  }

  function tryMove(from) {
    if (!active) return;
    if (performance.now() < ignoreUntil) return;
    const next = slide(board, from);
    if (!next) {
      setStatus("点空格旁边的数字。", "");
      return;
    }
    board = next;
    movesLeft -= 1;
    renderBoard();
    if (isSolved(board)) {
      finish(true, "画面咬合了——雪花拼回频道台标。");
      return;
    }
    if (movesLeft <= 0) {
      finish(false, "步数用尽，雪花又糊成一片。");
      return;
    }
    setStatus("继续拼。", "");
  }

  function onKey(e) {
    if (!active) return;
    if (performance.now() < ignoreUntil) return;
    if (e.key === "Escape") return;
    const empty = emptyIndex(board);
    const r = Math.floor(empty / SIZE);
    const c = empty % SIZE;
    let from = -1;
    // 方向键 / WASD：把数字推进空格（直觉：按右 = 空格右侧的块滑进来）
    if (e.key === "ArrowLeft" || e.key.toLowerCase() === "a") {
      if (c < SIZE - 1) from = empty + 1;
    } else if (e.key === "ArrowRight" || e.key.toLowerCase() === "d") {
      if (c > 0) from = empty - 1;
    } else if (e.key === "ArrowUp" || e.key.toLowerCase() === "w") {
      if (r < SIZE - 1) from = empty + SIZE;
    } else if (e.key === "ArrowDown" || e.key.toLowerCase() === "s") {
      if (r > 0) from = empty - SIZE;
    } else {
      return;
    }
    e.preventDefault();
    if (from >= 0) tryMove(from);
  }

  function finish(ok, message) {
    if (!active) return;
    active = false;
    window.removeEventListener("keydown", onKey, true);
    setStatus(message, ok ? "ok" : "bad");
    const grid = $("puzzle-grid");
    if (grid) {
      grid.querySelectorAll("button").forEach((b) => {
        b.disabled = true;
      });
    }
    const cb = onDone;
    onDone = null;
    setTimeout(() => {
      if (typeof cb === "function") cb({ ok, message });
    }, 480);
  }

  /**
   * @param {{ title?: string, lead?: string, onDone?: (r:{ok:boolean,message:string})=>void }} opts
   */
  function start(opts = {}) {
    stop();
    const title = $("puzzle-title");
    const lead = $("puzzle-lead");
    if (title) title.textContent = opts.title || "雪花拼图";
    if (lead) {
      lead.textContent =
        opts.lead ||
        "把 1–8 滑回顺序，空格在右下。点邻格或用方向键/WASD。步数用尽或放弃都算失手——成功才能翻静室奖励。";
    }
    board = shuffleFromSolved();
    movesLeft = MOVE_BUDGET;
    onDone = opts.onDone || null;
    active = true;
    ignoreUntil = performance.now() + 220;
    setStatus("拼吧。", "");
    renderBoard();
    window.addEventListener("keydown", onKey, true);
  }

  function stop() {
    active = false;
    window.removeEventListener("keydown", onKey, true);
    onDone = null;
    const grid = $("puzzle-grid");
    if (grid) grid.innerHTML = "";
  }

  function isRunning() {
    return active;
  }

  /** 沙盒用：主动放弃 */
  function forfeit(message) {
    if (!active) return;
    finish(false, message || "你把雪花屏推回了雪花。");
  }

  global.CabinPuzzle = { start, stop, isRunning, forfeit, keyOf };
})(window);
