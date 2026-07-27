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
  state.data = { rooms, cards, relics, bosses, pressure };
}

function show(id) {
  document.querySelectorAll(".panel").forEach((el) => el.classList.remove("active"));
  $(id).classList.add("active");
}

function showModal(id) {
  document.querySelectorAll(".panel.modal").forEach((el) => el.classList.remove("active"));
  if (id) $(id).classList.add("active");
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
  return state.data.rooms.rooms[id];
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
  // 对端被占则不传（玩家/怪/傀儡）
  const blocked =
    (who !== "player" && keyOf(dest) === keyOf(c.playerPos)) ||
    (who !== "enemy" && keyOf(dest) === keyOf(c.enemyPos)) ||
    (decoyAlive(c) && keyOf(dest) === keyOf(c.decoy.pos));
  if (blocked || isWall(dest) || !inBounds(dest)) {
    log("传送门嗡了一下，但对端被挡住了。");
    return false;
  }
  if (who === "player") c.playerPos = { ...dest };
  else if (who === "enemy") c.enemyPos = { ...dest };
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
  if (!inBounds(dest) || isWall(dest) || keyOf(dest) === keyOf(c.playerPos) || (decoyAlive(c) && keyOf(dest) === keyOf(c.decoy.pos))) {
    drainToughness(1, "推撞撞墙削韧");
    log(`推撞：${c.enemy.name}撞上障碍，韧性 -1。`, "ok");
    playTone("ok");
  } else {
    c.enemyPos = { ...dest };
    log(`你把${c.enemy.name}推到 (${dest.r + 1},${dest.c + 1})。`, "ok");
    playTone("ok");
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

function refreshVision() {
  const c = state.combat;
  if (!c) return { playerSees: false, enemySees: false, faceReveal: false };
  const playerSees = hasLoS(c.playerPos, c.enemyPos);
  const enemySees = hasLoS(c.enemyPos, c.playerPos);
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
  } else {
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
    uidSeq = p.uidSeq || 100;
    return true;
  } catch {
    return false;
  }
}

function resetGame() {
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
  discoverNeighbors(state.roomId);
  log("电视机亮起来了。山屋里的怪家伙有韧性——得用机关绊住再破韧。");
  log("行前先选一枚预兆；玄关只是出发坐标，不再发第二份奖励。");
  renderAll();
  show("screen-game");
  saveGame();
  offerOpeningRelics();
}

/** 调试：模拟一局成长结束 + 满血，直接进 Boss 决战测强度 */
function skipToBossTest() {
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
  const size = state.data.rooms.mapSize || { cols: 6, rows: 7 };
  box.style.gridTemplateColumns = `repeat(${size.cols}, minmax(0, 1fr))`;
  box.style.gridTemplateRows = `repeat(${size.rows}, minmax(0, 1fr))`;
  box.innerHTML = "";
  const here = roomDef(state.roomId);
  const exits = new Set(here.exits || []);
  for (const room of Object.values(state.data.rooms.rooms)) {
    const btn = document.createElement("button");
    btn.className = "map-node";
    btn.style.gridColumn = String(room.map.col);
    btn.style.gridRow = String(room.map.row);
    const known = state.knownRooms.has(room.id);
    const visited = state.resolvedRooms.has(room.id) || state.visitPath.includes(room.id);
    if (!known) {
      btn.classList.add("unknown");
      btn.disabled = true;
    } else {
      const label = document.createElement("span");
      label.className = "map-node-label";
      label.textContent = room.name;
      btn.appendChild(label);
      if (room.combat) btn.classList.add("combat-known");
      else btn.classList.add("safe-known");
      if (visited) btn.classList.add("visited");
      if (room.id === state.roomId) {
        btn.classList.add("current");
        btn.title = `${room.name}（你在这里）`;
        const pawn = document.createElement("span");
        pawn.className = "map-pawn";
        pawn.setAttribute("aria-label", `你在${room.name}`);
        pawn.innerHTML =
          `<img class="char-token" src="assets/ui/chars/SP_Lili_Pixel.png" alt="你" width="32" height="32" draggable="false" />`;
        btn.appendChild(pawn);
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
  $("room-tag").textContent = room.bossRoom
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
  if (room.combat) startCombat(room, false);
  else startNonCombat(room);
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
  // 已摇过的奖励从存档取，防止刷新页面重摇
  let rolled = state.rewardRolls[room.id];
  if (!rolled) {
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
    rolled = { kind, id, midGuaranteed: isMid };
    state.rewardRolls[room.id] = rolled;
    saveGame();
  }
  const kind = rolled.kind;

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

  $("event-text").textContent = "静室提供数值，也可放弃。";
  const pool = [
    { id: "speed", weight: 0.35, label: "速度 +1", apply: () => { state.speed += 1; log("速度 S +1", "ok"); } },
    { id: "max", weight: 1, label: "生命上限 +1 并治疗 1", apply: () => { state.maxHp += 1; state.hp = Math.min(state.maxHp, state.hp + 1); log("生命上限 +1", "ok"); } },
    { id: "heal", weight: 1, label: "恢复 2 生命", apply: () => { state.hp = Math.min(state.maxHp, state.hp + 2); log("恢复 2 生命", "ok"); } },
  ];
  const picked = [];
  const bag = [...pool];
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
    addChoice(box, opt.label, "", () => {
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

function offerCardReward({ title, lead, offers, onDone }) {
  showModal("screen-event");
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
  addChoice(box, "放弃这次机会", "", () => {
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

function combatTier() {
  const curve = state.data.pressure?.combatCurve || [1, 2, 4, 3, 1, 5];
  const idx = Math.min(Math.max(0, (state.combatCount || 1) - 1), curve.length - 1);
  return curve[idx];
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
  const sees = hasLoS(c.enemyPos, c.playerPos);
  const goal = getEnemyGoal(c);
  const chasingDecoy = !!(decoyAlive(c) && goal && keyOf(goal) === keyOf(c.decoy.pos));

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
      .filter((p) => !(decoyAlive(c) && keyOf(p) === keyOf(c.decoy.pos)))
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
  if (keyOf(pos) === keyOf(c.enemyPos)) return false;
  const cost = state.data.cards.moveCost + climbCost(c.playerPos, pos, true);
  if (c.energy < cost) {
    log(`体力不足（移动需 ${cost}，含攀爬）。`, "bad");
    return false;
  }
  if (decoyAlive(c) && keyOf(pos) === keyOf(c.decoy.pos)) {
    log("傀儡占着这格。", "bad");
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
    if (def.place.onStep.blind) {
      c.lastSeen = null;
      c.blindArmed = true;
      log("强光炸开——它暂时丢失了你的踪迹。", "ok");
    }
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
    if (item.onStep.blind) {
      c.lastSeen = null;
      c.blindArmed = true;
      log("强光炸开——它丢失了你的踪迹。", "ok");
    }
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
  const opts = neighbors(c.enemyPos)
    .filter((p) => keyOf(p) !== keyOf(c.playerPos))
    .filter((p) => !(decoyAlive(c) && keyOf(p) === keyOf(c.decoy.pos)))
    .map((p) => {
      const item = c.floor[keyOf(p)];
      const enterTax = item?.enterTax || 0;
      const climb = climbCost(c.enemyPos, p);
      const leaveTax = c.floor[keyOf(c.enemyPos)]?.enterTax || 0;
      const trapHazard = item?.onStep?.damage ? 2 : enterTax > 0 ? 1 : 0;
      return {
        p,
        dist: manhattan(p, goal),
        cost: 1 + leaveTax + enterTax + climb,
        climb,
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
    return;
  }
  if (c.isBoss && shouldBossCharge(c)) {
    beginBossCharge(c);
    // 蓄力回合：不动不出手，红格已预告
    if (tickBroadcast(c) || !state.combat) return;
    return;
  }

  // 回合开始时若没有视线：本回合最多打 1 下（突脸/重新发现），不给连击清算
  const sawAtStart = hasLoS(c.enemyPos, c.playerPos);
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

    // vault：仅当攀爬不拉远与目标的距离时才优先上高台
    if (!c.chasingDecoy && c.traits?.includes("vault") && vis.enemySees) {
      const climbOpts = neighbors(c.enemyPos)
        .filter((p) => keyOf(p) !== keyOf(c.playerPos) && climbCost(c.enemyPos, p) > 0)
        .filter((p) => !(decoyAlive(c) && keyOf(p) === keyOf(c.decoy.pos)))
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
        // 已经贴脸打过：本回合收工，别把剩余体力花在原地再砸
        if (c.enemyMovesThisTurn === 0) break;
        continue;
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
    if (c.hitsUsed >= c.hitBudget) break;
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
      // 威胁优先：有 hurt 时不盖绿色可走提示
      if (!c.placeUid && adjP && !isE && !isP && !isDecoy && threat?.kind !== "hurt") {
        cell.classList.add("move-ok");
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
        pawnHtml =
          `<span class="battle-pawn player-pawn"><img class="char-token" src="assets/ui/chars/SP_Lili_Pixel.png" alt="你" width="28" height="28" draggable="false" /></span>`;
      } else if (isE && sees) {
        pawnHtml =
          `<span class="battle-pawn enemy-pawn"><img class="char-token" src="assets/ui/chars/SP_Enemy_Pixel.png" alt="敌" width="28" height="28" draggable="false" /></span>`;
      } else if (isE && !sees) {
        pawnHtml = `<span class="battle-pawn enemy-pawn fog-pawn" aria-label="未知">?</span>`;
      } else if (isDecoy) {
        pawnHtml = `<span class="battle-pawn decoy-pawn" aria-label="纸影">影</span>`;
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
}

function endTurn() {
  const c = state.combat;
  if (!c) return;
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
    if (isTempCard(left)) continue; // 临时牌回合结束消失
    if (c.heldUid && left.uid === c.heldUid && kept.filter((k) => !cardDef(k.id).retain).length < budget) {
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
    state.combat = null;
    endGame(true, ritual ? `${title} · 掐断仪式` : title, body);
    return;
  }
  finalizeLabCombat("win", null, "kill");
  for (const left of c.hand || []) retireCard(left);
  state.discard = purgeTempCards(state.discard);
  state.deck = purgeTempCards(state.deck);
  state.combat = null;
  const pool = [...state.data.cards.rewardPool];
  shuffle(pool);
  offerCardReward({
    title: "惊吓结束 · 要不要新道具？",
    lead: "今天的惊吓时间结束啦。最多收下一张道具卡，觉得会卡手也可以不要。",
    offers: pool.slice(0, 2),
    onDone: (msg) => {
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
  showModal(null);
  show("screen-end");
  const result = $("end-result");
  const art = $("end-art");
  if (result) {
    result.textContent = won ? "通关 · 你赢了" : "失败 · 节目中断";
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
      labNote.textContent = `本场已写入实验记录：${last.outcome === "win" ? "胜" : "负"} · ${s.turns || 0} 回合 · 输出 ${s.damageDealt || 0} / 受伤 ${s.damageTaken || 0}（标题页可导出 JSON）`;
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
  $("btn-restart").onclick = () => {
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
    $("btn-mute").textContent = state.muted ? "声音：关" : "声音：开";
    if (!state.muted) startBgm();
  };
}

async function main() {
  bindUi();
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
};
