/** Side-view keyboard sandbox (WASD / arrows). Decoupled from run save. */
(function (global) {
  const SPRITE_IDLE = "assets/ui/chars/SP_Lili_Stand.png";
  /** Drop walk frames into assets/sideview/lili/ and list paths here later. */
  const FRAME_PATHS = {
    idle: (window.LiliAnim && window.LiliAnim.FRAMES) || [SPRITE_IDLE],
    walk: [],
  };

  const WORLD = { w: 960, h: 420 };
  const GROUND_Y = 360;
  const MOVE_SPEED = 220;
  const JUMP_V = -420;
  const GRAVITY = 1400;

  let canvas = null;
  let ctx = null;
  let raf = 0;
  let running = false;
  let lastTs = 0;
  let animT = 0;

  const keys = Object.create(null);
  const frames = { idle: [], walk: [] };

  const platforms = [
    { x: 0, y: GROUND_Y, w: WORLD.w, h: WORLD.h - GROUND_Y },
    { x: 180, y: 270, w: 160, h: 18 },
    { x: 420, y: 210, w: 140, h: 18 },
    { x: 680, y: 280, w: 170, h: 18 },
  ];

  const player = {
    x: 80,
    y: GROUND_Y - 96,
    w: 56,
    h: 96,
    vx: 0,
    vy: 0,
    facing: 1,
    onGround: false,
  };

  function loadImages(paths) {
    return Promise.all(
      paths.map(
        (src) =>
          new Promise((resolve) => {
            const img = new Image();
            img.onload = () => resolve(knockoutBlack(img));
            img.onerror = () => resolve(null);
            img.src = src;
          }),
      ),
    ).then((list) => list.filter(Boolean));
  }

  /** Idle exports sit on solid black — key near-black to alpha once. */
  function knockoutBlack(img, thr = 18) {
    const c = document.createElement("canvas");
    c.width = img.width;
    c.height = img.height;
    const cctx = c.getContext("2d");
    cctx.drawImage(img, 0, 0);
    const data = cctx.getImageData(0, 0, c.width, c.height);
    const d = data.data;
    for (let i = 0; i < d.length; i += 4) {
      if (d[i] <= thr && d[i + 1] <= thr && d[i + 2] <= thr) d[i + 3] = 0;
    }
    cctx.putImageData(data, 0, 0);
    // Tight crop to opaque bounds
    let x0 = c.width;
    let y0 = c.height;
    let x1 = 0;
    let y1 = 0;
    for (let y = 0; y < c.height; y++) {
      for (let x = 0; x < c.width; x++) {
        if (d[(y * c.width + x) * 4 + 3] > 10) {
          if (x < x0) x0 = x;
          if (y < y0) y0 = y;
          if (x > x1) x1 = x;
          if (y > y1) y1 = y;
        }
      }
    }
    if (x1 <= x0 || y1 <= y0) return c;
    const out = document.createElement("canvas");
    out.width = x1 - x0 + 1;
    out.height = y1 - y0 + 1;
    out.getContext("2d").drawImage(c, x0, y0, out.width, out.height, 0, 0, out.width, out.height);
    return out;
  }

  async function ensureSprites() {
    if (frames.idle.length) return;
    frames.idle = await loadImages(FRAME_PATHS.idle);
    frames.walk = await loadImages(FRAME_PATHS.walk);
  }

  function currentSprite() {
    const moving = Math.abs(player.vx) > 12;
    const pack = moving && frames.walk.length ? frames.walk : frames.idle;
    if (!pack.length) return null;
    const idx = Math.floor(animT * (moving ? 8 : 2)) % pack.length;
    return pack[idx];
  }

  function resizeCanvas() {
    if (!canvas) return;
    canvas.width = WORLD.w;
    canvas.height = WORLD.h;
  }

  function resetPlayer() {
    player.x = 80;
    player.y = GROUND_Y - player.h;
    player.vx = 0;
    player.vy = 0;
    player.facing = 1;
    player.onGround = true;
    animT = 0;
  }

  function onKeyDown(e) {
    if (!running) return;
    const k = e.key.toLowerCase();
    if (["arrowup", "arrowdown", "arrowleft", "arrowright", " ", "w", "a", "s", "d"].includes(k) || e.code === "Space") {
      e.preventDefault();
    }
    if (k === "escape") {
      stop();
      if (typeof global.CabinSideviewOnExit === "function") global.CabinSideviewOnExit();
      return;
    }
    keys[k] = true;
    if (e.code === "Space") keys[" "] = true;
  }

  function onKeyUp(e) {
    const k = e.key.toLowerCase();
    keys[k] = false;
    if (e.code === "Space") keys[" "] = false;
  }

  function wantLeft() {
    return !!(keys.a || keys.arrowleft);
  }
  function wantRight() {
    return !!(keys.d || keys.arrowright);
  }
  function wantJump() {
    return !!(keys.w || keys.arrowup || keys[" "]);
  }

  function aabbOverlap(ax, ay, aw, ah, b) {
    return ax < b.x + b.w && ax + aw > b.x && ay < b.y + b.h && ay + ah > b.y;
  }

  function resolvePlatforms(prevY) {
    player.onGround = false;
    for (const p of platforms) {
      if (!aabbOverlap(player.x, player.y, player.w, player.h, p)) continue;
      const prevBottom = prevY + player.h;
      // Land from above
      if (player.vy >= 0 && prevBottom <= p.y + 4) {
        player.y = p.y - player.h;
        player.vy = 0;
        player.onGround = true;
        continue;
      }
      // Hit ceiling
      if (player.vy < 0 && prevY >= p.y + p.h - 4) {
        player.y = p.y + p.h;
        player.vy = 0;
        continue;
      }
      // Side push
      const overlapL = player.x + player.w - p.x;
      const overlapR = p.x + p.w - player.x;
      if (overlapL < overlapR) player.x = p.x - player.w;
      else player.x = p.x + p.w;
      player.vx = 0;
    }
  }

  function update(dt) {
    let ax = 0;
    if (wantLeft()) ax -= 1;
    if (wantRight()) ax += 1;
    player.vx = ax * MOVE_SPEED;
    if (ax !== 0) player.facing = ax;

    if (wantJump() && player.onGround) {
      player.vy = JUMP_V;
      player.onGround = false;
    }

    player.vy += GRAVITY * dt;
    const prevY = player.y;
    player.x += player.vx * dt;
    player.y += player.vy * dt;

    if (player.x < 8) player.x = 8;
    if (player.x + player.w > WORLD.w - 8) player.x = WORLD.w - 8 - player.w;

    resolvePlatforms(prevY);

    if (player.y > WORLD.h + 40) resetPlayer();

    animT += dt;
  }

  function drawRoom() {
    // Atmosphere
    const g = ctx.createLinearGradient(0, 0, 0, WORLD.h);
    g.addColorStop(0, "#1c3d42");
    g.addColorStop(0.55, "#123033");
    g.addColorStop(1, "#0a1719");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, WORLD.w, WORLD.h);

    // Soft window glow
    const glow = ctx.createRadialGradient(720, 90, 10, 720, 90, 160);
    glow.addColorStop(0, "rgba(255, 210, 120, 0.28)");
    glow.addColorStop(1, "rgba(255, 210, 120, 0)");
    ctx.fillStyle = glow;
    ctx.fillRect(560, 0, 320, 220);

    ctx.strokeStyle = "rgba(255, 230, 170, 0.35)";
    ctx.lineWidth = 3;
    ctx.strokeRect(680, 48, 90, 70);

    // Platforms
    for (let i = 0; i < platforms.length; i++) {
      const p = platforms[i];
      if (i === 0) {
        ctx.fillStyle = "#2a4e48";
        ctx.fillRect(p.x, p.y, p.w, p.h);
        ctx.fillStyle = "#3d6b5f";
        ctx.fillRect(p.x, p.y, p.w, 8);
      } else {
        ctx.fillStyle = "#3a2a22";
        ctx.fillRect(p.x, p.y, p.w, p.h);
        ctx.fillStyle = "#6b4a36";
        ctx.fillRect(p.x, p.y, p.w, 6);
      }
    }

    // Prop silhouettes
    ctx.fillStyle = "rgba(8, 20, 22, 0.55)";
    ctx.fillRect(40, GROUND_Y - 70, 48, 70);
    ctx.fillRect(860, GROUND_Y - 100, 36, 100);
  }

  function drawPlayer() {
    const moving = Math.abs(player.vx) > 12;
    const bob =
      (moving ? Math.sin(animT * 14) * 3 : Math.sin(animT * 2.4) * 1.5) +
      (player.onGround ? 0 : Math.min(6, Math.abs(player.vy) * 0.01));

    const img = currentSprite();
    ctx.save();
    ctx.translate(player.x + player.w / 2, player.y + player.h + bob);
    ctx.scale(player.facing, 1);

    if (img) {
      // Idle art is full figure on black — draw with slight letterbox crop feel
      const aspect = img.width / img.height;
      const drawH = player.h + 8;
      const drawW = drawH * aspect * 0.72;
      ctx.drawImage(img, -drawW / 2, -drawH, drawW, drawH);
    } else {
      ctx.fillStyle = "#7ad7ff";
      ctx.fillRect(-player.w / 2, -player.h, player.w, player.h);
    }
    ctx.restore();

    if (player.y + player.h > GROUND_Y - 8) {
      ctx.fillStyle = "rgba(0, 0, 0, 0.25)";
      ctx.beginPath();
      ctx.ellipse(player.x + player.w / 2, GROUND_Y - 2, 22, 6, 0, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  function drawHud() {
    ctx.fillStyle = "rgba(0, 0, 0, 0.35)";
    ctx.fillRect(12, 12, 220, 36);
    ctx.fillStyle = "#e8fff8";
    ctx.font = "600 14px IBM Plex Sans, PingFang SC, sans-serif";
    ctx.fillText("临时手感 · 非最终美术", 24, 35);
  }

  function frame(ts) {
    if (!running) return;
    if (!lastTs) lastTs = ts;
    let dt = (ts - lastTs) / 1000;
    lastTs = ts;
    if (dt > 0.05) dt = 0.05;
    update(dt);
    drawRoom();
    drawPlayer();
    drawHud();
    raf = requestAnimationFrame(frame);
  }

  function bindKeys(on) {
    if (on) {
      window.addEventListener("keydown", onKeyDown);
      window.addEventListener("keyup", onKeyUp);
    } else {
      window.removeEventListener("keydown", onKeyDown);
      window.removeEventListener("keyup", onKeyUp);
      for (const k of Object.keys(keys)) keys[k] = false;
    }
  }

  async function start() {
    canvas = document.getElementById("sideview-canvas");
    if (!canvas) return;
    ctx = canvas.getContext("2d");
    await ensureSprites();
    resizeCanvas();
    resetPlayer();
    if (running) stop();
    running = true;
    lastTs = 0;
    bindKeys(true);
    raf = requestAnimationFrame(frame);
  }

  function stop() {
    running = false;
    if (raf) cancelAnimationFrame(raf);
    raf = 0;
    lastTs = 0;
    bindKeys(false);
  }

  global.CabinSideview = { start, stop, isRunning: () => running };
})(window);
