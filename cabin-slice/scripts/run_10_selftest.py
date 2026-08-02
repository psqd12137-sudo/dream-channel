#!/usr/bin/env python3
"""跑 10 局全流程自测（5 策略 × 2），并支持玩家摆房模式。"""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import full_selftest as base

OUT = Path(__file__).resolve().parent.parent / "lab-10run-selftest.json"

# 补点 QTE / 拼图 / 「回到散步」等，避免卡在考验屏空转
CLICK_CHOICE_JS = r"""
({ preferHeal, takeCards, relicPrefer, cardPrefer }) => {
  const end = document.getElementById("screen-end");
  if (end && end.classList.contains("active")) return { clicked: false, phase: "end" };

  const qte = document.getElementById("screen-qte");
  if (qte && qte.classList.contains("active")) {
    const go = document.getElementById("btn-qte-go");
    if (go && !go.disabled && !go.classList.contains("hidden")) {
      go.click();
      return { clicked: true, phase: "qte-go" };
    }
    const forfeit = document.getElementById("btn-qte-forfeit");
    if (forfeit) { forfeit.click(); return { clicked: true, phase: "qte-forfeit" }; }
    const exit = document.getElementById("btn-qte-exit");
    if (exit && !exit.classList.contains("hidden")) {
      exit.click();
      return { clicked: true, phase: "qte-exit" };
    }
    return { clicked: false, phase: "qte" };
  }

  const puzzle = document.getElementById("screen-puzzle");
  if (puzzle && puzzle.classList.contains("active")) {
    const forfeit = document.getElementById("btn-puzzle-forfeit");
    if (forfeit) { forfeit.click(); return { clicked: true, phase: "puzzle-forfeit" }; }
    const exit = document.getElementById("btn-puzzle-exit");
    if (exit && !exit.classList.contains("hidden")) {
      exit.click();
      return { clicked: true, phase: "puzzle-exit" };
    }
    return { clicked: false, phase: "puzzle" };
  }

  const boss = document.getElementById("screen-boss");
  if (boss && boss.classList.contains("active")) {
    const actions = document.getElementById("boss-actions");
    const btn = [...(actions?.querySelectorAll("button")||[])].find(b => /进入/.test(b.textContent||""));
    if (btn) { btn.click(); return { clicked: true, phase: "boss-enter" }; }
    return { clicked: false, phase: "boss" };
  }

  const event = document.getElementById("screen-event");
  if (!(event && event.classList.contains("active"))) return { clicked: false, phase: "none" };

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
      const prefer = cardPrefer || [];
      let bestI = 0;
      let bestS = 99;
      cards.forEach((card, i) => {
        const t = card.textContent || "";
        let s = 20;
        prefer.forEach((id, rank) => {
          const names = {
            fling: /甩开/, riposte: /迎击/, brace: /绷紧/, shove: /推撞/,
            jab: /地刺/, snare: /坠物|捕|网/, heavy: /重击|砸/, guard: /盐/,
            tonic: /补剂/, keepsake: /护身/, flare: /闪/,
          };
          if (names[id] && names[id].test(t)) s = Math.min(s, rank);
        });
        if (/甩开|迎击|绷紧/.test(t)) s = Math.min(s, 0);
        if (s < bestS) { bestS = s; bestI = i; }
      });
      const take = (cards[bestI] && cards[bestI].querySelector("button")) || rewardBtns[0];
      take.click();
      return { clicked: true, phase: "take-card", preferScore: bestS };
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
  if (i < 0) i = pick(t => /开战|打吧|进入惊吓|继续惊吓/.test(t));
  if (i < 0) i = pick(t => /回到散步|收下预兆|带上|接受|继续前进|离开|知道了|明白|开干/.test(t) && !/放弃|什么都不要|先回去|撤退/.test(t));
  if (i < 0 && takeCards) i = pick(t => /收下/.test(t));
  if (i < 0) i = pick(t => /速度/.test(t));
  if (i < 0) i = pick(t => !/放弃|什么都不要|先回去|撤退/.test(t));
  if (i < 0) i = 0;
  btns[i].click();
  return { clicked: true, phase: "choice", label: labels[i] };
}
"""

BUILD_PREFIX_JS = r"""
({ preferCombat, preferQuiet, latePush }) => {
  const D = window.CabinDebug;
  const st = D.getState();
  if (st.combat) return null;
  const playerMode = st.data?.rooms?.layoutRoll?.mode === "player";
  if (!playerMode || st.tutorial?.active) return null;

  const dockOpen = document.body.classList.contains("is-map-building");
  if (dockOpen) {
    const wraps = [...document.querySelectorAll(".build-offer-wrap")];
    if (wraps.length) {
      let best = 0;
      let bestScore = -1e9;
      wraps.forEach((w, i) => {
        const t = w.textContent || "";
        let s = Math.random() * 0.15;
        if (/惊吓/.test(t)) s += preferCombat;
        else if (/静室/.test(t)) s += preferQuiet;
        else if (/考验/.test(t)) s += (preferQuiet + preferCombat) * 0.45;
        if (latePush && (st.visitPath?.length || 0) >= 6 && /惊吓/.test(t)) s += 0.35;
        if (s > bestScore) { bestScore = s; best = i; }
      });
      wraps[best].click();
    }
    for (let i = 0; i < 4; i++) {
      const ok = document.querySelector(".map-build-btn-ok");
      if (!ok) break;
      ok.click();
      if (!document.body.classList.contains("is-map-building")) {
        return { action: "build-commit" };
      }
      const rot = document.querySelector(".map-build-btn-rot");
      if (rot) rot.click();
    }
    const cancel = document.querySelector(".map-build-btn-cancel");
    if (cancel) cancel.click();
    return { action: "build-abort" };
  }

  if (st.nodePending) return null;
  if (D.runReadyForBoss()) return null;

  const layoutCount = st.roomLayout ? Object.keys(st.roomLayout).length : 0;
  if (layoutCount >= 16) return null;
  const runLen = st.data?.rooms?.runLength || 12;
  const here = D.roomDef(st.roomId);
  const exits = (here?.exits || []).filter((id) => {
    const r = D.roomDef(id);
    return r && !r.bossRoom;
  });
  const visited = st.resolvedRooms;
  const unvisited = exits.filter((id) => !visited.has(id));
  const slots = [...document.querySelectorAll(".map-slot")];
  if (!slots.length) return null;

  const needProgress = (st.visitPath?.length || 0) < runLen;
  const stuck = !exits.length || (!unvisited.length && needProgress);
  const thinMap = layoutCount < Math.min(runLen + 1, 14);
  if (!(stuck || thinMap)) return null;

  slots[Math.floor(Math.random() * slots.length)].click();
  return { action: "build-open", layoutCount };
};
"""


def play_full_with_build(page, strategy: dict):
    page.goto(base.BASE, wait_until="networkidle")
    page.wait_for_function("() => window.CabinDebug && window.CabinDebug.getState()?.data")
    page.evaluate(
        """() => {
      try { window.CabinAudio && window.CabinAudio.setMuted(true); } catch (e) {}
      localStorage.removeItem('cabin-run-v3');
      localStorage.removeItem('cabin-lab-v1');
    }"""
    )

    # 强制用磁盘最新 layoutRoll（避免固定 query bust 残留旧 mode）
    page.evaluate(
        """async () => {
      const fresh = await (await fetch('data/rooms.json?nocache=' + Date.now())).json();
      const st = window.CabinDebug.getState();
      st.data.rooms = fresh;
      st.data.roomsMain = fresh;
      if (!st.data.rooms.layoutRoll) st.data.rooms.layoutRoll = {};
      st.data.rooms.layoutRoll.mode = 'player';
    }"""
    )

    page.click("#btn-start")
    page.wait_for_function("() => window.CabinDebug.getState().roomId", timeout=10000)
    page.wait_for_timeout(150)

    meta = page.evaluate(
        """() => {
      const st = window.CabinDebug.getState();
      return {
        mode: st.data?.rooms?.layoutRoll?.mode,
        rooms: Object.keys(st.roomLayout || {}).length,
        topology: st.layoutTopology || null,
      };
    }"""
    )
    if meta.get("mode") != "player" or (meta.get("rooms") or 0) > 3:
        # 再强制一次 player 开局
        page.evaluate(
            """() => {
          const st = window.CabinDebug.getState();
          st.data.rooms.layoutRoll = st.data.rooms.layoutRoll || {};
          st.data.rooms.layoutRoll.mode = 'player';
          window.CabinDebug.resetGame();
        }"""
        )
        page.wait_for_timeout(150)

    if strategy.get("seed_ready"):
        ids = strategy.get("seed_ready_ids") or ["fling", "riposte", "brace"]
        page.evaluate(
            """(ids) => {
          const st = window.CabinDebug.getState();
          for (const id of ids) {
            const def = window.CabinDebug.cardDef(id);
            if (!def) continue;
            st.deck.push({
              id,
              uid: 'seed-' + id + '-' + Math.random().toString(36).slice(2, 8),
            });
          }
        }""",
            ids,
        )

    log = []
    combat_logs = []
    steps = 0
    combat_actions = 0

    while steps < base.MAX_STEPS:
        steps += 1
        snap = base.snapshot(page)
        if snap.get("ended"):
            break

        clicked = page.evaluate(
            CLICK_CHOICE_JS,
            {
                "preferHeal": strategy.get("heal_bias", False),
                "takeCards": strategy.get("take_cards", True),
                "relicPrefer": strategy.get("relic_prefer") or [],
                "cardPrefer": strategy.get("card_prefer") or [],
            },
        )
        if clicked.get("clicked"):
            log.append({"step": steps, **clicked})
            page.wait_for_timeout(40)
            continue

        snap = base.snapshot(page)
        if snap.get("ended"):
            break

        if snap.get("hasCombat"):
            if combat_actions >= base.MAX_COMBAT_ACTIONS:
                page.evaluate(
                    "() => { const c=window.CabinDebug.getState().combat; if(c){c.placeUid=null;} window.CabinDebug.endTurn(); }"
                )
                combat_actions += 1
                log.append({"step": steps, "action": "combat-cap-endturn"})
                continue
            act = page.evaluate(
                base.COMBAT_STEP_JS,
                {
                    "bossStyle": strategy.get("boss_style") or "kill",
                    "readyBias": strategy.get("prefer_ready") or 0.0,
                    "cardPrefer": strategy.get("card_prefer") or [],
                },
            )
            combat_actions += 1
            combat_logs.append(act)
            log.append({"step": steps, "phase": "combat", **act})
            page.wait_for_timeout(20)
            continue

        built = page.evaluate(
            BUILD_PREFIX_JS,
            {
                "preferCombat": strategy.get("prefer_combat", 0.5),
                "preferQuiet": strategy.get("prefer_quiet", 0.5),
                "latePush": bool(strategy.get("late_combat_push")),
            },
        )
        if built:
            log.append({"step": steps, **built})
            page.wait_for_timeout(40)
            continue

        move = page.evaluate(
            base.EXPLORE_STEP_JS,
            {
                "preferCombat": strategy.get("prefer_combat", 0.5),
                "preferQuiet": strategy.get("prefer_quiet", 0.5),
                "latePush": bool(strategy.get("late_combat_push")),
            },
        )
        log.append({"step": steps, **move})
        if move.get("action") == "stuck":
            built2 = page.evaluate(
                BUILD_PREFIX_JS,
                {
                    "preferCombat": strategy.get("prefer_combat", 0.5),
                    "preferQuiet": strategy.get("prefer_quiet", 0.5),
                    "latePush": True,
                },
            )
            if built2:
                log.append({"step": steps, "retry": True, **built2})
                page.wait_for_timeout(40)
                continue
            break
        page.wait_for_timeout(30)

    final = base.snapshot(page)
    lab_store = page.evaluate("() => window.CabinDebug.loadLabStore()")
    labs = lab_store.get("runs") or []
    layout_meta = page.evaluate(
        """() => {
          const st = window.CabinDebug.getState();
          return {
            mode: st.data?.rooms?.layoutRoll?.mode,
            layoutCount: Object.keys(st.roomLayout || {}).length,
            topology: st.layoutTopology || null,
          };
        }"""
    )
    return {
        "strategy": strategy["id"],
        "label": strategy["label"],
        "final": final,
        "steps": steps,
        "log_tail": log[-50:],
        "combat_action_count": len(combat_logs),
        "labs": labs[:12],
        "layoutMode": layout_meta.get("mode"),
        "layoutCount": layout_meta.get("layoutCount"),
        "layoutTopology": layout_meta.get("topology"),
    }


def main():
    strategies = []
    for round_i in (1, 2):
        for s in base.STRATEGIES:
            strategies.append(
                {
                    **s,
                    "id": f"{s['id']}__r{round_i}",
                    "label": f"{s['label']}#{round_i}",
                }
            )

    results = []
    with base.sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.on("pageerror", lambda err: print("PAGEERROR:", err, file=sys.stderr))
        page.goto(base.BASE, wait_until="networkidle")
        page.wait_for_function("() => window.CabinDebug")
        page.evaluate("() => localStorage.removeItem('cabin-lab-v1')")

        for i, strat in enumerate(strategies, 1):
            print(
                f"\n=== [{i}/{len(strategies)}] {strat['label']} ({strat['id']}) ===",
                flush=True,
            )
            page.evaluate("() => localStorage.removeItem('cabin-lab-v1')")
            try:
                r = play_full_with_build(page, strat)
                results.append(r)
                f = r["final"]
                labs = r.get("labs") or []
                boss = next(
                    (x for x in labs if x.get("enemy", {}).get("isBoss")), None
                )
                s = (boss or {}).get("summary") or {}
                print(
                    f"  mode={r.get('layoutMode')} topo={r.get('layoutTopology')} "
                    f"rooms={r.get('layoutCount')} "
                    f"end={f.get('endResult')!r} title={f.get('endTitle')!r} "
                    f"path={f.get('visitLen')} combats={f.get('combatCount')} "
                    f"boss={f.get('chosenBoss')} outcome={boss and boss.get('outcome')} "
                    f"reason={s.get('outcomeReason')} turns={s.get('turns')} "
                    f"anchors={s.get('anchorsCleared')}/{s.get('anchorsTotal')} "
                    f"broadcast={s.get('broadcastEnd')}",
                    flush=True,
                )
                print(f"  visitPath={f.get('visitPath')}", flush=True)
                print(
                    f"  relics={f.get('relics')} deck={f.get('deckSize')} "
                    f"hp={f.get('hp')}/{f.get('maxHp')} speed={f.get('speed')}",
                    flush=True,
                )
            except Exception as e:
                print(f"  FAIL: {e}", flush=True)
                results.append(
                    {
                        "strategy": strat["id"],
                        "label": strat["label"],
                        "error": str(e),
                        "final": {},
                        "labs": [],
                    }
                )

        browser.close()

    summary = base.analyze(results)
    payload = {
        "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "n": len(results),
        "note": "latest local main; player layout forced; 5 strategies x 2",
        "summary": summary,
        "runs": results,
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    print("\n========== 10 局全流程自测报告 ==========")
    for row in summary:
        print(json.dumps(row, ensure_ascii=False))
    print(f"\nWrote {OUT}")

    finished = [x for x in summary if x.get("ended")]
    wins = [
        x
        for x in finished
        if x.get("endResult") and "赢" in (x.get("endResult") or "")
    ]
    reached_boss = [
        x for x in summary if x.get("boss_outcome") or x.get("chosenBoss")
    ]
    print(
        f"\n总览: 完成结局屏 {len(finished)}/{len(summary)} · 通关文案胜 {len(wins)} · "
        f"摸到Boss标记 {len(reached_boss)} · "
        f"Boss胜 {sum(1 for x in summary if x.get('boss_outcome')=='win')} · "
        f"Boss负 {sum(1 for x in summary if x.get('boss_outcome')=='lose')} · "
        f"普通战胜 {sum(x.get('normal_wins') or 0 for x in summary)}/"
        f"{sum((x.get('normal_wins') or 0) + (x.get('normal_losses') or 0) for x in summary)}"
    )


if __name__ == "__main__":
    main()
