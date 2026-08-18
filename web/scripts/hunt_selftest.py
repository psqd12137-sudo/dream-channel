#!/usr/bin/env python3
"""自测：躲藏空转 5 场，检测「怪不找人 / 援助击杀」。"""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

BASE = "http://127.0.0.1:8787/"
OUT = Path(__file__).resolve().parent.parent / "lab-hunt-selftest.json"

# 5 场：覆盖本地/外机出过问题的图 + 对照
CASES = [
    {"room": "gallery", "relics": ["omen_boots"], "label": "画廊·躲藏"},
    {"room": "attic", "relics": ["omen_boots"], "label": "阁楼·躲藏"},
    {"room": "darkroom", "relics": ["omen_decoy"], "label": "暗房·纸影"},
    {"room": "loft", "relics": ["omen_boots"], "label": "栈桥·躲藏"},
    {"room": "shed", "relics": ["omen_echo", "omen_bell"], "label": "棚屋·躲藏"},
]

MAX_TURNS = 28

HIDE_BOT_JS = r"""
() => {
  const D = window.CabinDebug;
  if (!D) return { done: true, error: "no CabinDebug" };
  const st = D.getState();
  const c = st.combat;
  if (!c) {
    const end = document.getElementById("screen-end");
    return { done: true, ended: !!(end && end.classList.contains("active")) };
  }

  const keyOf = D.keyOf;
  const neighbors = D.neighbors;
  const cardDef = D.cardDef;
  const manh = D.manhattan;
  const isPassable = D.isPassable;
  const hasLoS = D.hasLoS;

  // 1) 有纸影就先丢到离自己远、尽量挡怪的格子
  for (const inst of [...c.hand]) {
    const def = cardDef(inst.id);
    if (!def?.place?.decoy) continue;
    const cost = Math.max(0, (def.cost || 0) - (c.discount || 0));
    if (cost > c.energy) continue;
    const cells = [];
    for (let r = 0; r < c.grid.rows; r++) {
      for (let col = 0; col < c.grid.cols; col++) {
        const p = { r, c: col };
        if (!isPassable(p)) continue;
        if (keyOf(p) === keyOf(c.playerPos) || keyOf(p) === keyOf(c.enemyPos)) continue;
        cells.push(p);
      }
    }
    cells.sort((a, b) => manh(b, c.playerPos) - manh(a, c.playerPos));
    for (const p of cells.slice(0, 6)) {
      D.selectCard(inst.uid);
      if (D.tryPlace(p)) return { done: false, action: "decoy", pos: p };
    }
  }

  // 2) 能断视线就挪一步（远离敌人）
  if (c.energy >= 1) {
    const opts = neighbors(c.playerPos)
      .filter((p) => isPassable(p) && keyOf(p) !== keyOf(c.enemyPos))
      .map((p) => ({
        p,
        sees: hasLoS(c.enemyPos, p),
        dist: manh(p, c.enemyPos),
      }))
      .sort((a, b) => (a.sees === b.sees ? 0 : a.sees ? 1 : -1) || b.dist - a.dist);
    const curSees = hasLoS(c.enemyPos, c.playerPos);
    for (const o of opts) {
      if (curSees && o.sees) continue;
      if (!curSees && o.sees) continue;
      if (D.tryMovePlayer(o.p)) return { done: false, action: "hide-move", to: o.p, sees: o.sees };
    }
    // 已无视线：尽量再拉远
    if (!curSees) {
      for (const o of opts) {
        if (o.dist > manh(c.playerPos, c.enemyPos) && D.tryMovePlayer(o.p)) {
          return { done: false, action: "kite", to: o.p };
        }
      }
    }
  }

  // 3) 空过：不主动砸怪，专测追击
  D.endTurn();
  return { done: false, action: "end-turn" };
}
"""

SETUP_JS = r"""
({ roomId, relics }) => {
  const D = window.CabinDebug;
  if (!D) throw new Error("no CabinDebug");
  // 清确认框
  window.confirm = () => true;
  localStorage.removeItem("cabin-run-v3");
  localStorage.removeItem("cabin-run-v2");
  D.resetGame();
  const st = D.getState();
  st.relics = [...relics];
  st.hp = 6;
  st.maxHp = 6;
  st.speed = 4;
  st.combatCount = 2;
  const room = D.roomDef(roomId);
  if (!room) throw new Error("no room " + roomId);
  if (typeof startCombat !== "function") throw new Error("startCombat not global");
  startCombat(room, false);
  return { ok: true, room: roomId, enemy: D.getState().combat?.enemy?.name };
}
"""


def flags_for(lab: dict) -> list[str]:
    if not lab:
        return ["no-lab"]
    s = lab.get("summary") or {}
    events = lab.get("events") or []
    atk = s.get("enemyAttacks") or 0
    turns = s.get("turns") or 0
    dealt = s.get("damageDealt") or 0
    stalls = s.get("stallBreaks") or 0
    outcome = lab.get("outcome")

    stall_dmg = sum(
        (e.get("amount") or 0)
        for e in events
        if e.get("type") == "damage_dealt" and e.get("source") == "stall_break"
    )
    sees_t = sum(1 for e in events if e.get("type") == "player_turn" and e.get("sees"))
    sees_n = sum(1 for e in events if e.get("type") == "player_turn")
    decoy_p = sum(1 for e in events if e.get("type") == "decoy_place")
    decoy_s = sum(1 for e in events if e.get("type") == "decoy_smash")

    flags = []
    if outcome == "win" and atk == 0 and turns >= 8:
        flags.append("零出手胜利")
    if stall_dmg > 0 and stall_dmg >= dealt and dealt > 0:
        flags.append("纯援助击杀")
    if stalls >= 2:
        flags.append(f"stallBreaks={stalls}")
    if decoy_p and not decoy_s and atk == 0 and turns >= 6:
        flags.append("纸影未碎零出手")
    if sees_n >= 6 and sees_t >= sees_n * 0.35 and atk == 0 and turns >= 8:
        flags.append("常有视线却零出手")
    if atk == 0 and turns >= 12:
        flags.append("长局零出手")
    return flags, {
        "outcome": outcome,
        "turns": turns,
        "enemyAttacks": atk,
        "damageTaken": s.get("damageTaken"),
        "damageDealt": dealt,
        "stallBreaks": stalls,
        "stall_dmg": stall_dmg,
        "sees": f"{sees_t}/{sees_n}",
        "decoy": f"{decoy_p}p/{decoy_s}s",
        "playerHpEnd": s.get("playerHpEnd"),
        "enemyHpEnd": s.get("enemyHpEnd"),
        "room": lab.get("roomId"),
        "traits": (lab.get("enemy") or {}).get("traits"),
    }


def play_one(page, case: dict, idx: int) -> dict:
    page.goto(BASE, wait_until="domcontentloaded")
    page.wait_for_function("() => window.CabinDebug && window.CabinDebug.getState()?.data", timeout=15000)
    setup = page.evaluate(SETUP_JS, {"roomId": case["room"], "relics": case["relics"]})
    page.wait_for_function("() => window.CabinDebug.getState().combat", timeout=5000)

    actions = []
    turns = 0
    for _ in range(MAX_TURNS * 8):
        c = page.evaluate("() => !!window.CabinDebug.getState().combat")
        if not c:
            break
        result = page.evaluate(HIDE_BOT_JS)
        actions.append(result.get("action"))
        if result.get("error"):
            return {"case": case, "error": result["error"], "setup": setup}
        if result.get("done"):
            break
        if result.get("action") == "end-turn":
            turns += 1
            page.wait_for_timeout(60)
        else:
            page.wait_for_timeout(25)
        if turns >= MAX_TURNS:
            # 强制收工，避免无限
            page.evaluate("() => { const c=CabinDebug.getState().combat; if(c) CabinDebug.loseCombat('hp'); }")
            break

    page.wait_for_timeout(120)
    lab_store = page.evaluate("() => window.CabinDebug.loadLabStore()")
    last = (lab_store.get("runs") or [None])[0]
    fl, snap = flags_for(last)
    return {
        "run": idx,
        "label": case["label"],
        "setup": setup,
        "end_turns": turns,
        "actions_sample": actions[:30],
        "flags": fl,
        "snap": snap,
        "lab_id": last.get("id") if last else None,
    }


def main():
    results = []
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.on("pageerror", lambda err: print("PAGEERROR:", err, file=sys.stderr))
        for i, case in enumerate(CASES, 1):
            print(f"=== {i}/5 {case['label']} ({case['room']}) ===", flush=True)
            try:
                r = play_one(page, case, i)
                results.append(r)
                snap = r.get("snap") or {}
                print(
                    f"  outcome={snap.get('outcome')} T={snap.get('turns')} "
                    f"atk={snap.get('enemyAttacks')} taken={snap.get('damageTaken')} "
                    f"dealt={snap.get('damageDealt')} stallDmg={snap.get('stall_dmg')} "
                    f"sees={snap.get('sees')} decoy={snap.get('decoy')} "
                    f"flags={r.get('flags')}",
                    flush=True,
                )
            except Exception as e:
                print(f"  FAIL: {e}", flush=True)
                results.append({"run": i, "label": case["label"], "error": str(e)})
        browser.close()

    suspects = [r for r in results if r.get("flags")]
    payload = {
        "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "mode": "hide-stall probe ×5",
        "suspectCount": len(suspects),
        "results": results,
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print("\n=== VERDICT ===")
    if not suspects:
        print("5 场均未检出「零出手 / 援助击杀 / 纸影卡死」。")
    else:
        print(f"检出 {len(suspects)}/{len(results)} 场异常：")
        for r in suspects:
            print(f"  - {r.get('label')}: {r.get('flags')} | {r.get('snap')}")
    print(f"Wrote {OUT}")
    return 1 if suspects else 0


if __name__ == "__main__":
    sys.exit(main())
