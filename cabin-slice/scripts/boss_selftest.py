#!/usr/bin/env python3
"""Boss 仪式自测：Playwright 驱动真实页面，跑多场并汇总 lab。"""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

BASE = "http://127.0.0.1:8787/"
OUT = Path(__file__).resolve().parent.parent / "lab-selftest.json"
RUNS = 5
MAX_TURNS = 24

BOT_JS = r"""
() => {
  const D = window.CabinDebug;
  if (!D) return { done: true, error: "no CabinDebug" };
  const st = D.getState();
  const c = st.combat;
  if (!c) {
    const end = document.getElementById("screen-end");
    const active = end && end.classList.contains("active");
    return { done: true, ended: !!active, title: document.getElementById("end-title")?.textContent || "" };
  }

  const keyOf = D.keyOf;
  const neighbors = D.neighbors;
  const cardDef = D.cardDef;
  const manh = D.manhattan;
  const isPassable = D.isPassable;
  const isOrtho = D.isOrthoAdjacent;

  // 优先：站在亮锚上就拆
  const pk = keyOf(c.playerPos);
  if (c.anchors?.[pk]?.lit) {
    const cost = (st.data.pressure?.bossFight?.dismantleCost) || 2;
    if (c.energy >= cost) {
      D.tryDismantleAnchor();
      return { done: false, action: "dismantle", energy: c.energy };
    }
  }

  // 蓄力预告：若脚下是 pending hurt，先走开
  const intent = c.intent;
  const pendingHurt = new Set();
  if (intent?.pending || intent?.zones?.some(z => z.pending)) {
    for (const z of intent.zones || []) {
      if (z.kind === "hurt") for (const p of z.cells || []) pendingHurt.add(keyOf(p));
    }
  }
  const threatNow = new Set();
  for (const z of intent?.zones || []) {
    if (z.kind === "hurt" && !z.pending) for (const p of z.cells || []) threatNow.add(keyOf(p));
  }

  const litAnchors = Object.keys(c.anchors || {}).filter(k => c.anchors[k].lit).map(k => {
    const [r, cc] = k.split(",").map(Number);
    return { r, c: cc, k };
  });

  function stepToward(goal) {
    const opts = neighbors(c.playerPos)
      .filter(p => isPassable(p) && keyOf(p) !== keyOf(c.enemyPos))
      .filter(p => !(c.decoy?.pos && keyOf(p) === keyOf(c.decoy.pos)))
      .map(p => ({ p, d: manh(p, goal), k: keyOf(p) }))
      .sort((a, b) => a.d - b.d || Math.random() - 0.5);
    for (const o of opts) {
      // 尽量不走进当前威胁格；蓄力格更要躲
      if (pendingHurt.has(o.k) && opts.some(x => !pendingHurt.has(x.k))) continue;
      if (D.tryMovePlayer(o.p)) return true;
    }
    return false;
  }

  // 打出非放置技：护盾 / 预案 / 推撞（邻接时）
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
      D.selectCard(inst.uid);
      return { done: false, action: "skill:" + def.name };
    }
  }

  // 放置：优先砸敌 / 砸亮锚 / 放邻格陷阱或盐
  for (const inst of [...c.hand]) {
    const def = cardDef(inst.id);
    if (!def || def.type !== "place") continue;
    const cost = Math.max(0, def.cost - (c.discount || 0));
    if (cost > c.energy) continue;
    D.selectCard(inst.uid);
    // 砸敌人
    if (def.place?.onStep?.damage && c.playerSeesEnemy && isOrtho(c.playerPos, c.enemyPos)) {
      if (D.tryPlace(c.enemyPos)) return { done: false, action: "smash-enemy" };
    }
    // 砸亮锚
    for (const a of litAnchors) {
      if (isOrtho(c.playerPos, a) && D.tryPlace(a)) return { done: false, action: "smash-anchor:" + a.k };
    }
    // 放邻格（非威胁）
    const spots = neighbors(c.playerPos)
      .filter(p => isPassable(p) && keyOf(p) !== keyOf(c.enemyPos))
      .filter(p => !c.floor[keyOf(p)])
      .filter(p => !(c.decoy?.pos && keyOf(p) === keyOf(c.decoy.pos)));
    for (const p of spots) {
      if (pendingHurt.has(keyOf(p))) continue;
      if (D.tryPlace(p)) return { done: false, action: "place:" + def.name };
    }
    // 取消放置
    c.placeUid = null;
  }

  // 走向最近亮锚；若脚下威胁则先躲
  if (threatNow.has(pk) || pendingHurt.has(pk)) {
    const safeGoal = litAnchors[0] || { r: 0, c: 0 };
    // 先找非威胁邻格
    const flee = neighbors(c.playerPos)
      .filter(p => isPassable(p) && keyOf(p) !== keyOf(c.enemyPos))
      .filter(p => !threatNow.has(keyOf(p)) && !pendingHurt.has(keyOf(p)));
    for (const p of flee) {
      if (D.tryMovePlayer(p)) return { done: false, action: "flee" };
    }
  }

  if (litAnchors.length) {
    litAnchors.sort((a, b) => manh(c.playerPos, a) - manh(c.playerPos, b));
    if (stepToward(litAnchors[0])) return { done: false, action: "move-anchor" };
  }

  // 还能动就靠近敌人砸血
  if (c.playerSeesEnemy && stepToward(c.enemyPos)) return { done: false, action: "move-enemy" };

  // 收工
  D.endTurn();
  return { done: false, action: "end-turn", turn: st.lab?.summary?.turns };
}
"""


def snapshot(page):
    return page.evaluate(
        """() => {
      const D = window.CabinDebug;
      const st = D.getState();
      const c = st.combat;
      const end = document.getElementById("screen-end");
      return {
        hasCombat: !!c,
        ended: !!(end && end.classList.contains("active")),
        endTitle: document.getElementById("end-title")?.textContent || "",
        endResult: document.getElementById("end-result")?.textContent || "",
        hp: st.hp,
        labTag: st.labTag,
        combat: c ? {
          enemyHp: c.enemy.hp,
          toughness: c.toughness,
          broken: c.broken,
          broadcast: c.broadcast,
          broadcastMax: c.broadcastMax,
          phase: c.phaseName,
          directive: c.directive?.id || null,
          charge: !!c.chargePending,
          anchorsLit: Object.values(c.anchors||{}).filter(a=>a.lit).length,
          anchorsTotal: Object.keys(c.anchors||{}).length,
          energy: c.energy,
          playerPos: c.playerPos,
          enemyPos: c.enemyPos,
          hand: (c.hand||[]).map(h => h.id),
        } : null,
      };
    }"""
    )


def play_one(page, run_i: int):
    page.goto(BASE, wait_until="networkidle")
    page.wait_for_function("() => window.CabinDebug && window.CabinDebug.getState()?.data")
    # mute
    page.evaluate("() => { try { window.CabinAudio && window.CabinAudio.setMuted(true); } catch(e){} }")

    page.click("#btn-boss-test")
    page.wait_for_selector("#screen-boss.active, #boss-actions", timeout=10000)
    # enter fight
    page.evaluate(
        """() => {
      const actions = document.getElementById("boss-actions");
      const btn = [...(actions?.querySelectorAll("button")||[])].find(b => b.textContent.includes("进入"));
      if (btn) btn.click();
    }"""
    )
    page.wait_for_function("() => window.CabinDebug.getState().combat", timeout=10000)

    actions = []
    turns = 0
    errors = []
    while turns < MAX_TURNS:
        snap = snapshot(page)
        if snap.get("ended") or not snap.get("hasCombat"):
            break
        before = snap["combat"]
        result = page.evaluate(BOT_JS)
        actions.append(result)
        if result.get("error"):
            errors.append(result["error"])
            break
        if result.get("done"):
            break
        if result.get("action") == "end-turn":
            turns += 1
            page.wait_for_timeout(80)
        else:
            page.wait_for_timeout(30)
        # safety: if stuck repeating same action with no energy change
        after = snapshot(page)
        if after.get("ended"):
            break
        if not after.get("hasCombat"):
            break

    # wait end screen
    page.wait_for_timeout(200)
    final = snapshot(page)
    lab = page.evaluate("() => window.CabinDebug.loadLabStore()")
    last = (lab.get("runs") or [None])[0]
    return {
        "run": run_i,
        "final": final,
        "actions_sample": actions[:40],
        "action_count": len(actions),
        "end_turns_seen": turns,
        "errors": errors,
        "lab": last,
    }


def summarize(results):
    rows = []
    for r in results:
        lab = r.get("lab") or {}
        s = lab.get("summary") or {}
        rows.append(
            {
                "run": r["run"],
                "outcome": lab.get("outcome"),
                "reason": s.get("outcomeReason"),
                "turns": s.get("turns"),
                "dealt": s.get("damageDealt"),
                "taken": s.get("damageTaken"),
                "anchors": f"{s.get('anchorsCleared')}/{s.get('anchorsTotal')}",
                "byBoss": s.get("anchorsClearedByBoss"),
                "broadcast": s.get("broadcastEnd"),
                "phase": s.get("phaseReached"),
                "charges": s.get("chargeCasts"),
                "hpEnd": s.get("playerHpEnd"),
                "enemyEnd": s.get("enemyHpEnd"),
                "endTitle": (r.get("final") or {}).get("endTitle"),
                "errors": r.get("errors"),
            }
        )
    return rows


def main():
    results = []
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context()
        page = context.new_page()
        page.on("pageerror", lambda err: print("PAGEERROR:", err, file=sys.stderr))
        for i in range(1, RUNS + 1):
            print(f"=== run {i}/{RUNS} ===", flush=True)
            try:
                r = play_one(page, i)
                results.append(r)
                lab = r.get("lab") or {}
                s = lab.get("summary") or {}
                print(
                    f"  outcome={lab.get('outcome')} reason={s.get('outcomeReason')} "
                    f"turns={s.get('turns')} anchors={s.get('anchorsCleared')}/{s.get('anchorsTotal')} "
                    f"byBoss={s.get('anchorsClearedByBoss')} broadcast={s.get('broadcastEnd')} "
                    f"phase={s.get('phaseReached')} charges={s.get('chargeCasts')}",
                    flush=True,
                )
                if r.get("errors"):
                    print("  errors:", r["errors"], flush=True)
            except Exception as e:
                print(f"  FAIL: {e}", flush=True)
                results.append({"run": i, "error": str(e)})
            # clear between runs except keep lab history
            page.evaluate("() => { localStorage.removeItem('cabin-run-v3'); }")
        browser.close()

    summary = summarize(results)
    payload = {"generatedAt": time.strftime("%Y-%m-%dT%H:%M:%S"), "summary": summary, "runs": results}
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print("\n=== SUMMARY ===")
    for row in summary:
        print(row)
    print(f"\nWrote {OUT}")

    # quick verdict
    ok = [x for x in summary if x.get("outcome")]
    wins = [x for x in ok if x.get("outcome") == "win"]
    ritual = [x for x in ok if x.get("reason") == "ritual"]
    kills = [x for x in ok if x.get("reason") == "kill"]
    broadcasts = [x for x in ok if x.get("reason") == "broadcast"]
    by_boss = sum(1 for x in ok if (x.get("byBoss") or 0) >= 1)
    avg_turns = sum((x.get("turns") or 0) for x in ok) / max(1, len(ok))
    print(
        f"\nVERDICT: n={len(ok)} win={len(wins)} ritual={len(ritual)} kill={len(kills)} "
        f"broadcast_lose={len(broadcasts)} byBoss>0={by_boss} avg_turns={avg_turns:.1f}"
    )


if __name__ == "__main__":
    main()
