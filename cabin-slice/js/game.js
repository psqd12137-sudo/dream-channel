const { playTone, setMuted, startBgm } = window.CabinAudio || {
  playTone() {},
  setMuted() {},
  startBgm() {},
};

let uidSeq = 1;
const SAVE_KEY = "cabin-run-v3";
const LAB_KEY = "cabin-lab-v1";
const LAB_MAX_RUNS = 40;

const state = {
  data: null,
  roomId: null,
  speed: 3,
  hp: 6,
  maxHp: 6,
  visitPath: [],
  resolvedRooms: new Set(),
  knownRooms: new Set(),
  deck: [],
  discard: [],
  relics: [],
  muted: false,
  pending: null,
  combat: null,
  chosenBoss: null,
  nodePending: false,
  combatCount: 0,
  rewardRolls: {},
  /** 当前实验会话（战斗进行中） */
  lab: null,
  /** 本局是否来自「跳到 Boss」测强度入口 */
  labTag: "normal",
  /** 新手教学：{ active, step, roomsMain } */
  tutorial: null,
  /** 预备·甩开沙盒：{ active, layout }，不写正式存档 */
  flingSandbox: null,
  /** 本局房间类型伪随机：种子 + id→combat|quiet */
  runSeed: 0,
  roomLayout: null,
};

const $ = (id) => document.getElementById(id);

async function loadData() {
  const [rooms, cards, relics, bosses, pressure] = await Promise.all([
    fetch("data/rooms.json").then((r) => r.json()),
    fetch("data/cards.json").then((r) => r.json()),
    fetch("data/relics.json").then((r) => r.json()),
    fetch("data/bosses.json").then((r) => r.json()),
    fetch("data/pressure.json").then((r) => r.json()),
  ]);
  let tutorial = null;
  try {
    tutorial = await fetch("data/tutorial.json").then((r) => {
      if (!r.ok) throw new Error(`tutorial.json ${r.status}`);
      return r.json();
    });
  } catch (err) {
    console.warn("教学关未加载：", err);
  }
  state.data = { rooms, roomsMain: rooms, cards, relics, bosses, pressure, tutorial };
}

function show(id) {
  document.querySelectorAll(".panel").forEach((el) => el.classList.remove("active"));
  $(id).classList.add("active");
  document.body.classList.remove("sts-overlay-open");
  $("screen-event")?.classList.remove("sts-reward");
}

/** keep: 仍保持激活的 modal id 列表（用于 STS 式叠层：战场留底、奖励框盖上） */
function showModal(id, { keep = [] } = {}) {
  document.querySelectorAll(".panel.modal").forEach((el) => {
    if (keep.includes(el.id)) return;
    el.classList.remove("active");
  });
  if (id) $(id).classList.add("active");
  const overlayOpen = !!(id && (id === "screen-end" || id === "screen-event") && keep.includes("screen-cards"));
  document.body.classList.toggle("sts-overlay-open", overlayOpen);
  const eventPanel = $("screen-event");
  if (eventPanel) eventPanel.classList.toggle("sts-reward", overlayOpen && id === "screen-event");
}

function freezeCombatUnderlay() {
  const cards = $("screen-cards");
  if (cards && !cards.classList.contains("active")) {
    // 若刚关掉，强制留住最后一帧战场
    cards.classList.add("active");
  }
  return ["screen-cards"];
}

function cardDef(id) {
  return state.data.cards.cards[id];
}

function relicDef(id) {
  return state.data.relics.relics[id];
}

function bossDef(id) {
  return state.data?.bosses?.bosses?.[id] || null;
}

function cardKindLabel(type) {
  if (type === "place") return "放置";
  if (type === "medicine") return "药物";
  if (type === "skill") return "技巧";
  if (type === "ready") return "预备";
  return type || "卡牌";
}

function cardFrameClass(type) {
  if (type === "medicine") return "frame-red";
  if (type === "skill") return "frame-blue";
  if (type === "ready") return "frame-blue";
  return "frame-yellow";
}

function cardKindIcon(type) {
  if (type === "place") return "assets/ui/cards/SP_Card_IconT_Trap.png";
  if (type === "medicine") return "assets/ui/cards/SP_Card_IconS_Life.png";
  if (type === "skill") return "assets/ui/cards/SP_Card_IconT_Amulet.png";
  if (type === "ready") return "assets/ui/cards/SP_Card_IconT_Defence.png";
  return "assets/ui/cards/SP_Card_IconT_Thing.png";
}

function cardKindHtml(type) {
  return `<span class="card-kind"><img src="${cardKindIcon(type)}" alt="" />${cardKindLabel(type)}</span>`;
}

function cardUsageHint(def) {
  if (def.type === "place") {
    return "用法：战斗中点选后放到邻格；有视线时可砸在敌人脚下立刻结算伤害。";
  }
  if (def.type === "medicine") {
    return "用法：点一下立刻生效，不用放到格子上。注意：可被敌人偷取的药物会标「可被偷」。";
  }
  if (def.type === "ready") {
    if (def.ready?.shove && def.ready?.preferPortal) {
      return "用法：点一下挂上预备。敌方走进相邻十字时优先甩向传送格；传送成功抽牌。同时只能挂一个。";
    }
    if (def.ready?.shove) {
      return "用法：点一下挂上预备。敌方走进相邻十字格时把它甩开并触发落点（优先机关）。不否定对方行动；小房型侧面放刺最有戏。同时只能挂一个。";
    }
    return "用法：点一下挂上预备（你自己变成机关）。敌方回合走进你相邻十字格才触发；不否定对方行动，用来打引怪 combo。同时只能挂一个。";
  }
  if (def.type === "skill") {
    if (def.gainBlock) {
      return "用法：和补剂/肾上腺素一样——点一下立刻获得格挡，不用放置。留在手里不会自动挡伤害。想「等它走进来再挡」请用预备牌「绷紧」。";
    }
    if (def.shove && def.preferPortal) {
      return "用法：点一下立刻推开邻接敌人，优先甩向传送格；传送成功抽牌。";
    }
    if (def.shove) {
      return "用法：点一下立刻推开邻接的敌人（优先甩向机关）。你回合布景；想等它走进来再甩进刺/坠物，挂预备「甩开」。";
    }
    if (def.climbToHigher) {
      return "用法：点一下——若邻格有更高处，立刻登上去（不另耗行动力）。没有更高邻格打不出。";
    }
    if (def.topple) {
      return "用法：点一下——你必须站得比敌人高，立刻砸伤并削韧。";
    }
    if (def.puppetBang) {
      return "用法：场上需有纸影傀儡。点一下造成伤害并引爆消散纸影（消耗）。";
    }
    if (def.saltLash) {
      return "用法：敌人站在盐圈上时点一下，抽打造成伤害并削韧。";
    }
    if (def.ifBlinded || def.elseBlind) {
      return "用法：点一下。敌已闪瞎则追击伤害；否则施加闪瞎。";
    }
    if (def.drainTough) {
      return "用法：点一下立刻削韧；破韧可抽牌，已破韧则给下一张放置折扣。";
    }
    if (def.grantRetain) return "用法：打出后本场获得留牌能力（类似尖塔「周密计划」）。";
    if (def.retainThisTurn) return "用法：打出后，本回合结束时可点「留」保住一张牌。";
    if (def.retain) return "用法：带「保留」——未打出时回合结束不丢弃；要生效仍需点出去。";
    return "用法：点一下立刻生效，不用放到格子上。";
  }
  return "用法：在战斗手牌中点选使用。";
}

function hideCardTooltip() {
  const tip = $("card-tooltip");
  if (tip) tip.classList.add("hidden");
}

function showCardTooltip(anchor, html) {
  const tip = $("card-tooltip");
  if (!tip) return;
  tip.innerHTML = html;
  tip.classList.remove("hidden");
  const pad = 12;
  const tw = 280;
  // 固定停靠在右侧手牌栏左侧，不跟着鼠标/卡片上下飘
  const rail = document.querySelector(".battle-right");
  const railRect = rail?.getBoundingClientRect();
  let left;
  let top;
  if (railRect) {
    left = railRect.left - tw - 12;
    top = railRect.top + 48;
    if (left < pad) left = railRect.right + 12;
  } else {
    const rect = anchor.getBoundingClientRect();
    left = rect.left - tw - 12;
    top = rect.top;
    if (left < pad) left = rect.right + 12;
  }
  tip.style.width = `${tw}px`;
  tip.style.left = "0px";
  tip.style.top = "0px";
  const th = tip.offsetHeight || 160;
  if (top + th > window.innerHeight - pad) top = window.innerHeight - th - pad;
  if (top < pad) top = pad;
  if (left + tw > window.innerWidth - pad) left = window.innerWidth - tw - pad;
  if (left < pad) left = pad;
  tip.style.left = `${left}px`;
  tip.style.top = `${top}px`;
}

function bindHoverTip(el, html) {
  el.addEventListener("mouseenter", () => showCardTooltip(el, html));
  el.addEventListener("mouseleave", hideCardTooltip);
  el.addEventListener("focus", () => showCardTooltip(el, html));
  el.addEventListener("blur", hideCardTooltip);
}

function cardTooltipHtml(def) {
  const tags = [];
  if (def.retain) tags.push("保留");
  if (def.grantRetain) tags.push("赋予留牌");
  if (def.retainThisTurn) tags.push("本回合留牌");
  const tagLine = tags.length ? `<p class="tip-meta">${tags.join(" · ")}</p>` : "";
  return `<p class="tip-name">${def.name}</p>
    <p class="tip-meta">${cardKindLabel(def.type)} · 费用 ${def.cost}</p>
    ${tagLine}
    <p class="tip-body">${def.text}</p>
    <p class="tip-extra">${cardUsageHint(def)}</p>`;
}

function retainBudget(c) {
  return (c?.retainSlots || 0) + (c?.retainThisTurn || 0);
}

function relicTooltipHtml(def) {
  return `<p class="tip-name">${def.name}</p>
    <p class="tip-meta">预兆 · 常驻</p>
    <p class="tip-body">${def.desc}</p>
    <p class="tip-extra">预兆不可被偷，整场夜驾持续生效。</p>`;
}

function clearRewardCards() {
  const row = $("reward-cards");
  if (row) row.innerHTML = "";
}

function roomDef(id) {
  const base = state.data.rooms.rooms[id];
  if (!base) return null;
  if (state.tutorial?.active) return base;
  const loc = state.roomLayout?.[id];
  // 空间布局覆盖：只改地图坐标与出口，内容/战斗/场地仍用原房间数据
  if (loc && typeof loc === "object" && loc.col != null) {
    return {
      ...base,
      map: { col: loc.col, row: loc.row },
      exits: [...(loc.exits || [])],
      // 山屋惊魂式门朝向：由邻接推算，渲染用
      doors: loc.doors
        ? { ...loc.doors }
        : doorsFromExits(loc, state.roomLayout),
    };
  }
  return base;
}

/** 由布局邻接推出 NESW 门朝向（对齐 Unity Room.northDoor…） */
function doorsFromExits(loc, layout) {
  const doors = { N: false, E: false, S: false, W: false };
  if (!loc || !layout) return doors;
  for (const eid of loc.exits || []) {
    const other = layout[eid];
    if (!other) continue;
    const dc = other.col - loc.col;
    const dr = other.row - loc.row;
    if (dc === 0 && dr === -1) doors.N = true;
    else if (dc === 0 && dr === 1) doors.S = true;
    else if (dc === 1 && dr === 0) doors.E = true;
    else if (dc === -1 && dr === 0) doors.W = true;
  }
  return doors;
}

function assignDoorsToLayout(layout) {
  for (const loc of Object.values(layout)) {
    loc.doors = doorsFromExits(loc, layout);
  }
}

/** 当前房间朝 (dc,dr) 方向的邻接出口 id（若有） */
function exitIdToward(room, dc, dr) {
  if (!room?.map || !state.roomLayout) return null;
  const tc = room.map.col + dc;
  const tr = room.map.row + dr;
  for (const eid of room.exits || []) {
    const other = state.roomLayout[eid];
    if (other && other.col === tc && other.row === tr) return eid;
  }
  return null;
}

/** 本局实际出现在大地图上的房间 id */
function placedRoomIds() {
  if (state.tutorial?.active || !isSpatialLayout(state.roomLayout)) {
    return Object.keys(state.data.rooms.rooms);
  }
  return Object.keys(state.roomLayout);
}

function isSpatialLayout(layout) {
  if (!layout) return false;
  const first = Object.values(layout)[0];
  return !!first && typeof first === "object" && first.col != null;
}

/** 可复现的伪随机（Mulberry32） */
function makeRng(seed) {
  let t = seed >>> 0;
  return () => {
    t += 0x6d2b79f5;
    let r = Math.imul(t ^ (t >>> 15), 1 | t);
    r ^= r + Math.imul(r ^ (r >>> 7), 61 | r);
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}

function seededShuffle(arr, rng) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i -= 1) {
    const j = Math.floor(rng() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function cellKey(c, r) {
  return `${c},${r}`;
}

/**
 * 开局掷大地图布局：房间内容固定，落位 + 邻接伪随机。
 * 拓扑可树/网/混合/主轴/翼楼；生成后把团块居中到 mapSize。
 * 祭坛/仪式不进随机图（仍走 Boss 按钮）。
 */
function rollRoomLayout(seed = (Date.now() ^ (Math.random() * 0x7fffffff)) >>> 0) {
  const cfg = state.data.rooms.layoutRoll;
  const rooms = state.data.rooms.rooms;
  const size = state.data.rooms.mapSize || { cols: 9, rows: 9 };

  if (!cfg?.enabled || cfg.mode === "off" || state.tutorial?.active) {
    state.runSeed = seed;
    state.roomLayout = null;
    return null;
  }

  const rng = makeRng(seed);
  const exclude = new Set(cfg.exclude || ["altar", "ritual"]);
  const startId = cfg.start?.id || state.data.rooms.startRoom || "foyer";
  const topologies = cfg.topologies || ["tree", "mesh", "hybrid", "spine", "wings"];
  const topo = topologies[Math.floor(rng() * topologies.length)] || "hybrid";

  const pool = seededShuffle(
    Object.keys(rooms).filter(
      (id) => id !== startId && !exclude.has(id) && !rooms[id].bossRoom,
    ),
    rng,
  );

  const [lo, hi] = cfg.placeCount || [12, 22];
  const want = Math.max(
    1,
    Math.min(pool.length + 1, lo + Math.floor(rng() * (Math.max(lo, hi) - lo + 1))),
  );

  const dirs = [
    [0, -1],
    [0, 1],
    [-1, 0],
    [1, 0],
  ];
  // 在放大画布上生长，最后再居中裁进 mapSize（画布略大于正式格，给翼楼/主廊伸展）
  const growCols = Math.max(size.cols, 20);
  const growRows = Math.max(size.rows, 20);
  const inBounds = (c, r) => c >= 1 && r >= 1 && c <= growCols && r <= growRows;

  const occupied = new Map(); // "c,r" -> id
  const layout = {};
  const parentOf = {}; // childId -> parentId
  const startCol = Math.ceil(growCols / 2);
  const startRow = Math.ceil(growRows / 2);
  layout[startId] = { col: startCol, row: startRow, exits: [] };
  occupied.set(cellKey(startCol, startRow), startId);

  const frontierOf = () => {
    const edge = [];
    const seen = new Set();
    for (const [id, loc] of Object.entries(layout)) {
      for (const [dc, dr] of dirs) {
        const c = loc.col + dc;
        const r = loc.row + dr;
        const k = cellKey(c, r);
        if (!inBounds(c, r) || occupied.has(k) || seen.has(k)) continue;
        seen.add(k);
        edge.push({ c, r, fromId: id, dc, dr });
      }
    }
    return edge;
  };

  const placeAt = (id, c, r, fromId) => {
    layout[id] = { col: c, row: r, exits: [] };
    occupied.set(cellKey(c, r), id);
    if (fromId) parentOf[id] = fromId;
  };

  const pickFrontier = (frontier, preferDir = null, fromFilter = null) => {
    let poolF = frontier;
    if (fromFilter) poolF = poolF.filter((f) => fromFilter(f.fromId));
    if (!poolF.length) poolF = frontier;
    if (preferDir && poolF.length) {
      const aligned = poolF.filter((f) => f.dc === preferDir[0] && f.dr === preferDir[1]);
      if (aligned.length && rng() < 0.7) poolF = aligned;
    }
    // 树/翼：偏好末梢延伸，少填实心团
    if ((topo === "tree" || topo === "wings") && poolF.length > 2 && rng() < 0.55) {
      const childCount = {};
      for (const p of Object.values(parentOf)) childCount[p] = (childCount[p] || 0) + 1;
      const tipish = poolF.filter((f) => (childCount[f.fromId] || 0) <= 1);
      if (tipish.length) poolF = tipish;
    }
    return poolF[Math.floor(rng() * poolF.length)];
  };

  let pi = 0;
  let preferDir = null;

  if (topo === "spine") {
    // 先拉一条主走廊，再向两侧抽枝（致命公司主廊感）
    const axis = rng() < 0.5 ? "h" : "v";
    preferDir = axis === "h" ? (rng() < 0.5 ? [1, 0] : [-1, 0]) : rng() < 0.5 ? [0, 1] : [0, -1];
    const spineLen = Math.max(4, Math.floor(want * (0.4 + rng() * 0.25)));
    while (Object.keys(layout).length < Math.min(spineLen, want) && pi < pool.length) {
      const frontier = frontierOf();
      if (!frontier.length) break;
      const spot = pickFrontier(frontier, preferDir);
      placeAt(pool[pi++], spot.c, spot.r, spot.fromId);
    }
    preferDir = null;
    while (Object.keys(layout).length < want && pi < pool.length) {
      const frontier = frontierOf();
      if (!frontier.length) break;
      // 侧枝：偏好垂直于主轴
      const side =
        axis === "h"
          ? rng() < 0.5
            ? [0, 1]
            : [0, -1]
          : rng() < 0.5
            ? [1, 0]
            : [-1, 0];
      const spot = pickFrontier(frontier, rng() < 0.55 ? side : null);
      placeAt(pool[pi++], spot.c, spot.r, spot.fromId);
    }
  } else if (topo === "wings") {
    // 玄关作枢纽，2～3 翼各自生长，翼间少交叉
    const wingDirs = seededShuffle(
      [
        [1, 0],
        [-1, 0],
        [0, 1],
        [0, -1],
      ],
      rng,
    ).slice(0, 2 + (rng() < 0.55 ? 1 : 0));
    const perWing = Math.max(2, Math.floor((want - 1) / wingDirs.length));
    const wingRoots = {};
    for (const dir of wingDirs) {
      const nc = startCol + dir[0];
      const nr = startRow + dir[1];
      if (!inBounds(nc, nr) || occupied.has(cellKey(nc, nr)) || pi >= pool.length) continue;
      const id = pool[pi++];
      placeAt(id, nc, nr, startId);
      wingRoots[id] = dir;
    }
    const wingMembers = {};
    for (const id of Object.keys(wingRoots)) wingMembers[id] = new Set([id]);

    while (Object.keys(layout).length < want && pi < pool.length) {
      const frontier = frontierOf();
      if (!frontier.length) break;
      // 轮流给各翼加房
      const roots = Object.keys(wingRoots);
      const root = roots[Math.floor(rng() * roots.length)];
      const dir = wingRoots[root];
      const members = wingMembers[root];
      const wingFront = frontier.filter((f) => members.has(f.fromId));
      const spot = pickFrontier(wingFront.length ? wingFront : frontier, dir);
      const id = pool[pi++];
      placeAt(id, spot.c, spot.r, spot.fromId);
      // 归属：跟 from 所在翼
      let assigned = root;
      for (const [rid, set] of Object.entries(wingMembers)) {
        if (set.has(spot.fromId)) {
          assigned = rid;
          break;
        }
      }
      wingMembers[assigned].add(id);
      if (wingMembers[assigned].size >= perWing + 2 && rng() < 0.4) {
        // 偶尔允许换翼扩展，打破对称
      }
    }
  } else {
    // tree / mesh / hybrid：统一从 frontier 生长；mesh 偏填实，tree 偏抽条
    while (Object.keys(layout).length < want && pi < pool.length) {
      const frontier = frontierOf();
      if (!frontier.length) break;
      const dirBias =
        topo === "tree" && rng() < 0.35
          ? dirs[Math.floor(rng() * dirs.length)]
          : null;
      const spot = pickFrontier(frontier, dirBias);
      placeAt(pool[pi++], spot.c, spot.r, spot.fromId);
    }
  }

  // —— 接线 ——
  const link = (a, b) => {
    if (!a || !b || a === b) return;
    if (!layout[a].exits.includes(b)) layout[a].exits.push(b);
    if (!layout[b].exits.includes(a)) layout[b].exits.push(a);
  };

  // 树骨架：父子边
  for (const [child, parent] of Object.entries(parentOf)) {
    link(child, parent);
  }

  const orthoPairs = [];
  for (const [id, loc] of Object.entries(layout)) {
    for (const [dc, dr] of dirs) {
      const nid = occupied.get(cellKey(loc.col + dc, loc.row + dr));
      if (!nid || id >= nid) continue;
      orthoPairs.push([id, nid]);
    }
  }

  if (topo === "mesh") {
    for (const [a, b] of orthoPairs) link(a, b);
  } else if (topo === "hybrid") {
    const p = 0.4 + rng() * 0.25;
    for (const [a, b] of orthoPairs) {
      if (layout[a].exits.includes(b)) continue;
      if (rng() < p) link(a, b);
    }
  } else if (topo === "spine") {
    // 主廊已有树边；再给正交邻接少量环，形成局部回路
    const p = 0.22 + rng() * 0.18;
    for (const [a, b] of orthoPairs) {
      if (layout[a].exits.includes(b)) continue;
      if (rng() < p) link(a, b);
    }
  } else if (topo === "wings") {
    // 翼内偶发捷径，翼间极少
    const p = 0.12 + rng() * 0.12;
    for (const [a, b] of orthoPairs) {
      if (layout[a].exits.includes(b)) continue;
      if (rng() < p) link(a, b);
    }
  }
  // tree：只保留父子边（可有死胡同）

  // —— 居中到正式 mapSize，并保证不越界 ——
  let minC = Infinity;
  let maxC = -Infinity;
  let minR = Infinity;
  let maxR = -Infinity;
  for (const loc of Object.values(layout)) {
    minC = Math.min(minC, loc.col);
    maxC = Math.max(maxC, loc.col);
    minR = Math.min(minR, loc.row);
    maxR = Math.max(maxR, loc.row);
  }
  const bw = maxC - minC + 1;
  const bh = maxR - minR + 1;
  let offC = Math.floor((size.cols - bw) / 2) + 1 - minC;
  let offR = Math.floor((size.rows - bh) / 2) + 1 - minR;
  for (const loc of Object.values(layout)) {
    loc.col += offC;
    loc.row += offR;
  }
  minC = Infinity;
  maxC = -Infinity;
  minR = Infinity;
  maxR = -Infinity;
  for (const loc of Object.values(layout)) {
    minC = Math.min(minC, loc.col);
    maxC = Math.max(maxC, loc.col);
    minR = Math.min(minR, loc.row);
    maxR = Math.max(maxR, loc.row);
  }
  let shiftC = 0;
  let shiftR = 0;
  if (minC < 1) shiftC = 1 - minC;
  if (maxC + shiftC > size.cols) shiftC = size.cols - maxC;
  if (minR < 1) shiftR = 1 - minR;
  if (maxR + shiftR > size.rows) shiftR = size.rows - maxR;
  if (shiftC || shiftR) {
    for (const loc of Object.values(layout)) {
      loc.col += shiftC;
      loc.row += shiftR;
    }
  }

  // 邻接定稿后再写门朝向（正交边才开对应墙门）
  assignDoorsToLayout(layout);

  const topoLabel = {
    tree: "树状",
    mesh: "网状",
    hybrid: "混合",
    spine: "主廊",
    wings: "翼楼",
  };

  state.runSeed = seed;
  state.roomLayout = layout;
  state.layoutTopology = topo;
  const combatN = Object.keys(layout).filter((id) => rooms[id]?.combat).length;
  log(
    `本集山屋平面图 #${seed >>> 0} · ${topoLabel[topo] || topo} · ${Object.keys(layout).length} 间（惊吓 ${combatN}）`,
    "ok",
  );
  return layout;
}

function makeCard(id) {
  return { uid: uidSeq++, id };
}

function shuffle(arr) {
  for (let i = arr.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

function buildStarterDeck() {
  return state.data.cards.starter.map(makeCard);
}

function allOwnedCards() {
  return [...state.deck, ...state.discard, ...(state.combat?.hand || [])];
}

function drawOne() {
  if (!state.deck.length) {
    if (!state.discard.length) return null;
    state.deck = shuffle(state.discard.splice(0));
  }
  return state.deck.pop() || null;
}

function drawHand(n) {
  const hand = [];
  for (let i = 0; i < n; i += 1) {
    const c = drawOne();
    if (c) hand.push(c);
  }
  return hand;
}

function rollSpeedDice() {
  const faces = state.data.cards.diceFaces;
  const rolls = [];
  for (let i = 0; i < state.speed; i += 1) {
    rolls.push(faces[Math.floor(Math.random() * faces.length)]);
  }
  let total = rolls.reduce((a, b) => a + b, 0);
  if (hasRelicEffect("energyBonus")) total += relicValue("energyBonus");
  return { rolls, total };
}

function hasRelicEffect(key) {
  return state.relics.some((id) => relicDef(id).effect[key]);
}

function relicValue(key) {
  return state.relics.reduce((sum, id) => sum + (relicDef(id).effect[key] || 0), 0);
}

/** 预兆·镜头：每场战斗首次打出 0 费牌时额外抽 1 */
function maybeFreeDraw(c, costPaid) {
  if (costPaid !== 0 || c.freeDrawUsed || !hasRelicEffect("freeDraw")) return;
  c.freeDrawUsed = true;
  let drawn = 0;
  for (let i = 0; i < relicValue("freeDraw"); i += 1) {
    const card = drawOne();
    if (card) {
      c.hand.push(card);
      drawn += 1;
    }
  }
  if (drawn) log(`预兆·镜头闪了一下：额外抽 ${drawn} 张。`, "ok");
}

function keyOf(pos) {
  return `${pos.r},${pos.c}`;
}

function parseKey(k) {
  const [r, c] = k.split(",").map(Number);
  return { r, c };
}

function combatGrid() {
  return state.combat?.grid || state.data.cards.grid || { rows: 3, cols: 5 };
}

/** Boss 山屋决战：按有房格包围盒裁切，避免整张大画布把节点挤小 */
function battleHouseFrame() {
  const g = combatGrid();
  let minR = Infinity;
  let maxR = -Infinity;
  let minC = Infinity;
  let maxC = -Infinity;
  let any = false;
  for (let r = 0; r < g.rows; r += 1) {
    for (let c = 0; c < g.cols; c += 1) {
      if (isVoid({ r, c })) continue;
      any = true;
      minR = Math.min(minR, r);
      maxR = Math.max(maxR, r);
      minC = Math.min(minC, c);
      maxC = Math.max(maxC, c);
    }
  }
  if (!any) {
    return { cols: Math.max(1, g.cols || 1), rows: Math.max(1, g.rows || 1), col0: 0, row0: 0 };
  }
  return {
    cols: maxC - minC + 1,
    rows: maxR - minR + 1,
    col0: minC,
    row0: minR,
  };
}

function inBounds(pos) {
  const g = combatGrid();
  return pos.r >= 0 && pos.c >= 0 && pos.r < g.rows && pos.c < g.cols;
}

function manhattan(a, b) {
  return Math.abs(a.r - b.r) + Math.abs(a.c - b.c);
}

function isWall(pos) {
  return !!state.combat?.walls?.has(keyOf(pos));
}

function isVoid(pos) {
  return !!state.combat?.voids?.has(keyOf(pos));
}

/** 墙或空洞：不可站、挡视线 */
function isBlocked(pos) {
  return isWall(pos) || isVoid(pos);
}

function tileHeight(pos) {
  return state.combat?.heights?.[keyOf(pos)] || 0;
}

function isPassable(pos) {
  return inBounds(pos) && !isBlocked(pos);
}

function doorEdgeKey(a, b) {
  const ka = keyOf(a);
  const kb = keyOf(b);
  return ka < kb ? `${ka}|${kb}` : `${kb}|${ka}`;
}

function hasDoorLink(a, b) {
  const links = state.combat?.links;
  if (!links) return true;
  return links.has(doorEdgeKey(a, b));
}

/** 山屋图模式只沿门走；普通场地四向通行 */
function canStepBetween(a, b) {
  if (!a || !b || !isOrthoAdjacent(a, b)) return false;
  if (state.combat?.houseGraph && !hasDoorLink(a, b)) return false;
  return true;
}

/** 仅正交四向，禁止斜向 */
function isOrthoAdjacent(a, b) {
  return Math.abs(a.r - b.r) + Math.abs(a.c - b.c) === 1;
}

function neighbors(pos) {
  return [
    { r: pos.r - 1, c: pos.c },
    { r: pos.r + 1, c: pos.c },
    { r: pos.r, c: pos.c - 1 },
    { r: pos.r, c: pos.c + 1 },
  ].filter((n) => isPassable(n) && canStepBetween(pos, n));
}

function climbCost(from, to, forPlayer = false) {
  const dh = tileHeight(to) - tileHeight(from);
  if (dh <= 0) return 0;
  if (forPlayer && hasRelicEffect("ignoreClimb")) return 0;
  return dh;
}

/** 山屋惊魂式占格：单位不硬挡路；敌对穿格额外耗体，同阵营免费 */
function occupantsAt(c, pos) {
  if (!c || !pos) return { player: false, enemy: false, decoy: false };
  const k = keyOf(pos);
  return {
    player: keyOf(c.playerPos) === k,
    enemy: keyOf(c.enemyPos) === k,
    decoy: decoyAlive(c) && keyOf(c.decoy.pos) === k,
  };
}

function hostilePassCostValue() {
  return state.data?.cards?.hostilePassCost ?? 1;
}

/** 仅玩家穿格计费：进敌人格耗 hostilePassCost；傀儡同阵营 0。敌人不计穿格税（以击杀为目标）。 */
function unitPassCost(who, pos) {
  const c = state.combat;
  if (!c || !pos || who !== "player") return 0;
  const o = occupantsAt(c, pos);
  if (o.enemy) return hostilePassCostValue();
  return 0;
}

function playerMoveCost(from, to) {
  return state.data.cards.moveCost + climbCost(from, to, true) + unitPassCost("player", to);
}

/** 敌人落到单位格后的结算：踩上傀儡则打碎 */
function resolveEnemyLandOverlap(c) {
  if (!c) return;
  if (decoyAlive(c) && keyOf(c.enemyPos) === keyOf(c.decoy.pos)) {
    smashDecoy(c, "踩碎了");
  }
}

function isExhaustCard(instOrDef) {
  const def = typeof instOrDef === "string" ? cardDef(instOrDef) : instOrDef.id ? cardDef(instOrDef.id) : instOrDef;
  return !!def?.exhaust;
}

function isTempCard(instOrDef) {
  const def = typeof instOrDef === "string" ? cardDef(instOrDef) : instOrDef.id ? cardDef(instOrDef.id) : instOrDef;
  return !!def?.temp;
}

/** 打出后：消耗牌不进弃牌；普通牌进弃牌 */
function retireCard(inst) {
  if (!inst) return;
  if (isExhaustCard(inst) || isTempCard(inst)) return;
  state.discard.push(inst);
}

function purgeTempCards(list) {
  if (!list) return [];
  return list.filter((c) => !isTempCard(c));
}

function comboPop(name) {
  const c = state.combat;
  if (!c) return;
  c.comboFlash = name;
  log(`连击·${name}`, "ok");
  labNoteCombo(name);
  const el = $("combo-toast");
  if (el) {
    el.textContent = `连击·${name}`;
    el.classList.remove("show");
    void el.offsetWidth;
    el.classList.add("show");
  }
}

/** 丢视线后仍记得玩家落点的敌回合数（此前为 2，易被挂机空转） */
const LAST_SEEN_MEMORY_TURNS = 5;

function getEnemyGoal(c) {
  const sees = hasLoS(c.enemyPos, c.playerPos) && !isEnemyBlinded(c);

  // 纸影傀儡：嘲讽优先（有视线也要去砸，这才是诱饵意义）
  // 仅当此刻完全走不到纸影时，才回追玩家，避免卡死空转
  if (decoyAlive(c)) {
    const decoyGoal = { ...c.decoy.pos };
    const nextToDecoy = manhattan(c.enemyPos, decoyGoal) <= 1;
    if (nextToDecoy || stepEnemyToward(decoyGoal, c)) {
      c.patrolGoal = null;
      return decoyGoal;
    }
  }

  // 节目指令「点亮舞台」：优先追最近亮锚
  if (c.isBoss && c.directive?.id === "spotlight") {
    const anchor = nearestLitAnchor(c, c.enemyPos);
    if (anchor) return anchor;
  }
  if (sees) {
    c.patrolGoal = null;
    return { ...c.playerPos };
  }
  if (c.lastSeen) {
    c.patrolGoal = null;
    return { ...c.lastSeen };
  }
  // 无目击：巡逻偏向玩家所在半场，不能无限挂机
  return ensurePatrolGoal(c);
}

function listPatrolCandidates(c) {
  const out = [];
  for (let r = 0; r < c.grid.rows; r += 1) {
    for (let col = 0; col < c.grid.cols; col += 1) {
      const p = { r, c: col };
      if (!isPassable(p)) continue;
      if (keyOf(p) === keyOf(c.enemyPos)) continue;
      out.push(p);
    }
  }
  return out;
}

function pickPatrolWaypoint(c) {
  const cands = listPatrolCandidates(c);
  if (!cands.length) return null;
  // 偏向玩家（或最后目击点）附近，其次再挑离自己略远的点做搜查
  const bias = c.lastSeen || c.playerPos;
  cands.sort(
    (a, b) =>
      manhattan(a, bias) - manhattan(b, bias) ||
      manhattan(b, c.enemyPos) - manhattan(a, c.enemyPos),
  );
  const pool = cands.slice(0, Math.max(3, Math.ceil(cands.length / 3)));
  return { ...pool[Math.floor(Math.random() * pool.length)] };
}

function ensurePatrolGoal(c) {
  if (c.patrolGoal && keyOf(c.patrolGoal) === keyOf(c.enemyPos)) {
    c.patrolGoal = null;
  }
  if (c.patrolGoal && !isPassable(c.patrolGoal)) {
    c.patrolGoal = null;
  }
  if (!c.patrolGoal) {
    c.patrolGoal = pickPatrolWaypoint(c);
  }
  return c.patrolGoal ? { ...c.patrolGoal } : null;
}

function decoyAlive(c) {
  return !!(c.decoy && c.decoy.hp > 0 && c.decoy.pos);
}

function smashDecoy(c, reason) {
  if (!decoyAlive(c)) return false;
  c.decoy.hp -= 1;
  log(`${c.enemy.name}${reason || "打散了"}纸影傀儡。`, "ok");
  labEvent("decoy_smash", { reason: reason || "打散", pos: { ...c.decoy.pos } });
  if (c.decoy.hp <= 0) c.decoy = null;
  playTone("ok");
  return true;
}

/* ========== Boss 仪式（锚点 / 播出时钟 / 蓄力 / 阶段 / 节目指令） ========== */

function bossFightCfg() {
  return state.data.pressure?.bossFight || {};
}

function litAnchorKeys(c) {
  return Object.keys(c.anchors || {}).filter((k) => c.anchors[k]?.lit);
}

function anchorsClearedCount(c) {
  return Object.values(c.anchors || {}).filter((a) => !a.lit).length;
}

function allAnchorsOut(c) {
  const keys = Object.keys(c.anchors || {});
  return keys.length > 0 && keys.every((k) => !c.anchors[k].lit);
}

function currentBossPhase(c) {
  const phases = bossFightCfg().phases || [];
  const cleared = anchorsClearedCount(c);
  let best = phases[0] || { cleared: 0, name: "开场", stam: 4, clock: 1 };
  for (const p of phases) {
    if (cleared >= (p.cleared || 0)) best = p;
  }
  return best;
}

function nearestLitAnchor(c, fromPos) {
  let best = null;
  let bestD = Infinity;
  for (const k of litAnchorKeys(c)) {
    const p = parseKey(k);
    const d = manhattan(fromPos || c.enemyPos, p);
    if (d < bestD) {
      bestD = d;
      best = p;
    }
  }
  return best;
}

function chargeRadius(c) {
  const phase = currentBossPhase(c);
  // 山屋平面房间挤在一起：半径 2 会吞半张图，终幕只加快频率、不扩圈
  if (c.houseGraph) return 1;
  return phase.wideCharge || phase.frenzy ? 2 : 1;
}

function chargeCellsAround(center, radius) {
  const cells = [];
  for (let dr = -radius; dr <= radius; dr += 1) {
    for (let dc = -radius; dc <= radius; dc += 1) {
      const pos = { r: center.r + dr, c: center.c + dc };
      if (inBounds(pos) && !isBlocked(pos)) cells.push(pos);
    }
  }
  return cells;
}

function damageAnchorsInCells(c, cells, amount, source) {
  if (!c.isBoss || !c.anchors || amount <= 0) return 0;
  let hit = 0;
  for (const pos of cells || []) {
    const k = keyOf(pos);
    const a = c.anchors[k];
    if (!a?.lit) continue;
    a.hp -= amount;
    hit += 1;
    labEvent("anchor_hit", { key: k, amount, source, hpLeft: Math.max(0, a.hp) });
    if (a.hp <= 0) {
      a.lit = false;
      a.hp = 0;
      log(`信号锚 (${pos.r + 1},${pos.c + 1}) 熄灭了！`, "ok");
      labEvent("anchor_out", { key: k, source });
      if (state.lab) {
        state.lab.summary.anchorsCleared = (state.lab.summary.anchorsCleared || 0) + 1;
        if (source === "boss" || source === "charge") {
          state.lab.summary.anchorsClearedByBoss = (state.lab.summary.anchorsClearedByBoss || 0) + 1;
        }
      }
      relieveBroadcast(c, bossFightCfg().anchorClockRelief || 3, "熄灭锚点");
      checkBossPhaseUp(c);
      if (allAnchorsOut(c)) {
        winCombat("ritual");
        return hit;
      }
    } else {
      log(`信号锚 (${pos.r + 1},${pos.c + 1}) 受损（剩 ${a.hp}）。`, "ok");
    }
  }
  return hit;
}

function relieveBroadcast(c, amount, reason) {
  if (!c.isBoss || !amount) return;
  const before = c.broadcast || 0;
  c.broadcast = Math.max(0, before - amount);
  if (c.broadcast < before) {
    log(`播出进度 -${before - c.broadcast}（${reason}）→ ${c.broadcast}/${c.broadcastMax}`, "ok");
  }
}

function tickBroadcast(c) {
  if (!c.isBoss) return false;
  const phase = currentBossPhase(c);
  let add = phase.clock || 1;
  const sees = hasLoS(c.enemyPos, c.playerPos);
  if (sees) add += bossFightCfg().seenClockBonus || 0;
  if (c.directive?.id === "extra") add += 1;
  c.broadcast = Math.min(c.broadcastMax, (c.broadcast || 0) + add);
  labEvent("broadcast_tick", { add, value: c.broadcast, max: c.broadcastMax, sees });
  log(`播出进度 +${add} → ${c.broadcast}/${c.broadcastMax}${sees ? "（有视线）" : ""}`, c.broadcast >= c.broadcastMax ? "bad" : "");
  if (c.broadcast >= c.broadcastMax) {
    loseCombat("broadcast");
    return true;
  }
  return false;
}

function checkBossPhaseUp(c) {
  if (!c.isBoss) return;
  const phase = currentBossPhase(c);
  const idx = (bossFightCfg().phases || []).findIndex((p) => p.name === phase.name);
  if (idx > (c.phaseIndex || 0)) {
    c.phaseIndex = idx;
    c.phaseName = phase.name;
    if (phase.stam) c.staminaMax = phase.stam + (tierScale(c.tier).stam || 0);
    log(`频道切换——进入「${phase.name}」！`, "bad");
    labEvent("phase_up", { name: phase.name, cleared: anchorsClearedCount(c) });
    if (state.lab) state.lab.summary.phaseReached = phase.name;
    playTone("face");
  }
}

function drawBossDirective(c) {
  if (!c.isBoss) return null;
  const pool = bossFightCfg().directives || [];
  if (!pool.length) return null;
  const cleared = anchorsClearedCount(c);
  const eligible = pool.filter((d) => (d.minCleared || 0) <= cleared);
  const bag = eligible.length ? eligible : pool;
  const pick = bag[Math.floor(Math.random() * bag.length)];
  c.directive = { ...pick };
  labEvent("directive", { id: pick.id, label: pick.label });
  log(`节目指令：${pick.label}——${pick.desc}`, "bad");
  if (pick.id === "mute") {
    c.lastSeen = null;
    log(`${c.enemy.name}这一回合丢失了气味追踪。`, "ok");
  }
  return c.directive;
}

function shouldBossCharge(c) {
  if (!c.isBoss || c.chargePending) return false;
  const sees = hasLoS(c.enemyPos, c.playerPos);
  if (!sees) return false;
  const dist = manhattan(c.enemyPos, c.playerPos);
  // 贴脸或邻近、且行动力够时有机会蓄力；终幕更高
  const phase = currentBossPhase(c);
  if (dist > 2) return false;
  if (phase.frenzy) return Math.random() < 0.42;
  if (phase.wideCharge) return Math.random() < 0.35;
  return Math.random() < 0.28;
}

function beginBossCharge(c) {
  const radius = chargeRadius(c);
  // 落点优先：覆盖玩家，并尽量吞进附近亮锚（让「引砸」成为可见策略）
  const candidates = [{ ...c.playerPos }, ...neighbors(c.playerPos)];
  for (const a of litAnchorKeys(c)) candidates.push(parseKey(a));
  let best = null;
  let bestScore = -1;
  for (const center of candidates) {
    if (!inBounds(center) || isBlocked(center)) continue;
    const cells = chargeCellsAround(center, radius);
    if (!cellsContain(cells, c.playerPos)) continue;
    const anchorHits = cells.filter((p) => c.anchors?.[keyOf(p)]?.lit).length;
    const score = anchorHits * 10 - manhattan(center, c.playerPos);
    if (score > bestScore) {
      bestScore = score;
      best = { center: { ...center }, cells, radius };
    }
  }
  if (!best) {
    best = {
      center: { ...c.playerPos },
      cells: chargeCellsAround(c.playerPos, radius),
      radius,
    };
  }
  const phase = currentBossPhase(c);
  const mult = phase.frenzy ? 1.25 : 1.2;
  const per = Math.max(1, Math.ceil(estimateHurtDamage(c) * mult));
  c.chargePending = {
    cells: best.cells.map((p) => ({ ...p })),
    damage: per,
    center: best.center,
    radius: best.radius,
  };
  // 蓄力已锁定落点：清掉暴露惊吓，避免意图被「惊吓」盖住蓄力红区
  c.playerExposed = false;
  log(
    `${c.enemy.name}开始蓄力冲击——实线红区下回合必落（${per} 伤 · 半径 ${best.radius} · ${best.cells.length} 格）！先离开红区或叠格挡。`,
    "bad",
  );
  labEvent("charge_start", { damage: per, radius: best.radius, cells: best.cells.length });
  if (state.lab) state.lab.summary.chargeCasts = (state.lab.summary.chargeCasts || 0) + 1;
  playTone("face");
  // 立刻刷意图，让红区出现在「结束敌回合 → 你行动」之前也能看见
  c.intent = predictIntent(c);
  renderCombat();
}

function resolveBossCharge(c) {
  const ch = c.chargePending;
  if (!ch) return "ok";
  c.chargePending = null;
  labEvent("charge_land", { damage: ch.damage, cells: ch.cells.length });
  log(`${c.enemy.name}释放蓄力冲击！`, "bad");
  damageAnchorsInCells(c, ch.cells, 2, "charge");
  if (!state.combat) return "done";
  if (cellsContain(ch.cells, c.playerPos)) {
    if (applyEnemyHit(c, "charge", ch.damage)) return "lose";
  } else {
    log("你躲开了蓄力冲击的落点。", "ok");
  }
  return "ok";
}

function tryDismantleAnchor() {
  const c = state.combat;
  if (!c?.isBoss) return false;
  const k = keyOf(c.playerPos);
  const a = c.anchors?.[k];
  if (!a?.lit) {
    log("你脚下没有亮着的信号锚。", "bad");
    return false;
  }
  const cost = bossFightCfg().dismantleCost || 2;
  if (c.energy < cost) {
    log(`拆信号需要 ${cost} 行动力。`, "bad");
    return false;
  }
  c.energy -= cost;
  damageAnchorsInCells(c, [c.playerPos], 1, "dismantle");
  if (!state.combat) return true;
  renderCombat();
  return true;
}

function portalMate(pos) {
  const c = state.combat;
  if (!c?.portals) return null;
  const k = keyOf(pos);
  const dest = c.portals[k];
  return dest ? parseKey(dest) : null;
}

/** 踏入传送格：移到对端。返回是否传送。落地后由调用方 triggerFloor。 */
function tryPortal(who, fromPos) {
  const c = state.combat;
  const dest = portalMate(fromPos);
  if (!dest) return false;
  // 单位可叠格，仅墙/越界挡住传送
  if (isBlocked(dest) || !inBounds(dest)) {
    log("传送门嗡了一下，但对端被挡住了。");
    return false;
  }
  if (who === "player") c.playerPos = { ...dest };
  else if (who === "enemy") {
    c.enemyPos = { ...dest };
    resolveEnemyLandOverlap(c);
  }
  log(who === "player" ? `你跌进隧道，出现在 (${dest.r + 1},${dest.c + 1})。` : `${c.enemy.name}跌进隧道，出现在 (${dest.r + 1},${dest.c + 1})。`, who === "player" ? "ok" : "bad");
  c.portalLanded = true;
  return true;
}

function adjacentTrapBonus(c, enemyPos) {
  return neighbors(enemyPos).some((p) => {
    const item = c.floor[keyOf(p)];
    return item && (item.onStep?.damage || item.enterTax);
  });
}

function pickRelicOffers(n = 2) {
  const available = state.data.relics.pool.filter((x) => !state.relics.includes(x));
  const pool = shuffle([...available]);
  return pool.slice(0, n);
}

function offerOpeningRelics() {
  if (state.tutorial?.active) return;
  const offers = pickRelicOffers(2);
  if (!offers.length) return;
  showModal("screen-event");
  $("event-title").textContent = "行前预兆";
  $("event-text").textContent = "拧开旋钮前，频道先送来两枚预兆——选一枚随身带走。";
  $("btn-close-event").classList.add("hidden");
  clearRewardCards();
  hideCardTooltip();
  const box = $("event-choices");
  box.innerHTML = "";
  const row = $("reward-cards");
  for (const id of offers) {
    const def = relicDef(id);
    const card = document.createElement("div");
    card.className = "reward-card frame-blue";
    card.tabIndex = 0;
    card.innerHTML = `<strong>${def.name}</strong><span class="card-kind"><img src="assets/ui/cards/SP_Card_IconT_Omen.png" alt="" />预兆</span><p class="blurb">${def.desc}</p>`;
    bindHoverTip(card, relicTooltipHtml(def));
    const take = document.createElement("button");
    take.type = "button";
    take.className = "btn btn-primary btn-ticket";
    take.textContent = "带上";
    take.onclick = () => {
      hideCardTooltip();
      gainRelic(id);
      clearRewardCards();
      $("event-text").textContent = `${def.name}贴在掌心。该进山屋了。`;
      box.innerHTML = "";
      $("btn-close-event").classList.remove("hidden");
      renderAll();
      saveGame();
    };
    card.appendChild(take);
    row.appendChild(card);
  }
}

function cellHasMechanism(pos) {
  const c = state.combat;
  if (!c || !pos) return false;
  const item = c.floor[keyOf(pos)];
  return !!(item && (item.onStep || item.enterTax));
}

function cellTrapScore(pos) {
  const c = state.combat;
  if (!c || !pos) return 0;
  const item = c.floor[keyOf(pos)];
  if (!item) return 0;
  if (item.onStep?.damage) return 100 + (item.onStep.damage || 0) * 10;
  if (item.enterTax) return 40;
  if (item.onStep) return 30;
  return 0;
}

function cellIsPortal(pos) {
  const c = state.combat;
  return !!(c?.portals && c.portals[keyOf(pos)]);
}

/**
 * 甩开落点：机关优先（刺/盐），再空地。
 * 常见布景是「身侧 / 身后」放刺——不能只往「远离玩家」推，否则永远甩不进陷阱。
 * 空地绝不优先甩上传送门（长廊两头门会把怪瞬移到远端，像「越甩越远」）。
 */
function pickForcedShoveDest(c, opts = {}) {
  const preferPortal = !!opts.preferPortal;
  const pk = keyOf(c.playerPos);
  const ortho = neighbors(c.enemyPos).filter(
    (p) => keyOf(p) !== pk && inBounds(p) && !isBlocked(p),
  );

  const rank = (p, kindBonus = 0) => {
    const trap = cellTrapScore(p);
    const dist = manhattan(p, c.playerPos);
    // 有机关：略偏向靠近你的布景；无机关：略推远，但传送门大扣分（引渡则反过来）
    const distScore = trap > 0 ? Math.max(0, 6 - dist) : dist * 2;
    let portalScore = 0;
    if (cellIsPortal(p)) {
      portalScore = preferPortal ? (trap > 0 ? 40 : 90) : trap > 0 ? 0 : -80;
    }
    return trap * 10 + distScore + kindBonus + portalScore;
  };

  let best = null;
  let bestScore = -Infinity;
  let bestKind = "away";

  for (const p of ortho) {
    const s = rank(p);
    if (s > bestScore) {
      bestScore = s;
      best = p;
      bestKind = cellTrapScore(p) > 0 ? "trap" : cellIsPortal(p) ? "portal" : "away";
    }
  }

  // 穿过你：怪在身前贴脸时，身后那一格若有机关，优先甩过去（小鬼当家）
  if (isOrthoAdjacent(c.enemyPos, c.playerPos)) {
    const dr = Math.sign(c.playerPos.r - c.enemyPos.r);
    const dc = Math.sign(c.playerPos.c - c.enemyPos.c);
    const past = { r: c.playerPos.r + dr, c: c.playerPos.c + dc };
    if (inBounds(past) && !isBlocked(past) && keyOf(past) !== keyOf(c.enemyPos)) {
      const s = rank(past, 35);
      const pastGood =
        cellTrapScore(past) > 0 || (preferPortal && cellIsPortal(past));
      if (pastGood && s > bestScore) {
        bestScore = s;
        best = past;
        bestKind = cellTrapScore(past) > 0 ? "throughTrap" : "portal";
      }
    }
  }

  if (preferPortal) {
    if (best && (cellIsPortal(best) || cellTrapScore(best) > 0)) {
      return { dest: best, kind: bestKind };
    }
    const portalOpt = ortho
      .filter((p) => cellIsPortal(p))
      .sort((a, b) => rank(b) - rank(a))[0];
    if (portalOpt) return { dest: portalOpt, kind: "portal" };
  }

  if (best && cellTrapScore(best) > 0) {
    return { dest: best, kind: bestKind };
  }
  // 无机关：宁可推近侧空地，也不主动甩上传送门
  if (best && cellIsPortal(best)) {
    const nonPortal = ortho
      .filter((p) => !cellIsPortal(p))
      .sort((a, b) => rank(b) - rank(a))[0];
    if (nonPortal) {
      return { dest: nonPortal, kind: "away" };
    }
  }
  if (best) return { dest: best, kind: bestKind === "portal" ? "portal" : "away" };
  return { dest: null, kind: "wall" };
}

/**
 * 强制把敌人甩开 1 格并触发落点。预备已清空后再调用，避免二次触发。
 * @param {string} reason
 * @param {{ preferPortal?: boolean }} [opts]
 * @returns {{ moved: boolean, killed: boolean, ported: boolean }}
 */
function forceEnemyShove(reason = "推撞", opts = {}) {
  const c = state.combat;
  if (!c) return { moved: false, killed: false, ported: false };
  const from = { ...c.enemyPos };
  const pick = pickForcedShoveDest(c, opts);
  if (pick.kind === "wall" || !pick.dest) {
    drainToughness(1, `${reason}撞墙削韧`);
    log(`${reason}：${c.enemy.name}撞上障碍，韧性 -1。`, "ok");
    labEvent("shove", {
      reason,
      kind: "wall",
      from,
      dest: null,
      portal: false,
      trap: false,
      preferPortal: !!opts.preferPortal,
    });
    playTone("ok");
    return { moved: false, killed: false, ported: false };
  }
  const dest = pick.dest;
  const via =
    pick.kind === "trap" || pick.kind === "throughTrap" || pick.kind === "sideTrap"
      ? "，正好甩进机关"
      : cellTrapScore(dest) > 0
        ? "，甩进机关"
        : cellIsPortal(dest)
          ? "（落在隧道门上——可能被送走）"
          : "（附近没有可踩的机关）";
  c.enemyPos = { ...dest };
  log(`${reason}：把${c.enemy.name}甩到 (${dest.r + 1},${dest.c + 1})${via}。`, "ok");
  playTone("ok");
  resolveEnemyLandOverlap(c);
  c.portalLanded = false;
  // 先结算落点机关，再传送——避免陷阱被传送「跳过」
  triggerFloor(c.enemyPos, "enemy");
  if (!state.combat || c.enemy.hp <= 0) {
    labEvent("shove", {
      reason,
      kind: pick.kind,
      from,
      dest,
      portal: false,
      trap: true,
      killed: true,
      preferPortal: !!opts.preferPortal,
    });
    return { moved: true, killed: !!(c.enemy && c.enemy.hp <= 0), ported: false };
  }
  const beforePortal = { ...c.enemyPos };
  let ported = false;
  if (tryPortal("enemy", c.enemyPos)) {
    ported = keyOf(c.enemyPos) !== keyOf(beforePortal);
    if (ported) {
      triggerFloor(c.enemyPos, "enemy");
    }
  }
  labEvent("shove", {
    reason,
    kind: pick.kind,
    from,
    dest: beforePortal,
    afterPortal: ported ? { ...c.enemyPos } : null,
    portal: ported,
    trap: cellTrapScore(beforePortal) > 0,
    preferPortal: !!opts.preferPortal,
  });
  return { moved: true, killed: !!(c.enemy && c.enemy.hp <= 0), ported };
}

function resolveShove(inst) {
  const c = state.combat;
  const def = cardDef(inst.id);
  if (!isOrthoAdjacent(c.playerPos, c.enemyPos)) {
    log(`${def.name}需要与敌人邻接。`, "bad");
    return false;
  }
  const cost = Math.max(0, def.cost - c.discount);
  if (cost > c.energy) return false;
  c.energy -= cost;
  c.discount = 0;
  c.hand = c.hand.filter((x) => x.uid !== inst.uid);
  if (c.heldUid === inst.uid) c.heldUid = null;
  if (c.placeUid === inst.uid) c.placeUid = null;
  retireCard(inst);
  maybeFreeDraw(c, cost);

  const label = def.preferPortal ? def.name : "推撞";
  const result = forceEnemyShove(label, { preferPortal: !!def.preferPortal });
  if (result.ported && def.drawOnPortal) {
    combatDraw(def.drawOnPortal, "隧道连击");
    comboPop("隧道连击");
  }
  if (result.killed) {
    winCombat();
    return true;
  }
  c.intent = predictIntent(c);
  renderCombat();
  return true;
}

/** 登台：移到正交邻接的更高格（不另耗行动力） */
function resolveClimbToHigher(inst) {
  const c = state.combat;
  const def = cardDef(inst.id);
  const here = tileHeight(c.playerPos);
  const opts = neighbors(c.playerPos)
    .filter((p) => keyOf(p) !== keyOf(c.enemyPos))
    .filter((p) => tileHeight(p) > here)
    .sort((a, b) => tileHeight(b) - tileHeight(a) || keyOf(a).localeCompare(keyOf(b)));
  if (!opts.length) {
    log("附近没有更高的台面可登。", "bad");
    return false;
  }
  const cost = Math.max(0, def.cost - c.discount);
  if (cost > c.energy) return false;
  c.energy -= cost;
  c.discount = 0;
  c.hand = c.hand.filter((x) => x.uid !== inst.uid);
  if (c.heldUid === inst.uid) c.heldUid = null;
  if (c.placeUid === inst.uid) c.placeUid = null;
  retireCard(inst);
  maybeFreeDraw(c, cost);

  const dest = opts[0];
  c.playerPos = { ...dest };
  c.portalLanded = false;
  if (tryPortal("player", c.playerPos)) {
    /* teleported */
  }
  const h = tileHeight(c.playerPos);
  log(`登台至 (${c.playerPos.r + 1},${c.playerPos.c + 1}) · 高${h}。`, "ok");
  comboPop("高台砸击");
  playTone("ok");
  refreshVision();
  c.intent = predictIntent(c);
  renderCombat();
  return true;
}

/** 格子视线：墙/空洞遮挡；中间更高的脊也遮挡；邻接始终可见（山屋图还需有门） */
function hasLoS(a, b) {
  if (!a || !b) return false;
  if (keyOf(a) === keyOf(b)) return true;
  if (manhattan(a, b) === 1) {
    return isPassable(a) && isPassable(b) && canStepBetween(a, b);
  }

  const n = Math.max(Math.abs(b.r - a.r), Math.abs(b.c - a.c));
  const hEye = Math.max(tileHeight(a), tileHeight(b));
  let prev = a;
  for (let i = 1; i < n; i += 1) {
    const r = Math.round(a.r + ((b.r - a.r) * i) / n);
    const c = Math.round(a.c + ((b.c - a.c) * i) / n);
    const p = { r, c };
    if (!inBounds(p)) return false;
    if (isBlocked(p)) return false;
    if (tileHeight(p) > hEye) return false;
    if (state.combat?.houseGraph) {
      // 山屋图：直线路径上的格必须可走，且相邻格有门
      if (!isPassable(p)) return false;
      if (isOrthoAdjacent(prev, p) && !canStepBetween(prev, p)) return false;
      prev = p;
    }
  }
  if (state.combat?.houseGraph && isOrthoAdjacent(prev, b) && !canStepBetween(prev, b)) {
    return false;
  }
  return isPassable(b);
}

function isEnemyBlinded(c) {
  return !!(c && (c.blindTurns || 0) > 0);
}

/** 致盲至少 turns 个敌方回合——丢目击、无法靠视线锁定/攻击 */
function applyBlind(c, source = "flare", turns = 1) {
  if (!c) return;
  const add = Math.max(1, turns || 1);
  c.lastSeen = null;
  c.lastSeenAge = 0;
  c.blindArmed = true;
  c.blindTurns = Math.max(c.blindTurns || 0, add);
  c.enemySeesPlayer = false;
  log(
    `强光炸开——它瞎了 ${c.blindTurns} 敌回合：丢失目击，暂时无法锁定攻击！`,
    "ok",
  );
  labEvent("blind", { source, turns: c.blindTurns });
}

function combatDraw(n, reason = "抽牌") {
  const c = state.combat;
  if (!c || n <= 0) return 0;
  let drawn = 0;
  for (let i = 0; i < n; i += 1) {
    const card = drawOne();
    if (!card) break;
    c.hand.push(card);
    drawn += 1;
  }
  if (drawn) log(`${reason}：抽 ${drawn}。`, "ok");
  return drawn;
}

function tickBlind(c) {
  if (!c || !(c.blindTurns > 0)) return;
  c.blindTurns -= 1;
  if (c.blindTurns <= 0) {
    c.blindTurns = 0;
    log(`${c.enemy.name}的眼睛缓过来了。`);
  }
}

function refreshVision() {
  const c = state.combat;
  if (!c) return { playerSees: false, enemySees: false, faceReveal: false };
  const playerSees = hasLoS(c.playerPos, c.enemyPos);
  // 几何上有视线，但致盲期间当作看不见（否则砸闪光后立刻 refresh 会把目击设回来）
  const geoSees = hasLoS(c.enemyPos, c.playerPos);
  const enemySees = geoSees && !isEnemyBlinded(c);
  let faceReveal = false;
  if (enemySees) {
    if (!c.enemyHadLoS) faceReveal = true;
    c.lastSeen = { ...c.playerPos };
    c.lastSeenAge = 0;
    c.enemyHadLoS = true;
    if (c.ambushActive) {
      c.ambushActive = false;
      c.ambushSpring = true;
      log(`${c.enemy.name}的埋伏被揭开了——它猛地扑出来！`, "bad");
    }
  } else if (!isEnemyBlinded(c)) {
    c.enemyHadLoS = false;
  }
  c.playerSeesEnemy = playerSees;
  c.enemySeesPlayer = enemySees;
  return { playerSees, enemySees, faceReveal };
}

function log(msg, cls = "") {
  const el = document.createElement("div");
  if (cls) el.className = cls;
  el.textContent = msg;
  $("log").prepend(el);
}

/* ========== 实验遥测 Lab（胜负不清，供强度分析） ========== */

function deckCounts() {
  const counts = {};
  for (const c of allOwnedCards()) {
    counts[c.id] = (counts[c.id] || 0) + 1;
  }
  return counts;
}

function loadLabStore() {
  try {
    const raw = localStorage.getItem(LAB_KEY);
    if (!raw) return { version: 1, runs: [] };
    const data = JSON.parse(raw);
    if (!data || !Array.isArray(data.runs)) return { version: 1, runs: [] };
    return data;
  } catch {
    return { version: 1, runs: [] };
  }
}

function saveLabStore(store) {
  localStorage.setItem(LAB_KEY, JSON.stringify(store));
}

function labEvent(type, payload = {}) {
  if (!state.lab) return;
  state.lab.events.push({
    t: Date.now(),
    turn: state.lab.summary.turns,
    type,
    ...payload,
  });
}

function beginLabCombat(room, enc, isBoss) {
  state.lab = {
    id: `lab_${Date.now()}_${Math.floor(Math.random() * 9999)}`,
    startedAt: new Date().toISOString(),
    tag: state.labTag || "normal",
    roomId: room?.id || null,
    roomName: room?.name || roomDef(room?.id)?.name || null,
    player: {
      speed: state.speed,
      hpStart: state.hp,
      maxHp: state.maxHp,
      relics: [...state.relics],
      deckCounts: deckCounts(),
      visitLen: state.visitPath.length,
      combatCount: state.combatCount || 0,
    },
    enemy: {
      name: enc.name,
      isBoss: !!isBoss,
      bossId: isBoss ? state.chosenBoss : null,
      hp: enc.hp,
      damage: enc.damage,
      toughness: enc.toughness,
      staminaMax: enc.staminaMax,
      traits: [...(enc.traits || [])],
      archetype: enc.archetype,
      archetypeLabel: enc.archetypeLabel,
      tier: enc.tier,
    },
    summary: {
      turns: 0,
      damageDealt: 0,
      damageTaken: 0,
      damageBlocked: 0,
      smashHits: 0,
      trapHits: 0,
      toughnessBroken: false,
      toughnessBreakTurn: null,
      combos: {},
      enemyAttacks: 0,
      faceReveals: 0,
      playerHpEnd: null,
      enemyHpEnd: null,
      durationMs: null,
      anchorsTotal: isBoss
        ? Object.keys(state.combat?.anchors || {}).length ||
          (roomDef("altar")?.arena?.anchors || []).length
        : 0,
      anchorsCleared: 0,
      anchorsClearedByBoss: 0,
      broadcastEnd: null,
      phaseReached: isBoss ? "开场" : null,
      chargeCasts: 0,
      outcomeReason: null,
    },
    events: [],
    outcome: null,
    endingTitle: null,
  };
  labEvent("combat_start", {
    enemyHp: enc.hp,
    toughness: enc.toughness,
    playerHp: state.hp,
    tag: state.lab.tag,
  });
}

function labNoteCombo(name) {
  if (!state.lab) return;
  state.lab.summary.combos[name] = (state.lab.summary.combos[name] || 0) + 1;
  labEvent("combo", { name });
}

function labNoteDamageDealt(amount, source) {
  if (!state.lab || amount <= 0) return;
  state.lab.summary.damageDealt += amount;
  if (source === "smash") state.lab.summary.smashHits += 1;
  if (source === "trap") state.lab.summary.trapHits += 1;
  if (source === "ready") state.lab.summary.readyHits = (state.lab.summary.readyHits || 0) + 1;
  if (source === "stall_break") state.lab.summary.stallBreaks = (state.lab.summary.stallBreaks || 0) + 1;
  labEvent("damage_dealt", { amount, source, enemyHp: state.combat?.enemy?.hp });
}

function labNoteDamageTaken(raw, blocked, dealt, kind) {
  if (!state.lab) return;
  state.lab.summary.damageBlocked += blocked || 0;
  state.lab.summary.damageTaken += dealt || 0;
  state.lab.summary.enemyAttacks += 1;
  labEvent("damage_taken", {
    raw,
    blocked: blocked || 0,
    dealt: dealt || 0,
    kind,
    playerHp: state.hp,
  });
}

function labNoteToughBreak(reason) {
  if (!state.lab) return;
  state.lab.summary.toughnessBroken = true;
  state.lab.summary.toughnessBreakTurn = state.lab.summary.turns;
  labEvent("toughness_break", { reason, turn: state.lab.summary.turns });
}

function labNotePlayerTurn(energy, rolls) {
  if (!state.lab) return;
  state.lab.summary.turns += 1;
  labEvent("player_turn", {
    turn: state.lab.summary.turns,
    energy,
    rolls: [...(rolls || [])],
    playerHp: state.hp,
    enemyHp: state.combat?.enemy?.hp,
    toughness: state.combat?.toughness,
    sees: !!state.combat?.enemySeesPlayer,
  });
}

function finalizeLabCombat(outcome, endingTitle = null, outcomeReason = null) {
  if (!state.lab) return null;
  const c = state.combat;
  state.lab.outcome = outcome;
  state.lab.endingTitle = endingTitle;
  state.lab.endedAt = new Date().toISOString();
  state.lab.summary.playerHpEnd = state.hp;
  state.lab.summary.enemyHpEnd = c?.enemy?.hp ?? null;
  state.lab.summary.durationMs = Date.now() - Date.parse(state.lab.startedAt);
  if (c?.isBoss) {
    state.lab.summary.broadcastEnd = c.broadcast ?? null;
    state.lab.summary.phaseReached = c.phaseName || state.lab.summary.phaseReached;
    state.lab.summary.anchorsCleared = anchorsClearedCount(c);
    state.lab.summary.outcomeReason = outcomeReason || outcome;
  }
  labEvent("combat_end", {
    outcome,
    endingTitle,
    outcomeReason,
    playerHp: state.hp,
    enemyHp: c?.enemy?.hp ?? null,
  });

  const record = JSON.parse(JSON.stringify(state.lab));
  const store = loadLabStore();
  store.runs.unshift(record);
  if (store.runs.length > LAB_MAX_RUNS) store.runs.length = LAB_MAX_RUNS;
  saveLabStore(store);
  state.lab = null;
  renderLabPanel();
  return record;
}

function exportLabJson() {
  const store = loadLabStore();
  const blob = new Blob([JSON.stringify(store, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `cabin-lab-${new Date().toISOString().slice(0, 19).replace(/[:T]/g, "-")}.json`;
  a.click();
  URL.revokeObjectURL(url);
}

/** 调试：把 localStorage 实验记录 POST 到本地 dump 服务 */
async function dumpLabToWorkspace() {
  const raw = localStorage.getItem(LAB_KEY) || '{"version":1,"runs":[]}';
  try {
    await fetch("/__dump-lab", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: raw,
    });
  } catch (err) {
    console.warn("dumpLab POST failed", err);
  }
  return raw;
}

function clearLabStore() {
  if (!confirm("清空全部实验记录？此操作不可恢复。")) return;
  localStorage.removeItem(LAB_KEY);
  renderLabPanel();
}

function renderLabPanel() {
  const list = $("lab-list");
  const meta = $("lab-meta");
  if (!list) return;
  const store = loadLabStore();
  if (meta) {
    meta.textContent = store.runs.length
      ? `已记录 ${store.runs.length} 场（最多保留 ${LAB_MAX_RUNS}）· 键名 ${LAB_KEY}`
      : `尚无实验记录 · 打完战斗后会自动写入 ${LAB_KEY}`;
  }
  list.innerHTML = "";
  if (!store.runs.length) {
    list.innerHTML = `<li class="lab-empty">还没有数据。用「跳到 Boss」或正常通关/失败各打一场即可。</li>`;
    return;
  }
  for (const run of store.runs.slice(0, 12)) {
    const s = run.summary || {};
    const li = document.createElement("li");
    const outcome =
      run.outcome === "win" ? "胜" : run.outcome === "lose" ? "负" : run.outcome || "?";
    const boss = run.enemy?.isBoss ? `Boss·${run.enemy?.name}` : run.enemy?.name || "战斗";
    li.innerHTML = `<strong>[${outcome}] ${boss}</strong>
      <span>${run.tag || "normal"} · ${s.turns || 0} 回 · 输出 ${s.damageDealt || 0} / 受伤 ${s.damageTaken || 0}
      ${s.anchorsTotal ? ` · 锚 ${s.anchorsCleared || 0}/${s.anchorsTotal}` : ""}
      ${s.broadcastEnd != null ? ` · 播出 ${s.broadcastEnd}` : ""}
      ${s.phaseReached ? ` · ${s.phaseReached}` : ""}
      ${s.outcomeReason ? ` · ${s.outcomeReason}` : ""}
      · HP ${run.player?.hpStart}→${s.playerHpEnd} · ${run.endedAt ? run.endedAt.slice(11, 19) : ""}</span>`;
    list.appendChild(li);
  }
}

function saveGame() {
  if (state.tutorial?.active) return;
  if (state.flingSandbox?.active) return;
  const payload = {
    roomId: state.roomId,
    speed: state.speed,
    hp: state.hp,
    maxHp: state.maxHp,
    visitPath: state.visitPath,
    resolvedRooms: [...state.resolvedRooms],
    knownRooms: [...state.knownRooms],
    deck: state.deck,
    discard: state.discard,
    relics: state.relics,
    chosenBoss: state.chosenBoss,
    nodePending: state.nodePending,
    combatCount: state.combatCount || 0,
    rewardRolls: state.rewardRolls || {},
    midRelicDone: !!state.midRelicDone,
    runSeed: state.runSeed || 0,
    roomLayout: state.roomLayout || null,
    uidSeq,
  };
  localStorage.setItem(SAVE_KEY, JSON.stringify(payload));
}

function loadGame() {
  const raw = localStorage.getItem(SAVE_KEY);
  if (!raw) return false;
  try {
    const p = JSON.parse(raw);
    state.roomId = p.roomId;
    state.speed = p.speed;
    state.hp = p.hp;
    state.maxHp = p.maxHp;
    state.visitPath = p.visitPath || [];
    state.resolvedRooms = new Set(p.resolvedRooms || []);
    state.knownRooms = new Set(p.knownRooms || []);
    state.deck = p.deck || buildStarterDeck();
    state.discard = p.discard || [];
    state.relics = p.relics || [];
    state.chosenBoss = p.chosenBoss;
    state.nodePending = !!p.nodePending;
    state.combatCount = p.combatCount || 0;
    state.rewardRolls = p.rewardRolls || {};
    state.midRelicDone = !!p.midRelicDone;
    state.runSeed = p.runSeed || 0;
    state.roomLayout = p.roomLayout || null;
    uidSeq = p.uidSeq || 100;
    // 旧存档若是「类型翻转」格式或缺失空间布局：按种子重掷平面图 / 或沿用 json
    if (state.roomLayout && !isSpatialLayout(state.roomLayout)) {
      rollRoomLayout(state.runSeed || ((Date.now() ^ 0x9e3779b9) >>> 0));
    }
    return true;
  } catch {
    return false;
  }
}

function setExploreCoach(title, body) {
  const box = $("tutorial-coach");
  if (!box) return;
  if (!state.tutorial?.active) {
    box.classList.add("hidden");
    return;
  }
  box.classList.remove("hidden");
  $("coach-title").textContent = title;
  $("coach-body").textContent = body;
}

function setBattleCoach(title, body) {
  const box = $("battle-coach");
  if (!box) return;
  if ((!state.tutorial?.active && !state.flingSandbox?.active) || !state.combat) {
    box.classList.add("hidden");
    return;
  }
  box.classList.remove("hidden");
  $("battle-coach-title").textContent = title;
  $("battle-coach-body").textContent = body;
}

function clearCoaches() {
  $("tutorial-coach")?.classList.add("hidden");
  $("battle-coach")?.classList.add("hidden");
}

function updateMuteButton() {
  const label = state.muted ? "音乐：关" : "音乐：开";
  const pressed = state.muted ? "true" : "false";
  for (const id of ["btn-mute", "btn-mute-map", "btn-mute-battle"]) {
    const btn = $(id);
    if (!btn) continue;
    btn.textContent = label;
    btn.setAttribute("aria-pressed", pressed);
  }
}

function toggleMute() {
  state.muted = !state.muted;
  setMuted(state.muted);
  try {
    localStorage.setItem("cabin-mute", state.muted ? "1" : "0");
  } catch (_) {}
  updateMuteButton();
  if (!state.muted) startBgm();
}

/** 预备·甩开独立切片：固定布局，不写正式存档 */
const FLING_SANDBOX_LAYOUTS = {
  corridor: {
    id: "corridor",
    label: "走廊（侧刺甩开）",
    tip: "第一拍它只靠近不下手。侧面放刺 → 挂甩开 → 回合结束，让它走进邻接。",
    room: {
      id: "fling_corridor",
      name: "沙盒·走廊",
      combat: true,
      flingSandbox: true,
      enemy: { name: "直挺挺的剪影", hp: 14, damage: 2 },
      arena: {
        rows: 3,
        cols: 7,
        player: [1, 5],
        enemy: [1, 0],
        walls: [],
        spawnNote:
          "走廊沙盒：第一拍只靠近。把刺放在你与它之间的侧面格 → 挂甩开 → 结束回合。",
      },
    },
  },
  closet: {
    id: "closet",
    label: "小房（贴脸被动）",
    tip: "第一拍只靠近。侧面布刺，挂甩开；若已贴脸，推开再引回，或等它在十字上挪步。",
    room: {
      id: "fling_closet",
      name: "沙盒·小房",
      combat: true,
      flingSandbox: true,
      enemy: { name: "挤门缝的剪影", hp: 12, damage: 2 },
      arena: {
        rows: 5,
        cols: 4,
        player: [1, 2],
        enemy: [3, 2],
        walls: [
          "0,0",
          "0,1",
          "0,2",
          "0,3",
          "1,0",
          "1,3",
          "2,0",
          "2,3",
          "3,0",
          "3,3",
          "4,0",
          "4,1",
          "4,2",
          "4,3",
        ],
        spawnNote:
          "小房沙盒：第一拍只靠近。刺放左侧；挂甩开。已贴脸时先推撞再引回。",
      },
    },
  },
};

function flingSandboxDeck() {
  return shuffle(
    ["jab", "jab", "guard", "heavy", "fling", "fling", "shove", "brace", "riposte", "tonic"]
      .filter((id) => !!cardDef(id))
      .map((id) => makeCard(id)),
  );
}

function refreshFlingSandboxCoach() {
  if (!state.flingSandbox?.active || !state.combat) {
    if (!state.tutorial?.active) $("battle-coach")?.classList.add("hidden");
    return;
  }
  const layout = FLING_SANDBOX_LAYOUTS[state.flingSandbox.layout];
  const c = state.combat;
  if (c.ready?.effect?.shove) {
    if (c.ready.awaitStep || isOrthoAdjacent(c.enemyPos, c.playerPos)) {
      setBattleCoach(
        "预备已挂·但已贴脸",
        "站桩砍不会触发。推撞推开再引回，或等它在绿边十字上挪一步；有侧刺就会被甩进去。",
      );
    } else {
      setBattleCoach(
        "预备已挂·甩开",
        "绿边十字是触发带。点「回合结束」，等它走进来——优先甩向机关。",
      );
    }
    return;
  }
  setBattleCoach(
    layout?.label || "预备·甩开沙盒",
    layout?.tip || "放置机关 → 挂甩开 → 引怪走进邻接。",
  );
}

function ensureSandboxFlingInHand() {
  const c = state.combat;
  if (!c || !state.flingSandbox?.active) return;
  if (c.hand.some((x) => x.id === "fling")) return;
  const ix = state.deck.findIndex((x) => x.id === "fling");
  if (ix >= 0) {
    c.hand.unshift(state.deck.splice(ix, 1)[0]);
    log("沙盒：把「甩开」提到手上了。", "ok");
  }
}

function offerFlingSandboxMenu() {
  show("screen-title");
  showModal("screen-event");
  $("event-title").textContent = "切片试玩 · 预备甩开";
  $("event-text").textContent =
    "小鬼当家式机关：你回合布刺/坠，挂「甩开」；敌回合走进相邻十字时被强制甩进道具。\n\n不写正式存档。选一个布局开打。";
  $("btn-close-event").classList.add("hidden");
  clearRewardCards();
  hideCardTooltip();
  const box = $("event-choices");
  box.innerHTML = "";
  for (const layout of Object.values(FLING_SANDBOX_LAYOUTS)) {
    addChoice(box, layout.label, "primary", () => startFlingSandbox(layout.id));
  }
  addChoice(box, "回标题", "", () => {
    showModal(null);
    show("screen-title");
  });
}

function exitFlingSandbox() {
  state.flingSandbox = null;
  state.combat = null;
  state.lab = null;
  state.labTag = "normal";
  clearCoaches();
  showModal(null);
  document.body.classList.remove("sts-overlay-open");
  $("screen-cards")?.classList.remove("active");
  hideCardTooltip();
  show("screen-title");
  if (localStorage.getItem(SAVE_KEY)) $("btn-continue")?.classList.remove("hidden");
  const status = $("boot-status");
  if (status) {
    status.classList.remove("bad");
    status.textContent = "沙盒已关闭。正式一局请「打开电视机」。";
  }
}

function startFlingSandbox(layoutId = "corridor") {
  const layout = FLING_SANDBOX_LAYOUTS[layoutId] || FLING_SANDBOX_LAYOUTS.corridor;
  if (state.tutorial?.active) exitTutorialMode({ startReal: false });
  state.flingSandbox = { active: true, layout: layout.id, triggered: false };
  state.labTag = "fling_sandbox";
  state.lab = null;
  state.roomId = layout.room.id;
  state.speed = 5;
  state.hp = 8;
  state.maxHp = 8;
  state.visitPath = [layout.room.id];
  state.resolvedRooms = new Set();
  state.knownRooms = new Set([layout.room.id]);
  state.deck = flingSandboxDeck();
  state.discard = [];
  state.relics = [];
  state.chosenBoss = null;
  state.nodePending = false;
  state.combat = null;
  state.combatCount = 0;
  state.rewardRolls = {};
  state.midRelicDone = true;
  state.roomLayout = null;
  state.runSeed = 0;
  uidSeq = 9000;
  $("log").innerHTML = "";
  log(`【预备·甩开沙盒 · ${layout.label}】不写存档。`, "ok");
  log(layout.tip);
  show("screen-game");
  showModal(null);
  startCombat(layout.room, false);
  if (state.combat) state.combat.flingGraceTurns = 1;
  ensureSandboxFlingInHand();
  refreshFlingSandboxCoach();
  renderCombat();
}

function offerFlingSandboxResult(won) {
  const layoutId = state.flingSandbox?.layout || "corridor";
  const triggered = !!state.flingSandbox?.triggered;
  showModal("screen-event");
  $("event-title").textContent = won
    ? triggered
      ? "沙盒 · 甩开奏效"
      : "沙盒 · 赢了但没测到甩开"
    : "沙盒 · 再摆一次";
  $("event-text").textContent = won
    ? triggered
      ? "预备甩开落地了。可换小房测贴脸被动，或再打同布局巩固。"
      : "这局是砸/踩赢的，甩开没有触发。再试：侧面放刺 → 挂甩开（别等贴脸后才挂）→ 结束回合。"
    : "死了也没关系。第一拍只靠近；侧面放刺 → 挂甩开 → 让它走进来。";
  $("btn-close-event").classList.add("hidden");
  clearRewardCards();
  hideCardTooltip();
  document.body.classList.remove("sts-overlay-open");
  $("screen-cards")?.classList.remove("active");
  const box = $("event-choices");
  box.innerHTML = "";
  addChoice(box, triggered ? "再试同布局" : "再试·专测甩开", "primary", () =>
    startFlingSandbox(layoutId),
  );
  const otherId = layoutId === "corridor" ? "closet" : "corridor";
  addChoice(box, `换成「${FLING_SANDBOX_LAYOUTS[otherId].label}」`, "", () =>
    startFlingSandbox(otherId),
  );
  addChoice(box, "回标题", "", () => exitFlingSandbox());
}

/** 放弃本集重开一局（新种子会自然出新平面图） */
function restartRun() {
  if (state.flingSandbox?.active) {
    startFlingSandbox(state.flingSandbox.layout);
    return;
  }
  if (state.tutorial?.active) {
    log("教学片请先回首页，再开正式节目。", "bad");
    return;
  }
  if (state.combat) {
    log("惊吓时间里不能重开——先打完或回首页。", "bad");
    return;
  }
  const seedHint = state.runSeed != null ? `\n（本集平面图 #${state.runSeed >>> 0}）` : "";
  const ok = window.confirm(`放弃当前进度，重开一局？${seedHint}`);
  if (!ok) return;
  resetGame();
}

/** 回到标题页；存档保留，可用「接着看上集」 */
function goHome({ fromCombat = false } = {}) {
  if (state.flingSandbox?.active) {
    if (state.combat && !fromCombat) {
      const ok = window.confirm("离开甩开沙盒？进度不存档。");
      if (!ok) return;
    }
    exitFlingSandbox();
    return;
  }
  if (state.combat) {
    if (!fromCombat) {
      const ok = window.confirm(
        "正打着惊吓时间。回主页会中断本场（房间可再进；进度进存档，可接着看上集）。确定？",
      );
      if (!ok) return;
    }
    abandonCombatForMenu();
  }
  if (state.tutorial?.active) {
    exitTutorialMode({ startReal: false });
  }
  showModal(null);
  document.body.classList.remove("sts-overlay-open");
  hideCardTooltip();
  clearCoaches();
  saveGame();
  show("screen-title");
  if (localStorage.getItem(SAVE_KEY)) $("btn-continue")?.classList.remove("hidden");
  else $("btn-continue")?.classList.add("hidden");
  const status = $("boot-status");
  if (status) {
    status.classList.remove("bad");
    status.textContent = isSpatialLayout(state.roomLayout)
      ? `上集平面图 #${state.runSeed >>> 0} 已存档。接着看上集可续玩；打开电视机 / 重开新一局。`
      : "准备就绪——按下「打开电视机」或「接着看上集」。";
  }
}

/** 尖塔式：离开战斗回菜单，不判负；未结算房间保持可再进 */
function abandonCombatForMenu() {
  const c = state.combat;
  if (!c) return;
  const roomId = c.roomId || state.roomId;
  try {
    for (const left of c.hand || []) retireCard(left);
  } catch (_) {}
  state.discard = purgeTempCards(state.discard);
  state.deck = purgeTempCards(state.deck);
  // 开战时已 +1 惊吓计数；中途退出要退回，避免再进同房叠档
  if (!c.isBoss && (state.combatCount || 0) > 0) {
    state.combatCount -= 1;
  }
  state.combat = null;
  if (roomId) {
    state.roomId = roomId;
    if (!state.resolvedRooms.has(roomId)) state.nodePending = true;
  }
  document.body.classList.remove("sts-overlay-open");
}

/** 战斗中回主页（杀戮尖塔菜单感） */
function combatGoHome() {
  const ok = window.confirm(
    "回到主页？\n本场惊吓会中断，但不会判负——接着看上集后可再进这间房。",
  );
  if (!ok) return;
  goHome({ fromCombat: true });
}

function refreshTutorialCoach() {
  if (!state.tutorial?.active) {
    clearCoaches();
    return;
  }
  const room = roomDef(state.roomId);
  if (state.combat) {
    updateBattleTutorialCoach();
    return;
  }
  if (room?.tutorialHub) {
    setExploreCoach(
      "先搞懂三件事",
      "① 卡牌多半是往地上放的道具，不是站桩砍人。② 红格子 = 它要打的地方，走开。③ 让它踩刺/盐来削「韧性」，破韧后再收拾。点右边出口，走进练习客厅。",
    );
  } else if (room?.tutorialEnd) {
    setExploreCoach(
      "毕业了",
      "正式一局里还有预兆、更多房间和祭坛 Boss，但核心不变：放置 · 走位 · 看格子。点「走进这一间」领取结业说明，或直接回标题开电视。",
    );
  } else if (room?.tutorialFight && state.nodePending) {
    setExploreCoach(
      "进练习战",
      "点「走进这一间」开战。对手很弱，死了也能重试。目标不是硬刚，而是放刺再引它踩。",
    );
  } else if (room?.tutorialFight) {
    setExploreCoach(
      "练习客厅已清",
      "可以去休息角听结业说明，或回导播间再看一遍提示。",
    );
  } else {
    setExploreCoach("教学进行中", "跟着导播耳语走就行。");
  }
}

function updateBattleTutorialCoach() {
  const c = state.combat;
  if (!c || !state.tutorial?.active) {
    $("battle-coach")?.classList.add("hidden");
    return;
  }
  const hasTrap = Object.values(c.floor || {}).some((f) => f?.onStep?.damage);
  const step = state.tutorial.step || "place";

  if (c.broken || c.toughness <= 0) {
    state.tutorial.step = "finish";
    setBattleCoach(
      "韧性破了！",
      "现在砸它脚下的地刺，或继续引它踩刺，把血削光。破韧后怪会好打许多——正式节目里不同类型破韧奖励还不一样。",
    );
    return;
  }
  if (!hasTrap && step === "place") {
    setBattleCoach(
      "第一课 · 放置",
      "点手牌「地刺」，再点你旁边的空格子放下（高亮邻格）。这不是攻击键——是在布置陷阱。盐圈可以放来挡路/站上去格挡。",
    );
    return;
  }
  if (hasTrap && step === "place") state.tutorial.step = "intent";
  if (state.tutorial.step === "intent") {
    setBattleCoach(
      "第二课 · 看红格",
      "场上实线红数字 = 回合结束后站在那里会挨打；虚线红 = 锁定预告（走进才挨）。先走开或放好再点「回合结束」。蓝虚线是它要走的路。",
    );
    // advance after they've had a chance; mark when ending turn
    return;
  }
  if (state.tutorial.step === "kite" || (hasTrap && c.energy === 0)) {
    state.tutorial.step = "kite";
    setBattleCoach(
      "第三课 · 引怪踩踏",
      "点「回合结束」。它会花行动力追你——踩到刺会掉血并削韧性。韧性条清空就会「破韧」。别站桩砍，跑起来。",
    );
    return;
  }
  setBattleCoach(
    "继续练习",
    "有刺就引它踩；没刺再放。看着韧性条往下掉。行动力不够时用「补剂」或结束回合。",
  );
}

function exitTutorialMode({ startReal = false } = {}) {
  if (state.data?.roomsMain) state.data.rooms = state.data.roomsMain;
  state.tutorial = null;
  clearCoaches();
  state.combat = null;
  showModal(null);
  if (startReal) {
    resetGame();
  } else {
    show("screen-title");
    if (localStorage.getItem(SAVE_KEY)) $("btn-continue")?.classList.remove("hidden");
  }
}

function startTutorial() {
  if (!state.data) {
    alert("数据还在加载，请稍等。");
    return;
  }
  if (!state.data.tutorial) {
    alert("教学数据未加载。请强制刷新（Cmd+Shift+R）后重试。");
    return;
  }
  // 若已在教学中，先干净退回主地图再开
  if (state.tutorial?.active) {
    if (state.data.roomsMain) state.data.rooms = state.data.roomsMain;
    state.tutorial = null;
  }
  const mainRooms = state.data.roomsMain || state.data.rooms;
  state.data.roomsMain = mainRooms;
  state.tutorial = {
    active: true,
    step: "place",
  };
  state.data.rooms = state.data.tutorial;
  state.labTag = "tutorial";
  state.roomLayout = null;
  state.runSeed = 0;
  state.roomId = state.data.rooms.startRoom;
  state.speed = 3;
  state.hp = 6;
  state.maxHp = 6;
  state.visitPath = [state.roomId];
  state.resolvedRooms = new Set([state.roomId]);
  state.knownRooms = new Set([state.roomId]);
  state.deck = shuffle(
    ["jab", "jab", "jab", "jab", "guard", "guard", "keepsake", "tonic"].map((id) => makeCard(id)),
  );
  state.discard = [];
  state.relics = [];
  state.chosenBoss = null;
  state.nodePending = false;
  state.combat = null;
  state.combatCount = 0;
  state.rewardRolls = {};
  state.midRelicDone = true;
  state.lab = null;
  uidSeq = 100;
  $("log").innerHTML = "";
  discoverNeighbors(state.roomId);
  log("【新手教学】不玩过杀戮尖塔 / 山屋惊魂也没关系——这里只教三件事。", "ok");
  log("放置道具、走位引怪、看红格子。正式节目的预兆与 Boss 以后再说。");
  show("screen-game");
  renderAll();
  showModal("screen-event");
  $("event-title").textContent = "频道教学片 · 三分钟上手";
  $("event-text").textContent =
    "这不是站桩砍怪的卡牌游戏，也不是掷骰比大小的桌游。\n\n出牌 ≈ 往地上放机关；你的移动会逼怪把力气花在追你上；红格子是它要打的地方。\n\n先去练习客厅打一只很弱的剪影，导播会在旁边出字提词。";
  $("btn-close-event").classList.add("hidden");
  clearRewardCards();
  hideCardTooltip();
  const box = $("event-choices");
  box.innerHTML = "";
  addChoice(box, "明白了，去导播间", "primary", () => {
    showModal(null);
    setExploreCoach(
      "先搞懂三件事",
      "① 卡牌多半是往地上放的道具。② 红格子会挨打，走开。③ 引怪踩刺削韧性。从出口进练习客厅。",
    );
    renderAll();
  });
  refreshTutorialCoach();
  // 防止弹窗在视口外
  requestAnimationFrame(() => {
    $("screen-event")?.scrollIntoView({ block: "center", behavior: "smooth" });
  });
}

function resetGame() {
  if (state.tutorial?.active || state.data?.rooms !== state.data?.roomsMain) {
    if (state.data?.roomsMain) state.data.rooms = state.data.roomsMain;
    state.tutorial = null;
    clearCoaches();
  }
  localStorage.removeItem(SAVE_KEY);
  localStorage.removeItem("cabin-run-v2");
  localStorage.removeItem("cabin-run-v1");
  state.roomId = state.data.rooms.startRoom;
  state.speed = state.data.cards.baseSpeed;
  state.hp = 6;
  state.maxHp = 6;
  state.visitPath = [];
  state.resolvedRooms = new Set();
  state.knownRooms = new Set([state.roomId]);
  state.deck = shuffle(buildStarterDeck());
  state.discard = [];
  state.relics = [];
  state.chosenBoss = null;
  // 玄关只作为出发格：开局预兆二选一已是唯一起步奖励，不再弹强制速度
  state.visitPath = [state.roomId];
  state.resolvedRooms = new Set([state.roomId]);
  state.nodePending = false;
  state.combat = null;
  state.combatCount = 0;
  state.rewardRolls = {};
  state.midRelicDone = false;
  state.lab = null;
  state.labTag = "normal";
  $("log").innerHTML = "";
  rollRoomLayout();
  discoverNeighbors(state.roomId);
  log("电视机亮起来了。山屋里的怪家伙有韧性——得用机关绊住再破韧。");
  log("行前先选一枚预兆；玄关只是出发坐标，不再发第二份奖励。");
  document.body.classList.remove("sts-overlay-open");
  showModal(null);
  renderAll();
  show("screen-game");
  saveGame();
  offerOpeningRelics();
}

/** 调试：Boss 决战用的体系预设牌组 */
const BOSS_TEST_DECKS = {
  grown: {
    id: "grown",
    name: "混合成长",
    blurb: "原测强度牌库：起手 + 重砸/闪/推绊等杂食。",
    list: [
      "jab", "jab", "jab", "guard", "guard", "guard", "keepsake", "focus", "tonic", "flare",
      "heavy", "heavy", "flare", "shove", "snare", "keepsake", "plans", "adrenaline", "jab", "guard",
    ],
    relics: ["omen_salt", "omen_signal", "omen_decoy", "omen_flint"],
  },
  blind: {
    id: "blind",
    name: "闪瞎控场",
    blurb: "眩光粉 / 残像 / 长闪 / 闪光雷——打断锁定再追击。",
    list: [
      "jab", "jab", "guard", "focus", "tonic", "tonic",
      "glare", "glare", "afterimage", "afterimage", "strobe", "flare", "flare",
      "keepsake", "plans", "adrenaline",
    ],
    relics: ["omen_signal", "omen_flint", "omen_lens"],
  },
  height: {
    id: "height",
    name: "高台砸击",
    blurb: "登台 / 落锤 / 击落——抢高位再砸。",
    list: [
      "jab", "jab", "guard", "focus", "tonic", "tonic",
      "foothold", "foothold", "drop_hammer", "drop_hammer", "topple", "topple", "heavy",
      "keepsake", "plans", "adrenaline",
    ],
    relics: ["omen_signal", "omen_flint", "omen_boots"],
  },
  tunnel: {
    id: "tunnel",
    name: "隧道推送",
    blurb: "引渡 / 穿堂 / 隙刺——甩进传送门再踩伤。",
    list: [
      "jab", "jab", "guard", "focus", "tonic", "tonic",
      "usher", "usher", "rift_fling", "rift_fling", "warp_trap", "warp_trap", "shove", "fling",
      "snare", "plans",
    ],
    relics: ["omen_signal", "omen_salt", "omen_lens"],
  },
  tough: {
    id: "tough",
    name: "破韧专精",
    blurb: "凿钉 / 崩裂 / 破壳——先削壳再输出。",
    list: [
      "jab", "jab", "guard", "focus", "tonic", "tonic",
      "chisel", "chisel", "rupture", "rupture", "breach", "breach", "riposte", "heavy",
      "keepsake", "plans",
    ],
    relics: ["omen_signal", "omen_salt", "omen_flint"],
  },
  paper: {
    id: "paper",
    name: "纸影牵引",
    blurb: "纸影 / 绊线收束 / 影爆——拉线再炸。",
    list: [
      "jab", "jab", "guard", "focus", "tonic",
      "decoy", "decoy", "snare", "snare", "puppet_bang", "puppet_bang", "shove", "fling",
      "heavy", "plans", "adrenaline",
    ],
    relics: ["omen_decoy", "omen_signal", "omen_salt"],
  },
  salt: {
    id: "salt",
    name: "盐道控场",
    blurb: "盐圈铺路 + 盐鞭抽打 + 预备防守。",
    list: [
      "jab", "jab", "guard", "guard", "guard", "guard", "focus", "tonic",
      "salt_lash", "salt_lash", "brace", "poise", "keepsake", "plans", "shove", "adrenaline",
    ],
    relics: ["omen_salt", "omen_signal", "omen_echo"],
  },
  ready: {
    id: "ready",
    name: "预备夹击",
    blurb: "绷紧 / 迎击 / 甩开 / 蓄势——你变机关引怪。",
    list: [
      "jab", "jab", "jab", "guard", "focus", "tonic",
      "brace", "riposte", "riposte", "fling", "fling", "poise", "shove", "shove",
      "keepsake", "plans", "adrenaline",
    ],
    relics: ["omen_signal", "omen_salt", "omen_lens"],
  },
};

function offerBossTestMenu() {
  show("screen-title");
  showModal("screen-event");
  $("event-title").textContent = "测 Boss · 选体系牌组";
  $("event-text").textContent =
    "满血 8 · 速度 5 · 锈锁优先。场地=本集山屋平面（一房一格）。\n选一套体系预设牌库进决战；不覆盖正式存档流程（会清档开测）。";
  $("btn-close-event").classList.add("hidden");
  clearRewardCards();
  hideCardTooltip();
  const box = $("event-choices");
  box.innerHTML = "";
  for (const deck of Object.values(BOSS_TEST_DECKS)) {
    addChoice(box, deck.name, "primary", () => skipToBossTest(deck.id));
  }
  addChoice(box, "回标题", "", () => {
    showModal(null);
    show("screen-title");
  });
  // 次行说明：点选后直接开战
  const tip = document.createElement("p");
  tip.className = "event-deck-tip";
  tip.textContent = Object.values(BOSS_TEST_DECKS)
    .map((d) => `「${d.name}」${d.blurb}`)
    .join("\n");
  box.appendChild(tip);
}

/** 调试：模拟一局成长结束 + 满血，直接进 Boss 决战测强度 */
function skipToBossTest(deckId = "grown") {
  if (state.tutorial?.active) exitTutorialMode({ startReal: false });
  if (!state.data?.bosses?.bosses) {
    throw new Error("Boss 数据未加载，请刷新页面后再试。");
  }
  const preset = BOSS_TEST_DECKS[deckId] || BOSS_TEST_DECKS.grown;
  localStorage.removeItem(SAVE_KEY);
  localStorage.removeItem("cabin-run-v2");
  localStorage.removeItem("cabin-run-v1");
  state.speed = 5;
  state.maxHp = 8;
  state.hp = 8;
  const grown = preset.list.filter((id) => !!cardDef(id));
  if (!grown.length) {
    throw new Error(`体系牌组「${preset.name}」无可用卡牌。`);
  }
  state.deck = shuffle(grown.map((id) => makeCard(id)));
  state.discard = [];
  state.relics = (preset.relics || []).filter((id) => !!relicDef(id));
  // 优先硬壳锈锁；没有则退回规则锁定
  state.chosenBoss = bossDef("rust_keeper") ? "rust_keeper" : pickBossId();
  if (!bossDef(state.chosenBoss)) {
    state.chosenBoss = Object.keys(state.data.bosses.bosses)[0];
  }
  state.nodePending = false;
  state.combat = null;
  state.combatCount = 6;
  state.rewardRolls = {};
  state.midRelicDone = true;
  state.labTag = `boss_test:${preset.id}`;
  state.bossTestDeck = preset.id;
  // 掷一张大地图，Boss 决战用「一房一格」编译这张图
  const seed = (Date.now() ^ 0xb0557e57) >>> 0;
  rollRoomLayout(seed);
  const layout = state.roomLayout;
  const startId = state.data.rooms.startRoom || "foyer";
  const path = buildHouseVisitPath(layout, startId, state.data.rooms.runLength || 12);
  state.roomId = path[path.length - 1] || startId;
  state.visitPath = path;
  state.resolvedRooms = new Set(path);
  state.knownRooms = new Set(Object.keys(layout || { [startId]: 1 }));
  $("log").innerHTML = "";
  show("screen-game");
  showModal(null);
  const boss = bossDef(state.chosenBoss);
  const roomN = Object.keys(layout || {}).length;
  log(`【测 Boss · ${preset.name}】满血 8/8 · 速度 5 · ${grown.length} 张牌。`, "ok");
  log(preset.blurb);
  log(`决战对手：${boss.name} · 场地=本集山屋平面（${roomN} 间，一房一格，空洞不可站）。`);
  renderAll();
  saveGame();
  openBoss();
}

/** 沿门走一条够长的行程路径（Boss 测试用） */
function buildHouseVisitPath(layout, startId, need) {
  if (!layout || !layout[startId]) {
    return Array.from({ length: need }, (_, i) => (i === 0 ? startId : startId));
  }
  const path = [startId];
  const seen = new Set([startId]);
  let guard = need * 4;
  while (path.length < need && guard-- > 0) {
    const here = path[path.length - 1];
    const exits = (layout[here]?.exits || []).filter((id) => layout[id]);
    const fresh = exits.filter((id) => !seen.has(id));
    const next = (fresh.length ? fresh : exits)[0];
    if (!next) break;
    path.push(next);
    seen.add(next);
  }
  while (path.length < need) path.push(path[path.length - 1]);
  return path;
}

function discoverNeighbors(roomId) {
  state.knownRooms.add(roomId);
  for (const exit of roomDef(roomId).exits || []) state.knownRooms.add(exit);
}

function fingerprint() {
  const path = state.visitPath;
  const early = path.slice(1, 3);
  const late =
    path.length >= state.data.rooms.runLength
      ? path.slice(path.length - 3)
      : path.length >= 8
        ? path.slice(7, 10)
        : [];
  const earlyCombat = early.filter((id) => roomDef(id)?.combat).length;
  const lateCombat = late.filter((id) => roomDef(id)?.combat).length;
  return {
    early,
    late,
    earlyCombat,
    lateCombat,
    earlyReady: path.length >= 3,
    lateReady: path.length >= state.data.rooms.runLength,
  };
}

function ruleMatches(rule, fp, mode) {
  const w = rule.when || {};
  if (mode === "strict" || fp.earlyReady) {
    if (w.earlyCombat != null && fp.earlyCombat !== w.earlyCombat) return false;
    if (w.earlyCombatMax != null && fp.earlyCombat > w.earlyCombatMax) return false;
  }
  if (mode === "strict" || fp.lateReady) {
    if (w.lateCombatMin != null && fp.lateCombat < w.lateCombatMin) return false;
    if (w.lateCombatMax != null && fp.lateCombat > w.lateCombatMax) return false;
  }
  return true;
}

function pickBossId() {
  const fp = fingerprint();
  for (const rule of state.data.bosses.rules) {
    if (ruleMatches(rule, fp, "strict")) return rule.boss;
  }
  return "rust_keeper";
}

function candidateBosses() {
  const fp = fingerprint();
  const mode = fp.lateReady ? "strict" : "possible";
  const ids = [];
  for (const rule of state.data.bosses.rules) {
    if (!ruleMatches(rule, fp, mode)) continue;
    if (!ids.includes(rule.boss)) ids.push(rule.boss);
  }
  if (!ids.length) ids.push("rust_keeper");
  return ids;
}

function runReadyForBoss() {
  return state.visitPath.length >= state.data.rooms.runLength;
}

function formatWhen(w = {}) {
  const bits = [];
  if (w.earlyCombat != null) bits.push(`前=${w.earlyCombat}`);
  if (w.earlyCombatMax != null) bits.push(`前≤${w.earlyCombatMax}`);
  if (w.lateCombatMin != null) bits.push(`后≥${w.lateCombatMin}`);
  if (w.lateCombatMax != null) bits.push(`后≤${w.lateCombatMax}`);
  return bits.length ? bits.join(" ") : "默认收束";
}

function renderStats() {
  const pills = [
    ["速度", state.speed],
    ["生命", `${state.hp}/${state.maxHp}`],
    ["集数", `${state.visitPath.length}/${state.data.rooms.runLength}`],
    ["道具", state.deck.length + state.discard.length],
    ["惊吓", state.combatCount || 0],
  ];
  const statsEl = $("stats");
  if (statsEl) {
    statsEl.innerHTML = pills
      .map(([k, v]) => `<div class="stat-pill"><span>${k}</span><strong>${v}</strong></div>`)
      .join("");
  }
  const vitals = $("pane-vitals");
  if (vitals) {
    vitals.textContent = `生命 ${state.hp}/${state.maxHp} · 速度 ${state.speed} · 道具 ${
      state.deck.length + state.discard.length
    }`;
  }
  $("run-progress").textContent = `今天的行程 ${state.visitPath.length} / ${state.data.rooms.runLength}`;
  const seedEl = $("map-seed");
  if (seedEl) {
    if (state.tutorial?.active) {
      seedEl.textContent = "教学片 · 固定小地图";
    } else if (isSpatialLayout(state.roomLayout)) {
      seedEl.textContent = `平面图 #${state.runSeed >>> 0} · ${Object.keys(state.roomLayout).length} 间`;
    } else {
      seedEl.textContent = "平面图：手摆固定稿";
    }
  }
}

function renderBossBoard() {
  const fp = fingerprint();
  const lateHint = fp.lateReady ? String(fp.lateCombat) : state.visitPath.length < 8 ? "?" : String(fp.lateCombat);
  $("flags-note").textContent = `前段战斗 ${fp.earlyReady ? fp.earlyCombat : "?"} /2 · 后段战斗 ${lateHint} /3`;
  const cand = new Set(candidateBosses());
  const locked = fp.lateReady ? pickBossId() : null;
  const board = $("boss-board");
  board.innerHTML = "";
  for (const rule of state.data.bosses.rules) {
    const boss = bossDef(rule.boss);
    if (!boss) continue;
    const li = document.createElement("li");
    const alive = cand.has(rule.boss);
    const isLock = locked === rule.boss;
    li.className = alive ? (isLock ? "boss-lock" : "boss-maybe") : "boss-out";
    li.innerHTML = `<strong>${boss.name}</strong><span>${formatWhen(rule.when)}${isLock ? " · 已锁定" : alive ? " · 仍可能" : " · 已排除"}</span>`;
    board.appendChild(li);
  }
}

function renderLists() {
  const relics = $("relics");
  relics.innerHTML = "";
  if (!state.relics.length) {
    relics.innerHTML = `<li>无<span>静室可能出现 · 悬停可看详情</span></li>`;
  } else {
    for (const id of state.relics) {
      const r = relicDef(id);
      if (!r) continue;
      const li = document.createElement("li");
      li.className = "has-tip";
      li.innerHTML = `<strong>${r.name}</strong><span>${r.desc}</span>`;
      bindHoverTip(li, relicTooltipHtml(r));
      relics.appendChild(li);
    }
  }

  const counts = {};
  for (const c of allOwnedCards()) {
    counts[c.id] = (counts[c.id] || 0) + 1;
  }
  const inv = $("inventory");
  inv.innerHTML = "";
  const ids = Object.keys(counts);
  if (!ids.length) inv.innerHTML = `<li>空<span>悬停卡牌可看用途</span></li>`;
  for (const id of ids) {
    const def = cardDef(id);
    if (!def) continue;
    const li = document.createElement("li");
    li.className = "has-tip";
    li.innerHTML = `<strong>${def.name} ×${counts[id]}</strong><span>${cardKindLabel(def.type)} · 费用 ${def.cost} · ${def.text}</span>`;
    bindHoverTip(li, cardTooltipHtml(def));
    inv.appendChild(li);
  }
  $("deck-note").textContent = `一共 ${allOwnedCards().length} 张 · 悬停听旁白 · 拿太多会卡手哦`;
  $("item-actions").innerHTML = "";
}

function mapDisplayFrame() {
  const size = state.data?.rooms?.mapSize || { cols: 17, rows: 17 };
  const rooms = placedRoomIds()
    .map((id) => roomDef(id))
    .filter((r) => r?.map);
  if (!rooms.length) {
    return { cols: Math.min(9, size.cols), rows: Math.min(9, size.rows), col0: 1, row0: 1 };
  }
  let minC = Infinity;
  let maxC = -Infinity;
  let minR = Infinity;
  let maxR = -Infinity;
  for (const r of rooms) {
    minC = Math.min(minC, r.map.col);
    maxC = Math.max(maxC, r.map.col);
    minR = Math.min(minR, r.map.row);
    maxR = Math.max(maxR, r.map.row);
  }
  const col0 = Math.max(1, minC);
  const row0 = Math.max(1, minR);
  const col1 = Math.min(size.cols, maxC);
  const row1 = Math.min(size.rows, maxR);
  return {
    cols: Math.max(1, col1 - col0 + 1),
    rows: Math.max(1, row1 - row0 + 1),
    col0,
    row0,
  };
}

function fitHouseMapBox(box, frame) {
  const board = box?.parentElement;
  if (!box || !board || !frame) return;
  const bw = board.clientWidth || 0;
  const bh = board.clientHeight || 0;
  if (bw < 8 || bh < 8) return;
  const scale = Math.min(bw / frame.cols, bh / frame.rows);
  const w = Math.max(1, Math.floor(scale * frame.cols));
  const h = Math.max(1, Math.floor(scale * frame.rows));
  box.style.width = `${w}px`;
  box.style.height = `${h}px`;
}

function renderMap() {
  const box = $("house-map");
  const links = $("map-links");
  const frame = mapDisplayFrame();
  box.classList.add("house-map-abs");
  box.style.gridTemplateColumns = "";
  box.style.gridTemplateRows = "";
  box.style.setProperty("--map-cols", String(frame.cols));
  box.style.setProperty("--map-rows", String(frame.rows));
  // 先把连线 SVG 挪出再清空，避免 innerHTML 删掉节点引用
  if (links && links.parentElement === box) {
    (box.parentElement || document.body).appendChild(links);
  }
  box.innerHTML = "";
  fitHouseMapBox(box, frame);
  if (links) {
    box.appendChild(links);
    links.innerHTML = "";
    links.setAttribute("viewBox", `0 0 ${frame.cols} ${frame.rows}`);
    links.setAttribute("preserveAspectRatio", "none");
    links.className = "map-links map-links-inmap";
  }
  const here = roomDef(state.roomId);
  const exits = new Set(here?.exits || []);
  const rooms = placedRoomIds().map((id) => roomDef(id)).filter(Boolean);
  const byId = Object.fromEntries(rooms.map((r) => [r.id, r]));
  const toCell = (map) => ({
    col: map.col - frame.col0 + 1,
    row: map.row - frame.row0 + 1,
  });
  const placeAbs = (el, cell) => {
    const gap = 0.06;
    el.style.left = `${((cell.col - 1 + gap) / frame.cols) * 100}%`;
    el.style.top = `${((cell.row - 1 + gap) / frame.rows) * 100}%`;
    el.style.width = `${((1 - gap * 2) / frame.cols) * 100}%`;
    el.style.height = `${((1 - gap * 2) / frame.rows) * 100}%`;
  };

  // 走廊：已知↔已知的双向边只画一次
  if (links) {
    const drawn = new Set();
    for (const room of rooms) {
      if (!state.knownRooms.has(room.id) || !room.map) continue;
      for (const eid of room.exits || []) {
        const other = byId[eid];
        if (!other?.map || !state.knownRooms.has(eid)) continue;
        const a = room.id < eid ? room.id : eid;
        const b = room.id < eid ? eid : room.id;
        const key = `${a}|${b}`;
        if (drawn.has(key)) continue;
        drawn.add(key);
        const from = room.id < eid ? room : other;
        const to = room.id < eid ? other : room;
        const fc = toCell(from.map);
        const tc = toCell(to.map);
        const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
        line.setAttribute("x1", String(fc.col - 0.5));
        line.setAttribute("y1", String(fc.row - 0.5));
        line.setAttribute("x2", String(tc.col - 0.5));
        line.setAttribute("y2", String(tc.row - 0.5));
        const live =
          (room.id === state.roomId && exits.has(eid)) ||
          (eid === state.roomId && exits.has(room.id));
        line.setAttribute("class", live ? "map-link map-link-live" : "map-link");
        links.appendChild(line);
      }
    }
  }

  for (const room of rooms) {
    if (!room.map) continue;
    const cell = toCell(room.map);
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "map-node";
    placeAbs(btn, cell);
    const known = state.knownRooms.has(room.id);
    const visited = state.resolvedRooms.has(room.id) || state.visitPath.includes(room.id);
    const isHere = room.id === state.roomId;
    const isExit = exits.has(room.id);
    if (!known) {
      btn.classList.add("unknown");
      btn.disabled = true;
      btn.title = "还没看清";
    } else {
      const label = document.createElement("span");
      label.className = "map-node-label";
      label.textContent = room.name;
      btn.appendChild(label);

      const kind = document.createElement("span");
      kind.className = "map-node-kind";
      kind.setAttribute("aria-hidden", "true");
      if (room.bossRoom) {
        kind.innerHTML = `<img src="assets/ui/WarningSign.png" alt="" />`;
      } else if (room.combat) {
        kind.innerHTML = `<img src="assets/ui/EventIcon.png" alt="" />`;
        btn.classList.add("combat-known");
      } else {
        kind.innerHTML = `<img src="assets/ui/OmenIcon.png" alt="" />`;
        btn.classList.add("safe-known");
      }
      btn.appendChild(kind);

      if (visited) btn.classList.add("visited");
      if (isExit && !isHere) btn.classList.add("reachable");

      // 门朝向缺口（山屋惊魂 northDoor/eastDoor/southDoor/westDoor）
      const doors = room.doors || doorsFromExits(state.roomLayout?.[room.id], state.roomLayout);
      for (const d of ["N", "E", "S", "W"]) {
        if (!doors[d]) continue;
        const notch = document.createElement("span");
        notch.className = `map-door map-door-${d.toLowerCase()}`;
        notch.setAttribute("aria-hidden", "true");
        if (
          (d === "N" && exits.has(exitIdToward(room, 0, -1))) ||
          (d === "S" && exits.has(exitIdToward(room, 0, 1))) ||
          (d === "E" && exits.has(exitIdToward(room, 1, 0))) ||
          (d === "W" && exits.has(exitIdToward(room, -1, 0)))
        ) {
          notch.classList.add("is-live");
        }
        btn.appendChild(notch);
      }

      if (isHere) {
        btn.classList.add("current");
        btn.title = state.nodePending
          ? `${room.name}（点这里继续：打开惊吓/查看房间）`
          : `${room.name}（你在这里）`;
        const pawn = document.createElement("span");
        pawn.className = "map-pawn";
        pawn.setAttribute("aria-label", `你在${room.name}`);
        pawn.innerHTML =
          `<img class="char-token map-token" src="assets/ui/chars/SP_Lili_MapToken.png" alt="你" width="40" height="40" draggable="false" />`;
        btn.appendChild(pawn);
      } else {
        btn.title = room.name + (room.combat ? " · 惊吓" : " · 静室");
      }

      if (room.bossRoom) {
        btn.disabled = true;
        btn.title = "完成行程后决战";
      } else {
        btn.disabled = false;
        btn.onclick = () => {
          if (isHere) {
            if (state.nodePending) resolveCurrentNode();
            else log("你已经在这一间。点高亮邻房继续走。", "ok");
            return;
          }
          if (!isExit) {
            log("只能走进相邻连通的房间。", "bad");
            return;
          }
          if (state.nodePending) {
            log("先点脚下这间（或下方按钮）解决当前房间，再离开。", "bad");
            $("btn-resolve")?.classList.add("pulse-hint");
            $("btn-resolve")?.scrollIntoView({ block: "nearest", behavior: "smooth" });
            return;
          }
          if (runReadyForBoss()) {
            log("行程已满，去开启祭坛决战。", "bad");
            return;
          }
          moveTo(room.id);
        };
      }
    }
    box.appendChild(btn);
  }

  requestAnimationFrame(() => fitHouseMapBox(box, frame));
}

function renderRoom() {
  const room = roomDef(state.roomId);
  $("room-name").textContent = room.name;
  $("room-desc").textContent = room.desc;
  $("room-tag").textContent = state.tutorial?.active
    ? room.tutorialFight
      ? "教学战"
      : room.tutorialEnd
        ? "结业"
        : "教学"
    : room.bossRoom
      ? "大结局"
      : room.combat
        ? "惊吓时间"
        : "安静角落";

  const exits = $("exits");
  exits.innerHTML = "";
  for (const id of room.exits || []) {
    const dest = roomDef(id);
    if (!dest || dest.bossRoom) continue;
    const btn = document.createElement("button");
    btn.className = "btn";
    btn.textContent = state.knownRooms.has(id) ? `前往 ${dest.name}` : "前往未知房间";
    btn.disabled = state.nodePending || runReadyForBoss();
    btn.onclick = () => moveTo(id);
    exits.appendChild(btn);
  }

  const resolveBtn = $("btn-resolve");
  if (state.nodePending && !room.bossRoom) {
    resolveBtn.classList.remove("hidden");
    resolveBtn.textContent = room.combat ? "打开惊吓时间" : "看看房间里有什么";
  } else {
    resolveBtn.classList.add("hidden");
  }

  const bossBtn = $("btn-boss");
  if (runReadyForBoss()) bossBtn.classList.remove("hidden");
  else bossBtn.classList.add("hidden");

  renderMap();
}

function moveTo(targetId) {
  if (state.nodePending) {
    log("先解决当前节点。", "bad");
    return;
  }
  if (runReadyForBoss()) {
    log("行程已满，去开启祭坛决战。", "bad");
    return;
  }
  const room = roomDef(state.roomId);
  if (!(room.exits || []).includes(targetId)) return;
  state.roomId = targetId;
  discoverNeighbors(targetId);
  state.nodePending = !state.resolvedRooms.has(targetId) && !roomDef(targetId).bossRoom;
  log(`你推开了通向${roomDef(targetId).name}的门。`);
  playTone("ui");
  renderAll();
  saveGame();
}

function resolveCurrentNode() {
  const room = roomDef(state.roomId);
  if (!state.nodePending || room.bossRoom) return;
  if (room.combat) {
    if (state.hp <= 2) {
      offerCombatCaution(room);
      return;
    }
    startCombat(room, false);
  } else startNonCombat(room);
}

/** 残血进战：明确警告 + 可撤退（房间不结算，可改道） */
function offerCombatCaution(room) {
  const nextTier = combatTier((state.combatCount || 0) + 1);
  const preview = (() => {
    // 临时按「下一场」档位估伤害，不推进 combatCount
    const saved = state.combatCount;
    state.combatCount = (state.combatCount || 0) + 1;
    const enc = buildEncounter(room, false);
    state.combatCount = saved;
    return enc;
  })();
  showModal("screen-event");
  const kicker = $("event-kicker");
  if (kicker) kicker.textContent = "残血警告";
  $("event-title").textContent = room.name;
  $("event-text").textContent =
    `你只剩 ${state.hp}/${state.maxHp} 生命。此间预计难度档 ${nextTier} · ${preview.name}（伤 ${preview.damage} · 韧 ${preview.toughness}）。` +
    (state.hp <= 1 ? "一击就可能结束这一集。" : "容错很薄，建议先去静室喘息。");
  $("btn-close-event").classList.add("hidden");
  clearRewardCards();
  const box = $("event-choices");
  box.innerHTML = "";
  addChoice(box, "硬闯这一间", "danger", () => {
    showModal(null);
    startCombat(room, false);
  });
  addChoice(box, "先撤退", "primary", () => {
    state.nodePending = false;
    log(`你退回门口——${room.name}还在，可以稍后再进。`, "ok");
    finishNodeModal("先去别处回回血，再回来。");
    renderAll();
    saveGame();
  });
}

function healPlayer(amount, reason = "恢复") {
  const before = state.hp;
  state.hp = Math.min(state.maxHp, state.hp + Math.max(0, amount));
  const gained = state.hp - before;
  if (gained > 0) log(`${reason} +${gained}（现 ${state.hp}/${state.maxHp}）`, "ok");
  return gained;
}

function addChoice(box, label, cls, fn) {
  const btn = document.createElement("button");
    const map = { primary: "btn-primary", danger: "btn-danger", ghost: "btn-ghost" };
    btn.className = "btn" + (cls && map[cls] ? ` ${map[cls]}` : cls ? ` btn-secondary` : "");
  btn.textContent = label;
  btn.onclick = fn;
  box.appendChild(btn);
}

function startNonCombat(room) {
  // 解密事件：先考验，再进原有静室奖励；失败则丢奖励（可不致死）
  const rolledGate = state.rewardRolls[room.id];
  if (room.eventType === "qte" && !rolledGate?.qteResolved) {
    beginQteForRoom(room);
    return;
  }
  if (room.eventType === "puzzle" && !rolledGate?.puzzleResolved) {
    beginPuzzleForRoom(room);
    return;
  }
  startNonCombatRewards(room);
}

function applyEventTrialFail(room, result) {
  log(`【考验】${room.name}：失手，静室奖励溜走了。`, "bad");
  playTone("bad");
  if (state.hp > 1) {
    state.hp -= 1;
    log("被回声刮了一下（−1 生命）。", "bad");
  }
  completeRoom();
  showModal("screen-event");
  $("event-title").textContent = room.name;
  $("event-text").textContent = (result?.message || "信号断了。") + " 抽屉自己合上了。";
  $("btn-close-event").classList.add("hidden");
  clearRewardCards();
  const box = $("event-choices");
  box.innerHTML = "";
  addChoice(box, "离开", "primary", () => {
    finishNodeModal("你空着手退回走廊。");
  });
  renderAll();
  saveGame();
}

/** 警察抓小偷失败：优先偷牌，否则扣血 */
function applyChaseTrialFail(room, result) {
  playTone("bad");
  const stolen = stealCard({ preferHand: false, allowAny: true });
  let penalty = "";
  if (stolen) {
    const name = cardDef(stolen.id)?.name || "一张牌";
    log(`【考验】${room.name}：被警察搜身，夺走了「${name}」。`, "bad");
    penalty = `警察从你口袋掏走了「${name}」。`;
  } else if (state.hp > 1) {
    state.hp -= 1;
    log(`【考验】${room.name}：被按倒在泥里（−1 生命）。`, "bad");
    penalty = "警察把你按进泥里，刮掉 1 点生命。";
  } else {
    log(`【考验】${room.name}：被抓住了，口袋空空，节目组放过一马。`, "bad");
    penalty = "你口袋空空，节目组大笑后退开。";
  }
  completeRoom();
  showModal("screen-event");
  $("event-title").textContent = room.name;
  $("event-text").textContent = `${result?.message || "被抓住了。"} ${penalty} 抽屉自己合上了。`;
  $("btn-close-event").classList.add("hidden");
  clearRewardCards();
  const box = $("event-choices");
  box.innerHTML = "";
  addChoice(box, "离开", "primary", () => {
    finishNodeModal("泥靴间只剩脚印。");
  });
  renderAll();
  saveGame();
}

function beginQteForRoom(room) {
  if (!window.CabinQte) {
    startNonCombatRewards(room);
    return;
  }
  showModal("screen-qte");
  const exitBtn = $("btn-qte-exit");
  const forfeitBtn = $("btn-qte-forfeit");
  if (exitBtn) exitBtn.classList.add("hidden");
  if (forfeitBtn) {
    forfeitBtn.classList.remove("hidden");
    forfeitBtn.onclick = () => {
      if (window.CabinQte?.forfeit) CabinQte.forfeit("你举手投降——警察给节目组鞠躬。");
    };
  }
  CabinQte.start({
    title: room.name,
    lead: "你是小偷：打完整句英文往门口跑；警察匀速追。打错只闪一下、不清空进度。先点「开始追逐」，倒计时后再打字。逃出 → 速度 +1；被抓 → 偷牌或扣血。",
    onDone: (result) => {
      const prev = state.rewardRolls[room.id] || {};
      state.rewardRolls[room.id] = { ...prev, qteResolved: true, qteOk: !!result.ok };
      saveGame();
      if (forfeitBtn) forfeitBtn.classList.add("hidden");
      if (result.ok) {
        state.speed += 1;
        log(`【考验】${room.name}：逃过追捕 · 速度 S +1（现 ${state.speed}）。`, "ok");
        playTone("ok");
        startNonCombatRewards(room);
        return;
      }
      applyChaseTrialFail(room, result);
    },
  });
}

function beginPuzzleForRoom(room) {
  if (!window.CabinPuzzle) {
    startNonCombatRewards(room);
    return;
  }
  showModal("screen-puzzle");
  const exitBtn = $("btn-puzzle-exit");
  const forfeitBtn = $("btn-puzzle-forfeit");
  if (exitBtn) exitBtn.classList.add("hidden");
  if (forfeitBtn) {
    forfeitBtn.classList.remove("hidden");
    forfeitBtn.onclick = () => {
      if (window.CabinPuzzle) CabinPuzzle.forfeit("你把雪花屏推回了雪花。");
    };
  }
  CabinPuzzle.start({
    title: room.name,
    lead: "空相框要你把 1–8 拼回顺序（空格右下）。点邻格或方向键/WASD。卡住可「刷新局面」重洗并重置步数。成功翻静室奖励；步数用尽或放弃只丢奖励。",
    onDone: (result) => {
      const prev = state.rewardRolls[room.id] || {};
      state.rewardRolls[room.id] = { ...prev, puzzleResolved: true, puzzleOk: !!result.ok };
      saveGame();
      if (forfeitBtn) forfeitBtn.classList.add("hidden");
      if (result.ok) {
        log(`【考验】${room.name}：雪花拼合。`, "ok");
        playTone("ok");
        startNonCombatRewards(room);
        return;
      }
      applyEventTrialFail(room, result);
    },
  });
}

function startNonCombatRewards(room) {
  if (room.tutorialHub) {
    showModal("screen-event");
    $("event-title").textContent = room.name;
    $("event-text").textContent =
      "导播间没有奖励。记住口诀：放机关 · 看红格 · 引怪踩 · 破韧再打。从出口进练习客厅开打。";
    $("btn-close-event").classList.add("hidden");
    clearRewardCards();
    hideCardTooltip();
    const box = $("event-choices");
    box.innerHTML = "";
    addChoice(box, "知道了", "primary", () => {
      completeRoom();
      finishNodeModal("去练习客厅吧。");
      refreshTutorialCoach();
    });
    return;
  }
  if (room.tutorialEnd) {
    showModal("screen-event");
    $("event-title").textContent = "结业 · 三句话";
    $("event-text").textContent =
      "① 出牌多半是往场地放道具，不是站桩砍。\n② 红格子会挨打——走位比硬抗重要。\n③ 先削韧性（引怪踩刺/盐），破韧后再认真输出。\n\n正式节目还有预兆、行程地图和祭坛 Boss；内核就是这三句。";
    $("btn-close-event").classList.add("hidden");
    clearRewardCards();
    hideCardTooltip();
    const box = $("event-choices");
    box.innerHTML = "";
    addChoice(box, "打开电视机 · 正式一局", "primary", () => {
      completeRoom();
      exitTutorialMode({ startReal: true });
    });
    addChoice(box, "回标题", "", () => {
      completeRoom();
      exitTutorialMode({ startReal: false });
    });
    return;
  }
  // 已摇过的奖励从存档取，防止刷新页面重摇
  let rolled = state.rewardRolls[room.id];
  if (!rolled || rolled.kind == null) {
    const odds = state.data.rooms.rewardOdds;
    const roll = Math.random();
    // 中点保底：已结算 ≥4 且本局尚未发过中点遗物
    const midGuaranteed =
      !room.forcedReward && !state.midRelicDone && state.resolvedRooms.size >= 4;
    let kind =
      room.forcedReward ||
      (midGuaranteed
        ? "relic"
        : roll < odds.relic
          ? "relic"
          : roll < odds.relic + odds.item
            ? "item"
            : "stat");
    let id = null;
    if (kind === "relic") {
      const available = state.data.relics.pool.filter((x) => !state.relics.includes(x));
      id = available.length ? available[Math.floor(Math.random() * available.length)] : null;
      if (midGuaranteed && !id) kind = "item";
    }
    if (kind === "item") {
      const pool = state.data.cards.rewardPool;
      id = pool[Math.floor(Math.random() * pool.length)];
    }
    const isMid = !!midGuaranteed && kind === "relic" && !!id;
    if (isMid) state.midRelicDone = true;
    rolled = { ...(rolled || {}), kind, id, midGuaranteed: isMid };
    state.rewardRolls[room.id] = rolled;
    saveGame();
  }
  const kind = rolled.kind;

  // 进门前先记下残血，避免「静室喘息」把血抬过阈值后丢掉治疗保底
  const enteredLowHp = state.hp <= 2 && state.hp < state.maxHp;

  // 静室进门喘息：每房一次（写入 rewardRolls，防刷新重复回血）
  if (room.id !== "foyer" && !rolled.quietBreath && state.hp < state.maxHp) {
    healPlayer(1, "静室喘息");
    rolled.quietBreath = true;
    state.rewardRolls[room.id] = rolled;
    saveGame();
  }

  showModal("screen-event");
  $("event-title").textContent = room.name;
  $("btn-close-event").classList.add("hidden");
  clearRewardCards();
  hideCardTooltip();
  const box = $("event-choices");
  box.innerHTML = "";

  if (kind === "relic") {
    const id = rolled.id;
    $("event-text").textContent = id
      ? rolled.midGuaranteed
        ? `行程中点——频道强制送来一枚预兆。悬停查看，再决定收或弃。`
        : `静室浮现预兆。悬停卡片查看效果，再决定收或弃。`
      : "预兆已齐。";
    if (id) {
      const def = relicDef(id);
      const row = $("reward-cards");
      const card = document.createElement("div");
      card.className = "reward-card frame-blue";
      card.tabIndex = 0;
      card.innerHTML = `<strong>${def.name}</strong><span class="card-kind"><img src="assets/ui/cards/SP_Card_IconT_Omen.png" alt="" />预兆</span><p class="blurb">${def.desc}</p>`;
      bindHoverTip(card, relicTooltipHtml(def));
      row.appendChild(card);
      addChoice(box, "收下预兆", "primary", () => {
        gainRelic(id);
        completeRoom();
        finishNodeModal("预兆留下了。");
      });
      addChoice(box, "放弃", "", () => {
        completeRoom();
        finishNodeModal("你没有伸手。");
      });
    } else {
      addChoice(box, "离开", "primary", () => {
        completeRoom();
        finishNodeModal("静室空无一人。");
      });
    }
    return;
  }

  if (kind === "item") {
    const id = rolled.id;
    offerCardReward({
      title: room.name,
      lead: `抽屉里有：${cardDef(id).name}。加进去可能更强，也可能更卡手。`,
      offers: [id],
      onDone: (msg) => {
        completeRoom();
        finishNodeModal(msg);
      },
    });
    return;
  }

  if (room.stat?.speed) {
    $("event-text").textContent = "这里提供强制速度提升。";
    addChoice(box, `接受 速度 +${room.stat.speed}`, "primary", () => {
      state.speed += room.stat.speed;
      log(`速度 S +${room.stat.speed}`, "ok");
      completeRoom();
      finishNodeModal("你做好了出发的准备。");
    });
    return;
  }

  // 玄关等无数值池的静室兜底
  if (room.id === "foyer") {
    $("event-text").textContent = "行前预兆已经选过了，玄关只是出发坐标。";
    addChoice(box, "继续前进", "primary", () => {
      completeRoom();
      finishNodeModal("该推开下一扇门了。");
    });
    return;
  }

  $("event-text").textContent =
    enteredLowHp
      ? "你还很虚弱。静室提供数值——治疗已加重权重。"
      : "静室提供数值，也可放弃。";
  const lowHp = enteredLowHp;
  const pool = [
    { id: "speed", weight: lowHp ? 0.15 : 0.35, label: "速度 +1", apply: () => { state.speed += 1; log("速度 S +1", "ok"); } },
    {
      id: "max",
      weight: 1,
      label: "生命上限 +1 并治疗 1",
      apply: () => {
        state.maxHp += 1;
        healPlayer(1, "上限提升并治疗");
      },
    },
    {
      id: "heal",
      weight: lowHp ? 2.5 : 1,
      label: "恢复 2 生命",
      apply: () => {
        healPlayer(2, "静室治疗");
      },
    },
  ];
  const picked = [];
  const bag = [...pool];
  // 残血保底：治疗选项必进二选一
  if (lowHp && state.hp < state.maxHp) {
    const healOpt = bag.find((o) => o.id === "heal");
    if (healOpt) {
      picked.push(healOpt);
      bag.splice(bag.indexOf(healOpt), 1);
    }
  }
  while (picked.length < 2 && bag.length) {
    const total = bag.reduce((s, o) => s + o.weight, 0);
    let r = Math.random() * total;
    let idx = 0;
    for (; idx < bag.length; idx += 1) {
      r -= bag[idx].weight;
      if (r <= 0) break;
    }
    picked.push(bag.splice(Math.min(idx, bag.length - 1), 1)[0]);
  }
  for (const opt of picked) {
    addChoice(box, opt.label, opt.id === "heal" && lowHp ? "primary" : "", () => {
      opt.apply();
      completeRoom();
      finishNodeModal("身体给出反馈。");
    });
  }
  addChoice(box, "什么都不要", "", () => {
    completeRoom();
    finishNodeModal("你空着手离开静室。");
  });
}

function offerCardReward({ title, lead, offers, onDone, overCombat = false }) {
  const keep = overCombat ? freezeCombatUnderlay() : [];
  showModal("screen-event", { keep });
  const kicker = $("event-kicker");
  if (kicker) kicker.textContent = overCombat ? "战斗奖励" : "小插曲";
  $("event-title").textContent = title;
  $("event-text").textContent = `${lead} 悬停卡牌可查看用途与用法。`;
  $("btn-close-event").classList.add("hidden");
  const box = $("event-choices");
  box.innerHTML = "";
  clearRewardCards();
  const row = $("reward-cards");
  for (const id of offers) {
    const def = cardDef(id);
    const card = document.createElement("div");
    card.className = `reward-card ${cardFrameClass(def.type)}`;
    card.tabIndex = 0;
    card.innerHTML = `<div class="cost">${def.cost}</div>
      <strong>${def.name}</strong>
      ${cardKindHtml(def.type)}
      <p class="blurb">${def.text}</p>`;
    bindHoverTip(card, cardTooltipHtml(def));
    const take = document.createElement("button");
    take.type = "button";
    take.className = "btn btn-primary btn-ticket";
    take.textContent = "收下";
    take.onclick = () => {
      hideCardTooltip();
      gainCard(id);
      onDone(`你收下了 ${def.name}。`);
    };
    card.appendChild(take);
    row.appendChild(card);
  }
  addChoice(box, "跳过", "", () => {
    hideCardTooltip();
    onDone("你判断加牌不划算，放弃了。");
  });
}

function finishNodeModal(text) {
  hideCardTooltip();
  clearRewardCards();
  $("event-text").textContent = text;
  $("event-choices").innerHTML = "";
  $("btn-close-event").classList.remove("hidden");
  renderAll();
  saveGame();
}

function completeRoom() {
  if (!state.resolvedRooms.has(state.roomId)) {
    state.visitPath.push(state.roomId);
    state.resolvedRooms.add(state.roomId);
  }
  delete state.rewardRolls[state.roomId];
  state.nodePending = false;
  discoverNeighbors(state.roomId);
  if (runReadyForBoss()) {
    state.chosenBoss = pickBossId();
    log(`行程已满。指纹收束：${state.data.bosses.bosses[state.chosenBoss].name}`, "ok");
  }
}

function gainCard(id) {
  state.discard.push(makeCard(id));
  log(`获得：${cardDef(id).name}`, "ok");
  playTone("ok");
}

function gainRelic(id) {
  if (state.relics.includes(id)) return;
  state.relics.push(id);
  const r = relicDef(id);
  if (r.effect.maxHp) {
    state.maxHp += r.effect.maxHp;
    state.hp += r.effect.maxHp;
  }
  log(`获得${r.name}`, "ok");
  playTone("ok");
}

/* ========== 网格战斗 ========== */

function combatTier(atCount = state.combatCount || 1) {
  // 末段不再跳档 5；残血再压一档，避免 1 血硬吃尖峰
  const curve = state.data.pressure?.combatCurve || [1, 1, 2, 3, 2, 3];
  const idx = Math.min(Math.max(0, atCount - 1), curve.length - 1);
  let tier = curve[idx];
  if (state.hp <= 1) tier = Math.min(tier, 2);
  else if (state.hp <= 2) tier = Math.min(tier, 3);
  return tier;
}

function tierScale(tier) {
  return state.data.pressure?.tierScale?.[String(tier)] || {
    hp: 0,
    damage: 0,
    tough: 0,
    stam: 0,
  };
}

function effectiveAttackCost(c) {
  if (c.traits?.includes("relentless") && c.enemySeesPlayer) return 1;
  return c.attackCost;
}

function playerDefenseTotal(c) {
  const cover = coverBlockAtPlayer();
  const heightCover = tileHeight(c.playerPos) > tileHeight(c.enemyPos) ? 1 : 0;
  return (c.block || 0) + cover + heightCover;
}

/** 预估对玩家的毛伤害（含高差）；展示时再扣当前格挡 */
function estimateHurtDamage(c) {
  let dmg = c.enemy.damage;
  if (tileHeight(c.enemyPos) > tileHeight(c.playerPos)) dmg += 1;
  return dmg;
}

function estimateNetHurt(c) {
  return estimateNetTotal(c, estimateHurtDamage(c), 1, false);
}

/** 突进落点：走到与玩家相邻的一格（从当前距 2） */
function lungeLanding(c) {
  return neighbors(c.enemyPos)
    .filter((p) => keyOf(p) !== keyOf(c.playerPos))
    .filter((p) => manhattan(p, c.playerPos) === 1)
    .map((p) => {
      const leaveTax = c.floor[keyOf(c.enemyPos)]?.enterTax || 0;
      const enterTax = c.floor[keyOf(p)]?.enterTax || 0;
      const climb = climbCost(c.enemyPos, p);
      return { p, cost: 1 + leaveTax + enterTax + climb };
    })
    .sort((a, b) => a.cost - b.cost)[0] || null;
}

function stepCostTo(c, p) {
  const leaveTax = c.floor[keyOf(c.enemyPos)]?.enterTax || 0;
  const enterTax = c.floor[keyOf(p)]?.enterTax || 0;
  const climb = climbCost(c.enemyPos, p);
  return 1 + leaveTax + enterTax + climb;
}

/** slam：以玩家为角、向敌人方向扩的 2×2 */
function slamRectCells(c) {
  const p = c.playerPos;
  const e = c.enemyPos;
  const dr = Math.sign(e.r - p.r);
  const dc = Math.sign(e.c - p.c);
  const rows = dr < 0 ? [p.r - 1, p.r] : [p.r, p.r + 1];
  const cols = dc < 0 ? [p.c - 1, p.c] : [p.c, p.c + 1];
  const cells = [];
  for (const r of rows) {
    for (const col of cols) {
      const pos = { r, c: col };
      if (inBounds(pos) && !isBlocked(pos)) cells.push(pos);
    }
  }
  return cells;
}

/** beam：从敌人朝玩家方向的 1×3 线（须同行或同列） */
function beamLineCells(c) {
  const e = c.enemyPos;
  const p = c.playerPos;
  if (e.r !== p.r && e.c !== p.c) return [];
  const cells = [];
  if (e.r === p.r) {
    const step = Math.sign(p.c - e.c);
    if (!step) return [];
    for (let i = 1; i <= 3; i += 1) {
      const pos = { r: e.r, c: e.c + step * i };
      if (!inBounds(pos) || isBlocked(pos)) break;
      cells.push(pos);
    }
  } else {
    const step = Math.sign(p.r - e.r);
    if (!step) return [];
    for (let i = 1; i <= 3; i += 1) {
      const pos = { r: e.r + step * i, c: e.c };
      if (!inBounds(pos) || isBlocked(pos)) break;
      cells.push(pos);
    }
  }
  return cells;
}

function cellsContain(cells, pos) {
  const k = keyOf(pos);
  return (cells || []).some((x) => keyOf(x) === k);
}

function canEnemyAttack(c, dist, sees) {
  if (!sees) return { ok: false, cost: effectiveAttackCost(c), kind: null };
  const cost = effectiveAttackCost(c);
  const defense = playerDefenseTotal(c);
  const pk = keyOf(c.playerPos);

  // slam AoE：须邻接（距 ≤1）。距 2 站桩砸地会让怪永远不迈步，体验过猛
  if (c.traits?.includes("slam") && dist <= 1 && c.enemyStamina >= cost) {
    const cells = slamRectCells(c);
    if (cells.some((x) => keyOf(x) === pk)) {
      return { ok: true, cost, kind: "slam", cells };
    }
  }

  // beam 1×3：同行/列且距 2–3
  if (
    c.traits?.includes("beam") &&
    dist >= 2 &&
    dist <= 3 &&
    (c.enemyPos.r === c.playerPos.r || c.enemyPos.c === c.playerPos.c) &&
    c.enemyStamina >= cost
  ) {
    const cells = beamLineCells(c);
    if (cells.some((x) => keyOf(x) === pk)) {
      return { ok: true, cost, kind: "beam", cells };
    }
  }

  if (dist <= 1 && c.enemyStamina >= cost) {
    if (c.traits?.includes("guardBreak") && defense > 0 && c.enemyStamina >= cost + 1) {
      return { ok: true, cost: cost + 1, kind: "guardBreak", cells: [{ ...c.playerPos }] };
    }
    return { ok: true, cost, kind: "melee", cells: [{ ...c.playerPos }] };
  }

  if (c.traits?.includes("lunge") && dist === 2) {
    const land = lungeLanding(c);
    if (land && c.enemyStamina >= land.cost + cost) {
      return {
        ok: true,
        cost: land.cost + cost,
        kind: "lunge",
        land,
        cells: [{ ...land.p }, { ...c.playerPos }],
      };
    }
  }
  return { ok: false, cost, kind: null };
}

/** 每回合最多打你几下：默认单段；连击词条可多段，但「重新发现你」时强制单段 */
function maxHitsPerTurn(c) {
  if (!c.traits?.includes("flurry")) return 1;
  // Boss 不带 flurry；普通连击封顶 2——红字必须读得懂
  if (c.isBoss) return 1;
  return 2;
}

/** 首击花 firstCost 后，剩余行动力还能追加几段 */
function plannedHits(c, atk, staminaAvailable) {
  const followCost = Math.max(1, effectiveAttackCost(c));
  let left = staminaAvailable - atk.cost;
  let hits = 1;
  while (hits < maxHitsPerTurn(c) && left >= followCost) {
    left -= followCost;
    hits += 1;
  }
  return hits;
}

/** 模拟格挡池：掩体/高差每段都吃，卡牌格挡是会被打光的池子 */
function estimateNetTotal(c, perHit, hits, ignoreDefense) {
  if (ignoreDefense) return perHit * hits;
  const innate = coverBlockAtPlayer() + (tileHeight(c.playerPos) > tileHeight(c.enemyPos) ? 1 : 0);
  let pool = c.block || 0;
  let total = 0;
  for (let i = 0; i < hits; i += 1) {
    let inc = Math.max(0, perHit - innate);
    const used = Math.min(pool, inc);
    pool -= used;
    total += inc - used;
  }
  return total;
}

/**
 * 推演敌人这一回合会怎么打你：埋伏扑出 / 多步逼近 / 拐角突脸 / 走一步再打。
 * 红区与实际结算共用这份计划，避免「显示追击却挨了一刀」。
 */
function planEnemyTurn(c) {
  if ((c.flingGraceTurns || 0) > 0 || (c.setupGraceTurns || 0) > 0) {
    return { atk: null, hits: 0, steps: [], step: null, ctx: c, grace: true };
  }

  const ctx = {
    ...c,
    enemyPos: { ...c.enemyPos },
    enemyStamina: c.enemyStamina,
    enemyMovesThisTurn: 0,
  };
  const steps = [];
  const goal = getEnemyGoal(c);
  const chasingDecoy = !!(decoyAlive(c) && goal && keyOf(goal) === keyOf(c.decoy.pos));
  if (chasingDecoy) {
    return { atk: null, hits: 0, steps: [], step: null, ctx: c };
  }

  const sawAtStart = hasLoS(ctx.enemyPos, ctx.playerPos) && !isEnemyBlinded(c);
  const needMoveFirst = c.isBoss && c.directive?.id === "closeup";

  const tryAtk = () => {
    if (needMoveFirst && ctx.enemyMovesThisTurn === 0) return null;
    const sees = hasLoS(ctx.enemyPos, ctx.playerPos) && !isEnemyBlinded(c);
    if (!sees) return null;
    const atk = canEnemyAttack(ctx, manhattan(ctx.enemyPos, ctx.playerPos), true);
    return atk.ok ? atk : null;
  };

  const finishAttack = (atk, opts = {}) => {
    const hits = opts.hits != null ? opts.hits : sawAtStart ? plannedHits(ctx, atk, ctx.enemyStamina) : 1;
    return {
      atk,
      hits,
      steps,
      step: steps[0] || null,
      ctx,
      path: steps,
      faceShock: !!opts.faceShock,
      frightOnly: !!opts.frightOnly,
    };
  };

  const applyFreeStep = (label, toward = null) => {
    const s = stepEnemyToward(toward || goal || ctx.playerPos, ctx);
    if (!s) return false;
    ctx.enemyPos = { ...s.p };
    ctx.enemyMovesThisTurn += 1;
    steps.push({ p: { ...s.p }, cost: 0, free: true, label });
    return true;
  };

  // 埋伏弹簧：揭开当回合免费扑一步（与敌回合一致）
  if (ctx.ambushSpring && (sawAtStart || chasingDecoy)) {
    applyFreeStep("扑出");
  }

  let atk = tryAtk();
  if (atk) return finishAttack(atk);

  // vault：优先上高台（不拉远距离时），与敌回合一致
  if (c.traits?.includes("vault") && sawAtStart) {
    const climbOpts = neighbors(ctx.enemyPos)
      .filter((p) => keyOf(p) !== keyOf(ctx.playerPos) && climbCost(ctx.enemyPos, p) > 0)
      .map((p) => ({ p, cost: stepCostTo(ctx, p), height: tileHeight(p) }))
      .filter((o) => o.cost <= ctx.enemyStamina)
      .sort((a, b) => b.height - a.height || a.cost - b.cost);
    const best = climbOpts[0];
    if (best && best.height > tileHeight(ctx.enemyPos)) {
      const goalPos = goal || ctx.playerPos;
      if (manhattan(best.p, goalPos) <= manhattan(ctx.enemyPos, goalPos)) {
        ctx.enemyStamina -= best.cost;
        ctx.enemyPos = { ...best.p };
        ctx.enemyMovesThisTurn += 1;
        steps.push({ p: { ...best.p }, cost: best.cost, label: "攀爬" });
        atk = tryAtk();
        if (atk) return finishAttack(atk);
      }
    }
  }

  // 多步逼近：直到出手或行动力耗尽（与敌回合 while 一致）
  let guard = 10;
  let hadLos = sawAtStart;
  while (ctx.enemyStamina > 0 && guard-- > 0) {
    atk = tryAtk();
    if (atk) return finishAttack(atk);

    if (!goal) break;
    const step = stepEnemyToward(goal, ctx);
    if (!step || step.cost > ctx.enemyStamina) break;

    ctx.enemyStamina -= step.cost;
    ctx.enemyPos = { ...step.p };
    ctx.enemyMovesThisTurn += 1;
    steps.push({ p: { ...step.p }, cost: step.cost });

    const seesNow = hasLoS(ctx.enemyPos, ctx.playerPos) && !isEnemyBlinded(c);
    if (seesNow && !hadLos) {
      // 拐角重获视线：抄近路 → 突脸只惊吓（贴身 1 伤），不再放全额招
      if (c.traits?.includes("cornerCut")) applyFreeStep("抄近路", ctx.playerPos);
      if (c.traits?.includes("faceShock")) {
        const dist = manhattan(ctx.enemyPos, ctx.playerPos);
        if (dist <= 1) {
          return finishAttack(
            { ok: true, cost: 0, kind: "faceShock", cells: [{ ...ctx.playerPos }] },
            { hits: 1, faceShock: true, frightOnly: true },
          );
        }
        // 够不着：只打断节奏，不预告扣血
        return {
          atk: null,
          hits: 0,
          steps,
          step: steps[0] || null,
          ctx,
          path: steps,
          faceShock: true,
          frightWhiff: true,
        };
      }
      atk = tryAtk();
      if (atk) return finishAttack(atk, { hits: 1 });
    }
    hadLos = seesNow || hadLos;
  }

  atk = tryAtk();
  if (atk) return finishAttack(atk);
  return { atk: null, hits: 0, steps, step: steps[0] || null, ctx, path: steps };
}

function hurtZoneFromAttack(ctx, atk, hits, opts = {}) {
  const dmgCtx =
    atk.kind === "lunge" && atk.land?.p ? { ...ctx, enemyPos: { ...atk.land.p } } : ctx;
  const perHit = opts.frightOnly ? 1 : estimateHurtDamage(dmgCtx);
  const ignore = atk.kind === "guardBreak";
  const cells = (atk.cells || [{ ...ctx.playerPos }]).map((p) => ({ ...p }));
  let shape = "cell";
  if (atk.kind === "lunge" || atk.kind === "beam") shape = "line";
  if (atk.kind === "slam") shape = "rect";
  return {
    shape,
    cells,
    kind: "hurt",
    damage: perHit,
    hits,
    total: perHit * hits,
    net: estimateNetTotal(dmgCtx, perHit, hits, ignore),
    attackKind: opts.faceShock ? "faceShock" : atk.kind,
  };
}

/** 当前贴身挥击能打到的邻格（用于「还没贴脸也先亮威胁圈」） */
function meleeReachCells(c) {
  return neighbors(c.enemyPos).filter((p) => inBounds(p) && !isWall(p) && isPassable(p));
}

/**
 * 已锁定玩家、但本回合打不到时：只标贴身威胁圈（虚线红）。
 * 不在你脚下写伤害数字——那会像「本回合必挨打」，实际只是锁定预告。
 */
function buildLockThreatZones(c) {
  const perHit = estimateHurtDamage(c);
  const zones = [];
  const reach = meleeReachCells(c).filter((p) => keyOf(p) !== keyOf(c.playerPos));
  if (reach.length) {
    zones.push({
      shape: "cell",
      cells: reach.map((p) => ({ ...p })),
      kind: "hurt",
      damage: perHit,
      hits: 1,
      total: perHit,
      net: perHit,
      attackKind: "reach",
      pending: true,
    });
  }
  if (c.traits?.includes("beam") && (c.enemyPos.r === c.playerPos.r || c.enemyPos.c === c.playerPos.c)) {
    const line = beamLineCells(c);
    if (line.length) {
      zones.push({
        shape: "line",
        cells: line.map((p) => ({ ...p })),
        kind: "hurt",
        damage: perHit,
        hits: 1,
        total: perHit,
        net: perHit,
        attackKind: "beam",
        pending: true,
      });
    }
  }
  return zones;
}

function pathMoveZones(steps) {
  return (steps || []).map((s) => ({
    shape: "step",
    cells: [{ ...s.p }],
    kind: "move",
    label: s.label || null,
  }));
}

function simCornerCutCtx(c) {
  if (!c.traits?.includes("cornerCut")) return c;
  const s = stepEnemyToward(c.playerPos, c);
  if (!s) return c;
  return { ...c, enemyPos: { ...s.p }, enemyMovesThisTurn: (c.enemyMovesThisTurn || 0) + 1 };
}

function predictIntent(c) {
  const sees = hasLoS(c.enemyPos, c.playerPos) && !isEnemyBlinded(c);
  const goal = getEnemyGoal(c);
  const chasingDecoy = !!(decoyAlive(c) && goal && keyOf(goal) === keyOf(c.decoy.pos));

  // Boss 蓄力：已锁定落点，优先于致盲/突脸等一切预告——结束回合必结算
  if (c.isBoss && c.chargePending) {
    const ch = c.chargePending;
    const net = estimateNetTotal(c, ch.damage, 1, false);
    return {
      type: "attack",
      label: `蓄力必落 ${ch.damage}${net !== ch.damage ? `→${net}` : ""}`,
      detail: `结束回合后必砸 · 半径 ${ch.radius} · 覆盖亮锚也会被砸灭 · 先离开红格或叠格挡`,
      zones: [
        {
          shape: "rect",
          cells: ch.cells.map((p) => ({ ...p })),
          kind: "hurt",
          damage: ch.damage,
          hits: 1,
          total: ch.damage,
          net,
          attackKind: "charge",
          // 对玩家而言等于「本回合结束后必伤」——用实线红，不用淡虚线
          pending: false,
        },
      ],
      hits: 1,
      pending: false,
    };
  }

  if (isEnemyBlinded(c) && !chasingDecoy) {
    return {
      type: "search",
      label: "闪瞎",
      detail: "强光致盲：本回合无法锁定你攻击",
      zones: [],
    };
  }

  // 突脸惊吓：你本回合转角暴露且仍在视线里 → 贴身才扣 1，够不着只吓
  if (!chasingDecoy && c.traits?.includes("faceShock") && c.playerExposed && sees) {
    const afterCut = simCornerCutCtx(c);
    const dist = manhattan(afterCut.enemyPos, afterCut.playerPos);
    const cutStep =
      keyOf(afterCut.enemyPos) !== keyOf(c.enemyPos)
        ? [{ p: { ...afterCut.enemyPos }, cost: 0, free: true, label: "抄近路" }]
        : [];
    if (dist <= 1) {
      const net = estimateNetTotal(afterCut, 1, 1, false);
      return {
        type: "attack",
        label: net !== 1 ? `惊吓 1→${net}` : "惊吓 1",
        detail: [
          "突脸惊吓：贴身固定 1 伤（不再放全额招）",
          cutStep.length ? "会先抄近路贴近" : null,
        ]
          .filter(Boolean)
          .join(" · "),
        zones: [
          {
            shape: "cell",
            cells: [{ ...c.playerPos }],
            kind: "hurt",
            damage: 1,
            hits: 1,
            total: 1,
            net,
            attackKind: "faceShock",
          },
          ...pathMoveZones(cutStep),
        ],
        hits: 1,
      };
    }
    return {
      type: "chase",
      label: "惊吓（够不着）",
      detail: "突脸惊吓：你还在视线里，但它够不着——只吓一跳不扣血。可先脱离视线。",
      zones: pathMoveZones(cutStep),
      pending: true,
      hits: 0,
      surpriseRisk: true,
    };
  }

  // 邻接傀儡：预告打碎傀儡
  if (chasingDecoy && manhattan(c.enemyPos, c.decoy.pos) <= 1 && c.enemyStamina >= effectiveAttackCost(c)) {
    return {
      type: "attack",
      label: "撕影",
      detail: "打碎纸影傀儡",
      zones: [{ shape: "cell", cells: [{ ...c.decoy.pos }], kind: "hurt", damage: 0, attackKind: "decoy" }],
      attack: { ok: true, cost: effectiveAttackCost(c), kind: "decoy", cells: [{ ...c.decoy.pos }] },
    };
  }

  const plan = chasingDecoy ? { atk: null, hits: 0, steps: [], step: null, ctx: c } : planEnemyTurn(c);

  if (plan.grace) {
    const moveZones = plan.steps?.length
      ? pathMoveZones(plan.steps)
      : (() => {
          if (!goal || c.enemyStamina < 1) return [];
          const s = stepEnemyToward(goal, c);
          return s ? pathMoveZones([{ p: s.p, cost: s.cost }]) : [];
        })();
    return {
      type: "chase",
      label: "布景·靠近",
      detail: "布景窗：它这一拍只靠近、不下手",
      zones: moveZones,
      pending: true,
      hits: 0,
    };
  }

  if (plan.atk) {
    const short = {
      lunge: "突进",
      guardBreak: "破防",
      melee: "挥击",
      slam: "砸地",
      beam: "激光",
      faceShock: "惊吓",
    };
    const zone = hurtZoneFromAttack(plan.ctx, plan.atk, plan.hits, {
      faceShock: plan.faceShock,
      frightOnly: plan.frightOnly,
    });
    const approaching = (plan.steps || []).length > 0;
    const tag = plan.faceShock
      ? approaching
        ? "逼近惊吓"
        : "惊吓"
      : `${approaching ? "逼近" : ""}${short[plan.atk.kind] || "攻击"}`;
    const shots = plan.hits > 1 ? `${zone.damage}×${plan.hits}` : `${zone.damage}`;
    const blocked = zone.net !== zone.total;
    const zones = [zone, ...pathMoveZones(plan.steps)];
    const grabNote = c.traits?.includes("grab") ? "打中会搜刮偷牌" : null;
    return {
      type: "attack",
      label: `${tag} ${shots}${blocked ? `→${zone.net}` : ""}`,
      detail: [
        tag,
        plan.hits > 1 ? `${plan.hits} 段 · 每段 ${zone.damage} · 合计 ${zone.total}` : `单段 ${zone.damage}`,
        plan.atk.kind === "guardBreak"
          ? "破防：无视格挡与掩体"
          : blocked
            ? `格挡/掩护后实伤 ${zone.net}`
            : null,
        approaching
          ? `先走 ${(plan.steps || []).map((s) => `(${s.p.r + 1},${s.p.c + 1})`).join("→")}`
          : null,
        plan.frightOnly ? "突脸惊吓：贴身固定 1 伤" : `耗它行动力 ${plan.atk.cost || "—"}`,
        grabNote,
      ]
        .filter(Boolean)
        .join(" · "),
      zones,
      attack: plan.atk,
      hits: plan.hits,
    };
  }

  // 移动意图
  let stepPos = plan.steps?.[0]?.p || null;
  let moveLabel = chasingDecoy ? "追影" : "追击";
  let type = "chase";
  const moveSteps = plan.steps?.length
    ? plan.steps
    : (() => {
        if (chasingDecoy) return [];
        if (c.traits?.includes("vault") && sees) {
          const climbOpt = neighbors(c.enemyPos)
            .filter((p) => keyOf(p) !== keyOf(c.playerPos) && climbCost(c.enemyPos, p) > 0)
            .map((p) => ({ p, cost: stepCostTo(c, p), height: tileHeight(p) }))
            .filter((o) => o.cost <= c.enemyStamina)
            .sort((a, b) => b.height - a.height || a.cost - b.cost)[0];
          if (climbOpt && climbOpt.height > tileHeight(c.enemyPos)) {
            const goalPos = goal || c.playerPos;
            if (manhattan(climbOpt.p, goalPos) <= manhattan(c.enemyPos, goalPos)) {
              moveLabel = "攀爬";
              return [{ p: climbOpt.p, cost: climbOpt.cost, label: "攀爬" }];
            }
          }
        }
        if (c.ambushSpring && (sees || chasingDecoy)) {
          const s = stepEnemyToward(goal || c.playerPos, c);
          if (s) {
            moveLabel = "扑出";
            return [{ p: s.p, cost: 0, free: true, label: "扑出" }];
          }
        }
        if (goal && c.enemyStamina >= 1) {
          const s = stepEnemyToward(goal, c);
          if (s && s.cost <= c.enemyStamina) return [{ p: s.p, cost: s.cost }];
        }
        return [];
      })();

  if (moveSteps.length) {
    stepPos = moveSteps[0].p;
    if (moveSteps[0].label === "攀爬") moveLabel = "攀爬";
    if (moveSteps[0].label === "扑出") moveLabel = "扑出";
  }
  if (chasingDecoy) {
    moveLabel = "追影";
    type = "chase";
  } else if (sees) {
    if (moveLabel !== "攀爬" && moveLabel !== "扑出") moveLabel = "追击";
    type = "chase";
  } else if (c.lastSeen) {
    moveLabel = "搜索";
    type = "search";
  } else {
    moveLabel = "巡逻";
    type = "patrol";
  }

  // 看见你、且推演确认本回合打不到：锁定 + 贴身虚线红
  if (!chasingDecoy && sees) {
    const zones = [...buildLockThreatZones(c), ...pathMoveZones(moveSteps)];
    const dmg = estimateHurtDamage(c);
    return {
      type: "chase",
      label: stepPos ? `锁定·${moveLabel}` : "锁定",
      detail: [
        "已锁定你——推演后本回合仍够不着",
        stepPos ? `下一步 → (${stepPos.r + 1},${stepPos.c + 1})` : "停在原地",
        `贴身虚线红 = 你走进去会挨 ${dmg} 伤`,
      ]
        .filter(Boolean)
        .join(" · "),
      zones,
      pending: true,
      hits: 0,
    };
  }

  // 无视线但有突脸：搜索时标明拐角风险
  if (!chasingDecoy && !sees && c.traits?.includes("faceShock")) {
    const zones = pathMoveZones(moveSteps);
    return {
      type: type === "patrol" ? "patrol" : "search",
      label: stepPos ? `${moveLabel}·当心突脸` : "当心突脸",
      detail:
        "有「突脸惊吓」：拐进视线且贴身时固定吓 1 下（不再放全额招）；够不着只喊不伤。用遮挡拉开或闪光致盲。",
      zones,
      pending: true,
      hits: 0,
      surpriseRisk: true,
    };
  }

  if (!stepPos && c.enemyStamina >= 1 && !sees && !chasingDecoy) {
    return { type: "patrol", label: "巡逻", detail: "在场地里转悠", zones: [] };
  }
  if (moveSteps.length) {
    return {
      type,
      label: moveLabel,
      detail: `${moveLabel} → ${moveSteps.map((s) => `(${s.p.r + 1},${s.p.c + 1})`).join("→")}`,
      zones: pathMoveZones(moveSteps),
    };
  }
  return { type: "stall", label: "观望", detail: "行动力不足", zones: [] };
}

/** 从 intent.zones 建格 → 威胁信息映射，供渲染 */
function threatMapFromIntent(intent) {
  const map = new Map();
  for (const z of intent?.zones || []) {
    for (const cell of z.cells || []) {
      const k = keyOf(cell);
      const prev = map.get(k);
      if (z.kind === "hurt") {
        const next = {
          kind: "hurt",
          damage: z.damage || 0,
          hits: z.hits || 1,
          total: z.total != null ? z.total : z.damage || 0,
          net: z.net != null ? z.net : z.damage || 0,
          shape: z.shape,
          attackKind: z.attackKind || null,
          pending: !!z.pending,
        };
        // 实打红区优先于虚线锁定，避免预告盖住本回合必伤
        if (!prev || (prev.pending && !next.pending) || (prev.kind !== "hurt")) {
          map.set(k, next);
        } else if (prev.pending === next.pending && (next.damage || 0) > (prev.damage || 0)) {
          map.set(k, next);
        }
      } else if (z.kind === "move" && (!prev || prev.kind !== "hurt")) {
        map.set(k, { kind: "move", shape: z.shape });
      }
    }
  }
  return map;
}

function beginPlayerTurn(kept = []) {
  const c = state.combat;
  const dice = rollSpeedDice();
  c.rolls = dice.rolls;
  c.energy = dice.total;
  c.discount = 0;
  c.block = 0;
  c.heldUid = null;
  c.placeUid = null;
  c.turnDamageDealt = 0;
  c.turnToughChip = 0;
  // 踉跄：破韧后的下回合行动力上限降低
  const stamCap = c.staggerNext ? Math.max(1, c.staminaMax - 2) : c.staminaMax;
  if (c.staggerNext) {
    log(`${c.enemy.name}仍在踉跄，本回合行动力上限 ${stamCap}。`, "ok");
    c.staggerNext = false;
  }
  c.enemyStamina = stamCap;
  c.enemyMovesThisTurn = 0;
  c.saltSteppedThisTurn = false;
  c.snareForcedThisTurn = false;
  c.portalLanded = false;
  // 开场布景窗：首回合多 1 行动力，方便侧刺/挂预备
  if (c.setupBonusEnergy) {
    c.energy += c.setupBonusEnergy;
    log(`布景窗：本回合行动力 +${c.setupBonusEnergy}（先摆机关再接敌）。`, "ok");
    c.setupBonusEnergy = 0;
  }
  applyStallBreakAssistIfNeeded();
  if (!state.combat) return;
  const vis = refreshVision();
  if (vis.faceReveal) {
    log(`突脸！${c.enemy.name}从遮挡后锁定了你。`, "bad");
    playTone("bad");
    if (state.lab) state.lab.summary.faceReveals += 1;
    labEvent("face_reveal", { phase: "player_turn_start" });
  }
  c.intent = predictIntent(c);
  c.hand = kept;
  const need = Math.max(0, state.data.cards.handSize - c.hand.length);
  c.hand.push(...drawHand(need));
  labNotePlayerTurn(c.energy, c.rolls);
}

function drainToughness(amount, reason) {
  const c = state.combat;
  if (!c || c.toughness <= 0 || amount <= 0) return false;
  c.toughness = Math.max(0, c.toughness - amount);
  c.turnToughChip = (c.turnToughChip || 0) + amount;
  if (c.toughness > 0) return false;
  // 破韧
  c.broken = true;
  const style = c.archetype;
  log(`破韧！【${c.archetypeLabel}】${reason || ""}`, "ok");
  playTone("ok");
  labNoteToughBreak(reason || "");
  if (c.isBoss) relieveBroadcast(c, bossFightCfg().breakClockRelief || 2, "破韧");
  if (style === "execute") {
    c.executeReady = true;
    log("获得处决：下次砸击/踩踏 +2。", "ok");
  } else if (style === "stagger") {
    c.staggerNext = true;
    log(`${c.enemy.name}踉跄：其下回合行动力将下降。`, "ok");
  } else if (style === "crush") {
    c.crushReady = true;
    log("破甲：下一次对其伤害翻倍（额外最多 +4）。", "ok");
  } else if (style === "armor") {
    log("装甲剥落：减伤消失。", "ok");
  } else if (style === "wire") {
    c.wireBrokenBoost = true;
    log("布线暴露：踩踏额外 +1。", "ok");
  }
  return true;
}

/** source: smash | trap | other */
function dealToEnemy(rawDmg, source) {
  const c = state.combat;
  let dmg = rawDmg;
  if (dmg <= 0) return 0;

  if (!c.broken && c.archetype === "armor") {
    dmg = Math.max(0, dmg - 1);
  }
  if (!c.broken && c.archetype === "wire" && source === "smash") {
    dmg = Math.ceil(dmg * 0.5);
  }
  if (c.executeReady && (source === "smash" || source === "trap")) {
    dmg += 2;
    c.executeReady = false;
    log("处决发动 +2。", "ok");
  }
  if (c.wireBrokenBoost && source === "trap") {
    dmg += 1;
  }
  if (c.crushReady) {
    const doubled = dmg * 2;
    const capped = Math.min(doubled, dmg + 4);
    log(`破甲一击：${dmg} → ${capped}`, "ok");
    dmg = capped;
    c.crushReady = false;
  }

  c.enemy.hp -= dmg;
  c.turnDamageDealt = (c.turnDamageDealt || 0) + dmg;
  labNoteDamageDealt(dmg, source);
  return dmg;
}

/** 回合结束统计空转；援助在下一回合开始发放（行动力才有用） */
function noteStallAfterPlayerTurn() {
  const c = state.combat;
  if (!c || c.isBoss) return;
  const progressed = (c.turnDamageDealt || 0) > 0 || (c.turnToughChip || 0) > 0;
  if (progressed) {
    c.stallTurns = 0;
    return;
  }
  c.stallTurns = (c.stallTurns || 0) + 1;
  if (c.stallTurns === 3) {
    log("场面胶着：这几回合几乎没打上。试试砸它脚下，或先削韧再输出。", "bad");
    labEvent("stall_warn", { turns: c.stallTurns });
  }
}

function applyStallBreakAssistIfNeeded() {
  const c = state.combat;
  if (!c || c.isBoss) return;
  if ((c.stallTurns || 0) < 4) return;
  const level = (c.stallAssistLevel || 0) + 1;
  c.stallAssistLevel = level;
  c.stallTurns = 0;
  if (level === 1) {
    drainToughness(1, "破局·削韧");
    c.energy += 1;
    c.discount = Math.max(c.discount || 0, 1);
    log("破局援助：+1 行动力，下一件放置 -1，并削韧 1。把刺砸向它或引它踩上去。", "ok");
    labEvent("stall_assist", { level: 1 });
    playTone("ok");
    return;
  }
  const dealt = dealToEnemy(2, "stall_break");
  drainToughness(1, "破局一击削韧");
  log(`破局一击：造成 ${dealt} 伤${c.toughness <= 0 ? "，韧已破" : ""}。别再空转。`, "ok");
  labEvent("stall_assist", { level: 2, dealt });
  playTone("ok");
  if (c.enemy.hp <= 0) winCombat();
}

function buildEncounter(room, isBoss) {
  const P = state.data.pressure;
  if (room?.flingSandbox && !isBoss) {
    const src = room.enemy;
    const arch = P.archetypes.execute;
    return {
      name: src.name,
      hp: src.hp,
      damage: src.damage,
      archetype: "execute",
      archetypeLabel: "沙盒剪影",
      archetypeDesc: "直挺挺追你——用来测预备甩开与侧刺 combo。",
      toughness: 3,
      toughnessMax: 3,
      traits: [],
      tier: 1,
      staminaMax: 4,
      attackCost: 2,
    };
  }
  if (room?.tutorialFight && !isBoss) {
    const src = room.enemy;
    const arch = P.archetypes.execute;
    return {
      name: src.name,
      hp: src.hp,
      damage: src.damage,
      archetype: "execute",
      archetypeLabel: arch.label,
      archetypeDesc: "教学用：破韧后下次砸/踩 +2。正式局里不同类型奖励不同。",
      toughness: 2,
      toughnessMax: 2,
      traits: [],
      tier: 1,
      staminaMax: 3,
      attackCost: 2,
    };
  }
  const src = isBoss
    ? state.data.bosses.bosses[state.chosenBoss]
    : room.enemy;
  const archId = isBoss
    ? P.boss.archetype
    : P.roomArchetype[room.id] || "execute";
  const arch = P.archetypes[archId];
  const traits = isBoss
    ? [...(P.boss.traits || [])]
    : [...(P.roomTraits[room.id] || [])];
  const tier = isBoss ? 5 : combatTier();
  const scale = tierScale(tier);
  const hp = src.hp + scale.hp + (isBoss ? 2 : 0);
  const damage = src.damage + scale.damage;
  const tough =
    arch.baseTough +
    scale.tough +
    (isBoss ? P.boss.toughBonus || 0 : 0);
  const staminaMax = (isBoss ? 4 : 3) + scale.stam;
  return {
    name: src.name,
    hp,
    damage,
    archetype: archId,
    archetypeLabel: arch.label,
    archetypeDesc: arch.desc,
    toughness: tough,
    toughnessMax: tough,
    traits,
    tier,
    staminaMax,
    attackCost: 2,
  };
}

function resolveArena(room, isBoss) {
  const fallback = state.data.rooms.defaultArena || state.data.cards.grid;
  if (isBoss) {
    // Boss：本局大地图一房一格；无布局时先掷一张平面图
    if (!isSpatialLayout(state.roomLayout)) {
      rollRoomLayout((Date.now() ^ (Math.random() * 0x7fffffff)) >>> 0);
    }
    if (isSpatialLayout(state.roomLayout)) {
      return buildHouseGraphArena(state.roomLayout);
    }
  }
  const raw = isBoss
    ? roomDef("altar")?.arena || fallback
    : room.arena || fallback;
  const rows = raw.rows || fallback.rows || 3;
  const cols = raw.cols || fallback.cols || 5;
  const player = raw.player || [Math.floor(rows / 2), 0];
  const enemy = raw.enemy || [Math.floor(rows / 2), cols - 1];
  // 普通房仍可用墙；Boss 回退场把旧墙改成空洞
  const wallList = [...(raw.walls || [])];
  const walls = new Set(isBoss ? [] : wallList);
  const voids = new Set(isBoss ? wallList : []);
  const heights = { ...(raw.heights || {}) };
  const playerPos = { r: player[0], c: player[1] };
  const enemyPos = { r: enemy[0], c: enemy[1] };
  if (!isBoss) ensureArenaPath(rows, cols, walls, playerPos, enemyPos);
  const portals = {};
  for (const pair of raw.portals || []) {
    if (!pair || pair.length < 2) continue;
    const [a, b] = pair;
    portals[a] = b;
    portals[b] = a;
  }
  return {
    rows,
    cols,
    playerPos,
    enemyPos,
    walls,
    voids,
    heights,
    portals,
    links: null,
    houseGraph: false,
    roomAt: null,
    ambush: !!raw.ambush,
    spawnNote: raw.spawnNote || "",
    anchors: [...(raw.anchors || [])],
  };
}

/**
 * Boss 决战场：本局 roomLayout → 棋盘。
 * 有房间的坐标 = 可站格；没有房间的坐标 = 空洞（不是墙）；只沿 exits/门通行。
 */
function buildHouseGraphArena(layout) {
  const size = state.data.rooms.mapSize || { cols: 17, rows: 17 };
  const rows = size.rows;
  const cols = size.cols;
  const voids = new Set();
  const roomAt = {};
  for (let r = 0; r < rows; r += 1) {
    for (let c = 0; c < cols; c += 1) {
      voids.add(`${r},${c}`);
    }
  }
  for (const [id, loc] of Object.entries(layout)) {
    const r = (loc.row | 0) - 1;
    const c = (loc.col | 0) - 1;
    if (r < 0 || c < 0 || r >= rows || c >= cols) continue;
    const k = `${r},${c}`;
    voids.delete(k);
    roomAt[k] = id;
  }

  const links = new Set();
  for (const [id, loc] of Object.entries(layout)) {
    const a = { r: (loc.row | 0) - 1, c: (loc.col | 0) - 1 };
    if (voids.has(keyOf(a))) continue;
    for (const eid of loc.exits || []) {
      const other = layout[eid];
      if (!other) continue;
      const b = { r: (other.row | 0) - 1, c: (other.col | 0) - 1 };
      if (voids.has(keyOf(b))) continue;
      if (Math.abs(a.r - b.r) + Math.abs(a.c - b.c) !== 1) continue;
      links.add(doorEdgeKey(a, b));
    }
  }

  const startId =
    (state.roomId && layout[state.roomId] && state.roomId) ||
    state.data.rooms.startRoom ||
    "foyer";
  const startLoc = layout[startId] || Object.values(layout)[0];
  const playerPos = { r: (startLoc.row | 0) - 1, c: (startLoc.col | 0) - 1 };

  const enemyPos =
    farthestHousePos(layout, links, playerPos, voids) || {
      r: playerPos.r,
      c: playerPos.c,
    };
  // 若碰巧重合，再找任意其它房
  if (keyOf(enemyPos) === keyOf(playerPos)) {
    for (const loc of Object.values(layout)) {
      const p = { r: (loc.row | 0) - 1, c: (loc.col | 0) - 1 };
      if (keyOf(p) !== keyOf(playerPos) && !voids.has(keyOf(p))) {
        enemyPos.r = p.r;
        enemyPos.c = p.c;
        break;
      }
    }
  }

  // 兜圈：给正交相邻但未接线的房间补捷径，形成局部环
  weaveHouseLoops(layout, links, voids);
  // 高度 / 传送门：对齐小场地机关语汇
  const heights = assignHouseHeights(layout, voids);
  const portals = assignHousePortals(layout, links, voids, playerPos, enemyPos);

  const anchors = pickHouseAnchorKeys(layout, voids, playerPos, enemyPos, 4);
  const roomN = Object.keys(layout).length;
  const portalN = Object.keys(portals).length / 2;
  const highN = Object.keys(heights).length;
  return {
    rows,
    cols,
    playerPos,
    enemyPos,
    walls: new Set(),
    voids,
    heights,
    portals,
    links,
    houseGraph: true,
    roomAt,
    ambush: false,
    spawnNote: `决战场：本集山屋平面（${roomN} 间）。一房一格 · 空洞不画格 · 沿门走 · 高台 ${highN} · 传送门 ${Math.floor(portalN)} 对 · 已补环路可兜圈。`,
    anchors,
  };
}

/** 正交贴邻但没门的房间，按概率开门，方便 Boss 战兜圈子 */
function weaveHouseLoops(layout, links, voids) {
  const occupied = [];
  for (const loc of Object.values(layout)) {
    const p = { r: (loc.row | 0) - 1, c: (loc.col | 0) - 1 };
    if (!voids.has(keyOf(p))) occupied.push(p);
  }
  const candidates = [];
  for (let i = 0; i < occupied.length; i += 1) {
    for (let j = i + 1; j < occupied.length; j += 1) {
      const a = occupied[i];
      const b = occupied[j];
      if (Math.abs(a.r - b.r) + Math.abs(a.c - b.c) !== 1) continue;
      const edge = doorEdgeKey(a, b);
      if (links.has(edge)) continue;
      candidates.push([a, b, edge]);
    }
  }
  // 至少补 2 条环，其余约 45% 概率
  let added = 0;
  for (const [a, b, edge] of candidates) {
    const force = added < 2;
    if (force || Math.random() < 0.45) {
      links.add(edge);
      added += 1;
    }
  }
  return added;
}

function assignHouseHeights(layout, voids) {
  const heights = {};
  for (const [id, loc] of Object.entries(layout)) {
    const p = { r: (loc.row | 0) - 1, c: (loc.col | 0) - 1 };
    if (voids.has(keyOf(p))) continue;
    let h = 0;
    if (/attic|loft|gallery|塔|阁|廊顶/.test(id) || /阁|塔|画廊/.test(roomDef(id)?.name || "")) h = 2;
    else if (/study|bedroom|upper|西厢|主卧|书房|客房/.test(id + (roomDef(id)?.name || ""))) h = 1;
    else if (/cellar|boiler|mud|basement|地窖|锅炉|泥/.test(id + (roomDef(id)?.name || ""))) h = 0;
    else if (Math.random() < 0.28) h = 1;
    if (h > 0) heights[keyOf(p)] = h;
  }
  return heights;
}

/** 挑两个较远的末梢房做一对传送门（可再补一对） */
function assignHousePortals(layout, links, voids, playerPos, enemyPos) {
  const tips = [];
  for (const [id, loc] of Object.entries(layout)) {
    const p = { r: (loc.row | 0) - 1, c: (loc.col | 0) - 1 };
    const k = keyOf(p);
    if (voids.has(k)) continue;
    if (k === keyOf(playerPos) || k === keyOf(enemyPos)) continue;
    let deg = 0;
    for (const n of [
      { r: p.r - 1, c: p.c },
      { r: p.r + 1, c: p.c },
      { r: p.r, c: p.c - 1 },
      { r: p.r, c: p.c + 1 },
    ]) {
      if (links.has(doorEdgeKey(p, n))) deg += 1;
    }
    tips.push({ id, p, k, deg, spread: manhattan(p, playerPos) + manhattan(p, enemyPos) });
  }
  tips.sort((a, b) => a.deg - b.deg || b.spread - a.spread);
  const portals = {};
  const used = new Set();
  const pool = tips.length >= 4 ? tips : tips;
  for (let i = 0; i < pool.length && Object.keys(portals).length < 4; i += 1) {
    const a = pool[i];
    if (used.has(a.k)) continue;
    let best = null;
    let bestD = -1;
    for (let j = i + 1; j < pool.length; j += 1) {
      const b = pool[j];
      if (used.has(b.k)) continue;
      const d = manhattan(a.p, b.p);
      if (d < 3) continue;
      if (d > bestD) {
        bestD = d;
        best = b;
      }
    }
    if (!best) continue;
    portals[a.k] = best.k;
    portals[best.k] = a.k;
    used.add(a.k);
    used.add(best.k);
  }
  return portals;
}

function farthestHousePos(layout, links, from, voids) {
  const start = keyOf(from);
  const q = [{ ...from }];
  const dist = new Map([[start, 0]]);
  while (q.length) {
    const cur = q.shift();
    for (const n of [
      { r: cur.r - 1, c: cur.c },
      { r: cur.r + 1, c: cur.c },
      { r: cur.r, c: cur.c - 1 },
      { r: cur.r, c: cur.c + 1 },
    ]) {
      const nk = keyOf(n);
      if (voids.has(nk) || dist.has(nk)) continue;
      if (!links.has(doorEdgeKey(cur, n))) continue;
      dist.set(nk, (dist.get(keyOf(cur)) || 0) + 1);
      q.push(n);
    }
  }
  let best = null;
  let bestD = -1;
  for (const [k, d] of dist) {
    if (k === start) continue;
    if (d > bestD) {
      bestD = d;
      best = parseKey(k);
    }
  }
  return best;
}

function pickHouseAnchorKeys(layout, voids, playerPos, enemyPos, want = 4) {
  const forbidden = new Set([keyOf(playerPos), keyOf(enemyPos)]);
  const cells = [];
  for (const loc of Object.values(layout)) {
    const p = { r: (loc.row | 0) - 1, c: (loc.col | 0) - 1 };
    const k = keyOf(p);
    if (voids.has(k) || forbidden.has(k)) continue;
    const degree = (loc.exits || []).length;
    const spread = manhattan(p, playerPos) + manhattan(p, enemyPos);
    cells.push({ k, degree, spread });
  }
  // 偏好末梢 + 远离双方出生点
  cells.sort((a, b) => a.degree - b.degree || b.spread - a.spread);
  const picked = [];
  for (const cell of cells) {
    if (picked.length >= want) break;
    // 锚之间不要贴太近
    if (picked.some((pk) => manhattan(parseKey(pk), parseKey(cell.k)) <= 1)) continue;
    picked.push(cell.k);
  }
  // 不够就放宽间距再补
  if (picked.length < want) {
    for (const cell of cells) {
      if (picked.length >= want) break;
      if (picked.includes(cell.k)) continue;
      picked.push(cell.k);
    }
  }
  return picked;
}

/** BFS：若玩家到不了敌人格，逐格拆墙直到通路存在 */
function ensureArenaPath(rows, cols, walls, playerPos, enemyPos) {
  const goal = keyOf(enemyPos);
  const inb = (p) => p.r >= 0 && p.r < rows && p.c >= 0 && p.c < cols;
  const canReach = () => {
    const q = [{ ...playerPos }];
    const seen = new Set([keyOf(playerPos)]);
    while (q.length) {
      const cur = q.shift();
      if (keyOf(cur) === goal) return true;
      for (const n of [
        { r: cur.r - 1, c: cur.c },
        { r: cur.r + 1, c: cur.c },
        { r: cur.r, c: cur.c - 1 },
        { r: cur.r, c: cur.c + 1 },
      ]) {
        if (!inb(n)) continue;
        const k = keyOf(n);
        if (seen.has(k)) continue;
        if (walls.has(k) && k !== goal) continue;
        seen.add(k);
        q.push(n);
      }
    }
    return false;
  };
  if (canReach()) return;
  // 找一条无视墙的最短路，拆掉路上的墙
  const q = [{ ...playerPos }];
  const prev = new Map([[keyOf(playerPos), null]]);
  let found = false;
  while (q.length && !found) {
    const cur = q.shift();
    for (const n of [
      { r: cur.r - 1, c: cur.c },
      { r: cur.r + 1, c: cur.c },
      { r: cur.r, c: cur.c - 1 },
      { r: cur.r, c: cur.c + 1 },
    ]) {
      if (!inb(n)) continue;
      const k = keyOf(n);
      if (prev.has(k)) continue;
      prev.set(k, keyOf(cur));
      if (k === goal) {
        found = true;
        break;
      }
      q.push(n);
    }
  }
  if (!found) return;
  let k = goal;
  const cleared = [];
  while (k) {
    if (walls.has(k) && k !== goal && k !== keyOf(playerPos)) {
      walls.delete(k);
      cleared.push(k);
    }
    k = prev.get(k);
  }
  if (cleared.length) {
    log(`场地校准：拆开堵死通道的墙（${cleared.join(" / ")}），避免死局。`, "ok");
  }
}

function startCombat(room, isBoss) {
  if (!isBoss) state.combatCount = (state.combatCount || 0) + 1;
  const enc = buildEncounter(room, isBoss);
  const arena = resolveArena(room, isBoss);

  state.combat = {
    isBoss,
    roomId: room.id,
    roomName: room.name || roomDef(room.id)?.name || "场地",
    enemy: { name: enc.name, hp: enc.hp, damage: enc.damage },
    archetype: enc.archetype,
    archetypeLabel: enc.archetypeLabel,
    archetypeDesc: enc.archetypeDesc,
    toughness: enc.toughness,
    toughnessMax: enc.toughnessMax,
    broken: false,
    traits: enc.traits,
    tier: enc.tier,
    staminaMax: enc.staminaMax,
    attackCost: enc.attackCost,
    enemyStamina: enc.staminaMax,
    executeReady: false,
    crushReady: false,
    staggerNext: false,
    wireBrokenBoost: false,
    grid: { rows: arena.rows, cols: arena.cols },
    walls: arena.walls,
    voids: arena.voids || new Set(),
    links: arena.links || null,
    houseGraph: !!arena.houseGraph,
    roomAt: arena.roomAt || null,
    heights: arena.heights,
    portals: arena.portals || {},
    playerPos: arena.playerPos,
    enemyPos: arena.enemyPos,
    lastSeen: null,
    lastSeenAge: 0,
    patrolGoal: null,
    ambushIdleTurns: 0,
    enemyHadLoS: false,
    playerSeesEnemy: false,
    enemySeesPlayer: false,
    ambush: arena.ambush,
    ambushActive: arena.ambush,
    ambushSpring: false,
    spawnNote: arena.spawnNote,
    playerExposed: false,
    enemyMovesThisTurn: 0,
    floor: {},
    decoy: null,
    saltSteppedThisTurn: false,
    blindArmed: false,
    blindTurns: 0,
    firstSmashUsed: false,
    snareForcedThisTurn: false,
    chasingDecoy: false,
    portalLanded: false,
    comboFlash: null,
    energy: 0,
    rolls: [],
    hand: [],
    block: 0,
    discount: 0,
    heldUid: null,
    retainSlots: 0,
    retainThisTurn: 0,
    freeDrawUsed: false,
    placeUid: null,
    ready: null,
    intent: null,
    turnDamageDealt: 0,
    turnToughChip: 0,
    stallTurns: 0,
    stallAssistLevel: 0,
    setupGraceTurns: 0,
    setupBonusEnergy: 0,
    // Boss 仪式
    anchors: {},
    broadcast: 0,
    broadcastMax: 0,
    phaseIndex: 0,
    phaseName: "开场",
    chargePending: null,
    directive: null,
  };

  if (isBoss) {
    const cfg = bossFightCfg();
    const hp = cfg.anchorHp || 2;
    for (const key of arena.anchors || []) {
      state.combat.anchors[key] = { lit: true, hp };
    }
    state.combat.broadcastMax = cfg.broadcastMax || 12;
    state.combat.broadcast = 0;
    const phase0 = (cfg.phases || [])[0];
    if (phase0?.stam) {
      state.combat.staminaMax = phase0.stam + (tierScale(enc.tier).stam || 0);
      state.combat.enemyStamina = state.combat.staminaMax;
    }
    state.combat.phaseName = phase0?.name || "开场";
    log(
      `仪式开场：场上 ${Object.keys(state.combat.anchors).length} 枚信号锚。熄灭全部 或 打空血条均可通关。播出进度 ${state.combat.broadcastMax} 满则失败。`,
      "ok",
    );
  }
  if (hasRelicEffect("revealAmbush") && state.combat.ambushActive) {
    state.combat.ambushActive = false;
    state.combat.ambushSpring = false;
    log("预兆·铃铛叮了一声——埋伏被揭开了。", "ok");
  }
  const vis = refreshVision();
  if (state.combat.spawnNote) log(state.combat.spawnNote, vis.playerSees ? "ok" : "");
  else if (!vis.playerSees) log(`你踏进${state.combat.roomName}——有东西在，但被地形挡住了。`);
  else log(`${state.combat.enemy.name}已经在场地上。`);
  if (state.combat.ambushActive && !vis.playerSees) {
    log("埋伏：它暂不主动搜索，直到有一方建立视线。");
  }
  beginLabCombat(room, enc, isBoss);
  // 开场已贴脸：给 1 拍只靠近不下手 + 首回合 +1 行动力（沙盒沿用自己的 grace）
  if (
    !isBoss &&
    !state.flingSandbox?.active &&
    !room?.tutorialFight &&
    isOrthoAdjacent(state.combat.playerPos, state.combat.enemyPos)
  ) {
    state.combat.setupGraceTurns = 1;
    state.combat.setupBonusEnergy = 1;
    log("它已经贴上来了——这一拍它只靠近不下手，先摆机关。", "ok");
  }
  beginPlayerTurn([]);
  if (!state.combat) return;
  if (hasRelicEffect("combatDecoy")) {
    state.combat.hand.push(makeCard("decoy"));
    log("预兆·纸影：手牌加入「纸影傀儡」。", "ok");
  }
  renderCombat();
  showModal("screen-cards");
  playTone("dice");
  log(
    `遭遇【${enc.archetypeLabel}】${enc.name} · 难度档 ${enc.tier} · 韧性 ${enc.toughness}。${enc.archetypeDesc}`,
  );
  if (enc.traits.length) {
    const labels = state.data.pressure.traitLabels || {};
    log(`机制：${enc.traits.map((t) => labels[t] || t).join(" / ")}`);
  }
  if (isBoss) {
    log("Boss 仪式：熄灭全部信号锚 或 打空血条均可通关。播出进度满则失败。站在锚上可「拆信号」。", "ok");
  }
  if (state.tutorial?.active) {
    state.tutorial.step = "place";
    updateBattleTutorialCoach();
  }
  if (state.flingSandbox?.active) refreshFlingSandboxCoach();
}

function cancelPlace() {
  if (!state.combat) return;
  state.combat.placeUid = null;
  renderCombat();
}

function selectCard(uid) {
  const c = state.combat;
  const inst = c.hand.find((x) => x.uid === uid);
  if (!inst) return;
  const def = cardDef(inst.id);
  const cost = Math.max(0, def.cost - c.discount);
  if (cost > c.energy) return;

  if (def.type === "place") {
    c.placeUid = c.placeUid === uid ? null : uid;
    renderCombat();
    return;
  }

  // medicine / skill / ready：立刻打出（预备是挂起，不是放置）
  resolveInstant(inst);
}

function armReady(inst, def) {
  const c = state.combat;
  if (c.ready) {
    log(`改挂预备「${def.name}」（「${c.ready.name}」落空）。`);
  }
  const alreadyAdj = isOrthoAdjacent(c.enemyPos, c.playerPos);
  c.ready = {
    cardId: inst.id,
    name: def.name,
    effect: { ...(def.ready || {}) },
    /** 挂上时已贴脸：允许邻接十字间挪步触发，避免静默废牌 */
    awaitStep: alreadyAdj,
  };
  labEvent("ready_arm", {
    cardId: inst.id,
    name: def.name,
    shove: !!def.ready?.shove,
    alreadyAdjacent: alreadyAdj,
  });
  if (def.ready?.shove) {
    if (alreadyAdj) {
      log(
        `预备·${def.name}已挂，但它已经贴在十字上——站桩砍不会触发。它在邻接十字间挪一步会甩；或先推撞/走开再引它走进来。`,
        "bad",
      );
    } else if (def.ready?.preferPortal) {
      log(`预备·${def.name}：它走进相邻十字就会被甩向传送门（有门优先）。`, "ok");
    } else {
      log(`预备·${def.name}：它走进相邻十字就会被甩开——优先甩向机关格。`, "ok");
    }
  } else if (alreadyAdj) {
    log(
      `预备·${def.name}已挂，但它已贴脸——站桩不会触发。它挪到另一邻接格，或先拉开再走进来才会结算。`,
      "bad",
    );
  } else {
    log(`预备·${def.name}：你成了机关——它走进相邻十字格就会触发。`, "ok");
  }
  if (state.flingSandbox?.active) refreshFlingSandboxCoach();
}

/** 敌方回合位移后触发预备 */
function checkReadyOnEnemyEnter(prevPos) {
  const c = state.combat;
  if (!c?.ready) return false;
  if (!isOrthoAdjacent(c.enemyPos, c.playerPos)) return false;
  const wasAdj = !!(prevPos && isOrthoAdjacent(prevPos, c.playerPos));
  // 标准：非邻接 → 邻接
  if (!wasAdj) return fireReadyTrigger("enter");
  // 贴脸时挂上的预备：邻接格之间挪一步也算「走进触发带」
  if (c.ready.awaitStep && prevPos && keyOf(prevPos) !== keyOf(c.enemyPos)) {
    return fireReadyTrigger("adjacent_step");
  }
  return false;
}

function fireReadyTrigger(reason = "enter") {
  const c = state.combat;
  if (!c?.ready) return false;
  const ready = c.ready;
  c.ready = null;
  const fx = ready.effect || {};
  const bits = [];

  labEvent("ready_trigger", {
    cardId: ready.cardId,
    name: ready.name,
    reason,
    shove: !!fx.shove,
  });

  if (fx.gainBlock) {
    c.block = (c.block || 0) + fx.gainBlock;
    bits.push(`格挡 +${fx.gainBlock}`);
  }
  if (fx.draw) {
    const n = combatDraw(fx.draw, `预备·${ready.name}`);
    if (n) bits.push(`抽 ${n}`);
  }
  if (fx.damage) {
    let dmg = fx.damage + relicValue("damageBonus");
    if (tileHeight(c.playerPos) > tileHeight(c.enemyPos)) dmg += 1;
    const dealt = dealToEnemy(dmg, "ready");
    bits.push(`造成 ${dealt} 伤`);
    if (adjacentTrapBonus(c, c.enemyPos)) {
      comboPop("夹击连击");
      drainToughness(1, "夹击连击削韧");
    }
  }
  if (fx.tough) {
    drainToughness(fx.tough, `预备·${ready.name}`);
    bits.push(`削韧 ${fx.tough}`);
  }
  if (fx.shove) {
    const hpBefore = c.enemy.hp;
    const toughBefore = c.toughness;
    const result = forceEnemyShove(`预备·${ready.name}`, {
      preferPortal: !!fx.preferPortal,
    });
    bits.push(result.moved ? "强制甩开" : "撞墙");
    // 保底结算：空地落点也要有伤/韧反馈（撞墙已在 forceEnemyShove 削韧）
    if (result.moved && !result.killed) {
      const landedTrap = c.floor[keyOf(c.enemyPos)]?.onStep?.damage;
      if (!landedTrap && c.enemy.hp >= hpBefore) {
        const dealt = dealToEnemy(1, "ready");
        if (dealt > 0) bits.push(`空地保底 ${dealt} 伤`);
      }
      if (c.toughness >= toughBefore && c.toughness > 0) {
        drainToughness(1, `预备·${ready.name}甩开削韧`);
        bits.push("甩开削韧 1");
      }
    }
    if (result.ported && fx.drawOnPortal) {
      const n = combatDraw(fx.drawOnPortal, "隧道连击");
      if (n) {
        bits.push(`抽 ${n}`);
        comboPop("隧道连击");
      }
    }
    log(`预备触发·${ready.name}${bits.length ? `：${bits.join("，")}` : ""}。`, "ok");
    comboPop(ready.name);
    if (state.flingSandbox?.active) state.flingSandbox.triggered = true;
    return true;
  }

  // 非甩开预备：若只有格挡也算有反馈；纯空触发不应发生
  if (!bits.length) {
    drainToughness(1, `预备·${ready.name}`);
    bits.push("保底削韧 1");
  }

  log(`预备触发·${ready.name}${bits.length ? `：${bits.join("，")}` : ""}。`, "ok");
  playTone("ok");
  comboPop(ready.name);
  if (state.flingSandbox?.active) state.flingSandbox.triggered = true;
  return true;
}

function resolveInstant(inst) {
  const c = state.combat;
  const def = cardDef(inst.id);
  if (def.shove) {
    resolveShove(inst);
    return;
  }
  if (def.climbToHigher) {
    resolveClimbToHigher(inst);
    return;
  }
  if (def.topple) {
    resolveTopple(inst);
    return;
  }
  if (def.puppetBang) {
    resolvePuppetBang(inst);
    return;
  }
  if (def.saltLash) {
    resolveSaltLash(inst);
    return;
  }
  const cost = Math.max(0, def.cost - c.discount);
  if (cost > c.energy) return;
  c.energy -= cost;
  c.discount = 0;
  c.hand = c.hand.filter((x) => x.uid !== inst.uid);
  if (c.heldUid === inst.uid) c.heldUid = null;
  if (c.placeUid === inst.uid) c.placeUid = null;

  if (def.discountNext) c.discount = def.discountNext;
  if (def.gainEnergy) c.energy += def.gainEnergy;
  if (def.gainBlock) c.block = (c.block || 0) + def.gainBlock;
  if (def.type === "ready") armReady(inst, def);
  if (def.grantRetain) {
    c.retainSlots = Math.max(c.retainSlots || 0, def.grantRetain);
    log(`获得「预案」：每回合结束可留 ${c.retainSlots} 张牌。`, "ok");
  }
  if (def.retainThisTurn) {
    c.retainThisTurn = (c.retainThisTurn || 0) + def.retainThisTurn;
    log(`本回合结束可留 ${c.retainThisTurn} 张牌。`, "ok");
  }
  if (def.selfDamage) {
    state.hp -= def.selfDamage;
    log(`反噬 ${def.selfDamage}`, "bad");
  }

  if (def.ifBlinded || def.elseBlind) {
    if (isEnemyBlinded(c) && def.ifBlinded) {
      const fx = def.ifBlinded;
      if (fx.damage) {
        let dmg = fx.damage + relicValue("damageBonus");
        if (c.blindArmed) {
          dmg += 2;
          c.blindArmed = false;
          comboPop("闪瞎连击");
        }
        const dealt = dealToEnemy(dmg, "skill");
        log(`${def.name}：造成 ${dealt} 伤。`, "ok");
      }
      if (fx.tough) drainToughness(fx.tough, def.name);
    } else if (def.elseBlind) {
      applyBlind(c, def.id, def.elseBlind);
    }
  }

  if (def.drainTough) {
    const wasBroken = !!c.broken;
    const broke = drainToughness(def.drainTough, def.name);
    if (!wasBroken && !broke && def.drainTough) {
      log(`${def.name}：削韧 ${def.drainTough}（剩余 ${c.toughness}）。`, "ok");
    }
    if (broke && def.drawOnBreak) {
      combatDraw(def.drawOnBreak, "破韧");
      comboPop("破韧");
    }
    if (wasBroken && def.discountIfBroken) {
      c.discount = Math.max(c.discount || 0, def.discountIfBroken);
      log(`已破韧：下一件放置 -${def.discountIfBroken}。`, "ok");
    }
  }

  // 保留牌打出后仍进弃牌；消耗/临时牌不进弃牌
  retireCard(inst);
  maybeFreeDraw(c, cost);
  playTone("ok");
  if (state.hp <= 0) {
    loseCombat();
    return;
  }
  if (c.enemy?.hp <= 0) {
    winCombat("kill");
    return;
  }
  c.intent = predictIntent(c);
  renderCombat();
}

function resolveTopple(inst) {
  const c = state.combat;
  const def = cardDef(inst.id);
  if (tileHeight(c.playerPos) <= tileHeight(c.enemyPos)) {
    log("击落需要站在更高处。", "bad");
    return false;
  }
  const cost = Math.max(0, def.cost - c.discount);
  if (cost > c.energy) return false;
  c.energy -= cost;
  c.discount = 0;
  c.hand = c.hand.filter((x) => x.uid !== inst.uid);
  if (c.heldUid === inst.uid) c.heldUid = null;
  if (c.placeUid === inst.uid) c.placeUid = null;
  retireCard(inst);
  maybeFreeDraw(c, cost);

  let dmg = 2 + relicValue("damageBonus");
  const dealt = dealToEnemy(dmg, "skill");
  drainToughness(1, "击落削韧");
  log(`击落：从高处砸下，造成 ${dealt} 伤。`, "ok");
  comboPop("高台砸击");
  playTone("ok");
  if (c.enemy.hp <= 0) {
    winCombat("kill");
    return true;
  }
  c.intent = predictIntent(c);
  renderCombat();
  return true;
}

function resolvePuppetBang(inst) {
  const c = state.combat;
  const def = cardDef(inst.id);
  if (!decoyAlive(c)) {
    log("场上没有纸影可引爆。", "bad");
    return false;
  }
  const cost = Math.max(0, def.cost - c.discount);
  if (cost > c.energy) return false;
  c.energy -= cost;
  c.discount = 0;
  c.hand = c.hand.filter((x) => x.uid !== inst.uid);
  if (c.heldUid === inst.uid) c.heldUid = null;
  if (c.placeUid === inst.uid) c.placeUid = null;
  retireCard(inst);
  maybeFreeDraw(c, cost);

  const fx = def.puppetBang || { damage: 3 };
  let dmg = (fx.damage || 3) + relicValue("damageBonus");
  if (c.chasingDecoy) {
    dmg += 1;
    comboPop("纸影连击");
  }
  const dealt = dealToEnemy(dmg, "skill");
  smashDecoy(c, "影爆");
  log(`影爆：纸影炸开，造成 ${dealt} 伤。`, "ok");
  playTone("ok");
  if (c.enemy.hp <= 0) {
    winCombat("kill");
    return true;
  }
  c.intent = predictIntent(c);
  renderCombat();
  return true;
}

function resolveSaltLash(inst) {
  const c = state.combat;
  const def = cardDef(inst.id);
  const under = c.floor[keyOf(c.enemyPos)];
  if (!under?.enterTax) {
    log("盐鞭需要敌人站在盐圈上。", "bad");
    return false;
  }
  const cost = Math.max(0, def.cost - c.discount);
  if (cost > c.energy) return false;
  c.energy -= cost;
  c.discount = 0;
  c.hand = c.hand.filter((x) => x.uid !== inst.uid);
  if (c.heldUid === inst.uid) c.heldUid = null;
  if (c.placeUid === inst.uid) c.placeUid = null;
  retireCard(inst);
  maybeFreeDraw(c, cost);

  const fx = def.saltLash || { damage: 2, tough: 1 };
  let dmg = (fx.damage || 2) + relicValue("damageBonus");
  const dealt = dealToEnemy(dmg, "skill");
  if (fx.tough) drainToughness(fx.tough, "盐鞭削韧");
  c.saltSteppedThisTurn = true;
  log(`盐鞭抽打：造成 ${dealt} 伤。`, "ok");
  comboPop("盐道连击");
  playTone("ok");
  if (c.enemy.hp <= 0) {
    winCombat("kill");
    return true;
  }
  c.intent = predictIntent(c);
  renderCombat();
  return true;
}

function tryMovePlayer(pos) {
  const c = state.combat;
  if (c.placeUid) return false;
  if (!isOrthoAdjacent(c.playerPos, pos)) {
    log("只能上下左右移动，不能斜向。", "bad");
    return false;
  }
  if (c.houseGraph && !hasDoorLink(c.playerPos, pos)) {
    log("这边没有门，穿不过去。", "bad");
    return false;
  }
  if (!isPassable(pos)) {
    log(isVoid(pos) ? "那是空洞，站不住。" : "遮挡物无法通过。", "bad");
    return false;
  }
  if (keyOf(pos) === keyOf(c.playerPos)) return false;
  const passTax = unitPassCost("player", pos);
  const cost = playerMoveCost(c.playerPos, pos);
  if (c.energy < cost) {
    if (passTax > 0) {
      log(`行动力不足（穿过敌人需 ${cost}，含敌对穿格 +${passTax}）。`, "bad");
    } else {
      log(`行动力不足（移动需 ${cost}，含攀爬）。`, "bad");
    }
    return false;
  }
  const wasSeen = hasLoS(c.enemyPos, c.playerPos);
  c.energy -= cost;
  c.playerPos = { ...pos };
  c.portalLanded = false;
  if (tryPortal("player", c.playerPos)) {
    /* teleported */
  }
  const h = tileHeight(c.playerPos);
  log(`你移到 (${c.playerPos.r + 1},${c.playerPos.c + 1})${h ? ` · 高${h}` : ""}（耗${cost}）。`);
  if (passTax > 0) log(`擦身而过，多耗 ${passTax} 行动力。`);
  playTone("ui");
  const vis = refreshVision();
  if (vis.faceReveal) {
    log(`转过遮挡——突脸！${c.enemy.name}就在视线里。`, "bad");
    playTone("bad");
    if (c.traits?.includes("faceShock")) {
      c.playerExposed = true;
      log("它盯上你了——贴身会被吓 1 下；够不着只喊。可先缩回遮挡。", "bad");
    }
  } else if (wasSeen && !vis.enemySees) {
    log("你缩进遮挡/高差后，暂时脱离目击。", "ok");
  }
  c.intent = predictIntent(c);
  renderCombat();
  return true;
}

function tryPlace(pos) {
  const c = state.combat;
  if (!c.placeUid) return false;
  if (!isOrthoAdjacent(c.playerPos, pos)) {
    log("只能放到上下左右邻格，不能斜向。", "bad");
    return false;
  }
  if (c.houseGraph && !hasDoorLink(c.playerPos, pos)) {
    log("只能放到有门通向的邻房。", "bad");
    return false;
  }
  if (!isPassable(pos) && keyOf(pos) !== keyOf(c.enemyPos)) {
    log(isVoid(pos) ? "不能放到空洞上。" : "不能放在遮挡物上。", "bad");
    return false;
  }
  if (keyOf(pos) === keyOf(c.playerPos)) {
    log("不能放在自己脚下。", "bad");
    return false;
  }
  const onEnemy = keyOf(pos) === keyOf(c.enemyPos);
  const onDecoy = decoyAlive(c) && keyOf(pos) === keyOf(c.decoy.pos);
  if (onEnemy && !hasLoS(c.playerPos, c.enemyPos)) {
    log("没有视线，砸不到转角后的敌人。", "bad");
    return false;
  }
  const k = keyOf(pos);
  const inst = c.hand.find((x) => x.uid === c.placeUid);
  if (!inst) return false;
  const def = cardDef(inst.id);
  const isDecoyCard = !!def.place?.decoy;

  if (isDecoyCard) {
    if (onEnemy) {
      log("傀儡不能砸在敌人身上，放到邻格。", "bad");
      return false;
    }
    if (c.floor[k]) {
      log("这里已有物品。", "bad");
      return false;
    }
  } else if (!onEnemy && c.floor[k]) {
    log("这里已有物品。", "bad");
    return false;
  } else if (!onEnemy && onDecoy) {
    log("傀儡占着这格。", "bad");
    return false;
  }

  const cost = Math.max(0, def.cost - c.discount);
  if (cost > c.energy) return false;

  c.energy -= cost;
  c.discount = 0;
  c.hand = c.hand.filter((x) => x.uid !== inst.uid);
  c.placeUid = null;
  if (c.heldUid === inst.uid) c.heldUid = null;
  retireCard(inst);
  maybeFreeDraw(c, cost);

  if (isDecoyCard) {
    c.decoy = { pos: { ...pos }, hp: 1 };
    log(`纸影傀儡立在 (${pos.r + 1},${pos.c + 1})——怪会优先追它，挨打才消失。`, "ok");
    labEvent("decoy_place", { pos: { ...pos } });
    playTone("ok");
  } else if (onEnemy && def.place?.onStep?.damage) {
    let dmg = def.place.onStep.damage + relicValue("damageBonus");
    const combos = [];
    if (tileHeight(c.playerPos) > tileHeight(c.enemyPos)) {
      const heightBonus = def.place.heightSmashExtra ?? 1;
      dmg += heightBonus;
      combos.push("高台砸击");
    }
    if (c.broken && def.place.smashBonusIfBroken) {
      dmg += def.place.smashBonusIfBroken;
      combos.push("破韧");
    }
    if (c.blindArmed) {
      dmg += 2;
      c.blindArmed = false;
      combos.push("闪瞎连击");
    }
    if (adjacentTrapBonus(c, c.enemyPos)) {
      dmg += 1;
      drainToughness(1, "夹击连击削韧");
      combos.push("夹击连击");
    }
    if (!c.firstSmashUsed && hasRelicEffect("firstSmashBonus")) {
      dmg += relicValue("firstSmashBonus");
      c.firstSmashUsed = true;
      log("预兆·火漆：首次砸击加伤。", "ok");
    } else {
      c.firstSmashUsed = true;
    }
    const smashTough = def.place.smashTough ?? 1;
    drainToughness(smashTough, smashTough > 1 ? "凿击削韧" : "砸击削韧");
    const dealt = dealToEnemy(dmg, "smash");
    log(`你把「${def.name}」砸向${c.enemy.name}，造成 ${dealt} 伤害。`, "ok");
    for (const name of combos) comboPop(name);
    playTone("ok");
    if (def.place.onStep.blind) {
      applyBlind(c, def.id || "flare", def.place.onStep.blindTurns || 1);
    }
    if (c.enemy.hp <= 0) {
      winCombat("kill");
      return true;
    }
  } else if (c.isBoss && c.anchors?.[k]?.lit) {
    // 放置牌砸在亮锚上：拆信号（牌仍落到地上）
    damageAnchorsInCells(c, [pos], 1, "place");
    if (!state.combat) return true;
    if (def.place?.gather) {
      applyGatherPlace(pos, inst, def);
    } else {
      c.floor[k] = {
        cardId: inst.id,
        ...def.place,
      };
    }
    log(`「${def.name}」砸上信号锚 (${pos.r + 1},${pos.c + 1})。`, "ok");
    playTone("ok");
  } else if (def.place?.gather) {
    applyGatherPlace(pos, inst, def);
    if (onEnemy) log(`「${def.name}」落到${c.enemy.name}脚下。`, "ok");
    playTone("ok");
  } else {
    c.floor[k] = {
      cardId: inst.id,
      ...def.place,
    };
    if (onEnemy) log(`「${def.name}」落到${c.enemy.name}脚下。`, "ok");
    else log(`放置「${def.name}」于 (${pos.r + 1},${pos.c + 1})。`, "ok");
    playTone("ok");
  }

  if (!state.combat) return true;
  refreshVision();
  c.intent = predictIntent(c);
  if (state.tutorial?.active && state.tutorial.step === "place") {
    const hasTrap = Object.values(c.floor || {}).some((f) => f?.onStep?.damage);
    if (hasTrap) state.tutorial.step = "intent";
  }
  renderCombat();
  return true;
}

function onTileClick(pos) {
  const c = state.combat;
  if (!c) return;
  if (c.placeUid) tryPlace(pos);
  else tryMovePlayer(pos);
}

/** 绊线：九宫格内收束伤害道具，合并为集束陷阱（有件数/伤害上限）。 */
function applyGatherPlace(pos, inst, def) {
  const c = state.combat;
  const k = keyOf(pos);
  const cfg = def.place.gather || {};
  const maxItems = cfg.maxItems ?? 2;
  const damageCap = cfg.damageCap ?? 5;
  const fallback = cfg.fallbackDamage ?? 1;
  const candidates = [];
  for (let dr = -1; dr <= 1; dr += 1) {
    for (let dc = -1; dc <= 1; dc += 1) {
      if (dr === 0 && dc === 0) continue;
      const p = { r: pos.r + dr, c: pos.c + dc };
      if (!inBounds(p) || isVoid(p)) continue;
      const fk = keyOf(p);
      const item = c.floor[fk];
      if (!item?.onStep?.damage) continue;
      candidates.push({
        key: fk,
        pos: p,
        item,
        damage: item.onStep.damage || 0,
        blind: !!item.onStep.blind,
      });
    }
  }
  candidates.sort((a, b) => b.damage - a.damage || a.key.localeCompare(b.key));
  const pulled = candidates.slice(0, maxItems);
  let sum = 0;
  let blind = false;
  const names = [];
  for (const entry of pulled) {
    sum += entry.damage;
    if (entry.blind) blind = true;
    names.push(cardDef(entry.item.cardId)?.name || "道具");
    delete c.floor[entry.key];
  }
  const onStep = {};
  if (pulled.length) {
    onStep.damage = Math.min(damageCap, sum);
    if (blind) onStep.blind = true;
    c.floor[k] = {
      cardId: inst.id,
      glyph: "束",
      gathered: true,
      onStep,
    };
    log(
      `绊线收束 ${pulled.length} 件（${names.join("、")}）→ 集束 ${onStep.damage} 伤${blind ? "·致盲" : ""}于 (${pos.r + 1},${pos.c + 1})。`,
      "ok"
    );
    comboPop("集束收束");
  } else {
    onStep.damage = fallback;
    c.floor[k] = {
      cardId: inst.id,
      glyph: def.place.glyph || "绊",
      onStep,
    };
    log(`放置「${def.name}」于 (${pos.r + 1},${pos.c + 1})——附近无可收束，留下 ${fallback} 伤绊索。`, "ok");
  }
}

function triggerFloor(pos, who) {
  const c = state.combat;
  const k = keyOf(pos);
  const item = c.floor[k];
  if (!item) return { tax: 0 };
  let tax = item.enterTax || 0;
  if (who === "enemy" && item.onStep?.forceStepTowardGoal) {
    // 旧版绊线：被迫多走一步（数据已改为收束，保留兼容）
    log(`${c.enemy.name}绊上「${cardDef(item.cardId).name}」。`, "ok");
    delete c.floor[k];
    playTone("ok");
    if (!c.snareForcedThisTurn) {
      c.snareForcedThisTurn = true;
      const goal = getEnemyGoal(c);
      if (goal) {
        const step = stepEnemyToward(goal);
        if (step && keyOf(step.p) !== keyOf(c.playerPos)) {
          const prev = { ...c.enemyPos };
          c.enemyPos = { ...step.p };
          c.enemyMovesThisTurn = (c.enemyMovesThisTurn || 0) + 1;
          log(`${c.enemy.name}被绊线拽向目标 (${step.p.r + 1},${step.p.c + 1})。`, "ok");
          c.portalLanded = false;
          checkReadyOnEnemyEnter(prev);
          if (!state.combat || c.enemy.hp <= 0) return { tax: 0 };
          const beforePortal = { ...c.enemyPos };
          if (tryPortal("enemy", c.enemyPos)) {
            checkReadyOnEnemyEnter(beforePortal);
            if (!state.combat || c.enemy.hp <= 0) return { tax: 0 };
          }
          triggerFloor(c.enemyPos, "enemy");
        }
      }
    }
  } else if (who === "enemy" && item.onStep?.damage) {
    let dmg = item.onStep.damage + relicValue("damageBonus");
    const combos = [];
    if ((c.enemyMovesThisTurn || 0) >= 1) {
      dmg += 1;
      combos.push("追击踩踏");
    }
    if (c.saltSteppedThisTurn) {
      dmg += 1;
      drainToughness(1, "盐道连击削韧");
      combos.push("盐道连击");
    }
    if (c.chasingDecoy || (decoyAlive(c) && getEnemyGoal(c) && keyOf(getEnemyGoal(c)) === keyOf(c.decoy.pos))) {
      dmg += 1;
      combos.push("纸影连击");
    }
    if (c.portalLanded) {
      combos.push("隧道连击");
      if (item.onStep.portalBonus) dmg += item.onStep.portalBonus;
    }
    const stepTough = item.onStep.tough;
    drainToughness(
      stepTough != null ? stepTough : 2,
      stepTough != null ? "凿钉陷阱削韧" : "陷阱削韧",
    );
    const dealt = dealToEnemy(dmg, "trap");
    log(`${c.enemy.name}踩上「${cardDef(item.cardId).name}」受到 ${dealt} 伤害。`, "ok");
    for (const name of combos) comboPop(name);
    if (item.onStep.blind) applyBlind(c, item.cardId || "flare", item.onStep.blindTurns || 1);
    delete c.floor[k];
    playTone("ok");
  } else if (who === "enemy" && item.enterTax) {
    log(`${c.enemy.name}踏入盐圈，多耗行动力。`);
    c.saltSteppedThisTurn = true;
    drainToughness(1, "盐圈削韧");
  }
  return { tax };
}

function coverBlockAtPlayer() {
  const c = state.combat;
  const item = c.floor[keyOf(c.playerPos)];
  return item?.coverBlock || 0;
}

function enemyEdgeCost(c, from, to) {
  const leaveTax = c.floor[keyOf(from)]?.enterTax || 0;
  const enterTax = c.floor[keyOf(to)]?.enterTax || 0;
  const climb = climbCost(from, to);
  let cost = 1 + leaveTax + enterTax + climb;
  if (c.traits?.includes("trapAware")) {
    const item = c.floor[keyOf(to)];
    if (item?.onStep?.damage) cost += 8;
    else if (item?.enterTax) cost += 2;
  }
  return cost;
}

/**
 * 朝目标走一步：Dijkstra 最短路首步（可绕墙），不踩玩家格。
 * 目标是玩家时，走到邻接格即视为抵达。
 */
function stepEnemyToward(goal, c = state.combat) {
  if (!c || !goal) return null;
  const vault = c.traits?.includes("vault");
  const playerKey = keyOf(c.playerPos);
  const goalKey = keyOf(goal);
  const targetPlayer = goalKey === playerKey;

  if (targetPlayer && manhattan(c.enemyPos, c.playerPos) <= 1) return null;
  if (!targetPlayer && keyOf(c.enemyPos) === goalKey) return null;

  const reached = (p) => (targetPlayer ? manhattan(p, c.playerPos) === 1 : keyOf(p) === goalKey);
  if (reached(c.enemyPos)) return null;

  const startKey = keyOf(c.enemyPos);
  const bestG = new Map([[startKey, 0]]);
  const prev = new Map();
  const pq = [{ p: { ...c.enemyPos }, g: 0 }];
  let guard = 200;
  let found = null;

  while (pq.length && guard-- > 0) {
    pq.sort((a, b) => a.g - b.g || (vault ? tileHeight(b.p) - tileHeight(a.p) : 0));
    const cur = pq.shift();
    const ck = keyOf(cur.p);
    if (cur.g !== bestG.get(ck)) continue;
    if (ck !== startKey && reached(cur.p)) {
      found = cur.p;
      break;
    }
    for (const n of neighbors(cur.p)) {
      const nk = keyOf(n);
      if (nk === playerKey) continue;
      const g2 = cur.g + enemyEdgeCost(c, cur.p, n);
      if (bestG.has(nk) && bestG.get(nk) <= g2) continue;
      bestG.set(nk, g2);
      prev.set(nk, { ...cur.p });
      pq.push({ p: { ...n }, g: g2 });
    }
  }

  if (!found) {
    // 无通路时退回邻格贪心，尽量靠近目标
    const opts = neighbors(c.enemyPos)
      .filter((p) => keyOf(p) !== playerKey)
      .map((p) => ({
        p,
        dist: manhattan(p, goal),
        cost: stepCostTo(c, p),
        height: tileHeight(p),
      }));
    if (!opts.length) return null;
    opts.sort((a, b) => a.dist - b.dist || (vault ? b.height - a.height : 0) || a.cost - b.cost);
    return opts[0];
  }

  let stepPos = found;
  let backGuard = 64;
  while (backGuard-- > 0) {
    const pr = prev.get(keyOf(stepPos));
    if (!pr) break;
    if (keyOf(pr) === startKey) {
      return {
        p: { ...stepPos },
        cost: stepCostTo(c, stepPos),
        climb: climbCost(c.enemyPos, stepPos),
        height: tileHeight(stepPos),
      };
    }
    stepPos = pr;
  }
  return null;
}

/** 朝目标免费迈一步（埋伏弹簧 / 抄近路），不耗行动力 */
function freeStepToward(c, goal, label) {
  const step = stepEnemyToward(goal);
  if (!step) return false;
  const prev = { ...c.enemyPos };
  c.enemyPos = { ...step.p };
  c.enemyMovesThisTurn = (c.enemyMovesThisTurn || 0) + 1;
  c.chasingDecoy = !!(decoyAlive(c) && goal && keyOf(goal) === keyOf(c.decoy.pos));
  const h = tileHeight(c.enemyPos);
  log(`${c.enemy.name}${label}至 (${step.p.r + 1},${step.p.c + 1})${h ? `高${h}` : ""}。`, "bad");
  resolveEnemyLandOverlap(c);
  c.portalLanded = false;
  checkReadyOnEnemyEnter(prev);
  if (!state.combat || c.enemy.hp <= 0) return true;
  const beforePortal = { ...c.enemyPos };
  if (tryPortal("enemy", c.enemyPos)) {
    checkReadyOnEnemyEnter(beforePortal);
    if (!state.combat || c.enemy.hp <= 0) return true;
  }
  triggerFloor(c.enemyPos, "enemy");
  return true;
}

function applyEnemyHit(c, kind, damageOverride = null) {
  let incoming = damageOverride != null ? damageOverride : c.enemy.damage;
  if (damageOverride == null && kind === "faceShock") incoming = Math.max(1, incoming);
  if (damageOverride == null && tileHeight(c.enemyPos) > tileHeight(c.playerPos)) incoming += 1;
  const raw = incoming;
  let blockedTotal = 0;

  const cover = coverBlockAtPlayer();
  const heightCover = tileHeight(c.playerPos) > tileHeight(c.enemyPos) ? 1 : 0;
  if (kind === "guardBreak") {
    log(`${c.enemy.name}破防一击——格挡与掩体被撕开！`, "bad");
    c.block = 0;
  } else {
    // 先吃地形/高差掩护，再扣卡牌格挡；格挡是池子，未被打光的可挡本回合后续命中
    let remain = incoming;
    const innate = cover + heightCover;
    const innUsed = Math.min(innate, remain);
    remain -= innUsed;
    const blockUsed = Math.min(c.block || 0, remain);
    remain -= blockUsed;
    c.block = Math.max(0, (c.block || 0) - blockUsed);
    blockedTotal = blockUsed + innUsed;
    incoming = remain;
    if (blockedTotal > 0) {
      log(
        `格挡/掩护抵消 ${blockedTotal}（预估 ${raw} → ${incoming}）。`,
        incoming > 0 ? "" : "ok",
      );
    }
  }

  if (incoming > 0) {
    state.hp -= incoming;
    labNoteDamageTaken(raw, blockedTotal, incoming, kind);
    const verb =
      kind === "lunge"
        ? "突进"
        : kind === "faceShock"
          ? "惊吓"
          : kind === "guardBreak"
            ? "破防"
            : kind === "slam"
              ? "砸地"
              : kind === "beam"
                ? "激光"
                : kind === "charge"
                  ? "蓄力冲击"
                  : "攻击";
    log(`${c.enemy.name}${verb}造成 ${incoming} 伤害。`, "bad");
    playTone("bad");
    if (c.traits?.includes("grab")) {
      const stolen = stealCard({ preferHand: true, allowAny: true });
      if (stolen) {
        const med = !!cardDef(stolen.id).stealable;
        log(
          med
            ? `搜刮：夺走了 ${cardDef(stolen.id).name}！`
            : `扯走了杂物：${cardDef(stolen.id).name}！`,
          "bad",
        );
      }
    }
  } else {
    labNoteDamageTaken(raw, blockedTotal || raw, 0, kind);
    log("格挡与掩护挡住了攻击。", "ok");
  }
  return state.hp <= 0;
}

function executeEnemyAttack(c, atk, hitKind) {
  if (atk.kind === "lunge" && atk.land) {
    const prev = { ...c.enemyPos };
    c.enemyPos = { ...atk.land.p };
    c.enemyMovesThisTurn += 1;
    log(`${c.enemy.name}突进贴近至 (${atk.land.p.r + 1},${atk.land.p.c + 1})。`, "bad");
    c.portalLanded = false;
    checkReadyOnEnemyEnter(prev);
    if (!state.combat) return "done";
    if (c.enemy.hp <= 0) return "win";
    const beforePortal = { ...c.enemyPos };
    if (tryPortal("enemy", c.enemyPos)) {
      checkReadyOnEnemyEnter(beforePortal);
      if (!state.combat) return "done";
      if (c.enemy.hp <= 0) return "win";
    }
    triggerFloor(c.enemyPos, "enemy");
    if (c.enemy.hp <= 0) return "win";
  }
  c.enemyStamina = Math.max(0, c.enemyStamina - atk.cost);

  // 砸地 AoE 可砸灭锚点（引怪自爆）
  if (atk.kind === "slam" && atk.cells) {
    damageAnchorsInCells(c, atk.cells, 2, "boss");
    if (!state.combat) return "done";
  }

  // 按威胁区结算：玩家须仍在 hurt cells 内（与预警同源）
  const cells = atk.cells || [{ ...c.playerPos }];
  if (!cellsContain(cells, c.playerPos)) {
    log(`${c.enemy.name}的攻击落空——你已不在威胁区内。`, "ok");
    return "ok";
  }
  if (applyEnemyHit(c, hitKind || atk.kind)) return "lose";
  return "ok";
}

function enemyTurn() {
  const c = state.combat;
  c.enemyMovesThisTurn = 0;
  c.saltSteppedThisTurn = false;
  c.snareForcedThisTurn = false;
  c.hitsUsed = 0;

  if (c.isBoss) drawBossDirective(c);

  // 蓄力必落：上一回合蓄的大招本回合结算，然后收工（大招即本回合主事件）
  if (c.isBoss && c.chargePending) {
    const landed = resolveBossCharge(c);
    if (landed === "lose") {
      loseCombat("hp");
      return;
    }
    if (landed === "done" || !state.combat) return;
    if (tickBroadcast(c) || !state.combat) return;
    const endVis = refreshVision();
    if (!endVis.enemySees) {
      c.lastSeenAge = (c.lastSeenAge || 0) + 1;
      if (c.lastSeen && c.lastSeenAge >= LAST_SEEN_MEMORY_TURNS) {
        c.lastSeen = null;
        log(`${c.enemy.name}在遮挡后失去了你的踪迹。`, "ok");
      }
    } else {
      c.lastSeenAge = 0;
    }
    tickBlind(c);
    return;
  }
  if (c.isBoss && shouldBossCharge(c)) {
    beginBossCharge(c);
    // 蓄力回合：不动不出手，红格已预告
    if (tickBroadcast(c) || !state.combat) return;
    tickBlind(c);
    return;
  }

  // 回合开始时若没有视线（含致盲）：本回合最多打 1 下，不给连击清算
  const sawAtStart = hasLoS(c.enemyPos, c.playerPos) && !isEnemyBlinded(c);
  if (isEnemyBlinded(c)) {
    log(`${c.enemy.name}被闪光晃花了眼，这一回合盯不稳你。`, "ok");
  }
  const planned = predictIntent(c);
  c.hitBudget = Math.max(1, planned?.hits || 1);
  if (!sawAtStart) c.hitBudget = 1;
  if ((c.flingGraceTurns || 0) > 0) {
    c.flingGraceTurns -= 1;
    c.hitBudget = 0;
    log("沙盒布景拍：它这一拍只靠近、不下手。", "ok");
  } else if ((c.setupGraceTurns || 0) > 0) {
    c.setupGraceTurns -= 1;
    c.hitBudget = 0;
    log("布景窗：它这一拍只靠近、不下手。", "ok");
  }
  // 导播特写：必须先移动才能出手
  const needMoveFirst = c.isBoss && c.directive?.id === "closeup";

  let guard = 16;
  while (c.enemyStamina > 0 && guard-- > 0) {
    const vis = refreshVision();
    let goal = getEnemyGoal(c);
    c.chasingDecoy = !!(decoyAlive(c) && goal && keyOf(goal) === keyOf(c.decoy.pos));

    // 邻接傀儡：优先撕碎
    if (c.chasingDecoy && manhattan(c.enemyPos, c.decoy.pos) <= 1) {
      const cost = effectiveAttackCost(c);
      if (c.enemyStamina >= cost) {
        c.enemyStamina -= cost;
        smashDecoy(c, "撕碎了");
        continue;
      }
    }

    // 埋伏弹簧：揭开当回合免费扑一步
    if (c.ambushSpring && (vis.enemySees || c.chasingDecoy)) {
      c.ambushSpring = false;
      freeStepToward(c, goal || c.playerPos, "埋伏扑出");
      if (c.enemy.hp <= 0) {
        winCombat("kill");
        return;
      }
    }

    const canAttackNow = !needMoveFirst || c.enemyMovesThisTurn > 0;

    const selfExposed = c.playerExposed && vis.enemySees && !vis.faceReveal;
    c.playerExposed = false;
    if (canAttackNow && !c.chasingDecoy && c.hitsUsed < c.hitBudget && (vis.faceReveal || selfExposed)) {
      if (selfExposed) log(`${c.enemy.name}早就盯着你暴露的位置——惊吓扑面而来！`, "bad");
      else log(`突脸！${c.enemy.name}拐过遮挡看见了你。`, "bad");
      playTone("face");

      if (c.traits?.includes("cornerCut") && vis.enemySees) {
        freeStepToward(c, c.playerPos, "抄近路");
        if (c.enemy.hp <= 0) {
          winCombat("kill");
          return;
        }
      }

      if (c.traits?.includes("faceShock")) {
        const dist = manhattan(c.enemyPos, c.playerPos);
        if (dist <= 1) {
          const died = applyEnemyHit(c, "faceShock", 1);
          c.hitsUsed += 1;
          if (died) {
            loseCombat("hp");
            return;
          }
          break;
        }
        log(`${c.enemy.name}吓了你一跳，但这一下够不着。`, "ok");
        c.hitsUsed += 1;
        break;
      }
    }

    // vault：仅当攀爬不拉远与目标的距离时才优先上高台（打过以后不再挪）
    if (!c.chasingDecoy && c.hitsUsed === 0 && c.traits?.includes("vault") && vis.enemySees) {
      const climbOpts = neighbors(c.enemyPos)
        .filter((p) => keyOf(p) !== keyOf(c.playerPos) && climbCost(c.enemyPos, p) > 0)
        .map((p) => ({ p, cost: stepCostTo(c, p), height: tileHeight(p) }))
        .filter((o) => o.cost <= c.enemyStamina)
        .sort((a, b) => b.height - a.height || a.cost - b.cost);
      const best = climbOpts[0];
      if (best && best.height > tileHeight(c.enemyPos)) {
        const goalPos = goal || c.playerPos;
        const afterDist = manhattan(best.p, goalPos);
        const nowDist = manhattan(c.enemyPos, goalPos);
        if (afterDist <= nowDist) {
          c.enemyStamina -= best.cost;
          c.enemyMovesThisTurn += 1;
          const prev = { ...c.enemyPos };
          c.enemyPos = { ...best.p };
          log(
            `${c.enemy.name}攀上高台 (${best.p.r + 1},${best.p.c + 1})高${best.height}（耗${best.cost}）。`,
            "bad",
          );
          resolveEnemyLandOverlap(c);
          c.portalLanded = false;
          checkReadyOnEnemyEnter(prev);
          if (!state.combat) return;
          if (c.enemy.hp <= 0) {
            winCombat("kill");
            return;
          }
          const beforePortal = { ...c.enemyPos };
          if (tryPortal("enemy", c.enemyPos)) {
            checkReadyOnEnemyEnter(beforePortal);
            if (!state.combat) return;
            if (c.enemy.hp <= 0) {
              winCombat("kill");
              return;
            }
          }
          triggerFloor(c.enemyPos, "enemy");
          if (c.enemy.hp <= 0) {
            winCombat("kill");
            return;
          }
          if (!state.combat) return;
          continue;
        }
      }
    }

    if (canAttackNow && !c.chasingDecoy && c.hitsUsed < c.hitBudget) {
      const dist = manhattan(c.enemyPos, c.playerPos);
      const atk = canEnemyAttack(c, dist, vis.enemySees);
      if (atk.ok) {
        const result = executeEnemyAttack(c, atk, atk.kind);
        c.hitsUsed += 1;
        if (result === "win") {
          winCombat("kill");
          return;
        }
        if (result === "done" || !state.combat) return;
        if (result === "lose") {
          loseCombat("hp");
          return;
        }
        // 出手后只尝试连击；刀数用尽则收工。绝不再用剩行动力走路（贴脸挪开会像后退）
        if (c.hitsUsed < c.hitBudget) continue;
        break;
      }
    }

    if (c.ambushActive && !vis.enemySees && !c.chasingDecoy) {
      c.ambushIdleTurns = (c.ambushIdleTurns || 0) + 1;
      // 埋伏最多蹲 1 拍；再藏就下架巡逻——不能让玩家无限躲
      if (c.ambushIdleTurns <= 1) {
        log(`${c.enemy.name}仍藏在出生点窥探……`);
        break;
      }
      c.ambushActive = false;
      ensurePatrolGoal(c);
      goal = getEnemyGoal(c);
      log(`${c.enemy.name}等不及了，离开埋伏点开始巡逻。`, "bad");
    }
    if (!goal) {
      log(`${c.enemy.name}还不知道往哪走。`);
      break;
    }
    // 本回合已经打过：不再追步（连击打不满时也不要把剩行动力走成“后退”）
    if (c.hitsUsed > 0) break;
    const step = stepEnemyToward(goal);
    if (!step || step.cost > c.enemyStamina) {
      // 巡逻点不可达时换点再试
      if (!vis.enemySees && !c.lastSeen) {
        c.patrolGoal = null;
        const again = ensurePatrolGoal(c);
        const retry = again && stepEnemyToward(again);
        if (retry && retry.cost <= c.enemyStamina) {
          c.enemyStamina -= retry.cost;
          c.enemyMovesThisTurn += 1;
          const prev = { ...c.enemyPos };
          c.enemyPos = { ...retry.p };
          log(`${c.enemy.name}巡逻至 (${retry.p.r + 1},${retry.p.c + 1})（耗${retry.cost}）。`);
          resolveEnemyLandOverlap(c);
          c.portalLanded = false;
          checkReadyOnEnemyEnter(prev);
          if (!state.combat) return;
          if (c.enemy.hp <= 0) {
            winCombat("kill");
            return;
          }
          continue;
        }
      }
      log(`${c.enemy.name}在遮挡后停住了。`);
      break;
    }
    c.enemyStamina -= step.cost;
    c.enemyMovesThisTurn += 1;
    const prev = { ...c.enemyPos };
    c.enemyPos = { ...step.p };
    const h = tileHeight(c.enemyPos);
    const verb = c.chasingDecoy
      ? "追影"
      : c.directive?.id === "spotlight"
        ? "奔锚"
        : vis.enemySees
          ? "追击"
          : c.lastSeen
            ? "搜索"
            : "巡逻";
    log(
      `${c.enemy.name}${verb}至 (${step.p.r + 1},${step.p.c + 1})${h ? `高${h}` : ""}（耗${step.cost}）。`,
    );
    resolveEnemyLandOverlap(c);
    c.portalLanded = false;
    checkReadyOnEnemyEnter(prev);
    if (!state.combat) return;
    if (c.enemy.hp <= 0) {
      winCombat("kill");
      return;
    }
    const beforePortal = { ...c.enemyPos };
    if (tryPortal("enemy", c.enemyPos)) {
      checkReadyOnEnemyEnter(beforePortal);
      if (!state.combat) return;
      if (c.enemy.hp <= 0) {
        winCombat("kill");
        return;
      }
    }
    triggerFloor(c.enemyPos, "enemy");
    if (c.enemy.hp <= 0) {
      winCombat("kill");
      return;
    }
    if (!state.combat) return;
  }

  if (c.isBoss) {
    if (tickBroadcast(c) || !state.combat) return;
  }

  const endVis = refreshVision();
  // 丢视线后气味会散：连续若干敌回合找不到，才忘掉 lastSeen，改去偏向玩家的搜查
  if (!endVis.enemySees) {
    c.lastSeenAge = (c.lastSeenAge || 0) + 1;
    if (c.lastSeen && c.lastSeenAge >= LAST_SEEN_MEMORY_TURNS) {
      c.lastSeen = null;
      ensurePatrolGoal(c);
      log(`${c.enemy.name}在遮挡后失去了你的踪迹，开始在场地里搜查。`, "ok");
    }
  } else {
    c.lastSeenAge = 0;
  }
  tickBlind(c);
}

function renderBossRitualHud(c) {
  const wrap = $("boss-ritual-hud");
  if (!wrap) return;
  if (!c.isBoss) {
    wrap.classList.add("hidden");
    return;
  }
  wrap.classList.remove("hidden");
  const phase = $("boss-phase-chip");
  if (phase) phase.textContent = c.phaseName || "开场";
  const dir = $("program-directive");
  if (dir) {
    dir.textContent = c.directive ? `指令·${c.directive.label}` : "等待导播…";
    dir.title = c.directive?.desc || "";
  }
  const bar = $("broadcast-fill");
  const label = $("broadcast-label");
  const max = Math.max(1, c.broadcastMax || 12);
  const val = c.broadcast || 0;
  if (bar) {
    bar.style.width = `${Math.round((val / max) * 100)}%`;
    bar.classList.toggle("hot", val >= max - 2);
  }
  if (label) label.textContent = `播出 ${val}/${max}`;
  const btn = $("btn-dismantle");
  if (btn) {
    const onAnchor = !!c.anchors?.[keyOf(c.playerPos)]?.lit;
    const cost = bossFightCfg().dismantleCost || 2;
    btn.classList.toggle("hidden", !onAnchor);
    btn.disabled = !onAnchor || c.energy < cost;
    btn.textContent = `拆信号（${cost}）`;
  }
}

function toggleHold(uid) {
  const c = state.combat;
  if (retainBudget(c) <= 0) {
    log("需要先打出「预案」或「夹带」才能留牌。", "bad");
    return;
  }
  const inst = c.hand.find((x) => x.uid === uid);
  if (inst && cardDef(inst.id).retain) return;
  c.heldUid = c.heldUid === uid ? null : uid;
  renderCombat();
}

function renderCombat() {
  const c = state.combat;
  if (!c) return;
  refreshVision();
  $("combat-title").textContent = c.isBoss
    ? `${c.enemy.name}`
    : `${c.enemy.name}`;
  $("card-check-label").textContent = c.isBoss
    ? `${c.roomName} · ${c.phaseName || "开场"} · 锚 ${anchorsClearedCount(c)}/${Object.keys(c.anchors || {}).length}`
    : `${c.roomName} · ${c.archetypeLabel} · 难度档 ${c.tier}`;
  $("card-energy").textContent = String(c.energy);
  const energyEl = $("card-energy");
  if (energyEl) {
    energyEl.classList.toggle("is-zero", c.energy <= 0);
    energyEl.classList.toggle("is-low", c.energy > 0 && c.energy <= 2);
  }
  const speedEl = $("player-speed");
  if (speedEl) speedEl.textContent = `S${state.speed}`;
  const energyPreview = $("energy-preview");
  if (energyPreview) {
    energyPreview.textContent = "待机";
    energyPreview.className = "ticket-sub ticket-preview";
  }
  $("enemy-stamina").textContent = `${c.enemyStamina}/${c.staminaMax}`;
  const stamEl = $("enemy-stamina");
  if (stamEl) {
    stamEl.classList.toggle("is-zero", c.enemyStamina <= 0);
    stamEl.classList.toggle("is-low", c.enemyStamina > 0 && c.enemyStamina <= 1);
  }
  const intentLabel = c.intent?.label || "观望";
  $("enemy-intent").textContent = intentLabel;
  const intentShort = $("enemy-intent-short");
  if (intentShort) {
    intentShort.textContent = intentLabel.length > 4 ? `${intentLabel.slice(0, 3)}…` : intentLabel;
    intentShort.title = c.intent?.detail || intentLabel;
  }
  $("enemy-intent").className = `intent-banner intent-banner-wide intent-${c.intent?.type || "chase"}${c.intent?.pending ? " pending" : ""}`;
  $("enemy-intent").title = c.intent?.detail || c.intent?.label || "";
  $("enemy-hp").textContent = c.playerSeesEnemy ? String(c.enemy.hp) : "??";
  $("player-block").textContent = String(c.block + coverBlockAtPlayer());
  const readyEl = $("player-ready");
  if (readyEl) {
    readyEl.textContent = c.ready ? c.ready.name : "—";
    const stale = !!(c.ready && c.ready.awaitStep);
    const live = !!(c.ready && !c.ready.awaitStep);
    readyEl.classList.toggle("is-armed", live);
    readyEl.classList.toggle("is-stale", stale);
    const chip = readyEl.closest(".stat-ready");
    chip?.classList.toggle("is-armed", live);
    chip?.classList.toggle("is-stale", stale);
  }
  $("player-hp").textContent = `${state.hp}/${state.maxHp}`;
  renderTraitChips(c);
  renderBossRitualHud(c);

  const toughEl = $("kite-meter");
  const fill = $("tough-fill");
  const t = c.toughness;
  const tm = Math.max(1, c.toughnessMax || 1);
  const buff = [
    c.executeReady ? "处决" : "",
    c.crushReady ? "破甲" : "",
    c.staggerNext ? "踉跄" : "",
  ]
    .filter(Boolean)
    .join(" · ");
  if (toughEl) {
    toughEl.textContent = t <= 0 ? `已破${buff ? ` · ${buff}` : ""}` : `${t}/${tm}${buff ? ` · ${buff}` : ""}`;
    toughEl.title = `${c.archetypeDesc}\n${(c.traits || []).join(", ")}`;
  }
  if (fill) {
    const pct = t <= 0 ? 100 : Math.round((t / tm) * 100);
    fill.style.width = `${pct}%`;
    fill.classList.toggle("broken", t <= 0);
  }

  const diceBox = $("energy-dice");
  diceBox.innerHTML = "";
  for (const n of c.rolls) {
    const pip = document.createElement("div");
    pip.className = "pip";
    pip.textContent = n;
    diceBox.appendChild(pip);
  }

  renderBattleGrid();

  const hint = $("place-hint");
  const cardHint = $("card-hint");
  const hintMove = $("hint-move");
  const hintSearch = $("hint-search");
  const hintDiscard = $("hint-discard");
  if (hintMove) hintMove.className = `action-hint-chip${c.energy > 0 ? " is-on" : ""}`;
  if (hintSearch) hintSearch.className = `action-hint-chip${!c.playerSeesEnemy ? " is-hot" : ""}`;
  if (hintDiscard) hintDiscard.className = `action-hint-chip${(c.hand?.length || 0) >= 4 ? " is-on" : ""}`;
  if (c.placeUid) {
    const inst = c.hand.find((x) => x.uid === c.placeUid);
    const def = inst ? cardDef(inst.id) : null;
    const cost = def ? Math.max(0, def.cost - c.discount) : 0;
    const msg = inst
      ? `放置「${cardDef(inst.id).name}」：点高亮邻格放下；有视线可点敌人砸击`
      : "";
    hint.textContent = msg;
    if (cardHint) cardHint.textContent = "放置模式";
    if (energyPreview) {
      const remain = Math.max(0, c.energy - cost);
      energyPreview.textContent = `消耗 ${cost} → 余 ${remain}`;
      energyPreview.className = `ticket-sub ticket-preview ${remain <= 1 ? "warn" : "ok"}`;
    }
    if (hintMove) hintMove.className = "action-hint-chip is-hot";
    $("btn-cancel-place").classList.remove("hidden");
  } else {
    hint.textContent = c.isBoss
      ? "金格「烛」=信号锚 · 站上点拆信号 · 实线红=必伤/蓄力"
      : c.ready
        ? c.ready.awaitStep
          ? `预备·${c.ready.name}未生效：橙虚线=贴脸挂上——它在邻格挪一步才触发（站桩砍不会触发）`
          : c.ready.effect?.shove
            ? `预备·${c.ready.name}：绿虚线十字=触发带，走进来会被甩`
            : `预备·${c.ready.name}：绿虚线十字=触发带，走进来才结算`
        : "实线红=必伤 · 虚线红=预告 · 蓝=它走";
    if (cardHint) cardHint.textContent = c.archetypeDesc;
    if (energyPreview) {
      if (c.energy <= 1) {
        energyPreview.textContent = "建议：先保留 1 点走位";
        energyPreview.className = "ticket-sub ticket-preview warn";
      } else {
        energyPreview.textContent = "可先移动再出牌";
        energyPreview.className = "ticket-sub ticket-preview ok";
      }
    }
    $("btn-cancel-place").classList.add("hidden");
  }

  const hand = $("hand-cards");
  hand.innerHTML = "";
  for (const inst of c.hand) {
    const def = cardDef(inst.id);
    const cost = Math.max(0, def.cost - c.discount);
    const wrap = document.createElement("div");
    wrap.className =
      "card-wrap" +
      (c.placeUid === inst.uid ? " placing" : "") +
      (c.heldUid === inst.uid ? " holding" : "");

    const btn = document.createElement("button");
    btn.className = `card ${cardFrameClass(def.type)}`;
    btn.innerHTML = `<div class="cost">${cost}</div><strong>${def.name}</strong>${cardKindHtml(def.type)}<span>${def.text}</span>`;
    btn.disabled = cost > c.energy;
    btn.onclick = () => selectCard(inst.uid);
    bindHoverTip(btn, cardTooltipHtml(def));
    wrap.appendChild(btn);

    // 留牌按钮仅在打出「预案/夹带」后出现（尖塔：留牌是能力，不是免费操作）
    if (retainBudget(c) > 0 && !def.retain) {
      const hold = document.createElement("button");
      hold.type = "button";
      hold.className = "card-hold" + (c.heldUid === inst.uid ? " on" : "");
      hold.textContent = c.heldUid === inst.uid ? "已留" : "留";
      hold.onclick = (e) => {
        e.stopPropagation();
        toggleHold(inst.uid);
      };
      wrap.appendChild(hold);
    }
    if (def.retain) {
      const tag = document.createElement("div");
      tag.className = "card-retain-tag";
      tag.textContent = "保留";
      wrap.appendChild(tag);
    }
    if (def.exhaust || def.temp) {
      const tag = document.createElement("div");
      tag.className = "card-exhaust-tag";
      tag.textContent = "消耗";
      wrap.appendChild(tag);
    }
    hand.appendChild(wrap);
  }
}

/**
 * Boss 山屋决战 UI：和大地图同一套节点+连线，空洞不画格（露出底图）。
 * 按房间包围盒 + 固定格宽绘制，优先把格子做大，而不是撑满空画布。
 */
function renderHouseGraphBattle() {
  const c = state.combat;
  const g = combatGrid();
  const frame = battleHouseFrame();
  const CELL = 96;
  const GAP = 10;
  const wrap = $("battle-grid")?.parentElement;
  if (wrap) wrap.classList.add("house-battle-wrap");
  const box = $("battle-grid");
  box.className = "battle-grid house-graph-map";
  box.style.gridTemplateColumns = `repeat(${frame.cols}, ${CELL}px)`;
  box.style.gridTemplateRows = `repeat(${frame.rows}, ${CELL}px)`;
  box.style.width = `${frame.cols * CELL + Math.max(0, frame.cols - 1) * GAP}px`;
  box.style.height = `${frame.rows * CELL + Math.max(0, frame.rows - 1) * GAP}px`;
  box.style.gap = `${GAP}px`;
  box.innerHTML = "";

  const linksSvg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  linksSvg.classList.add("battle-map-links");
  linksSvg.setAttribute("aria-hidden", "true");
  linksSvg.setAttribute("viewBox", `${frame.col0} ${frame.row0} ${frame.cols} ${frame.rows}`);
  linksSvg.setAttribute("preserveAspectRatio", "none");
  box.appendChild(linksSvg);

  const sees = c.playerSeesEnemy;
  c.intent = predictIntent(c);
  const threats = threatMapFromIntent(c.intent);

  if (c.links) {
    const drawn = new Set();
    for (const edge of c.links) {
      if (drawn.has(edge)) continue;
      drawn.add(edge);
      const [a, b] = edge.split("|");
      const pa = parseKey(a);
      const pb = parseKey(b);
      const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
      line.setAttribute("x1", String(pa.c + 0.5));
      line.setAttribute("y1", String(pa.r + 0.5));
      line.setAttribute("x2", String(pb.c + 0.5));
      line.setAttribute("y2", String(pb.r + 0.5));
      const live =
        keyOf(c.playerPos) === a ||
        keyOf(c.playerPos) === b;
      line.setAttribute("class", live ? "map-link map-link-live" : "map-link");
      linksSvg.appendChild(line);
    }
  }

  for (let r = 0; r < g.rows; r += 1) {
    for (let cidx = 0; cidx < g.cols; cidx += 1) {
      const pos = { r, c: cidx };
      const k = keyOf(pos);
      if (isVoid(pos)) continue;

      const cell = document.createElement("button");
      cell.type = "button";
      cell.className = "battle-cell map-node-battle";
      cell.style.gridColumn = String(cidx - frame.col0 + 1);
      cell.style.gridRow = String(r - frame.row0 + 1);

      const h = tileHeight(pos);
      const isP = keyOf(c.playerPos) === k;
      const isE = keyOf(c.enemyPos) === k;
      const item = c.floor[k];
      const roomId = c.roomAt?.[k];
      const roomName = roomId ? roomDef(roomId)?.name || roomId : `格${r + 1},${cidx + 1}`;
      const adjP = canStepBetween(pos, c.playerPos) && isPassable(pos) && !isP;
      const threat = threats.get(k);
      const anchor = c.anchors?.[k];
      const isDecoy = decoyAlive(c) && keyOf(c.decoy.pos) === k;

      if (h === 1) cell.classList.add("h1");
      if (h >= 2) cell.classList.add("h2");
      if (isP) cell.classList.add("has-player", "current");
      if (isE && sees) cell.classList.add("has-enemy");
      if (isE && !sees) cell.classList.add("enemy-fog");
      if (item) cell.classList.add("has-item");
      if (c.portals?.[k]) cell.classList.add("is-portal");
      if (isDecoy) cell.classList.add("has-decoy");
      if (c.lastSeen && keyOf(c.lastSeen) === k && !sees) cell.classList.add("last-seen");
      if (anchor?.lit) cell.classList.add("anchor-lit");
      else if (anchor && !anchor.lit) cell.classList.add("anchor-dead");
      if (adjP) cell.classList.add("reachable");

      if (threat?.kind === "hurt") {
        cell.classList.add("threat-hurt");
        if (threat.attackKind === "charge") cell.classList.add("threat-charge");
        if (threat.pending) cell.classList.add("pending-hurt");
        if (isP) cell.classList.add("threat-on-you");
        paintFlurryCue(cell, threat);
      } else if (threat?.kind === "move") {
        cell.classList.add("threat-move");
      }
      paintReadyZoneCue(cell, c, adjP, isP);

      const canPlaceEnemy = isE && sees && hasLoS(c.playerPos, c.enemyPos);
      const placingDecoy =
        c.placeUid && cardDef(c.hand.find((x) => x.uid === c.placeUid)?.id || "")?.place?.decoy;
      if (
        c.placeUid &&
        adjP &&
        ((isE && canPlaceEnemy && !placingDecoy) || (!isE && !item && (!isDecoy || placingDecoy)))
      ) {
        cell.classList.add("place-ok");
      }
      if (c.placeUid && adjP && canPlaceEnemy) cell.classList.add("place-enemy");
      if (!c.placeUid && adjP && threat?.kind !== "hurt") {
        const moveCost = playerMoveCost(c.playerPos, pos);
        if (c.energy >= moveCost) {
          cell.classList.add("move-ok");
          if (isE) cell.classList.add("move-hostile");
        }
      }

      for (const [d, dc, dr] of [
        ["n", 0, -1],
        ["s", 0, 1],
        ["e", 1, 0],
        ["w", -1, 0],
      ]) {
        const nb = { r: r + dr, c: cidx + dc };
        if (!hasDoorLink(pos, nb)) continue;
        const notch = document.createElement("span");
        notch.className = `map-door map-door-${d}`;
        if (isP || (adjP && keyOf(nb) === keyOf(c.playerPos))) notch.classList.add("is-live");
        cell.appendChild(notch);
      }

      const label = document.createElement("span");
      label.className = "map-node-label";
      label.textContent = isP ? "" : roomName;
      if (!isP) cell.appendChild(label);

      if (anchor?.lit) {
        const candle = document.createElement("span");
        candle.className = "cell-glyph glyph-anchor";
        candle.textContent = "烛";
        candle.title = `信号锚 · 耐久 ${anchor.hp} · 站上点「拆信号」`;
        cell.appendChild(candle);
      } else if (anchor && !anchor.lit) {
        const ash = document.createElement("span");
        ash.className = "cell-glyph glyph-anchor-dead";
        ash.textContent = "灰";
        cell.appendChild(ash);
      }

      const bits = [];
      if (c.portals?.[k]) bits.push("门");
      if (anchor?.lit) bits.push(`信号${anchor.hp}`);
      else if (anchor && !anchor.lit) bits.push("已熄");
      if (item) bits.push(item.glyph || "物");
      if (isDecoy) bits.push("影");
      if (h) bits.push(`↑${h}`);

      let pawnHtml = "";
      if (isP) {
        pawnHtml =
          `<span class="map-pawn battle-pawn player-pawn"><img class="char-token map-token" src="assets/ui/chars/SP_Lili_MapToken.png" alt="你" width="36" height="36" draggable="false" /></span>`;
      }
      if (isE && sees) {
        pawnHtml +=
          `<span class="battle-pawn enemy-pawn"><img class="char-token" src="assets/ui/chars/SP_Enemy_Pixel.png" alt="敌" width="28" height="28" draggable="false" /></span>`;
      } else if (isE && !sees) {
        pawnHtml += `<span class="battle-pawn fog-pawn" aria-label="未知">?</span>`;
      }
      if (isDecoy) pawnHtml += `<span class="battle-pawn decoy-pawn" aria-label="纸影">影</span>`;

      const shots = threat?.hits > 1 ? `${threat.damage}×${threat.hits}` : `${threat?.damage}`;
      const dmgHtml =
        threat?.kind === "hurt" && threat.damage
          ? `<span class="threat-dmg${threat.pending ? " pending" : ""}">${
              threat.net !== threat.total ? `${shots}→${threat.net}` : shots
            }</span>`
          : "";
      const meta = bits.length ? `<span class="cell-meta">${bits.join(" ")}</span>` : "";
      const body = document.createElement("span");
      body.className = "map-battle-body";
      body.innerHTML = `${dmgHtml}${pawnHtml}${meta}`;
      cell.appendChild(body);

      cell.title = [
        roomName,
        "山屋格 · 沿门移动",
        h ? `高度 ${h}` : null,
        c.portals?.[k] ? "传送门" : null,
        anchor?.lit ? `信号锚（亮 · 耐久 ${anchor.hp} · 站上点「拆信号」/砸牌）` : null,
        anchor && !anchor.lit ? "信号锚（已熄）" : null,
        isP ? "你在这里" : null,
        isE && sees ? c.enemy.name : null,
        adjP && !c.placeUid ? "可移动" : null,
      ]
        .filter(Boolean)
        .join(" · ");
      cell.onclick = () => onTileClick(pos);
      box.appendChild(cell);
    }
  }

  syncBattleIntentBanner();
  if (state.tutorial?.active) updateBattleTutorialCoach();
}

function syncBattleIntentBanner() {
  const c = state.combat;
  const banner = $("enemy-intent");
  if (!banner || !c) return;
  const label = c.intent?.label || "观望";
  banner.textContent = label;
  banner.className = `intent-banner intent-banner-wide intent-${c.intent?.type || "chase"}${c.intent?.pending ? " pending" : ""}`;
  banner.title = c.intent?.detail || "";
  const intentShort = $("enemy-intent-short");
  if (intentShort) {
    intentShort.textContent = label.length > 4 ? `${label.slice(0, 3)}…` : label;
    intentShort.title = c.intent?.detail || label;
  }
}

/** 预备触发带图形：绿=可触发，橙斜纹=贴脸挂上需挪步 */
function paintReadyZoneCue(cell, c, adjP, isP) {
  if (!c?.ready || !adjP || isP) return;
  const stale = !!c.ready.awaitStep;
  cell.classList.add(stale ? "ready-zone-stale" : "ready-zone");
  const g = document.createElement("span");
  g.className = `cell-glyph ${stale ? "glyph-ready-stale" : "glyph-ready"}`;
  g.setAttribute("aria-hidden", "true");
  cell.appendChild(g);
}

/** 连击威胁：格子角标 ×段数 */
function paintFlurryCue(cell, threat) {
  if (!threat || threat.kind !== "hurt" || !(threat.hits > 1)) return;
  cell.classList.add("threat-flurry");
  const g = document.createElement("span");
  g.className = "cell-glyph glyph-flurry";
  g.textContent = `×${threat.hits}`;
  g.setAttribute("aria-hidden", "true");
  cell.appendChild(g);
}

function renderBattleGrid() {
  const c = state.combat;
  if (!c) return;
  const wrap = $("battle-grid")?.parentElement;
  if (wrap) wrap.classList.remove("house-battle-wrap");
  if (c.houseGraph) {
    renderHouseGraphBattle();
    return;
  }
  const g = combatGrid();
  const box = $("battle-grid");
  box.className = "battle-grid";
  box.style.gridTemplateColumns = `repeat(${g.cols}, 80px)`;
  box.style.gridTemplateRows = "";
  box.style.width = "";
  box.style.height = "";
  box.style.gap = "";
  box.style.justifyContent = "center";
  box.innerHTML = "";
  const sees = c.playerSeesEnemy;
  // 意图刷新：玩家走位后威胁区跟着变
  c.intent = predictIntent(c);
  const threats = threatMapFromIntent(c.intent);

  for (let r = 0; r < g.rows; r += 1) {
    for (let cidx = 0; cidx < g.cols; cidx += 1) {
      const pos = { r, c: cidx };
      const cell = document.createElement("button");
      cell.type = "button";
      cell.className = "battle-cell";
      const k = keyOf(pos);
      const wall = isWall(pos);
      const hole = isVoid(pos);
      const h = tileHeight(pos);
      const isP = keyOf(c.playerPos) === k;
      const isE = keyOf(c.enemyPos) === k;
      const item = c.floor[k];
      const roomId = c.roomAt?.[k];
      const roomName = roomId ? roomDef(roomId)?.name : null;
      const adjP =
        isOrthoAdjacent(pos, c.playerPos) &&
        !wall &&
        !hole &&
        canStepBetween(pos, c.playerPos);
      const threat = threats.get(k);

      if (hole) {
        cell.classList.add("is-void");
        cell.disabled = true;
        cell.title = "空洞";
        cell.innerHTML = `<span class="void-mark" aria-hidden="true"></span>`;
        box.appendChild(cell);
        continue;
      }

      if (wall) {
        // 墙 = 空白占位（不画砖），仍挡路挡视线
        cell.classList.add("is-wall", "is-void");
        cell.disabled = true;
        cell.title = "挡路";
        cell.setAttribute("aria-label", "挡路");
        cell.innerHTML = "";
        box.appendChild(cell);
        continue;
      }

      if (h === 1) cell.classList.add("h1");
      if (h >= 2) cell.classList.add("h2");
      if (isP) cell.classList.add("has-player");
      if (isE && sees) cell.classList.add("has-enemy");
      if (isE && !sees) cell.classList.add("enemy-fog");
      if (item) cell.classList.add("has-item");
      if (c.portals?.[k]) cell.classList.add("is-portal");
      const isDecoy = decoyAlive(c) && keyOf(c.decoy.pos) === k;
      if (isDecoy) cell.classList.add("has-decoy");
      if (c.lastSeen && keyOf(c.lastSeen) === k && !sees) cell.classList.add("last-seen");
      const anchor = c.anchors?.[k];
      if (anchor?.lit) cell.classList.add("anchor-lit");
      else if (anchor && !anchor.lit) cell.classList.add("anchor-dead");

      if (threat?.kind === "hurt") {
        cell.classList.add("threat-hurt");
        if (threat.attackKind === "charge") cell.classList.add("threat-charge");
        if (threat.pending) cell.classList.add("pending-hurt");
        if (isP) cell.classList.add("threat-on-you");
        paintFlurryCue(cell, threat);
      } else if (threat?.kind === "move") {
        cell.classList.add("threat-move");
      }

      paintReadyZoneCue(cell, c, adjP, isP);

      const canPlaceEnemy = isE && sees && hasLoS(c.playerPos, c.enemyPos);
      const placingDecoy = c.placeUid && cardDef(c.hand.find((x) => x.uid === c.placeUid)?.id || "")?.place?.decoy;
      if (
        c.placeUid &&
        adjP &&
        !isP &&
        ((isE && canPlaceEnemy && !placingDecoy) || (!isE && !item && (!isDecoy || placingDecoy)))
      ) {
        cell.classList.add("place-ok");
      }
      if (c.placeUid && adjP && canPlaceEnemy) cell.classList.add("place-enemy");
      // 威胁优先：有 hurt 时不盖绿色可走提示；单位可穿，敌对格标 move-hostile
      if (!c.placeUid && adjP && !isP && threat?.kind !== "hurt") {
        const moveCost = playerMoveCost(c.playerPos, pos);
        if (c.energy >= moveCost) {
          cell.classList.add("move-ok");
          if (isE) cell.classList.add("move-hostile");
        }
      }

      const bits = [];
      if (roomName && c.houseGraph) bits.push(roomName.length > 2 ? roomName.slice(0, 2) : roomName);
      if (c.portals?.[k]) bits.push("门");
      if (anchor?.lit) bits.push(`信号${anchor.hp}`);
      else if (anchor && !anchor.lit) bits.push("已熄");
      if (item) bits.push(item.glyph || "物");
      if (isDecoy) bits.push("影");
      if (h) bits.push(`↑${h}`);
      let pawnHtml = "";
      if (isP) {
        pawnHtml +=
          `<span class="battle-pawn player-pawn"><img class="char-token map-token" src="assets/ui/chars/SP_Lili_MapToken.png" alt="你" width="34" height="34" draggable="false" /></span>`;
      }
      if (isE && sees) {
        pawnHtml +=
          `<span class="battle-pawn enemy-pawn"><img class="char-token" src="assets/ui/chars/SP_Enemy_Pixel.png" alt="敌" width="28" height="28" draggable="false" /></span>`;
      } else if (isE && !sees) {
        pawnHtml += `<span class="battle-pawn enemy-pawn fog-pawn" aria-label="未知">?</span>`;
      }
      if (isDecoy) {
        pawnHtml += `<span class="battle-pawn decoy-pawn" aria-label="纸影">影</span>`;
      }
      if (anchor?.lit) {
        pawnHtml += `<span class="cell-glyph glyph-anchor" aria-hidden="true">烛</span>`;
      } else if (anchor && !anchor.lit) {
        pawnHtml += `<span class="cell-glyph glyph-anchor-dead" aria-hidden="true">灰</span>`;
      }
      const shots = threat?.hits > 1 ? `${threat.damage}×${threat.hits}` : `${threat?.damage}`;
      const dmgHtml =
        threat?.kind === "hurt" && threat.damage
          ? `<span class="threat-dmg${threat.pending ? " pending" : ""}">${
              threat.net !== threat.total ? `${shots}→${threat.net}` : shots
            }</span>`
          : threat?.kind === "hurt" && threat.attackKind === "decoy"
            ? `<span class="threat-dmg">影</span>`
            : "";
      const meta = bits.length ? `<span class="cell-meta">${bits.join(" ")}</span>` : "";
      cell.innerHTML = `${dmgHtml}${pawnHtml}${meta || (!isP && !isE && !isDecoy && !dmgHtml ? "<span>·</span>" : "")}`;
      cell.title = [
        roomName || (wall ? "挡路" : "空地"),
        c.houseGraph ? "山屋格（沿门移动）" : null,
        h ? `高度 ${h}` : null,
        c.portals?.[k] ? "传送门" : null,
        anchor?.lit ? `信号锚（亮 · 耐久 ${anchor.hp} · 站上拆 / 砸牌 / 引怪砸）` : null,
        anchor && !anchor.lit ? "信号锚（已熄）" : null,
        item ? cardDef(item.cardId)?.name : null,
        isDecoy ? "纸影傀儡（嘲讽 · 挨打才消失）" : null,
        isP ? "你在这里" : null,
        isE && sees ? c.enemy.name : null,
        isE && !sees ? "有动静，但看不见" : null,
        threat?.kind === "hurt"
          ? threat.damage
            ? `${
                threat.attackKind === "charge"
                  ? "蓄力必落（结束回合后砸下）"
                  : threat.pending
                    ? threat.attackKind === "reach"
                      ? "走进这格本回合会挨打"
                      : "锁定预告（本回合打不到你）"
                    : threat.attackKind === "faceShock"
                      ? "突脸惊吓 · 本回合必结算"
                      : "本回合必伤"
              } · ${threat.hits > 1 ? `${threat.damage}×${threat.hits} = ${threat.total}` : `${threat.damage}`} 伤${
                threat.net !== threat.total ? `（格挡后 ${threat.net}）` : ""
              }`
            : "威胁 · 撕碎傀儡"
          : null,
        threat?.kind === "move" ? "它下一步可能到这" : null,
        adjP && !c.placeUid ? "可移动" : null,
        adjP && c.placeUid ? "可放置" : null,
      ]
        .filter(Boolean)
        .join(" · ");
      cell.onclick = () => onTileClick(pos);
      box.appendChild(cell);
    }
  }
  syncBattleIntentBanner();
  if (state.tutorial?.active) updateBattleTutorialCoach();
}

function endTurn() {
  const c = state.combat;
  if (!c) return;
  if (state.tutorial?.active) {
    const hasTrap = Object.values(c.floor || {}).some((f) => f?.onStep?.damage);
    if (hasTrap) state.tutorial.step = "kite";
    else if (state.tutorial.step === "intent") state.tutorial.step = "place";
  }
  c.placeUid = null;

  const budget = retainBudget(c);
  const kept = [];
  const rest = [];
  for (const left of c.hand) {
    const def = cardDef(left.id);
    if (def.retain) {
      kept.push(left);
      continue;
    }
    rest.push(left);
  }
  for (const left of rest) {
    const canHold =
      c.heldUid &&
      left.uid === c.heldUid &&
      kept.filter((k) => !cardDef(k.id).retain).length < budget;
    if (isTempCard(left)) {
      // 临时牌默认回合结束消失；若本回合点了「留」则例外带到下回合
      if (canHold) kept.push(left);
      continue;
    }
    if (canHold) {
      kept.push(left);
    } else {
      retireCard(left);
    }
  }
  c.hand = [];
  c.heldUid = null;
  c.retainThisTurn = 0;

  noteStallAfterPlayerTurn();
  enemyTurn();
  if (!state.combat) return;
  if (c.enemy.hp <= 0) {
    winCombat();
    return;
  }

  beginPlayerTurn(kept);
  if (kept.length) {
    log(`留到下回合：${kept.map((k) => cardDef(k.id).name).join("、")}。`, "ok");
  }
  renderCombat();
}

function winCombat(reason = "kill") {
  const c = state.combat;
  const isBoss = c.isBoss;
  if (isBoss) {
    const boss = state.data.bosses.bosses[state.chosenBoss];
    const ending = state.data.bosses.endings[boss.endingId];
    const ritual = reason === "ritual";
    const title = ending?.title || "通关";
    const body = ritual
      ? `${boss.ritualVictory || boss.victory}\n${ending?.text || ""}`
      : `${boss.victory}\n${ending?.text || ""}`;
    finalizeLabCombat("win", title, ritual ? "ritual" : "kill");
    for (const left of c.hand || []) retireCard(left);
    state.discard = purgeTempCards(state.discard);
    state.deck = purgeTempCards(state.deck);
    freezeCombatUnderlay();
    state.combat = null;
    endGame(true, ritual ? `${title} · 掐断仪式` : title, body);
    return;
  }
  finalizeLabCombat("win", null, "kill");
  for (const left of c.hand || []) retireCard(left);
  state.discard = purgeTempCards(state.discard);
  state.deck = purgeTempCards(state.deck);
  // 战后喘息：残血多补一点，满血不浪费
  const breath = state.hp <= 2 ? 2 : state.hp < state.maxHp ? 1 : 0;
  if (breath) healPlayer(breath, "战后喘息");
  // 先留住战场画面，再叠奖励框（杀戮尖塔式）
  freezeCombatUnderlay();
  state.combat = null;
  $("battle-coach")?.classList.add("hidden");

  if (state.flingSandbox?.active) {
    offerFlingSandboxResult(true);
    return;
  }

  if (state.tutorial?.active) {
    state.tutorial.step = "done_fight";
    offerCardReward({
      title: "练习战结束",
      lead: "正式节目里打完惊吓也会让你挑新道具。先随便收一张练手——或不要也行。然后去休息角听结业说明。",
      offers: ["jab", "guard"],
      onDone: (msg) => {
        completeRoom();
        finishNodeModal(msg);
        setExploreCoach(
          "去休息角",
          "练习客厅已清。走到休息角，点「走进这一间」看结业三句话。",
        );
        renderAll();
      },
    });
    return;
  }

  const pool = [...state.data.cards.rewardPool];
  shuffle(pool);
  offerCardReward({
    title: "胜利！",
    lead: "选择一张道具卡作为本场奖励，或跳过。",
    offers: pool.slice(0, 2),
    overCombat: true,
    onDone: (msg) => {
      document.body.classList.remove("sts-overlay-open");
      $("screen-cards")?.classList.remove("active");
      completeRoom();
      finishNodeModal(msg);
    },
  });
}

function stealCard({ preferHand = false, allowAny = false } = {}) {
  const hand = state.combat?.hand || [];
  const all = [...state.deck, ...state.discard, ...hand];
  if (!all.length) return null;
  let pool = [];
  if (preferHand) {
    pool = hand.filter((c) => cardDef(c.id).stealable);
  }
  if (!pool.length) {
    pool = all.filter((c) => cardDef(c.id).stealable);
  }
  if (!pool.length && allowAny) {
    // grab 无药时扯走杂物，保证有反馈
    pool = all;
  }
  if (!pool.length) return null;
  const target = pool[Math.floor(Math.random() * pool.length)];
  state.deck = state.deck.filter((c) => c.uid !== target.uid);
  state.discard = state.discard.filter((c) => c.uid !== target.uid);
  if (state.combat) {
    state.combat.hand = state.combat.hand.filter((c) => c.uid !== target.uid);
  }
  return target;
}

function loseCombat(reason = "hp") {
  const c = state.combat;
  const isBoss = c?.isBoss;
  const roomName = c?.roomName || "山屋";
  const fail = state.data.bosses.endings.end_fail;
  const broadcast = reason === "broadcast";
  const stall = reason === "stall";
  const outcomeReason = broadcast ? "broadcast" : stall ? "stall" : "hp";
  const normalTitle = stall ? "节目中断·僵局" : "节目中断";
  finalizeLabCombat("lose", isBoss ? fail?.title || "失败" : normalTitle, outcomeReason);
  if (c) {
    for (const left of c.hand || []) retireCard(left);
  }
  state.discard = purgeTempCards(state.discard);
  state.deck = purgeTempCards(state.deck);
  freezeCombatUnderlay();
  state.combat = null;
  if (isBoss) {
    const boss = state.data.bosses.bosses[state.chosenBoss];
    const title = broadcast ? "结局·被播映" : fail.title;
    const text = broadcast
      ? `播出进度满格。频道锁定了你的影像。\n${fail.text}`
      : boss?.defeat
        ? `${boss.defeat}\n${fail.text}`
        : fail.text;
    endGame(false, title, text);
    return;
  }
  // 普通战斗失败也直接终局：逃出后缺牌难翻盘，不如重开
  if (state.flingSandbox?.active) {
    state.hp = Math.max(1, state.maxHp);
    offerFlingSandboxResult(false);
    return;
  }
  if (state.tutorial?.active) {
    state.hp = Math.max(1, state.maxHp);
    showModal("screen-event");
    $("event-title").textContent = "练习失败 · 没关系";
    $("event-text").textContent =
      "教学里死了也能重来。再试一次：先放地刺，看红格躲开，再点回合结束让它自己踩上来。";
    $("btn-close-event").classList.add("hidden");
    clearRewardCards();
    const box = $("event-choices");
    box.innerHTML = "";
    addChoice(box, "再打一次", "primary", () => {
      state.tutorial.step = "place";
      startCombat(roomDef("tut_practice"), false);
    });
    addChoice(box, "回导播间", "", () => {
      showModal(null);
      state.roomId = "tut_studio";
      state.nodePending = false;
      discoverNeighbors(state.roomId);
      renderAll();
      refreshTutorialCoach();
    });
    return;
  }
  endGame(
    false,
    stall ? "结局·节目中断·僵局" : "结局·节目中断",
    stall
      ? `你在${roomName}陷入空转，惊吓时间被掐断。\n试试砸击脚下或削韧后再输出。按下「再看一集」重开。\n${fail.text}`
      : `你在${roomName}没能逃掉。\n山屋把这一集掐灭了——按下「再看一集」重开一局。\n${fail.text}`,
  );
}

function traitLabel(id) {
  return state.data.pressure?.traitLabels?.[id] || id;
}

function fillBossKit(preview) {
  const box = $("boss-kit");
  if (!box) return;
  const labels = state.data.pressure?.traitLabels || {};
  const arch = preview?.archetypeLabel || "";
  const archDesc = preview?.archetypeDesc || "";
  const traits = preview?.traits || [];
  const chips = traits.map((t) => `<span class="trait-chip">${labels[t] || t}</span>`).join("");
  box.innerHTML = `
    <p class="boss-kit-lead"><strong>${arch}</strong> · ${archDesc}</p>
    <div class="trait-chips">${chips}</div>
    <p class="boss-kit-tip">双轨通关：熄灭全部金色「烛」信号锚，或打空血条。播出进度满则失败。蓄力会亮实线红区——先离开再贪刀。</p>
  `;
}

function traitTip(id) {
  const labels = state.data.pressure?.traitLabels || {};
  const name = labels[id] || id;
  const tips = {
    faceShock:
      "转角重获视线，或你主动暴露后仍待在视线里——贴身固定吓 1 点；够不着只喊不伤。不再借突脸放全额招。看横幅「惊吓 / 当心突脸」。",
    cornerCut: "见面时免费贴近一步，方便下一拍出手；若带突脸，可贴身把惊吓打实。",
    lunge: "距 2 时可突进落点再打你；红线标出落点与你。",
    vault: "优先上高台，可能改变伤害或本回合路线。",
    trapAware: "尽量不踩你放的刺/盐。",
    guardBreak: "无视格挡与掩体。",
    grab: "打中会偷你的牌。",
    relentless: "看见你时攻击更便宜，更容易多步贴脸。",
    slam: "邻接时范围砸击；红区为 2×2。",
    beam: "直线激光；红线为射线。",
    flurry: "有视线时可多段出手；红字如 2×2。",
  };
  return tips[id] ? `${name}：${tips[id]}` : name;
}

function renderTraitChips(c) {
  const box = $("enemy-traits");
  if (!box) return;
  const bits = [];
  if (c.archetypeLabel) {
    bits.push(`<span class="trait-chip trait-arch" title="${c.archetypeDesc || ""}">${c.archetypeLabel}</span>`);
  }
  for (const t of c.traits || []) {
    const hot =
      t === "faceShock" &&
      ((c.playerExposed && c.enemySeesPlayer) ||
        c.intent?.surpriseRisk ||
        c.intent?.zones?.some((z) => z.attackKind === "faceShock"));
    bits.push(
      `<span class="trait-chip${hot ? " trait-hot" : ""}" title="${traitTip(t)}">${state.data.pressure?.traitLabels?.[t] || t}</span>`,
    );
  }
  if (isEnemyBlinded(c)) {
    bits.push(`<span class="trait-chip trait-blind" title="本回合无法锁定攻击">闪瞎</span>`);
  }
  box.innerHTML = bits.join("") || "";
}

function openBoss() {
  if (!runReadyForBoss()) return;
  state.chosenBoss = state.chosenBoss || pickBossId();
  let boss = bossDef(state.chosenBoss);
  if (!boss) {
    state.chosenBoss = Object.keys(state.data.bosses.bosses)[0];
    boss = bossDef(state.chosenBoss);
  }
  if (!boss) {
    alert("Boss 数据缺失，请刷新页面。");
    return;
  }
  // 用 buildEncounter 预览含压力加成的实战数值，而非 bosses.json 原始值
  const preview = buildEncounter(null, true);
  showModal("screen-boss");
  $("boss-name").textContent = boss.name;
  $("boss-phase-text").textContent = boss.intro;
  const deckPreset = state.bossTestDeck ? BOSS_TEST_DECKS[state.bossTestDeck] : null;
  const deckLine = deckPreset ? ` · 测牌组「${deckPreset.name}」` : "";
  $("boss-hp").textContent = `生命 ${preview.hp} · 伤害 ${preview.damage} · 韧性 ${preview.toughness} · 场地=本集山屋平面（一房一格）${deckLine}`;
  fillBossKit(preview);
  const actions = $("boss-actions");
  actions.innerHTML = "";
  addChoice(actions, "进入山屋决战", "primary", () => {
    startCombat({ id: "altar", enemy: boss }, true);
  });
  if (deckPreset) {
    addChoice(actions, "换体系牌组", "ghost", () => {
      offerBossTestMenu();
    });
  }
  addChoice(actions, "先回去", "", () => {
    showModal(null);
    renderAll();
  });
}

function endGame(won, title, text) {
  // 若战斗未正常 finalize（异常路径），兜底记一笔
  if (state.lab) finalizeLabCombat(won ? "win" : "lose", title);
  // 保留当前战场/地图画面作底，叠 STS 式结算框
  const keep = [];
  if ($("screen-cards")?.classList.contains("active")) keep.push("screen-cards");
  else if ($("screen-game")?.classList.contains("active")) {
    // 地图场景：保持 game 底（非 modal，show 不碰它即可）
  } else {
    // 兜底：若已离开战斗，仍强制亮起最后一帧战场
    freezeCombatUnderlay();
    keep.push("screen-cards");
  }
  // 不切换主面板，只叠结束框
  showModal("screen-end", { keep });
  document.body.classList.add("sts-overlay-open");
  const result = $("end-result");
  const art = $("end-art");
  if (result) {
    result.textContent = won ? "胜利！" : "失败…";
    result.className = `end-result ${won ? "won" : "lost"}`;
  }
  if (art) {
    art.src = won ? "assets/ui/SP_EndGame.png" : "assets/ui/SP_Gameover.png";
    art.alt = won ? "通关" : "失败";
  }
  $("end-title").textContent = title;
  $("end-log").textContent = text;
  const labNote = $("end-lab-note");
  if (labNote) {
    const store = loadLabStore();
    const last = store.runs[0];
    if (last) {
      const s = last.summary || {};
      labNote.textContent = `本场已写入实验记录：${last.outcome === "win" ? "胜" : "负"} · ${s.turns || 0} 回合 · 输出 ${s.damageDealt || 0} / 受伤 ${s.damageTaken || 0}`;
    } else {
      labNote.textContent = "";
    }
  }
  playTone(won ? "ok" : "bad");
  localStorage.removeItem(SAVE_KEY);
  state.labTag = "normal";
  renderLabPanel();
}

function renderAll() {
  renderStats();
  renderBossBoard();
  renderLists();
  renderRoom();
  refreshTutorialCoach();
  if ($("screen-game").classList.contains("active")) saveGame();
}

function bindUi() {
  $("btn-start").onclick = () => {
    if (!state.data) {
      alert("数据还在加载，请稍等一秒再点。若一直无效，请用本地服务器打开：python3 -m http.server 8787");
      return;
    }
    try {
      startBgm();
      resetGame();
    } catch (err) {
      console.error(err);
      alert(`无法开始：${err.message}`);
    }
  };
  const tutBtn = $("btn-tutorial");
  if (tutBtn) {
    tutBtn.onclick = () => {
      if (!state.data) {
        alert("数据还在加载，请稍等一秒再点。");
        return;
      }
      try {
        startBgm();
        startTutorial();
      } catch (err) {
        console.error(err);
        alert(`无法开始教学：${err.message}`);
      }
    };
  }
  $("btn-boss-test").onclick = () => {
    if (!state.data) {
      alert("数据还在加载，请稍等一秒再点。");
      return;
    }
    try {
      startBgm();
      offerBossTestMenu();
    } catch (err) {
      console.error(err);
      alert(`无法打开 Boss 测试：${err.message}`);
    }
  };
  const flingBtn = $("btn-fling-test");
  if (flingBtn) {
    flingBtn.onclick = () => {
      if (!state.data) {
        alert("数据还在加载，请稍等一秒再点。");
        return;
      }
      try {
        startBgm();
        offerFlingSandboxMenu();
      } catch (err) {
        console.error(err);
        alert(`无法打开甩开沙盒：${err.message}`);
      }
    };
  }
  const exitSideview = () => {
    if (window.CabinSideview) window.CabinSideview.stop();
    showModal(null);
    show("screen-title");
  };
  window.CabinSideviewOnExit = exitSideview;
  const sideBtn = $("btn-sideview-test");
  if (sideBtn) {
    sideBtn.onclick = () => {
      show("screen-title");
      showModal("screen-sideview");
      if (window.CabinSideview) window.CabinSideview.start();
    };
  }
  const sideExit = $("btn-sideview-exit");
  if (sideExit) sideExit.onclick = () => exitSideview();
  const exitQteSandbox = () => {
    if (window.CabinQte) CabinQte.stop();
    const exitBtn = $("btn-qte-exit");
    const forfeitBtn = $("btn-qte-forfeit");
    const goBtn = $("btn-qte-go");
    if (exitBtn) exitBtn.classList.add("hidden");
    if (forfeitBtn) forfeitBtn.classList.add("hidden");
    if (goBtn) goBtn.classList.add("hidden");
    showModal(null);
    show("screen-title");
  };
  const qteBtn = $("btn-qte-test");
  if (qteBtn) {
    qteBtn.onclick = () => {
      show("screen-title");
      showModal("screen-qte");
      const exitBtn = $("btn-qte-exit");
      const forfeitBtn = $("btn-qte-forfeit");
      if (exitBtn) exitBtn.classList.add("hidden");
      if (forfeitBtn) {
        forfeitBtn.classList.remove("hidden");
        forfeitBtn.onclick = () => {
          if (window.CabinQte?.forfeit) CabinQte.forfeit("试玩中途投降。");
        };
      }
      if (!window.CabinQte) return;
      CabinQte.start({
        title: "警察抓小偷（试玩）",
        onDone: (result) => {
          const status = $("qte-status");
          if (status) {
            status.textContent = result.ok
              ? result.message + "（正式局：速度 +1，再翻静室奖励）"
              : result.message + "（正式局：偷牌或扣血，抽屉不开）";
          }
          if (forfeitBtn) forfeitBtn.classList.add("hidden");
          if (exitBtn) {
            exitBtn.classList.remove("hidden");
            exitBtn.onclick = () => exitQteSandbox();
          }
        },
      });
    };
  }
  const qteExit = $("btn-qte-exit");
  if (qteExit) qteExit.onclick = () => exitQteSandbox();

  const exitPuzzleSandbox = () => {
    if (window.CabinPuzzle) CabinPuzzle.stop();
    const exitBtn = $("btn-puzzle-exit");
    const forfeitBtn = $("btn-puzzle-forfeit");
    if (exitBtn) exitBtn.classList.add("hidden");
    if (forfeitBtn) forfeitBtn.classList.add("hidden");
    $("btn-puzzle-refresh")?.classList.add("hidden");
    showModal(null);
    show("screen-title");
  };
  const puzzleBtn = $("btn-puzzle-test");
  if (puzzleBtn) {
    puzzleBtn.onclick = () => {
      show("screen-title");
      showModal("screen-puzzle");
      const exitBtn = $("btn-puzzle-exit");
      const forfeitBtn = $("btn-puzzle-forfeit");
      if (exitBtn) exitBtn.classList.add("hidden");
      if (forfeitBtn) {
        forfeitBtn.classList.remove("hidden");
        forfeitBtn.onclick = () => {
          if (window.CabinPuzzle) CabinPuzzle.forfeit("试玩中途放弃。");
        };
      }
      if (!window.CabinPuzzle) return;
      CabinPuzzle.start({
        title: "雪花拼图（试玩）",
        onDone: (result) => {
          const status = $("puzzle-status");
          if (status) {
            status.textContent = result.ok
              ? result.message + "（正式局里过关才会发静室奖励）"
              : result.message + "（正式局里失败只丢奖励）";
          }
          if (forfeitBtn) forfeitBtn.classList.add("hidden");
          if (exitBtn) {
            exitBtn.classList.remove("hidden");
            exitBtn.onclick = () => exitPuzzleSandbox();
          }
        },
      });
    };
  }
  const puzzleExit = $("btn-puzzle-exit");
  if (puzzleExit) puzzleExit.onclick = () => exitPuzzleSandbox();
  $("btn-restart").onclick = () => {
    document.body.classList.remove("sts-overlay-open");
    $("screen-cards")?.classList.remove("active");
    showModal(null);
    startBgm();
    resetGame();
  };
  $("btn-continue").onclick = () => {
    if (!loadGame()) return;
    startBgm();
    $("log").innerHTML = "";
    log("欢迎回来。上一集的书签还夹在这里。");
    renderAll();
    show("screen-game");
    showModal(null);
  };
  $("btn-resolve").onclick = () => resolveCurrentNode();
  $("btn-boss").onclick = () => openBoss();
  $("btn-close-event").onclick = () => {
    hideCardTooltip();
    clearRewardCards();
    showModal(null);
    renderAll();
  };
  window.addEventListener("scroll", hideCardTooltip, true);
  window.addEventListener("resize", () => {
    hideCardTooltip();
    if ($("screen-game")?.classList.contains("active") && !state.combat) {
      const box = $("house-map");
      if (box?.classList.contains("house-map-abs")) fitHouseMapBox(box, mapDisplayFrame());
    }
  });
  $("btn-dice-continue").onclick = () => {
    const fn = state.pending;
    state.pending = null;
    if (fn) fn();
  };
  $("btn-end-turn").onclick = () => endTurn();
  $("btn-cancel-place").onclick = () => cancelPlace();
  const dismantleBtn = $("btn-dismantle");
  if (dismantleBtn) dismantleBtn.onclick = () => tryDismantleAnchor();
  const exportBtn = $("btn-lab-export");
  if (exportBtn) exportBtn.onclick = () => exportLabJson();
  const exportEnd = $("btn-lab-export-end");
  if (exportEnd) exportEnd.onclick = () => exportLabJson();
  const clearBtn = $("btn-lab-clear");
  if (clearBtn) clearBtn.onclick = () => clearLabStore();
  $("btn-mute")?.addEventListener("click", () => toggleMute());
  $("btn-mute-map")?.addEventListener("click", () => toggleMute());
  $("btn-mute-battle")?.addEventListener("click", () => toggleMute());
  $("btn-restart-run")?.addEventListener("click", () => restartRun());
  $("btn-home")?.addEventListener("click", () => goHome());
  $("btn-combat-home")?.addEventListener("click", () => combatGoHome());
}

async function main() {
  bindUi();
  try {
    state.muted = localStorage.getItem("cabin-mute") === "1";
  } catch (_) {
    state.muted = false;
  }
  setMuted(state.muted);
  updateMuteButton();
  renderLabPanel();
  const status = $("boot-status");
  try {
    await loadData();
    if (status) {
      status.textContent = state.data.tutorial
        ? "准备就绪——「新手教学」或「打开电视机」。"
        : "准备就绪——按下「打开电视机」就开始吧。";
    }
    show("screen-title");
    if (localStorage.getItem(SAVE_KEY)) $("btn-continue").classList.remove("hidden");
    if (new URLSearchParams(location.search).has("dumpLab")) {
      const raw = await dumpLabToWorkspace();
      let n = 0;
      try {
        n = JSON.parse(raw)?.runs?.length || 0;
      } catch (_) {}
      if (status) status.textContent = `已导出实验记录 ${n} 场 → lab-fling-extract.json`;
    }
  } catch (err) {
    console.error(err);
    if (status) {
      status.classList.add("bad");
      status.textContent = `节目带卡住了：${err.message}。请在 cabin-slice 目录运行 python3 -m http.server 8787，再打开 http://127.0.0.1:8787/`;
    } else {
      document.body.innerHTML = `<pre style="padding:24px">加载失败：${err.message}</pre>`;
    }
  }
}

main();

/* 自测 / 调试入口：浏览器控制台与 Playwright 用 */
window.CabinDebug = {
  getState: () => state,
  skipToBossTest,
  offerBossTestMenu,
  resetGame,
  startTutorial,
  exitTutorialMode,
  dumpLabToWorkspace,
  exportLabJson,
  offerFlingSandboxMenu,
  startFlingSandbox,
  exitFlingSandbox,
  moveTo,
  resolveCurrentNode,
  openBoss,
  endTurn,
  tryMovePlayer,
  tryPlace,
  selectCard,
  tryDismantleAnchor,
  loseCombat,
  winCombat,
  roomDef,
  cardDef,
  loadLabStore,
  LAB_KEY,
  neighbors,
  keyOf,
  manhattan,
  isPassable,
  isOrthoAdjacent,
  hasLoS,
  runReadyForBoss,
  rollRoomLayout,
  placedRoomIds,
  restartRun,
  forceEnemyShove,
  goHome,
  combatGoHome,
};
