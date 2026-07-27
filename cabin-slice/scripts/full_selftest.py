#!/usr/bin/env python3
"""全流程自测：开局→探索→战斗→Boss，多路线策略，汇总报告。"""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

BASE = "http://127.0.0.1:8787/"
OUT = Path(__file__).resolve().parent.parent / "lab-full-selftest.json"
MAX_STEPS = 250
MAX_COMBAT_ACTIONS = 60

# 5 条不同路线偏好
STRATEGIES = [
    {
        "id": "combat_rush",
        "label": "战斗冲刺",
        "prefer_combat": 1.0,
        "prefer_quiet": 0.0,
        "boss_style": "kill",
        "relic_prefer": ["omen_flint", "omen_salt", "omen_signal", "omen_decoy"],
        "take_cards": True,
        "heal_bias": False,
    },
    {
        "id": "quiet_path",
        "label": "静室迂回",
        "prefer_combat": 0.0,
        "prefer_quiet": 1.0,
        "boss_style": "ritual",
        "relic_prefer": ["omen_signal", "omen_boots", "omen_bell", "omen_decoy"],
        "take_cards": True,
        "heal_bias": True,
    },
    {
        "id": "mixed_heal",
        "label": "混走保命",
        "prefer_combat": 0.45,
        "prefer_quiet": 0.55,
        "boss_style": "ritual",
        "relic_prefer": ["omen_decoy", "omen_salt", "omen_signal", "omen_flint"],
        "take_cards": True,
        "heal_bias": True,
    },
    {
        "id": "late_heavy",
        "label": "后段加压",
        "prefer_combat": 0.7,
        "prefer_quiet": 0.3,
        "boss_style": "kill",
        "relic_prefer": ["omen_flint", "omen_decoy", "omen_salt", "omen_signal"],
        "take_cards": True,
        "heal_bias": False,
        "late_combat_push": True,
    },
    {
        "id": "bait_boss",
        "label": "引砸仪式",
        "prefer_combat": 0.5,
        "prefer_quiet": 0.5,
        "boss_style": "bait",
        "relic_prefer": ["omen_decoy", "omen_salt", "omen_flint", "omen_signal"],
        "take_cards": True,
        "heal_bias": True,
    },
]

CLICK_CHOICE_JS = r"""
({ preferHeal, takeCards, relicPrefer }) => {
  const event = document.getElementById("screen-event");
  const boss = document.getElementById("screen-boss");
  const end = document.getElementById("screen-end");
  if (end && end.classList.contains("active")) return { clicked: false, phase: "end" };
  if (boss && boss.classList.contains("active")) {
    const actions = document.getElementById("boss-actions");
    const btn = [...(actions?.querySelectorAll("button")||[])].find(b => /进入/.test(b.textContent||""));
    if (btn) { btn.click(); return { clicked: true, phase: "boss-enter" }; }
    return { clicked: false, phase: "boss" };
  }
  if (!(event && event.classList.contains("active"))) return { clicked: false, phase: "none" };

  // 奖励卡上的「带上 / 收下」
  const rewardBtns = [...document.querySelectorAll("#reward-cards button")];
  if (rewardBtns.length) {
    const cards = [...document.querySelectorAll("#reward-cards .reward-card")];
    if (cards.length && /预兆|行前/.test(document.getElementById("event-title")?.textContent||"")) {
      let best = 0;
      let bestScore = 99;
      cards.forEach((card, i) => {
        const t = card.textContent || "";
        let s = 9;
        if (/纸影/.test(t)) s = (relicPrefer||[]).indexOf("omen_decoy");
        else if (/火漆/.test(t)) s = (relicPrefer||[]).indexOf("omen_flint");
        else if (/盐/.test(t)) s = (relicPrefer||[]).indexOf("omen_salt");
        else if (/信号/.test(t)) s = (relicPrefer||[]).indexOf("omen_signal");
        else if (/铃/.test(t)) s = (relicPrefer||[]).indexOf("omen_bell");
        else if (/胶靴|靴/.test(t)) s = (relicPrefer||[]).indexOf("omen_boots");
        if (s < 0) s = 9;
        if (s < bestScore) { bestScore = s; best = i; }
      });
      const take = cards[best].querySelector("button");
      if (take) { take.click(); return { clicked: true, phase: "opening-relic" }; }
    }
    if (takeCards) {
      rewardBtns[0].click();
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
({ bossStyle }) => {
  const D = window.CabinDebug;
  const st = D.getState();
  const c = st.combat;
  if (!c) return { done: true, reason: "no-combat" };

  const keyOf = D.keyOf;
  const neighbors = D.neighbors;
  const cardDef = D.cardDef;
  const manh = D.manhattan;
  const isPassable = D.isPassable;
  const isOrtho = D.isOrthoAdjacent;

  const pk = keyOf(c.playerPos);
  if (c.isBoss && c.anchors?.[pk]?.lit) {
    const cost = (st.data.pressure?.bossFight?.dismantleCost) || 3;
    if (c.energy >= cost) {
      D.tryDismantleAnchor();
      return { done: false, action: "dismantle" };
    }
  }

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

  const litAnchors = Object.keys(c.anchors || {}).filter(k => c.anchors[k].lit).map(k => {
    const [r, cc] = k.split(",").map(Number);
    return { r, c: cc, k };
  });

  function stepToward(goal, avoidThreat) {
    const opts = neighbors(c.playerPos)
      .filter(p => isPassable(p) && keyOf(p) !== keyOf(c.enemyPos))
      .filter(p => !(c.decoy?.pos && keyOf(p) === keyOf(c.decoy.pos)))
      .map(p => ({ p, d: manh(p, goal), k: keyOf(p) }))
      .sort((a, b) => a.d - b.d || Math.random() - 0.5);
    for (const o of opts) {
      if (avoidThreat && (pendingHurt.has(o.k) || threatNow.has(o.k)) && opts.some(x => !pendingHurt.has(x.k) && !threatNow.has(x.k))) continue;
      if (D.tryMovePlayer(o.p)) return true;
    }
    return false;
  }

  for (const inst of [...c.hand]) {
    const def = cardDef(inst.id);
    if (!def || def.type === "place") continue;
    const cost = Math.max(0, def.cost - (c.discount || 0));
    if (cost > c.energy) continue;
    if (def.shove) {
      if (manh(c.playerPos, c.enemyPos) === 1 && c.playerSeesEnemy) {
        D.selectCard(inst.uid);
        return { done: false, action: "shove" };
      }
      continue;
    }
    if (def.gainBlock || def.grantRetain || def.retainThisTurn || def.gainEnergy || def.discountNext) {
      if (def.selfDamage && st.hp <= def.selfDamage + 1) continue;
      D.selectCard(inst.uid);
      return { done: false, action: "skill:" + def.name };
    }
  }

  for (const inst of [...c.hand]) {
    const def = cardDef(inst.id);
    if (!def || def.type !== "place") continue;
    const cost = Math.max(0, def.cost - (c.discount || 0));
    if (cost > c.energy) continue;
    D.selectCard(inst.uid);

    const wantKill = bossStyle === "kill" || !c.isBoss;
    const wantBait = bossStyle === "bait" && c.isBoss;

    if (def.place?.onStep?.damage && c.playerSeesEnemy && isOrtho(c.playerPos, c.enemyPos) && (wantKill || !c.isBoss)) {
      if (D.tryPlace(c.enemyPos)) return { done: false, action: "smash-enemy" };
    }
    if (c.isBoss && litAnchors.length) {
      for (const a of litAnchors) {
        if (isOrtho(c.playerPos, a) && D.tryPlace(a)) return { done: false, action: "smash-anchor" };
      }
    }
    const spots = neighbors(c.playerPos)
      .filter(p => isPassable(p) && keyOf(p) !== keyOf(c.enemyPos))
      .filter(p => !c.floor[keyOf(p)])
      .filter(p => !(c.decoy?.pos && keyOf(p) === keyOf(c.decoy.pos)));
    for (const p of spots) {
      if (pendingHurt.has(keyOf(p))) continue;
      if (def.place?.decoy && wantBait) {
        if (manh(p, c.enemyPos) <= 2 && D.tryPlace(p)) return { done: false, action: "decoy" };
      }
      if (D.tryPlace(p)) return { done: false, action: "place:" + def.name };
    }
    c.placeUid = null;
  }

  if (threatNow.has(pk) || pendingHurt.has(pk)) {
    const flee = neighbors(c.playerPos)
      .filter(p => isPassable(p) && keyOf(p) !== keyOf(c.enemyPos))
      .filter(p => !threatNow.has(keyOf(p)) && !pendingHurt.has(keyOf(p)));
    for (const p of flee) {
      if (D.tryMovePlayer(p)) return { done: false, action: "flee" };
    }
  }

  if (c.isBoss && litAnchors.length && bossStyle !== "kill") {
    litAnchors.sort((a, b) => manh(c.playerPos, a) - manh(c.playerPos, b));
    if (bossStyle === "bait") {
      litAnchors.sort((a, b) => (manh(c.playerPos, a) + manh(c.enemyPos, a)) - (manh(c.playerPos, b) + manh(c.enemyPos, b)));
    }
    if (stepToward(litAnchors[0], true)) return { done: false, action: "move-anchor" };
  }

  if (c.playerSeesEnemy && (bossStyle === "kill" || !c.isBoss)) {
    if (stepToward(c.enemyPos, true)) return { done: false, action: "move-enemy" };
  }

  // 无视线时朝 lastSeen / 任意可走格靠近
  if (!c.playerSeesEnemy) {
    const goal = c.lastSeen || c.enemyPos;
    if (stepToward(goal, false)) return { done: false, action: "search" };
  }

  D.endTurn();
  return { done: false, action: "end-turn" };
}
"""

EXPLORE_STEP_JS = r"""
({ preferCombat, preferQuiet, latePush }) => {
  const D = window.CabinDebug;
  const st = D.getState();
  if (st.combat) return { action: "in-combat" };
  if (D.runReadyForBoss()) {
    const bossScreen = document.getElementById("screen-boss");
    if (bossScreen && bossScreen.classList.contains("active")) {
      const actions = document.getElementById("boss-actions");
      const btn = [...(actions?.querySelectorAll("button")||[])].find(b => /进入/.test(b.textContent||""));
      if (btn) { btn.click(); return { action: "boss-enter" }; }
      return { action: "boss-modal" };
    }
    const btn = document.getElementById("btn-boss");
    if (btn && !btn.classList.contains("hidden")) { btn.click(); return { action: "open-boss" }; }
    D.openBoss();
    return { action: "open-boss-api" };
  }

  if (st.nodePending) {
    D.resolveCurrentNode();
    return { action: "resolve-node", room: st.roomId };
  }

  const here = D.roomDef(st.roomId);
  const exits = (here.exits || []).filter(id => {
    const r = D.roomDef(id);
    return r && !r.bossRoom;
  });
  if (!exits.length) return { action: "stuck", room: st.roomId };

  const visited = st.resolvedRooms;
  const unvisited = exits.filter(id => !visited.has(id));
  const pool = unvisited.length ? unvisited : exits;

  const scored = pool.map(id => {
    const r = D.roomDef(id);
    let score = Math.random() * 0.2;
    if (r.combat) score += preferCombat;
    else score += preferQuiet;
    if (!visited.has(id)) score += 0.35;
    if (latePush && st.visitPath.length >= 6 && r.combat) score += 0.4;
    if (["attic","loft","cellar","boiler","ritual","darkroom","study"].includes(id)) score += 0.15;
    return { id, score, combat: !!r.combat, name: r.name };
  }).sort((a,b) => b.score - a.score);

  const pick = scored[0];
  D.moveTo(pick.id);
  return { action: "move", to: pick.id, name: pick.name, combat: pick.combat };
}
"""


def snapshot(page):
    return page.evaluate(
        """() => {
      const D = window.CabinDebug;
      const st = D.getState();
      const end = document.getElementById("screen-end");
      const event = document.getElementById("screen-event");
      const boss = document.getElementById("screen-boss");
      const cards = document.getElementById("screen-cards");
      return {
        roomId: st.roomId,
        hp: st.hp,
        maxHp: st.maxHp,
        speed: st.speed,
        visitLen: st.visitPath.length,
        visitPath: [...st.visitPath],
        combatCount: st.combatCount || 0,
        relics: [...st.relics],
        deckSize: (st.deck||[]).length + (st.discard||[]).length + ((st.combat&&st.combat.hand)||[]).length,
        nodePending: st.nodePending,
        hasCombat: !!st.combat,
        combatIsBoss: !!(st.combat && st.combat.isBoss),
        readyBoss: D.runReadyForBoss(),
        chosenBoss: st.chosenBoss,
        ended: !!(end && end.classList.contains("active")),
        endTitle: document.getElementById("end-title")?.textContent || "",
        endResult: document.getElementById("end-result")?.textContent || "",
        modalEvent: !!(event && event.classList.contains("active")),
        modalBoss: !!(boss && boss.classList.contains("active")),
        modalCards: !!(cards && cards.classList.contains("active")),
      };
    }"""
    )


def play_full(page, strategy: dict):
    page.goto(BASE, wait_until="networkidle")
    page.wait_for_function("() => window.CabinDebug && window.CabinDebug.getState()?.data")
    page.evaluate(
        """() => {
      try { window.CabinAudio && window.CabinAudio.setMuted(true); } catch(e){}
      localStorage.removeItem('cabin-run-v3');
      localStorage.removeItem('cabin-lab-v1'); // 单局干净；最后再读本局 finalize 前写入
    }"""
    )
    # 其实我们想保留 lab across runs for aggregate — don't clear lab between runs.
    # Re-clear only save.
    page.evaluate("() => localStorage.removeItem('cabin-run-v3')")

    page.click("#btn-start")
    page.wait_for_function("() => window.CabinDebug.getState().roomId", timeout=10000)

    log = []
    combat_logs = []
    steps = 0
    combat_actions = 0
    t0 = time.time()

    while steps < MAX_STEPS:
        if time.time() - t0 > 90:
            log.append({"t": "timeout"})
            break
        steps += 1
        snap = snapshot(page)
        if snap.get("ended"):
            break

        # handle modals / rewards first
        clicked = page.evaluate(
            CLICK_CHOICE_JS,
            {
                "preferHeal": strategy.get("heal_bias", False),
                "takeCards": strategy.get("take_cards", True),
                "relicPrefer": strategy.get("relic_prefer", []),
            },
        )
        if clicked.get("clicked"):
            log.append({"t": "ui", **clicked})
            page.wait_for_timeout(40)
            continue

        snap = snapshot(page)
        if snap.get("ended"):
            break

        if snap.get("hasCombat") or snap.get("modalCards"):
            combat_actions = 0
            idle = 0
            last_sig = None
            cleared = False
            while combat_actions < MAX_COMBAT_ACTIONS:
                combat_actions += 1
                s2 = snapshot(page)
                if s2.get("ended") or not (s2.get("hasCombat") or s2.get("modalCards")):
                    cleared = True
                    break
                if s2.get("modalEvent") and not s2.get("hasCombat"):
                    cleared = True
                    break
                sig = page.evaluate(
                    """() => {
                  const c = window.CabinDebug.getState().combat;
                  if (!c) return 'none';
                  return [c.energy, c.enemy.hp, c.toughness, c.broadcast||0, (c.hand||[]).length,
                          c.playerPos.r, c.playerPos.c, !!(c.placeUid)].join('|');
                }"""
                )
                if sig == last_sig:
                    idle += 1
                else:
                    idle = 0
                    last_sig = sig
                if idle >= 3:
                    page.evaluate("() => { const c=window.CabinDebug.getState().combat; if(c){c.placeUid=null;} window.CabinDebug.endTurn(); }")
                    log.append({"t": "combat", "action": "force-end-turn"})
                    idle = 0
                    page.wait_for_timeout(80)
                    continue
                res = page.evaluate(COMBAT_STEP_JS, {"bossStyle": strategy.get("boss_style", "ritual")})
                combat_logs.append(res)
                log.append({"t": "combat", **res})
                if res.get("done"):
                    cleared = True
                    break
                page.wait_for_timeout(25 if res.get("action") != "end-turn" else 60)
            if not cleared and snapshot(page).get("hasCombat"):
                page.evaluate("() => { try { window.CabinDebug.loseCombat('hp'); } catch(e) { window.CabinDebug.getState().hp=0; } }")
                log.append({"t": "combat", "action": "combat-cap-lose"})
                page.wait_for_timeout(100)
                break
            continue

        # explore
        exp = page.evaluate(
            EXPLORE_STEP_JS,
            {
                "preferCombat": strategy.get("prefer_combat", 0.5),
                "preferQuiet": strategy.get("prefer_quiet", 0.5),
                "latePush": bool(strategy.get("late_combat_push")),
            },
        )
        log.append({"t": "explore", **exp})
        page.wait_for_timeout(40)

        if exp.get("action") == "stuck":
            break

    final = snapshot(page)
    # wait a tick for lab finalize
    page.wait_for_timeout(150)
    lab_store = page.evaluate("() => window.CabinDebug.loadLabStore()")
    labs = lab_store.get("runs") or []
    # labs for this session: filter by recent / all in store since we may clear
    return {
        "strategy": strategy["id"],
        "label": strategy["label"],
        "final": final,
        "steps": steps,
        "log_tail": log[-30:],
        "combat_action_count": len(combat_logs),
        "labs": labs[:8],  # newest first
    }


def analyze(results):
    rows = []
    for r in results:
        f = r.get("final") or {}
        labs = r.get("labs") or []
        # pick labs that look like this run: newest until visit matches? Use all newest until boss/non
        boss_lab = next((x for x in labs if x.get("enemy", {}).get("isBoss")), None)
        normal_labs = [x for x in labs if not x.get("enemy", {}).get("isBoss")]
        # approximate: if we cleared lab store per run we'd only have this run — we didn't clear between.
        # So attach by reading from a cleared-per-run approach in main.
        s = (boss_lab or {}).get("summary") or {}
        rows.append(
            {
                "strategy": r["strategy"],
                "label": r["label"],
                "ended": f.get("ended"),
                "endResult": f.get("endResult"),
                "endTitle": f.get("endTitle"),
                "hp": f"{f.get('hp')}/{f.get('maxHp')}",
                "speed": f.get("speed"),
                "visitLen": f.get("visitLen"),
                "visitPath": f.get("visitPath"),
                "combatCount": f.get("combatCount"),
                "relics": f.get("relics"),
                "deckSize": f.get("deckSize"),
                "chosenBoss": f.get("chosenBoss"),
                "boss_outcome": (boss_lab or {}).get("outcome"),
                "boss_reason": s.get("outcomeReason"),
                "boss_turns": s.get("turns"),
                "boss_dealt": s.get("damageDealt"),
                "boss_taken": s.get("damageTaken"),
                "anchors": f"{s.get('anchorsCleared')}/{s.get('anchorsTotal')}" if s else None,
                "byBoss": s.get("anchorsClearedByBoss"),
                "broadcast": s.get("broadcastEnd"),
                "phase": s.get("phaseReached"),
                "charges": s.get("chargeCasts"),
                "normal_fights": len(normal_labs),
                "normal_wins": sum(1 for x in normal_labs if x.get("outcome") == "win"),
                "normal_losses": sum(1 for x in normal_labs if x.get("outcome") == "lose"),
                "error": r.get("error"),
            }
        )
    return rows


def main():
    results = []
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.on("pageerror", lambda err: print("PAGEERROR:", err, file=sys.stderr))

        # clear lab once at start
        page.goto(BASE, wait_until="networkidle")
        page.wait_for_function("() => window.CabinDebug")
        page.evaluate("() => localStorage.removeItem('cabin-lab-v1')")

        for i, strat in enumerate(STRATEGIES, 1):
            print(f"\n=== [{i}/{len(STRATEGIES)}] {strat['label']} ({strat['id']}) ===", flush=True)
            # isolate lab per run for clean attribution
            page.evaluate("() => localStorage.removeItem('cabin-lab-v1')")
            try:
                r = play_full(page, strat)
                results.append(r)
                f = r["final"]
                labs = r.get("labs") or []
                boss = next((x for x in labs if x.get("enemy", {}).get("isBoss")), None)
                s = (boss or {}).get("summary") or {}
                print(
                    f"  end={f.get('endResult')!r} title={f.get('endTitle')!r} "
                    f"path={f.get('visitLen')} combats={f.get('combatCount')} "
                    f"boss={f.get('chosenBoss')} outcome={boss and boss.get('outcome')} "
                    f"reason={s.get('outcomeReason')} turns={s.get('turns')} "
                    f"anchors={s.get('anchorsCleared')}/{s.get('anchorsTotal')} byBoss={s.get('anchorsClearedByBoss')} "
                    f"broadcast={s.get('broadcastEnd')}",
                    flush=True,
                )
                print(f"  visitPath={f.get('visitPath')}", flush=True)
                print(f"  relics={f.get('relics')} deck={f.get('deckSize')} hp={f.get('hp')}/{f.get('maxHp')} speed={f.get('speed')}", flush=True)
            except Exception as e:
                print(f"  FAIL: {e}", flush=True)
                results.append({"strategy": strat["id"], "label": strat["label"], "error": str(e), "final": {}, "labs": []})

        browser.close()

    summary = analyze(results)
    payload = {
        "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "summary": summary,
        "runs": results,
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    print("\n========== 全流程自测报告 ==========")
    for row in summary:
        print(json.dumps(row, ensure_ascii=False))
    print(f"\nWrote {OUT}")

    # high-level
    finished = [x for x in summary if x.get("ended")]
    wins = [x for x in finished if x.get("endResult") and "赢" in (x.get("endResult") or "")]
    print(
        f"\n总览: 完成 {len(finished)}/{len(summary)} · 通关文案胜 {len(wins)} · "
        f"Boss胜 {sum(1 for x in summary if x.get('boss_outcome')=='win')} · "
        f"Boss负 {sum(1 for x in summary if x.get('boss_outcome')=='lose')}"
    )


if __name__ == "__main__":
    main()
