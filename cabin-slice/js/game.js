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
  /** 本局房间类型伪随机：种子 + id→combat|quiet */
  runSeed: 0,
  roomLayout: null,
};

const $ = (id) => document.getElementById(id);

async function loadData() {
  const [rooms, cards, relics, bosses, pressure, tutorial] = await Promise.all([
    fetch("data/rooms.json").then((r) => r.json()),
    fetch("data/cards.json").then((r) => r.json()),
    fetch("data/relics.json").then((r) => r.json()),
    fetch("data/bosses.json").then((r) => r.json()),
    fetch("data/pressure.json").then((r) => r.json()),
    fetch("data/tutorial.json").then((r) => r.json()),
  ]);
  state.data = { rooms, cards, relics, bosses, pressure, tutorial };
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
  return type || "卡牌";
}

function cardFrameClass(type) {
  if (type === "medicine") return "frame-red";
  if (type === "skill") return "frame-blue";
  return "frame-yellow";
}

function cardKindIcon(type) {
  if (type === "place") return "assets/ui/cards/SP_Card_IconT_Trap.png";
  if (type === "medicine") return "assets/ui/cards/SP_Card_IconS_Life.png";
  if (type === "skill") return "assets/ui/cards/SP_Card_IconT_Amulet.png";
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
  if (def.type === "skill") {
    if (def.gainBlock) {
      return "用法：和补剂/肾上腺素一样——点一下立刻获得格挡，不用放置。留在手里不会自动挡伤害。";
    }
    if (def.shove) return "用法：点一下立刻推开邻接的敌人，不用放置。";
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
  const rect = anchor.getBoundingClientRect();
  const pad = 10;
  let left = rect.right + 12;
  let top = rect.top;
  tip.style.left = "0px";
  tip.style.top = "0px";
  const tw = tip.offsetWidth;
  const th = tip.offsetHeight;
  if (left + tw > window.innerWidth - pad) left = rect.left - tw - 12;
  if (left < pad) left = pad;
  if (top + th > window.innerHeight - pad) top = window.innerHeight - th - pad;
  if (top < pad) top = pad;
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
    };
  }
  return base;
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
 * 开局掷大地图布局：房间内容固定，落位 + 邻接出口伪随机（连通）。
 * 玄关固定出生格；祭坛/仪式不进随机图（仍走 Boss 按钮）。
 */
function rollRoomLayout(seed = (Date.now() ^ (Math.random() * 0x7fffffff)) >>> 0) {
  const cfg = state.data.rooms.layoutRoll;
  const rooms = state.data.rooms.rooms;
  const size = state.data.rooms.mapSize || { cols: 6, rows: 7 };

  if (!cfg?.enabled || cfg.mode === "off" || state.tutorial?.active) {
    state.runSeed = seed;
    state.roomLayout = null;
    return null;
  }

  const rng = makeRng(seed);
  const exclude = new Set(cfg.exclude || ["altar", "ritual"]);
  const startId = cfg.start?.id || state.data.rooms.startRoom || "foyer";
  const [colLo, colHi] = cfg.startColRange || [cfg.start?.col ?? 3, cfg.start?.col ?? 3];
  const startCol =
    colLo + Math.floor(rng() * (Math.max(colLo, colHi) - colLo + 1));
  const startRow = cfg.start?.row ?? rooms[startId]?.map?.row ?? size.rows;

  const pool = seededShuffle(
    Object.keys(rooms).filter(
      (id) => id !== startId && !exclude.has(id) && !rooms[id].bossRoom,
    ),
    rng,
  );

  const [lo, hi] = cfg.placeCount || [pool.length + 1, pool.length + 1];
  const want = Math.max(
    1,
    Math.min(pool.length + 1, lo + Math.floor(rng() * (Math.max(lo, hi) - lo + 1))),
  );

  const occupied = new Map(); // "c,r" -> id
  const layout = {};
  layout[startId] = { col: startCol, row: startRow, exits: [] };
  occupied.set(cellKey(startCol, startRow), startId);

  const dirs = [
    [0, -1],
    [0, 1],
    [-1, 0],
    [1, 0],
  ];
  const inBounds = (c, r) => c >= 1 && r >= 1 && c <= size.cols && r <= size.rows;

  const frontierOf = () => {
    const edge = [];
    const seen = new Set();
    for (const loc of Object.values(layout)) {
      for (const [dc, dr] of dirs) {
        const c = loc.col + dc;
        const r = loc.row + dr;
        const k = cellKey(c, r);
        if (!inBounds(c, r) || occupied.has(k) || seen.has(k)) continue;
        seen.add(k);
        edge.push({ c, r });
      }
    }
    return edge;
  };

  let pi = 0;
  while (Object.keys(layout).length < want && pi < pool.length) {
    const frontier = frontierOf();
    if (!frontier.length) break;
    const spot = frontier[Math.floor(rng() * frontier.length)];
    const id = pool[pi++];
    layout[id] = { col: spot.c, row: spot.r, exits: [] };
    occupied.set(cellKey(spot.c, spot.r), id);
  }

  // 正交邻格互为出口（无向）
  for (const [id, loc] of Object.entries(layout)) {
    const exits = [];
    for (const [dc, dr] of dirs) {
      const nid = occupied.get(cellKey(loc.col + dc, loc.row + dr));
      if (nid) exits.push(nid);
    }
    loc.exits = exits;
  }

  state.runSeed = seed;
  state.roomLayout = layout;
  const combatN = Object.keys(layout).filter((id) => rooms[id]?.combat).length;
  log(
    `本集山屋平面图 #${seed >>> 0} · ${Object.keys(layout).length} 间（惊吓 ${combatN}）`,
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

function tileHeight(pos) {
  return state.combat?.heights?.[keyOf(pos)] || 0;
}

function isPassable(pos) {
  return inBounds(pos) && !isWall(pos);
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
  ].filter(isPassable);
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

function getEnemyGoal(c) {
  if (decoyAlive(c)) return { ...c.decoy.pos };
  // 节目指令「点亮舞台」：优先追最近亮锚
  if (c.isBoss && c.directive?.id === "spotlight") {
    const anchor = nearestLitAnchor(c, c.enemyPos);
    if (anchor) return anchor;
  }
  const sees = hasLoS(c.enemyPos, c.playerPos);
  if (sees) return { ...c.playerPos };
  if (c.lastSeen) return { ...c.lastSeen };
  return null;
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
  return phase.wideCharge || phase.frenzy ? 2 : 1;
}

function chargeCellsAround(center, radius) {
  const cells = [];
  for (let dr = -radius; dr <= radius; dr += 1) {
    for (let dc = -radius; dc <= radius; dc += 1) {
      const pos = { r: center.r + dr, c: center.c + dc };
      if (inBounds(pos) && !isWall(pos)) cells.push(pos);
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
  const pick = pool[Math.floor(Math.random() * pool.length)];
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
  // 贴脸或邻近、且体力够时有机会蓄力；终幕更高
  const phase = currentBossPhase(c);
  if (dist > 2) return false;
  if (phase.frenzy) return Math.random() < 0.65;
  if (phase.wideCharge) return Math.random() < 0.45;
  return Math.random() < 0.32;
}

function beginBossCharge(c) {
  const radius = chargeRadius(c);
  // 落点优先：覆盖玩家，并尽量吞进附近亮锚（让「引砸」成为可见策略）
  const candidates = [{ ...c.playerPos }, ...neighbors(c.playerPos)];
  for (const a of litAnchorKeys(c)) candidates.push(parseKey(a));
  let best = null;
  let bestScore = -1;
  for (const center of candidates) {
    if (!inBounds(center) || isWall(center)) continue;
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
  const per = Math.ceil(estimateHurtDamage(c) * 1.5);
  c.chargePending = {
    cells: best.cells.map((p) => ({ ...p })),
    damage: per,
    center: best.center,
    radius: best.radius,
  };
  log(`${c.enemy.name}开始蓄力大招——红格已标出，下回合必落！`, "bad");
  labEvent("charge_start", { damage: per, radius: best.radius, cells: best.cells.length });
  if (state.lab) state.lab.summary.chargeCasts = (state.lab.summary.chargeCasts || 0) + 1;
  playTone("face");
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
  if (isWall(dest) || !inBounds(dest)) {
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

function resolveShove(inst) {
  const c = state.combat;
  const def = cardDef(inst.id);
  if (!isOrthoAdjacent(c.playerPos, c.enemyPos)) {
    log("推撞需要与敌人邻接。", "bad");
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

  const dr = Math.sign(c.enemyPos.r - c.playerPos.r);
  const dc = Math.sign(c.enemyPos.c - c.playerPos.c);
  const dest = { r: c.enemyPos.r + dr, c: c.enemyPos.c + dc };
  // 单位可穿：仅墙/越界算撞障；推上傀儡则落地打碎
  if (!inBounds(dest) || isWall(dest)) {
    drainToughness(1, "推撞撞墙削韧");
    log(`推撞：${c.enemy.name}撞上障碍，韧性 -1。`, "ok");
    playTone("ok");
  } else {
    c.enemyPos = { ...dest };
    log(`你把${c.enemy.name}推到 (${dest.r + 1},${dest.c + 1})。`, "ok");
    playTone("ok");
    resolveEnemyLandOverlap(c);
    c.portalLanded = false;
    tryPortal("enemy", c.enemyPos);
    triggerFloor(c.enemyPos, "enemy");
    if (c.enemy.hp <= 0) {
      winCombat();
      return true;
    }
  }
  c.intent = predictIntent(c);
  renderCombat();
  return true;
}

/** 格子视线：墙遮挡；中间更高的脊也遮挡；邻接始终可见 */
function hasLoS(a, b) {
  if (!a || !b) return false;
  if (keyOf(a) === keyOf(b)) return true;
  if (manhattan(a, b) === 1) return isPassable(a) && isPassable(b);

  const n = Math.max(Math.abs(b.r - a.r), Math.abs(b.c - a.c));
  const hEye = Math.max(tileHeight(a), tileHeight(b));
  for (let i = 1; i < n; i += 1) {
    const r = Math.round(a.r + ((b.r - a.r) * i) / n);
    const c = Math.round(a.c + ((b.c - a.c) * i) / n);
    const p = { r, c };
    if (!inBounds(p)) return false;
    if (isWall(p)) return false;
    if (tileHeight(p) > hEye) return false;
  }
  return true;
}

function isEnemyBlinded(c) {
  return !!(c && (c.blindTurns || 0) > 0);
}

/** 闪光雷：致盲至少 1 个敌方回合——丢目击、本回合无法靠视线锁定/攻击 */
function applyBlind(c, source = "flare") {
  if (!c) return;
  c.lastSeen = null;
  c.lastSeenAge = 0;
  c.blindArmed = true;
  c.blindTurns = Math.max(c.blindTurns || 0, 1);
  c.enemySeesPlayer = false;
  log("强光炸开——它瞎了一回合：丢失目击，暂时无法锁定攻击！", "ok");
  labEvent("blind", { source, turns: c.blindTurns });
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
      anchorsTotal: isBoss ? (roomDef("altar")?.arena?.anchors || []).length : 0,
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
  if (!state.tutorial?.active || !state.combat) {
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
  const btn = $("btn-mute");
  if (!btn) return;
  btn.textContent = state.muted ? "音乐：关" : "音乐：开";
  btn.setAttribute("aria-pressed", state.muted ? "true" : "false");
}

/** 放弃本集，换一张新平面图（新种子） */
function rerollMapRun() {
  if (state.tutorial?.active) {
    log("教学片不能换平面图。先回首页再开正式节目。", "bad");
    return;
  }
  if (state.combat) {
    log("惊吓时间里不能换平面图——先打完或回首页。", "bad");
    return;
  }
  const ok = window.confirm(
    `放弃当前进度，换一张全新山屋平面图？\n（当前 #${state.runSeed >>> 0}）`,
  );
  if (!ok) return;
  resetGame();
}

/** 回到标题页；存档保留，可用「接着看上集」 */
function goHome({ fromCombat = false } = {}) {
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
      ? `上集平面图 #${state.runSeed >>> 0} 已存档。接着看上集可续玩；打开电视机 / 换平面图开新山屋。`
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
      "场上红底数字 = 回合结束后站在那里会挨打。先走开或放好再点「回合结束」。蓝虚线是它可能走的下一步。",
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
  if (state.tutorial?.roomsMain) {
    state.data.rooms = state.tutorial.roomsMain;
  }
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

async function startTutorial() {
  if (!state.data?.tutorial) {
    alert("教学数据未加载，请刷新页面。");
    return;
  }
  // 不覆盖正式存档
  state.tutorial = {
    active: true,
    step: "place",
    roomsMain: state.data.rooms,
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
  renderAll();
  show("screen-game");
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
}

function resetGame() {
  if (state.tutorial?.active && state.tutorial.roomsMain) {
    state.data.rooms = state.tutorial.roomsMain;
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

/** 调试：模拟一局成长结束 + 满血，直接进 Boss 决战测强度 */
function skipToBossTest() {
  if (state.tutorial?.active) exitTutorialMode({ startReal: false });
  if (!state.data?.bosses?.bosses) {
    throw new Error("Boss 数据未加载，请刷新页面后再试。");
  }
  localStorage.removeItem(SAVE_KEY);
  localStorage.removeItem("cabin-run-v2");
  localStorage.removeItem("cabin-run-v1");
  const path = [
    "foyer",
    "living",
    "kitchen",
    "hall",
    "gallery",
    "study",
    "attic",
    "loft",
    "cellar",
    "ritual",
  ];
  state.roomId = "ritual";
  state.speed = 5;
  state.maxHp = 8;
  state.hp = 8;
  state.visitPath = [...path];
  state.resolvedRooms = new Set(path);
  state.knownRooms = new Set(Object.keys(state.data.rooms.rooms));
  // 约一局期望牌库：起手 + 战斗/静室加牌（只保留数据里存在的 id）
  const grown = [
    ...state.data.cards.starter,
    "heavy",
    "heavy",
    "flare",
    "shove",
    "snare",
    "keepsake",
    "plans",
    "adrenaline",
    "jab",
    "guard",
  ].filter((id) => !!cardDef(id));
  state.deck = shuffle(grown.map((id) => makeCard(id)));
  state.discard = [];
  state.relics = ["omen_salt", "omen_signal", "omen_decoy", "omen_flint"].filter(
    (id) => !!relicDef(id),
  );
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
  state.labTag = "boss_test";
  state.roomLayout = null;
  state.runSeed = 0;
  $("log").innerHTML = "";
  show("screen-game");
  showModal(null);
  const boss = bossDef(state.chosenBoss);
  log("【测 Boss】行程已满 · 满血 8/8 · 速度 5 · 强化牌库。", "ok");
  log(`决战对手：${boss.name}（偏硬壳，方便测强度）。`);
  renderAll();
  saveGame();
  openBoss();
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
  $("stats").innerHTML = pills
    .map(([k, v]) => `<div class="stat-pill"><span>${k}</span><strong>${v}</strong></div>`)
    .join("");
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

function renderMap() {
  const box = $("house-map");
  const links = $("map-links");
  const size = state.data.rooms.mapSize || { cols: 6, rows: 7 };
  box.style.gridTemplateColumns = `repeat(${size.cols}, minmax(0, 1fr))`;
  box.style.gridTemplateRows = `repeat(${size.rows}, minmax(0, 1fr))`;
  box.innerHTML = "";
  if (links) {
    links.innerHTML = "";
    links.setAttribute("viewBox", `0 0 ${size.cols} ${size.rows}`);
    links.setAttribute("preserveAspectRatio", "none");
  }
  const here = roomDef(state.roomId);
  const exits = new Set(here?.exits || []);
  const rooms = placedRoomIds().map((id) => roomDef(id)).filter(Boolean);
  const byId = Object.fromEntries(rooms.map((r) => [r.id, r]));

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
        const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
        line.setAttribute("x1", String(from.map.col - 0.5));
        line.setAttribute("y1", String(from.map.row - 0.5));
        line.setAttribute("x2", String(to.map.col - 0.5));
        line.setAttribute("y2", String(to.map.row - 0.5));
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
    const btn = document.createElement("button");
    btn.className = "map-node";
    btn.style.gridColumn = String(room.map.col);
    btn.style.gridRow = String(room.map.row);
    const known = state.knownRooms.has(room.id);
    const visited = state.resolvedRooms.has(room.id) || state.visitPath.includes(room.id);
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
      if (exits.has(room.id) && room.id !== state.roomId) btn.classList.add("reachable");

      if (room.id === state.roomId) {
        btn.classList.add("current");
        btn.title = `${room.name}（你在这里）`;
        const pawn = document.createElement("span");
        pawn.className = "map-pawn";
        pawn.setAttribute("aria-label", `你在${room.name}`);
        pawn.innerHTML =
          `<img class="char-token map-token" src="assets/ui/chars/SP_Lili_MapToken.png" alt="你" width="40" height="40" draggable="false" />`;
        btn.appendChild(pawn);
      } else {
        btn.title = room.name + (room.combat ? " · 惊吓" : " · 静室");
      }

      const canMove =
        exits.has(room.id) &&
        !state.nodePending &&
        !runReadyForBoss() &&
        room.id !== state.roomId &&
        !room.bossRoom;
      btn.disabled = !canMove && room.id !== state.roomId;
      if (room.bossRoom) {
        btn.disabled = true;
        btn.title = "完成 10 房后决战";
      }
      btn.onclick = () => {
        if (canMove) moveTo(room.id);
      };
    }
    box.appendChild(btn);
  }
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
  // QTE 解谜占位：先考验，再进原有静室奖励；失败则丢奖励（可不致死）
  const rolledGate = state.rewardRolls[room.id];
  if (room.eventType === "qte" && !rolledGate?.qteResolved) {
    beginQteForRoom(room);
    return;
  }
  startNonCombatRewards(room);
}

function beginQteForRoom(room) {
  if (!window.CabinQte) {
    startNonCombatRewards(room);
    return;
  }
  showModal("screen-qte");
  $("btn-qte-exit").classList.add("hidden");
  CabinQte.start({
    title: room.name,
    lead: "频道要求你跟上乱码节拍。成功后才能翻静室奖励；失败只丢掉这次奖励（Haunt 式考验）。",
    onDone: (result) => {
      const prev = state.rewardRolls[room.id] || {};
      state.rewardRolls[room.id] = { ...prev, qteResolved: true, qteOk: !!result.ok };
      saveGame();
      if (result.ok) {
        log(`【考验】${room.name}：节拍咬合。`, "ok");
        playTone("ok");
        startNonCombatRewards(room);
        return;
      }
      log(`【考验】${room.name}：节拍失手，静室奖励溜走了。`, "bad");
      playTone("bad");
      // 小代价：若血量 >1 扣 1，否则只丢奖励
      if (state.hp > 1) {
        state.hp -= 1;
        log("被回声刮了一下（−1 生命）。", "bad");
      }
      completeRoom();
      showModal("screen-event");
      $("event-title").textContent = room.name;
      $("event-text").textContent = result.message + " 抽屉自己合上了。";
      $("btn-close-event").classList.add("hidden");
      clearRewardCards();
      const box = $("event-choices");
      box.innerHTML = "";
      addChoice(box, "离开", "primary", () => {
        finishNodeModal("你空着手退回走廊。");
      });
      renderAll();
      saveGame();
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
      if (inBounds(pos) && !isWall(pos)) cells.push(pos);
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
      if (!inBounds(pos) || isWall(pos)) break;
      cells.push(pos);
    }
  } else {
    const step = Math.sign(p.r - e.r);
    if (!step) return [];
    for (let i = 1; i <= 3; i += 1) {
      const pos = { r: e.r + step * i, c: e.c };
      if (!inBounds(pos) || isWall(pos)) break;
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

/** 首击花 firstCost 后，剩余体力还能追加几段 */
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
 * 推演敌人这一回合会怎么打你：现在就能打 / 走一步再打 / 只是靠近。
 * 红区与实际结算共用这份计划，避免「显示追击却挨了一刀」。
 */
function planEnemyTurn(c) {
  const sees = hasLoS(c.enemyPos, c.playerPos);
  const now = canEnemyAttack(c, manhattan(c.enemyPos, c.playerPos), sees);
  if (now.ok) {
    return { atk: now, hits: plannedHits(c, now, c.enemyStamina), step: null, ctx: c };
  }

  const goal = getEnemyGoal(c);
  if (!goal || c.enemyStamina < 1) return { atk: null, hits: 0, step: null, ctx: c };
  const step = stepEnemyToward(goal);
  if (!step || step.cost > c.enemyStamina) return { atk: null, hits: 0, step: null, ctx: c };

  const after = {
    ...c,
    enemyPos: { ...step.p },
    enemyStamina: c.enemyStamina - step.cost,
  };
  const seesAfter = hasLoS(after.enemyPos, after.playerPos);
  const atk = canEnemyAttack(after, manhattan(after.enemyPos, after.playerPos), seesAfter);
  if (atk.ok) {
    // 当前没视线、走一步才撞上：预告「逼近」但最多 1 段——藏匿后被发现不连打
    const hits = sees ? plannedHits(after, atk, after.enemyStamina) : 1;
    return { atk, hits, step, ctx: after };
  }
  return { atk: null, hits: 0, step, ctx: c };
}

function hurtZoneFromAttack(ctx, atk, hits) {
  const perHit = estimateHurtDamage(ctx);
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
    net: estimateNetTotal(ctx, perHit, hits, ignore),
    attackKind: atk.kind,
  };
}

function predictIntent(c) {
  const sees = hasLoS(c.enemyPos, c.playerPos) && !isEnemyBlinded(c);
  const goal = getEnemyGoal(c);
  const chasingDecoy = !!(decoyAlive(c) && goal && keyOf(goal) === keyOf(c.decoy.pos));

  if (isEnemyBlinded(c) && !chasingDecoy) {
    return {
      type: "search",
      label: "闪瞎",
      detail: "强光致盲：本回合无法锁定你攻击",
      zones: [],
    };
  }

  // Boss 蓄力中：虚线红格预告下回合必落
  if (c.isBoss && c.chargePending) {
    const ch = c.chargePending;
    return {
      type: "attack",
      label: `蓄力 ${ch.damage}`,
      detail: `下回合必落 · 范围半径 ${ch.radius} · 覆盖锚点会砸灭`,
      zones: [
        {
          shape: "rect",
          cells: ch.cells.map((p) => ({ ...p })),
          kind: "hurt",
          damage: ch.damage,
          hits: 1,
          total: ch.damage,
          net: estimateNetTotal(c, ch.damage, 1, false),
          attackKind: "charge",
          pending: true,
        },
      ],
      hits: 1,
      pending: true,
    };
  }

  // 邻接傀儡：预告打碎傀儡（蓝/灰 hurt 在傀儡格）
  if (chasingDecoy && manhattan(c.enemyPos, c.decoy.pos) <= 1 && c.enemyStamina >= effectiveAttackCost(c)) {
    return {
      type: "attack",
      label: "撕影",
      detail: "打碎纸影傀儡",
      zones: [{ shape: "cell", cells: [{ ...c.decoy.pos }], kind: "hurt", damage: 0, attackKind: "decoy" }],
      attack: { ok: true, cost: effectiveAttackCost(c), kind: "decoy", cells: [{ ...c.decoy.pos }] },
    };
  }

  const plan = chasingDecoy ? { atk: null, hits: 0, step: null, ctx: c } : planEnemyTurn(c);

  if (plan.atk) {
    const short = {
      lunge: "突进",
      guardBreak: "破防",
      melee: "挥击",
      slam: "砸地",
      beam: "激光",
      faceShock: "突脸",
    };
    const zone = hurtZoneFromAttack(plan.ctx, plan.atk, plan.hits);
    const tag = `${plan.step ? "逼近" : ""}${short[plan.atk.kind] || "攻击"}`;
    const shots = plan.hits > 1 ? `${zone.damage}×${plan.hits}` : `${zone.damage}`;
    const blocked = zone.net !== zone.total;
    const zones = [zone];
    if (plan.step) zones.push({ shape: "step", cells: [{ ...plan.step.p }], kind: "move" });
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
        plan.step ? `先走到 (${plan.step.p.r + 1},${plan.step.p.c + 1})` : null,
        `耗它行动力 ${plan.atk.cost}`,
      ]
        .filter(Boolean)
        .join(" · "),
      zones,
      attack: plan.atk,
      hits: plan.hits,
    };
  }

  // 移动意图：下一步落点（蓝虚线）——傀儡优先
  let stepPos = null;
  let moveLabel = chasingDecoy ? "追影" : "追击";
  let type = chasingDecoy ? "chase" : "chase";
  if (!chasingDecoy && c.traits?.includes("vault") && sees) {
    const climbOpt = neighbors(c.enemyPos)
      .filter((p) => keyOf(p) !== keyOf(c.playerPos) && climbCost(c.enemyPos, p) > 0)
      .map((p) => ({ p, cost: stepCostTo(c, p), height: tileHeight(p) }))
      .filter((o) => o.cost <= c.enemyStamina)
      .sort((a, b) => b.height - a.height || a.cost - b.cost)[0];
    // 只在不拉远与目标距离时攀爬，避免死守出生高台
    if (climbOpt && climbOpt.height > tileHeight(c.enemyPos)) {
      const goalPos = goal || c.playerPos;
      const afterDist = manhattan(climbOpt.p, goalPos);
      const nowDist = manhattan(c.enemyPos, goalPos);
      if (afterDist <= nowDist) {
        stepPos = climbOpt.p;
        moveLabel = "攀爬";
      }
    }
  }
  if (!stepPos && c.ambushSpring && (sees || chasingDecoy)) {
    const s = stepEnemyToward(goal || c.playerPos);
    if (s) {
      stepPos = s.p;
      moveLabel = "扑出";
    }
  }
  if (!stepPos && goal && c.enemyStamina >= 1 && (sees || chasingDecoy || c.lastSeen)) {
    const s = stepEnemyToward(goal);
    if (s && s.cost <= c.enemyStamina) stepPos = s.p;
    moveLabel = chasingDecoy ? "追影" : sees ? "追击" : "搜索";
    type = sees || chasingDecoy ? "chase" : "search";
  }
  if (!stepPos && c.enemyStamina >= 1 && !sees && !chasingDecoy) {
    return { type: "search", label: "摸索", detail: "尚不知你的位置", zones: [] };
  }
  if (stepPos) {
    return {
      type,
      label: moveLabel,
      detail: `${moveLabel} → (${stepPos.r + 1},${stepPos.c + 1})`,
      zones: [{ shape: "step", cells: [{ ...stepPos }], kind: "move" }],
    };
  }
  return { type: "stall", label: "观望", detail: "体力不足", zones: [] };
}

/** 从 intent.zones 建格 → 威胁信息映射，供渲染 */
function threatMapFromIntent(intent) {
  const map = new Map();
  for (const z of intent?.zones || []) {
    for (const cell of z.cells || []) {
      const k = keyOf(cell);
      const prev = map.get(k);
      if (z.kind === "hurt") {
        map.set(k, {
          kind: "hurt",
          damage: z.damage || 0,
          hits: z.hits || 1,
          total: z.total != null ? z.total : z.damage || 0,
          net: z.net != null ? z.net : z.damage || 0,
          shape: z.shape,
          attackKind: z.attackKind || null,
          pending: !!z.pending,
        });
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
  // 踉跄：破韧后的下回合体力上限降低
  const stamCap = c.staggerNext ? Math.max(1, c.staminaMax - 2) : c.staminaMax;
  if (c.staggerNext) {
    log(`${c.enemy.name}仍在踉跄，本回合体力上限 ${stamCap}。`, "ok");
    c.staggerNext = false;
  }
  c.enemyStamina = stamCap;
  c.enemyMovesThisTurn = 0;
  c.saltSteppedThisTurn = false;
  c.snareForcedThisTurn = false;
  c.portalLanded = false;
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
    log(`${c.enemy.name}踉跄：其下回合体力将下降。`, "ok");
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
  labNoteDamageDealt(dmg, source);
  return dmg;
}

function buildEncounter(room, isBoss) {
  const P = state.data.pressure;
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
  const raw = isBoss
    ? roomDef("altar")?.arena || fallback
    : room.arena || fallback;
  const rows = raw.rows || fallback.rows || 3;
  const cols = raw.cols || fallback.cols || 5;
  const player = raw.player || [Math.floor(rows / 2), 0];
  const enemy = raw.enemy || [Math.floor(rows / 2), cols - 1];
  const walls = new Set([...(raw.walls || [])]);
  const heights = { ...(raw.heights || {}) };
  const playerPos = { r: player[0], c: player[1] };
  const enemyPos = { r: enemy[0], c: enemy[1] };
  // 防死局：墙不能把玩家与敌人完全切开；必要时拆掉挡路的墙格
  ensureArenaPath(rows, cols, walls, playerPos, enemyPos);
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
    heights,
    portals,
    ambush: !!raw.ambush,
    spawnNote: raw.spawnNote || "",
    anchors: [...(raw.anchors || [])],
  };
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
    heights: arena.heights,
    portals: arena.portals || {},
    playerPos: arena.playerPos,
    enemyPos: arena.enemyPos,
    lastSeen: null,
    lastSeenAge: 0,
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
    intent: null,
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
  beginPlayerTurn([]);
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

  // medicine / skill：立刻打出
  resolveInstant(inst);
}

function resolveInstant(inst) {
  const c = state.combat;
  const def = cardDef(inst.id);
  if (def.shove) {
    resolveShove(inst);
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
  // 保留牌打出后仍进弃牌；消耗/临时牌不进弃牌
  retireCard(inst);
  maybeFreeDraw(c, cost);
  playTone("ok");
  if (state.hp <= 0) {
    loseCombat();
    return;
  }
  c.intent = predictIntent(c);
  renderCombat();
}

function tryMovePlayer(pos) {
  const c = state.combat;
  if (c.placeUid) return false;
  if (!isOrthoAdjacent(c.playerPos, pos)) {
    log("只能上下左右移动，不能斜向。", "bad");
    return false;
  }
  if (!isPassable(pos)) {
    log("遮挡物无法通过。", "bad");
    return false;
  }
  if (keyOf(pos) === keyOf(c.playerPos)) return false;
  const passTax = unitPassCost("player", pos);
  const cost = playerMoveCost(c.playerPos, pos);
  if (c.energy < cost) {
    if (passTax > 0) {
      log(`体力不足（穿过敌人需 ${cost}，含敌对穿格 +${passTax}）。`, "bad");
    } else {
      log(`体力不足（移动需 ${cost}，含攀爬）。`, "bad");
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
  if (passTax > 0) log(`擦身而过，多耗 ${passTax} 体力。`);
  playTone("ui");
  const vis = refreshVision();
  if (vis.faceReveal) {
    log(`转过遮挡——突脸！${c.enemy.name}就在视线里。`, "bad");
    playTone("bad");
    if (c.traits?.includes("faceShock")) {
      c.playerExposed = true;
      log("它盯上你了——如果回合结束时你还在视线里，惊吓躲不掉。", "bad");
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
  if (!isPassable(pos) && keyOf(pos) !== keyOf(c.enemyPos)) {
    log("不能放在遮挡物上。", "bad");
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
      dmg += 1;
      combos.push("高台砸击");
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
    drainToughness(1, "砸击削韧");
    const dealt = dealToEnemy(dmg, "smash");
    log(`你把「${def.name}」砸向${c.enemy.name}，造成 ${dealt} 伤害。`, "ok");
    for (const name of combos) comboPop(name);
    playTone("ok");
    if (def.place.onStep.blind) applyBlind(c, def.id || "flare");
    if (c.enemy.hp <= 0) {
      winCombat("kill");
      return true;
    }
  } else if (c.isBoss && c.anchors?.[k]?.lit) {
    // 放置牌砸在亮锚上：拆信号（牌仍落到地上）
    damageAnchorsInCells(c, [pos], 1, "place");
    if (!state.combat) return true;
    c.floor[k] = {
      cardId: inst.id,
      ...def.place,
    };
    log(`「${def.name}」砸上信号锚 (${pos.r + 1},${pos.c + 1})。`, "ok");
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

function triggerFloor(pos, who) {
  const c = state.combat;
  const k = keyOf(pos);
  const item = c.floor[k];
  if (!item) return { tax: 0 };
  let tax = item.enterTax || 0;
  if (who === "enemy" && item.onStep?.forceStepTowardGoal) {
    log(`${c.enemy.name}绊上「${cardDef(item.cardId).name}」。`, "ok");
    delete c.floor[k];
    playTone("ok");
    if (!c.snareForcedThisTurn) {
      c.snareForcedThisTurn = true;
      const goal = getEnemyGoal(c);
      if (goal) {
        const step = stepEnemyToward(goal);
        if (step && keyOf(step.p) !== keyOf(c.playerPos)) {
          c.enemyPos = { ...step.p };
          c.enemyMovesThisTurn = (c.enemyMovesThisTurn || 0) + 1;
          log(`${c.enemy.name}被绊线拽向目标 (${step.p.r + 1},${step.p.c + 1})。`, "ok");
          c.portalLanded = false;
          if (tryPortal("enemy", c.enemyPos)) {
            /* portal */
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
    }
    drainToughness(2, "陷阱削韧");
    const dealt = dealToEnemy(dmg, "trap");
    log(`${c.enemy.name}踩上「${cardDef(item.cardId).name}」受到 ${dealt} 伤害。`, "ok");
    for (const name of combos) comboPop(name);
    if (item.onStep.blind) applyBlind(c, item.cardId || "flare");
    delete c.floor[k];
    playTone("ok");
  } else if (who === "enemy" && item.enterTax) {
    log(`${c.enemy.name}踏入盐圈，多耗体力。`);
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

function stepEnemyToward(goal) {
  const c = state.combat;
  const trapAware = c.traits?.includes("trapAware");
  const vault = c.traits?.includes("vault");
  // 不踩玩家格（贴脸就打，不「穿过」）；可踩傀儡格（落地打碎）
  const opts = neighbors(c.enemyPos)
    .filter((p) => keyOf(p) !== keyOf(c.playerPos))
    .map((p) => {
      const item = c.floor[keyOf(p)];
      const enterTax = item?.enterTax || 0;
      const trapHazard = item?.onStep?.damage ? 2 : enterTax > 0 ? 1 : 0;
      return {
        p,
        dist: manhattan(p, goal),
        cost: stepCostTo(c, p),
        climb: climbCost(c.enemyPos, p),
        trapHazard,
        height: tileHeight(p),
      };
    });
  if (!opts.length) return null;
  opts.sort((a, b) => {
    if (a.dist !== b.dist) return a.dist - b.dist;
    if (trapAware && a.trapHazard !== b.trapHazard) return a.trapHazard - b.trapHazard;
    if (vault && a.height !== b.height) return b.height - a.height;
    return a.cost - b.cost;
  });
  return opts[0];
}

/** 朝目标免费迈一步（埋伏弹簧 / 抄近路），不耗体力 */
function freeStepToward(c, goal, label) {
  const step = stepEnemyToward(goal);
  if (!step) return false;
  c.enemyPos = { ...step.p };
  c.enemyMovesThisTurn = (c.enemyMovesThisTurn || 0) + 1;
  c.chasingDecoy = !!(decoyAlive(c) && goal && keyOf(goal) === keyOf(c.decoy.pos));
  const h = tileHeight(c.enemyPos);
  log(`${c.enemy.name}${label}至 (${step.p.r + 1},${step.p.c + 1})${h ? `高${h}` : ""}。`, "bad");
  resolveEnemyLandOverlap(c);
  c.portalLanded = false;
  if (tryPortal("enemy", c.enemyPos)) {
    /* portal */
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
    c.enemyPos = { ...atk.land.p };
    c.enemyMovesThisTurn += 1;
    log(`${c.enemy.name}突进贴近至 (${atk.land.p.r + 1},${atk.land.p.c + 1})。`, "bad");
    c.portalLanded = false;
    if (tryPortal("enemy", c.enemyPos)) {
      /* portal */
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
      if (c.lastSeen && c.lastSeenAge >= 2) {
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
  // 导播特写：必须先移动才能出手
  const needMoveFirst = c.isBoss && c.directive?.id === "closeup";

  let guard = 16;
  while (c.enemyStamina > 0 && guard-- > 0) {
    const vis = refreshVision();
    const goal = getEnemyGoal(c);
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
        const atk = canEnemyAttack(c, dist, true);
        if (atk.ok) {
          const shaped = ["guardBreak", "slam", "beam", "lunge"].includes(atk.kind);
          const hitKind = shaped ? atk.kind : "faceShock";
          const result = executeEnemyAttack(c, atk, hitKind);
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
          break;
        }
        // 够不着时的惊吓：普通怪 1 伤；Boss 只喊声
        if (c.isBoss) {
          log(`${c.enemy.name}被你吓了一跳，但这一下够不着。`, "ok");
          c.hitsUsed += 1;
          break;
        }
        const died = applyEnemyHit(c, "faceShock", 1);
        c.hitsUsed += 1;
        if (died) {
          loseCombat("hp");
          return;
        }
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
          c.enemyPos = { ...best.p };
          log(
            `${c.enemy.name}攀上高台 (${best.p.r + 1},${best.p.c + 1})高${best.height}（耗${best.cost}）。`,
            "bad",
          );
          resolveEnemyLandOverlap(c);
          c.portalLanded = false;
          if (tryPortal("enemy", c.enemyPos)) {
            /* portal */
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
        // 出手后只尝试连击；刀数用尽则收工。绝不再用剩体力走路（贴脸挪开会像后退）
        if (c.hitsUsed < c.hitBudget) continue;
        break;
      }
    }

    if (c.ambushActive && !vis.enemySees && !c.chasingDecoy) {
      log(`${c.enemy.name}仍藏在出生点，没有下来搜索。`);
      break;
    }
    if (!goal) {
      log(`${c.enemy.name}还不知道你的位置。`);
      break;
    }
    // 本回合已经打过：不再追步（连击打不满时也不要把剩体力走成“后退”）
    if (c.hitsUsed > 0) break;
    const step = stepEnemyToward(goal);
    if (!step || step.cost > c.enemyStamina) {
      log(`${c.enemy.name}在遮挡后停住了。`);
      break;
    }
    c.enemyStamina -= step.cost;
    c.enemyMovesThisTurn += 1;
    c.enemyPos = { ...step.p };
    const h = tileHeight(c.enemyPos);
    const verb = c.chasingDecoy ? "追影" : c.directive?.id === "spotlight" ? "奔锚" : vis.enemySees ? "追击" : "搜索";
    log(
      `${c.enemy.name}${verb}至 (${step.p.r + 1},${step.p.c + 1})${h ? `高${h}` : ""}（耗${step.cost}）。`,
    );
    resolveEnemyLandOverlap(c);
    c.portalLanded = false;
    if (tryPortal("enemy", c.enemyPos)) {
      /* portal */
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
  // 丢视线后气味会散：连续 2 个敌回合找不到，就忘掉 lastSeen
  if (!endVis.enemySees) {
    c.lastSeenAge = (c.lastSeenAge || 0) + 1;
    if (c.lastSeen && c.lastSeenAge >= 2) {
      c.lastSeen = null;
      log(`${c.enemy.name}在遮挡后失去了你的踪迹。`, "ok");
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
  $("enemy-stamina").textContent = `${c.enemyStamina}/${c.staminaMax}`;
  $("enemy-intent").textContent = c.intent?.label || "观望";
  $("enemy-intent").className = `intent-banner intent-${c.intent?.type || "chase"}${c.intent?.pending ? " pending" : ""}`;
  $("enemy-intent").title = c.intent?.detail || c.intent?.label || "";
  $("enemy-hp").textContent = c.playerSeesEnemy ? String(c.enemy.hp) : "??";
  $("player-block").textContent = String(c.block + coverBlockAtPlayer());
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
  if (c.placeUid) {
    const inst = c.hand.find((x) => x.uid === c.placeUid);
    const msg = inst
      ? `放置「${cardDef(inst.id).name}」：点高亮邻格放下；有视线可点敌人砸击`
      : "";
    hint.textContent = msg;
    if (cardHint) cardHint.textContent = "放置模式";
    $("btn-cancel-place").classList.remove("hidden");
  } else {
    hint.textContent = c.isBoss
      ? "烛=亮锚 · 灰=熄灭 · 虚线红=蓄力预告 · 站锚上可「拆信号」· 引砸可灭锚"
      : "红格数字=它这回合会打你多少（2×2 即两段共 4，→后为格挡后实伤）· 蓝=它下一步 · 绿=可走";
    if (cardHint) cardHint.textContent = c.archetypeDesc;
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

function renderBattleGrid() {
  const c = state.combat;
  const g = combatGrid();
  const box = $("battle-grid");
  box.style.gridTemplateColumns = `repeat(${g.cols}, minmax(40px, 1fr))`;
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
      const h = tileHeight(pos);
      const isP = keyOf(c.playerPos) === k;
      const isE = keyOf(c.enemyPos) === k;
      const item = c.floor[k];
      const adjP = isOrthoAdjacent(pos, c.playerPos) && !wall;
      const threat = threats.get(k);

      if (wall) {
        cell.classList.add("is-wall");
        cell.disabled = true;
        cell.innerHTML = `<span>墙</span>`;
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
        if (threat.pending) cell.classList.add("pending-hurt");
        if (isP) cell.classList.add("threat-on-you");
      } else if (threat?.kind === "move") {
        cell.classList.add("threat-move");
      }

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
      if (c.portals?.[k]) bits.push("门");
      if (anchor?.lit) bits.push(`烛${anchor.hp}`);
      else if (anchor && !anchor.lit) bits.push("灰");
      if (item) bits.push(item.glyph || "物");
      if (isDecoy) bits.push("影");
      if (h) bits.push(`↑${h}`);
      let pawnHtml = "";
      if (isP) {
        pawnHtml +=
          `<span class="battle-pawn player-pawn"><img class="char-token" src="assets/ui/chars/SP_Lili_Pixel.png" alt="你" width="28" height="28" draggable="false" /></span>`;
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
      const shots = threat?.hits > 1 ? `${threat.damage}×${threat.hits}` : `${threat?.damage}`;
      const dmgHtml =
        threat?.kind === "hurt" && threat.damage
          ? `<span class="threat-dmg">${
              threat.net !== threat.total ? `${shots}→${threat.net}` : shots
            }</span>`
          : threat?.kind === "hurt" && threat.attackKind === "decoy"
            ? `<span class="threat-dmg">影</span>`
            : "";
      const meta = bits.length ? `<span class="cell-meta">${bits.join(" ")}</span>` : "";
      cell.innerHTML = `${dmgHtml}${pawnHtml}${meta || (!isP && !isE && !isDecoy && !dmgHtml ? "<span>·</span>" : "")}`;
      cell.title = [
        wall ? "墙" : "空地",
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
            ? `${threat.pending ? "蓄力预告" : "威胁"} · ${threat.hits > 1 ? `${threat.damage}×${threat.hits} = ${threat.total}` : `${threat.damage}`} 伤${
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
  // 同步短 banner
  const banner = $("enemy-intent");
  if (banner) {
    banner.textContent = c.intent?.label || "观望";
    banner.className = `intent-banner intent-${c.intent?.type || "chase"}`;
    banner.title = c.intent?.detail || "";
  }
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
  finalizeLabCombat("lose", isBoss ? fail?.title || "失败" : "节目中断", broadcast ? "broadcast" : "hp");
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
    "结局·节目中断",
    `你在${roomName}没能逃掉。\n山屋把这一集掐灭了——按下「再看一集」重开一局。\n${fail.text}`,
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
    <p class="boss-kit-tip">双轨通关：熄灭全部信号锚，或打空血条。播出进度满则失败。引它砸地可砸灭锚点；蓄力回合红格提前亮出。</p>
  `;
}

function renderTraitChips(c) {
  const box = $("enemy-traits");
  if (!box) return;
  const labels = state.data.pressure?.traitLabels || {};
  const bits = [];
  if (c.archetypeLabel) {
    bits.push(`<span class="trait-chip trait-arch" title="${c.archetypeDesc || ""}">${c.archetypeLabel}</span>`);
  }
  for (const t of c.traits || []) {
    bits.push(`<span class="trait-chip" title="${labels[t] || t}">${labels[t] || t}</span>`);
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
  $("boss-hp").textContent = `生命 ${preview.hp} · 伤害 ${preview.damage} · 韧性 ${preview.toughness} · 仪式双轨（熄锚/击杀）`;
  fillBossKit(preview);
  const actions = $("boss-actions");
  actions.innerHTML = "";
  addChoice(actions, "进入场地决战", "primary", () => {
    startCombat({ id: "altar", enemy: boss }, true);
  });
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
      skipToBossTest();
    } catch (err) {
      console.error(err);
      alert(`无法跳转 Boss：${err.message}`);
    }
  };
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
    if (exitBtn) exitBtn.classList.add("hidden");
    showModal(null);
    show("screen-title");
  };
  const qteBtn = $("btn-qte-test");
  if (qteBtn) {
    qteBtn.onclick = () => {
      show("screen-title");
      showModal("screen-qte");
      const exitBtn = $("btn-qte-exit");
      if (exitBtn) exitBtn.classList.add("hidden");
      if (!window.CabinQte) return;
      CabinQte.start({
        title: "信号咬合（试玩）",
        onDone: (result) => {
          const status = $("qte-status");
          if (status) {
            status.textContent = result.ok
              ? result.message + "（正式局里过关才会发静室奖励）"
              : result.message + "（正式局里失败只丢奖励）";
          }
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
  window.addEventListener("resize", hideCardTooltip);
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
  $("btn-mute").onclick = () => {
    state.muted = !state.muted;
    setMuted(state.muted);
    try {
      localStorage.setItem("cabin-mute", state.muted ? "1" : "0");
    } catch (_) {}
    updateMuteButton();
    if (!state.muted) startBgm();
  };
  $("btn-reroll-map")?.addEventListener("click", () => rerollMapRun());
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
    if (status) status.textContent = "准备就绪——按下「打开电视机」就开始吧。";
    show("screen-title");
    if (localStorage.getItem(SAVE_KEY)) $("btn-continue").classList.remove("hidden");
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
  resetGame,
  startTutorial,
  exitTutorialMode,
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
  rerollMapRun,
  goHome,
  combatGoHome,
};
