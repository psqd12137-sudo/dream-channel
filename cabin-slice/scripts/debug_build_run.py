#!/usr/bin/env python3
"""调试：跑一局摆房流程，输出完整日志并在异常时转储状态。"""

import json
import time

from playwright.sync_api import sync_playwright

BASE = "http://127.0.0.1:8787/"

LOG = []

CLICK_CHOICE_JS = r"""
({ preferHeal, takeCards, relicPrefer, cardPrefer }) => {
  const event = document.getElementById("screen-event");
  const boss = document.getElementById("screen-boss");
  const end = document.getElementById("screen-end");
  if (end && end.classList.contains("active")) return { clicked: false, phase: "end" };
  if (boss && boss.classList.contains("active")) return { clicked: false, phase: "boss" };
  if (document.getElementById("screen-puzzle")?.classList.contains("active")) {
    const f = document.getElementById("btn-puzzle-forfeit");
    if (f) { f.click(); return { clicked: true, phase: "puzzle-forfeit" }; }
    return { clicked: false, phase: "puzzle" };
  }
  if (document.getElementById("screen-qte")?.classList.contains("active")) {
    const f = document.getElementById("btn-qte-forfeit");
    if (f) { f.click(); return { clicked: true, phase: "qte-forfeit" }; }
    return { clicked: false, phase: "qte" };
  }
  if (!(event && event.classList.contains("active"))) return { clicked: false, phase: "none" };
  const rewardBtns = [...document.querySelectorAll("#reward-cards button")];
  if (rewardBtns.length) {
    const cards = [...document.querySelectorAll("#reward-cards .reward-card")];
    if (cards.length && /预兆|行前/.test(document.getElementById("event-title")?.textContent||"")) {
      let best = 0; let bestScore = 99;
      cards.forEach((card, i) => {
        const t = card.textContent || "";
        let s = 9;
        if (/纸影/.test(t)) s = relicPrefer.indexOf("omen_decoy");
        else if (/火漆/.test(t)) s = relicPrefer.indexOf("omen_flint");
        else if (/盐/.test(t)) s = relicPrefer.indexOf("omen_salt");
        else if (/信号/.test(t)) s = relicPrefer.indexOf("omen_signal");
        else if (/铃/.test(t)) s = relicPrefer.indexOf("omen_bell");
        else if (/靴/.test(t)) s = relicPrefer.indexOf("omen_boots");
        if (s < 0) s = 9;
        if (s < bestScore) { bestScore = s; best = i; }
      });
      const take = cards[best].querySelector("button");
      if (take) { take.click(); return { clicked: true, phase: "opening-relic" }; }
    }
    if (takeCards) {
      const take = (cards[0]?.querySelector("button")) || rewardBtns[0];
      take.click();
      return { clicked: true, phase: "take-card" };
    }
  }
  const box = document.getElementById("event-choices");
  const btns = [...(box?.querySelectorAll("button")||[])];
  if (!btns.length) {
    const close = document.getElementById("btn-close-event");
    if (close && !close.classList.contains("hidden")) {
      close.click();
      return { clicked: true, phase: "close-event" };
    }
    return { clicked: false, phase: "event-empty" };
  }
  const labels = btns.map(b => b.textContent || "");
  const pick = (pred) => labels.findIndex(pred);
  let i = -1;
  if (preferHeal) i = pick(t => /恢复|生命上限/.test(t));
  if (i < 0) i = pick(t => /收下预兆|带上|接受|继续前进|离开/.test(t) && !/放弃|什么都不要|先回去/.test(t));
  if (i < 0 && takeCards) i = pick(t => /收下/.test(t));
  if (i < 0) i = pick(t => /速度/.test(t));
  if (i < 0) i = pick(t => !/放弃|什么都不要|先回去/.test(t));
  if (i < 0) i = 0;
  btns[i].click();
  return { clicked: true, phase: "choice", label: labels[i] };
}
"""

COMBAT_STEP_JS = r"""
() => {
  const D = window.CabinDebug;
  const c = D.getState().combat;
  if (!c) return { done: true, reason: "no-combat" };
  const keyOf = D.keyOf;
  const neighbors = D.neighbors;
  const isPassable = D.isPassable;
  const manh = D.manhattan;
  const pk = keyOf(c.playerPos);
  const intent = c.intent;
  const pendingHurt = new Set();
  const threatNow = new Set();
  for (const z of intent?.zones || []) {
    if (z.kind !== "hurt") continue;
    for (const p of z.cells || []) {
      const k = keyOf(p);
      if (z.pending || intent?.pending) pendingHurt.add(k);
      else threatNow.add(k);
    }
  }
  function stepToward(goal, avoidThreat) {
    const opts = neighbors(c.playerPos)
      .filter(p => isPassable(p) && keyOf(p) !== keyOf(c.enemyPos))
      .map(p => ({ p, d: manh(p, goal), k: keyOf(p) }))
      .sort((a, b) => a.d - b.d || Math.random() - 0.5);
    for (const o of opts) {
      if (avoidThreat && (pendingHurt.has(o.k) || threatNow.has(o.k)) && opts.some(x => !pendingHurt.has(x.k) && !threatNow.has(x.k))) continue;
      if (D.tryMovePlayer(o.p)) return true;
    }
    return false;
  }
  function stepAway(avoidThreat) {
    const opts = neighbors(c.playerPos)
      .filter(p => isPassable(p) && keyOf(p) !== keyOf(c.enemyPos))
      .map(p => ({ p, d: manh(p, c.enemyPos), k: keyOf(p) }))
      .sort((a, b) => b.d - a.d);
    for (const o of opts) {
      if (avoidThreat && (pendingHurt.has(o.k) || threatNow.has(o.k))) continue;
      if (D.tryMovePlayer(o.p)) return true;
    }
    return false;
  }
  const dist = manh(c.playerPos, c.enemyPos);
  if (c.isBoss && c.anchors?.[pk]?.lit) {
    const cost = 3;
    if (c.energy >= cost) { D.tryDismantleAnchor(); return { action: "dismantle" }; }
  }
  if (c.playerSeesEnemy && !c.ready) {
    if (stepToward(c.enemyPos, true)) return { action: "move-enemy" };
  }
  if (threatNow.has(pk) || pendingHurt.has(pk)) {
    if (stepAway(true)) return { action: "flee" };
  }
  D.endTurn();
  return { action: "end-turn" };
}
"""

EXPLORE_STEP_JS = r"""
({ preferCombat, preferQuiet }) => {
  const D = window.CabinDebug;
  const st = D.getState();
  if (st.combat) return { action: "in-combat" };
  if (D.runReadyForBoss()) return { action: "boss-ready" };
  if (st.nodePending) {
    D.resolveCurrentNode();
    return { action: "resolve-node", room: st.roomId };
  }
  if (D.isPlayerLayoutMode && D.isPlayerLayoutMode()) {
    const hereR = D.roomDef(st.roomId);
    if (st.mapBuild) {
      const offers = st.mapBuild.offers || [];
      if (!offers.length) { D.cancelMapBuild(); return { action: "build-cancel" }; }
      let best = 0; let bestScore = -1e9;
      offers.forEach((o, i) => {
        let s = Math.random() * 0.2;
        if (o.role === "combat") s += preferCombat;
        else if (o.role === "quiet") s += preferQuiet;
        else s += (preferCombat + preferQuiet) * 0.5;
        if (o.contentId && /hall|gallery/.test(o.contentId)) s += 0.25;
        if (s > bestScore) { bestScore = s; best = i; }
      });
      D.selectMapBuildPick(best);
      D.commitMapBuild();
      return { action: "build", room: offers[best]?.name, role: offers[best]?.role };
    }
    const bfsNext = (pred) => {
      const seen = new Set([st.roomId]);
      const q = [[st.roomId, null]];
      while (q.length) {
        const [id, hop] = q.shift();
        if (id !== st.roomId && pred(id)) return hop;
        for (const eid of D.roomDef(id)?.exits || []) {
          if (seen.has(eid)) continue;
          seen.add(eid);
          q.push([eid, hop === null ? eid : hop]);
        }
      }
      return null;
    };
    const unvisited = (hereR?.exits || []).filter((id) => !st.resolvedRooms.has(id));
    if (unvisited.length) {
      const id = unvisited[0];
      D.moveTo(id);
      return { action: "move", to: id, name: D.roomDef(id)?.name };
    }
    const slots = D.listBuildSlots();
    if (slots.length) {
      const pool = slots.filter((s) => s.fromId === st.roomId);
      if (pool.length) {
        const slot = pool[Math.floor(Math.random() * pool.length)];
        D.openMapBuildAt(slot.col, slot.row);
        return { action: "open-build", col: slot.col, row: slot.row };
      }
      const withSlots = new Set(slots.map((s) => s.fromId));
      const hop = bfsNext((id) => withSlots.has(id));
      if (hop) {
        D.moveTo(hop);
        return { action: "walk-build", to: hop, name: D.roomDef(hop)?.name };
      }
    }
    const anyExit = (hereR?.exits || []).filter((id) => !D.roomDef(id)?.bossRoom);
    if (anyExit.length) {
      const hop = bfsNext((id) => id !== st.roomId);
      if (hop) { D.moveTo(hop); return { action: "wander", to: hop }; }
    }
    return { action: "stuck", room: st.roomId };
  }
  const here = D.roomDef(st.roomId);
  const exits = (here?.exits || []).filter(id => {
    const r = D.roomDef(id);
    return r && !r.bossRoom;
  });
  if (!exits.length) return { action: "stuck", room: st.roomId };
  const visited = st.resolvedRooms;
  const unvisited = exits.filter(id => !visited.has(id));
  const pool = unvisited.length ? unvisited : exits;
  const pick = pool[Math.floor(Math.random() * pool.length)];
  D.moveTo(pick);
  return { action: "move", to: pick };
}
"""


def snap(page):
    return page.evaluate(
        """() => {
      const D = window.CabinDebug;
      const st = D.getState();
      return {
        roomId: st.roomId, nodePending: st.nodePending,
        hp: st.hp, visitLen: st.visitPath.length,
        hasCombat: !!st.combat, mapBuild: !!st.mapBuild,
        slots: D.listBuildSlots ? D.listBuildSlots().length : -1,
        roomLayoutN: st.roomLayout ? Object.keys(st.roomLayout).length : 0,
        ended: !!(document.getElementById("screen-end")?.classList.contains("active")),
      };
    }"""
    )


def dump_state(page, tag):
    LOG.append("===== DUMP " + tag + " =====")
    d = page.evaluate(
        """() => {
      const st = window.CabinDebug.getState();
      const room = window.CabinDebug.roomDef(st.roomId);
      return {
        roomId: st.roomId,
        roomCombat: room ? { name: room.name, combat: !!room.combat, eventType: room.eventType, bossRoom: !!room.bossRoom, exits: room.exits } : null,
        nodePending: st.nodePending,
        hp: st.hp, maxHp: st.maxHp,
        combat: st.combat ? {
          roomName: st.combat.roomName, enemy: st.combat.enemy, archetype: st.combat.archetype,
          hand: (st.combat.hand||[]).length, playerPos: st.combat.playerPos, enemyPos: st.combat.enemyPos,
        } : null,
      };
    }"""
    )
    LOG.append(json.dumps(d, ensure_ascii=False, indent=1))
    page.wait_for_timeout(50)


def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.on("pageerror", lambda err: LOG.append("PAGEERROR: " + str(err)))
        page.goto(BASE, wait_until="networkidle")
        page.wait_for_function("() => window.CabinDebug")
        page.evaluate("() => localStorage.clear()")
        page.click("#btn-start")
        page.wait_for_function("() => window.CabinDebug.getState().roomId", timeout=10000)

        steps = 0
        last_sig = None
        while steps < 200:
            steps += 1
            s = snap(page)
            if s["ended"]:
                LOG.append("ENDED")
                break
            clicked = page.evaluate(CLICK_CHOICE_JS, {"preferHeal": True, "takeCards": True, "relicPrefer": [], "cardPrefer": []})
            if clicked.get("clicked"):
                LOG.append("ui " + json.dumps(clicked, ensure_ascii=False))
                page.wait_for_timeout(30)
                continue
            s = snap(page)
            if s["hasCombat"]:
                ca = 0
                while ca < 40:
                    ca += 1
                    s2 = snap(page)
                    if s2["ended"] or not s2["hasCombat"]:
                        break
                    sig = page.evaluate(
                        """() => { const c=window.CabinDebug.getState().combat;
                          return c ? [c.energy,c.enemy.hp,c.toughness,(c.hand||[]).length,c.playerPos.r,c.playerPos.c].join('|') : 'none'; }"""
                    )
                    if sig == last_sig:
                        LOG.append("combat STALL sig=" + sig)
                        break
                    last_sig = sig
                    res = page.evaluate(COMBAT_STEP_JS)
                    LOG.append("combat " + json.dumps(res, ensure_ascii=False))
                    page.wait_for_timeout(25)
                continue
            exp = page.evaluate(EXPLORE_STEP_JS, {"preferCombat": 1.0, "preferQuiet": 0.0})
            LOG.append("explore " + json.dumps(exp, ensure_ascii=False) + " state=" + json.dumps(s, ensure_ascii=False))
            if exp["action"] == "stuck":
                dump_state(page, "stuck")
                break
            if exp["action"] == "resolve-node":
                # 连续 resolve 两次仍未生效则转储
                s3 = snap(page)
                if s3["nodePending"] and s3["roomId"] == s["roomId"]:
                    dump_state(page, "resolve-noop")
            page.wait_for_timeout(30)

        dump_state(page, "final")
        print("\n".join(LOG))
        browser.close()


if __name__ == "__main__":
    main()
