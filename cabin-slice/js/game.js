const { playTone, setMuted, startBgm } = window.CabinAudio || {
  playTone() {},
  setMuted() {},
  startBgm() {},
};

let uidSeq = 1;
const SAVE_KEY = "cabin-run-v3";

const state = {
  data: null,
  roomId: null,
  speed: 3,
  hp: 5,
  maxHp: 5,
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
  const el = $("combo-toast");
  if (el) {
    el.textContent = `连击·${name}`;
    el.classList.remove("show");
    void el.offsetWidth;
    el.classList.add("show");
  }
}

function getEnemyGoal(c) {
  if (c.decoy?.pos) return { ...c.decoy.pos };
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
  if (c.decoy.hp <= 0) c.decoy = null;
  playTone("ok");
  return true;
}

function tickDecoyTtl(c) {
  if (!decoyAlive(c)) return;
  c.decoy.ttl = (c.decoy.ttl || 0) - 1;
  if (c.decoy.ttl <= 0) {
    log("纸影傀儡消散了。");
    c.decoy = null;
  }
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
  state.hp = 5;
  state.maxHp = 5;
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
  $("log").innerHTML = "";
  discoverNeighbors(state.roomId);
  log("电视机亮起来了。山屋里的怪家伙有韧性——得用机关绊住再破韧。");
  log("行前先选一枚预兆；玄关只是出发坐标，不再发第二份奖励。");
  renderAll();
  show("screen-game");
  saveGame();
  offerOpeningRelics();
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
    const boss = state.data.bosses.bosses[rule.boss];
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
    if (roomDef(id).bossRoom) continue;
    const btn = document.createElement("button");
    btn.className = "btn";
    btn.textContent = state.knownRooms.has(id) ? `前往 ${roomDef(id).name}` : "前往未知房间";
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

  // slam AoE：距 ≤2
  if (c.traits?.includes("slam") && dist <= 2 && c.enemyStamina >= cost) {
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

/** 每回合最多打你几下：默认单段，带「连击」词条才多段（段数始终在红字里写明） */
function maxHitsPerTurn(c) {
  if (!c.traits?.includes("flurry")) return 1;
  return c.isBoss ? 3 : 2;
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
    return { atk, hits: plannedHits(after, atk, after.enemyStamina), step, ctx: after };
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
  }
  c.intent = predictIntent(c);
  c.hand = kept;
  const need = Math.max(0, state.data.cards.handSize - c.hand.length);
  c.hand.push(...drawHand(need));
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
  };
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
    c.decoy = { pos: { ...pos }, hp: 1, ttl: 2 };
    log(`纸影傀儡立在 (${pos.r + 1},${pos.c + 1})——怪会优先追它。`, "ok");
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
      winCombat();
      return true;
    }
  } else {
    c.floor[k] = {
      cardId: inst.id,
      ...def.place,
    };
    if (onEnemy) log(`「${def.name}」落到${c.enemy.name}脚下。`, "ok");
    else log(`放置「${def.name}」于 (${pos.r + 1},${pos.c + 1})。`, "ok");
    playTone("ok");
  }

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
    incoming = remain;
    if (blockUsed + innUsed > 0) {
      log(
        `格挡/掩护抵消 ${blockUsed + innUsed}（预估 ${raw} → ${incoming}）。`,
        incoming > 0 ? "" : "ok",
      );
    }
  }

  if (incoming > 0) {
    state.hp -= incoming;
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
  // 段数按回合开始时的预告锁定，玩家看到的红字就是实际会挨的刀数
  c.hitBudget = Math.max(1, predictIntent(c)?.hits || 1);
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
        winCombat();
        return;
      }
    }

    const selfExposed = c.playerExposed && vis.enemySees && !vis.faceReveal;
    c.playerExposed = false;
    if (!c.chasingDecoy && c.hitsUsed < c.hitBudget && (vis.faceReveal || selfExposed)) {
      if (selfExposed) log(`${c.enemy.name}早就盯着你暴露的位置——惊吓扑面而来！`, "bad");
      else log(`突脸！${c.enemy.name}拐过遮挡看见了你。`, "bad");
      playTone("face");

      if (c.traits?.includes("cornerCut") && vis.enemySees) {
        freeStepToward(c, c.playerPos, "抄近路");
        if (c.enemy.hp <= 0) {
          winCombat();
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
            winCombat();
            return;
          }
          if (result === "lose") {
            loseCombat();
            return;
          }
          continue;
        }
        // 够不着时的惊吓：1 伤，同样吃格挡
        const died = applyEnemyHit(c, "faceShock", 1);
        c.hitsUsed += 1;
        if (died) {
          loseCombat();
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
            winCombat();
            return;
          }
          continue;
        }
      }
    }

    if (!c.chasingDecoy && c.hitsUsed < c.hitBudget) {
      const dist = manhattan(c.enemyPos, c.playerPos);
      const atk = canEnemyAttack(c, dist, vis.enemySees);
      if (atk.ok) {
        const result = executeEnemyAttack(c, atk, atk.kind);
        c.hitsUsed += 1;
        if (result === "win") {
          winCombat();
          return;
        }
        if (result === "lose") {
          loseCombat();
          return;
        }
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
    // 预告的刀数已打完：不再追步，收工（避免超出红字的额外伤害）
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
    const verb = c.chasingDecoy ? "追影" : vis.enemySees ? "追击" : "搜索";
    log(
      `${c.enemy.name}${verb}至 (${step.p.r + 1},${step.p.c + 1})${h ? `高${h}` : ""}（耗${step.cost}）。`,
    );
    c.portalLanded = false;
    if (tryPortal("enemy", c.enemyPos)) {
      /* portal */
    }
    triggerFloor(c.enemyPos, "enemy");
    if (c.enemy.hp <= 0) {
      winCombat();
      return;
    }
  }
  tickDecoyTtl(c);
  refreshVision();
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
  $("card-check-label").textContent = `${c.roomName} · ${c.archetypeLabel} · 难度档 ${c.tier}`;
  $("card-energy").textContent = String(c.energy);
  $("enemy-stamina").textContent = `${c.enemyStamina}/${c.staminaMax}`;
  $("enemy-intent").textContent = c.intent?.label || "观望";
  $("enemy-intent").className = `intent-banner intent-${c.intent?.type || "chase"}`;
  $("enemy-intent").title = c.intent?.detail || c.intent?.label || "";
  $("enemy-hp").textContent = c.playerSeesEnemy ? String(c.enemy.hp) : "??";
  $("player-block").textContent = String(c.block + coverBlockAtPlayer());
  $("player-hp").textContent = `${state.hp}/${state.maxHp}`;

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
    hint.textContent =
      "红格数字=它这回合会打你多少（2×2 即两段共 4，→后为格挡后实伤）· 蓝=它下一步 · 绿=可走";
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

      if (threat?.kind === "hurt") {
        cell.classList.add("threat-hurt");
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
        item ? cardDef(item.cardId)?.name : null,
        isDecoy ? "纸影傀儡（嘲讽）" : null,
        isP ? "你在这里" : null,
        isE && sees ? c.enemy.name : null,
        isE && !sees ? "有动静，但看不见" : null,
        threat?.kind === "hurt"
          ? threat.damage
            ? `威胁 · ${threat.hits > 1 ? `${threat.damage}×${threat.hits} = ${threat.total}` : `${threat.damage}`} 伤${
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

function winCombat() {
  const c = state.combat;
  const isBoss = c.isBoss;
  for (const left of c.hand || []) retireCard(left);
  state.discard = purgeTempCards(state.discard);
  state.deck = purgeTempCards(state.deck);
  state.combat = null;
  if (isBoss) {
    const boss = state.data.bosses.bosses[state.chosenBoss];
    const ending = state.data.bosses.endings[boss.endingId];
    endGame(true, ending.title, `${boss.victory}\n${ending.text}`);
    return;
  }
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

function loseCombat() {
  const c = state.combat;
  const isBoss = c?.isBoss;
  const roomName = c?.roomName || "山屋";
  if (c) {
    for (const left of c.hand || []) retireCard(left);
  }
  state.discard = purgeTempCards(state.discard);
  state.deck = purgeTempCards(state.deck);
  state.combat = null;
  const fail = state.data.bosses.endings.end_fail;
  if (isBoss) {
    const boss = state.data.bosses.bosses[state.chosenBoss];
    endGame(false, fail.title, boss?.defeat ? `${boss.defeat}\n${fail.text}` : fail.text);
    return;
  }
  // 普通战斗失败也直接终局：逃出后缺牌难翻盘，不如重开
  endGame(
    false,
    "结局·节目中断",
    `你在${roomName}没能逃掉。\n山屋把这一集掐灭了——按下「再看一集」重开一局。\n${fail.text}`,
  );
}

function openBoss() {
  if (!runReadyForBoss()) return;
  state.chosenBoss = state.chosenBoss || pickBossId();
  const boss = state.data.bosses.bosses[state.chosenBoss];
  // 用 buildEncounter 预览含压力加成的实战数值，而非 bosses.json 原始值
  const preview = buildEncounter(null, true);
  showModal("screen-boss");
  $("boss-name").textContent = boss.name;
  $("boss-phase-text").textContent = boss.intro;
  $("boss-hp").textContent = `生命 ${preview.hp} · 伤害 ${preview.damage} · 韧性 ${preview.toughness}`;
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
  showModal(null);
  show("screen-end");
  $("end-title").textContent = title;
  $("end-log").textContent = text;
  playTone(won ? "ok" : "bad");
  localStorage.removeItem(SAVE_KEY);
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
  $("btn-mute").onclick = () => {
    state.muted = !state.muted;
    setMuted(state.muted);
    $("btn-mute").textContent = state.muted ? "声音：关" : "声音：开";
    if (!state.muted) startBgm();
  };
}

async function main() {
  bindUi();
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
