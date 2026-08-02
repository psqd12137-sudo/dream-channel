#!/usr/bin/env python3
"""10 局随机策略全流程测试：统计正常流程下 Boss 分布，重点看 3 个新剧本 Boss 出现情况。"""

from __future__ import annotations

import json
import random
import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

from full_selftest import CLICK_CHOICE_JS, COMBAT_STEP_JS, EXPLORE_STEP_JS

BASE = "http://127.0.0.1:8787/"
OUT = Path(__file__).resolve().parent.parent / "lab-10run-boss-dist.json"
MAX_STEPS = 220
MAX_COMBAT_ACTIONS = 60
N_RUNS = 10

NEW_BOSS_IDS = {"director_cut", "hide_and_seek", "stars_align"}
BOSS_CN = {
    "channel_host": "频道宿主",
    "whisper_wall": "墙内耳语",
    "fog_walker": "雾中行人",
    "rust_keeper": "锈锁看守",
    "director_cut": "疯狂导演",
    "hide_and_seek": "躲猫猫小姐",
    "stars_align": "星位司仪",
}


def random_strategy(rng: random.Random) -> dict:
    prefer_combat = rng.random()
    prefer_quiet = 1 - prefer_combat
    return {
        "id": f"rand-{rng.randint(0, 999999):06d}",
        "label": "随机策略",
        "prefer_combat": prefer_combat,
        "prefer_quiet": prefer_quiet,
        "boss_style": rng.choice(["kill", "ritual", "bait"]),
        "relic_prefer": [],
        "card_prefer": [],
        "take_cards": True,
        "heal_bias": rng.random() < 0.5,
        "prefer_ready": rng.random(),
        "late_combat_push": rng.random() < 0.5,
        "seed_ready": False,
    }


def snapshot(page):
    return page.evaluate(
        """() => {
      const D = window.CabinDebug;
      const st = D.getState();
      const end = document.getElementById("screen-end");
      const cards = document.getElementById("screen-cards");
      const path = st.visitPath || [];
      const runLen = st.data?.rooms?.runLength || 12;
      const early = path.slice(1, 3);
      const late = path.length >= runLen ? path.slice(-3) : (path.length >= 8 ? path.slice(7, 10) : []);
      const roomDef = D.roomDef;
      return {
        roomId: st.roomId,
        visitLen: path.length,
        visitPath: [...path],
        earlyCombat: early.filter((id) => roomDef(id)?.combat).length,
        lateCombat: late.filter((id) => roomDef(id)?.combat).length,
        combatCount: st.combatCount || 0,
        hasCombat: !!st.combat,
        modalCards: !!(cards && cards.classList.contains("active")),
        readyBoss: D.runReadyForBoss(),
        chosenBoss: st.chosenBoss,
        ended: !!(end && end.classList.contains("active")),
        endTitle: document.getElementById("end-title")?.textContent || "",
        endResult: document.getElementById("end-result")?.textContent || "",
      };
    }"""
    )


def play_one(page, strat: dict):
    page.goto(BASE, wait_until="networkidle")
    page.wait_for_function("() => window.CabinDebug && window.CabinDebug.getState()?.data")
    page.evaluate(
        """() => {
      try { window.CabinAudio && window.CabinAudio.setMuted(true); } catch(e){}
      localStorage.removeItem('cabin-run-v3');
    }"""
    )
    page.click("#btn-start")
    page.wait_for_function("() => window.CabinDebug.getState().roomId", timeout=10000)

    log = []
    steps = 0
    combat_actions = 0
    t0 = time.time()

    while steps < MAX_STEPS:
        if time.time() - t0 > 100:
            log.append({"t": "timeout"})
            break
        steps += 1
        snap = snapshot(page)
        if snap.get("ended"):
            break

        clicked = page.evaluate(
            CLICK_CHOICE_JS,
            {
                "preferHeal": strat.get("heal_bias", False),
                "takeCards": strat.get("take_cards", True),
                "relicPrefer": strat.get("relic_prefer", []),
                "cardPrefer": strat.get("card_prefer", []),
            },
        )
        if clicked.get("clicked"):
            log.append({"t": "ui", **clicked})
            # 小游戏放弃后 onDone 延迟 520ms 才结算，等它走完再继续
            if clicked.get("phase") in ("qte-forfeit", "puzzle-forfeit"):
                page.wait_for_timeout(800)
            else:
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
                          c.playerPos.r, c.playerPos.c, !!(c.placeUid),
                          c.ready ? c.ready.cardId : '-', c.enemyPos.r, c.enemyPos.c].join('|');
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
                res = page.evaluate(
                    COMBAT_STEP_JS,
                    {
                        "bossStyle": strat.get("boss_style", "ritual"),
                        "preferReady": float(strat.get("prefer_ready", 0.4)),
                    },
                )
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

        exp = page.evaluate(
            EXPLORE_STEP_JS,
            {
                "preferCombat": strat.get("prefer_combat", 0.5),
                "preferQuiet": strat.get("prefer_quiet", 0.5),
                "latePush": bool(strat.get("late_combat_push")),
            },
        )
        log.append({"t": "explore", **exp})
        page.wait_for_timeout(40)
        if exp.get("action") == "stuck":
            break

    final = snapshot(page)
    page.wait_for_timeout(150)
    return {"final": final, "steps": steps, "log_tail": log[-20:]}


def main():
    rng = random.Random(20260802)
    results = []
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.on("pageerror", lambda err: print("PAGEERROR:", err, file=sys.stderr))

        for i in range(1, N_RUNS + 1):
            strat = random_strategy(rng)
            print(f"\n=== [{i}/{N_RUNS}] 随机 #{strat['id']} combat={strat['prefer_combat']:.2f} quiet={strat['prefer_quiet']:.2f} style={strat['boss_style']} ready={strat['prefer_ready']:.2f} ===", flush=True)
            try:
                r = play_one(page, strat)
                f = r["final"]
                results.append(r)
                print(
                    f"  end={f.get('endResult')!r} title={f.get('endTitle')!r} "
                    f"path={f.get('visitLen')} combats={f.get('combatCount')} "
                    f"fingerprint=({f.get('earlyCombat')},{f.get('lateCombat')}) "
                    f"boss={f.get('chosenBoss')}({BOSS_CN.get(f.get('chosenBoss'), '?')}) "
                    f"steps={r['steps']}",
                    flush=True,
                )
                if f.get("chosenBoss") in NEW_BOSS_IDS:
                    print(f"  >>> 命中新剧本 Boss: {BOSS_CN[f['chosenBoss']]} <<<", flush=True)
            except Exception as e:
                print(f"  FAIL: {e}", flush=True)
                results.append({"final": {}, "error": str(e), "steps": 0, "log_tail": []})

        browser.close()

    # 汇总
    dist = {}
    reach_boss = 0
    new_hits = 0
    fp_hist = {}
    for r in results:
        f = r.get("final") or {}
        boss = f.get("chosenBoss")
        if boss:
            reach_boss += 1
            dist[boss] = dist.get(boss, 0) + 1
            if boss in NEW_BOSS_IDS:
                new_hits += 1
        fp = (f.get("earlyCombat"), f.get("lateCombat"))
        fp_hist[fp] = fp_hist.get(fp, 0) + 1

    payload = {
        "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "nRuns": N_RUNS,
        "bossDistribution": {BOSS_CN.get(k, k): v for k, v in sorted(dist.items(), key=lambda x: -x[1])},
        "newBossHits": new_hits,
        "fingerprintHist": {f"({k[0]},{k[1]})": v for k, v in sorted(fp_hist.items())},
        "runs": results,
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    print("\n========== 10 局 Boss 分布 ==========")
    for name, cnt in sorted(payload["bossDistribution"].items(), key=lambda x: -x[1]):
        mark = " ★" if name in (BOSS_CN[x] for x in NEW_BOSS_IDS) else ""
        print(f"  {name}: {cnt} 局{mark}")
    print(f"\n触达 Boss: {reach_boss}/{N_RUNS} 局")
    print(f"命中新剧本 Boss: {new_hits}/{reach_boss} 局")
    print(f"指纹分布: {payload['fingerprintHist']}")
    print(f"结果已写入 {OUT}")


if __name__ == "__main__":
    main()
