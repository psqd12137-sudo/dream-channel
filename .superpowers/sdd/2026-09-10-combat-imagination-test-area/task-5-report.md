# Task 5 report: cartoon combat motion and visual capture

## TDD evidence

Added the combat-lab entry assertions first, then ran:

```text
COMBAT_IMAGINATION_PRESENTATION: imagination lab must use the existing combat entry animation
COMBAT_IMAGINATION_PRESENTATION: imagination entry must expose profile-driven stagger metadata
```

The failure occurred before the production change because `start_combat_lab()` did not request the existing entry animation and the presentation root had no profile entry metadata.

## Implemented

- Test-lab combat now requests the existing `combat_entry` state lock.
- The imagination profile drives staged floor, shell and hero-prop rebound timing after the existing stage settle.
- The hero prop has low-amplitude idle motion; actor state changes and room-shell cutaway transitions get bounded squash/rebound feedback.
- All new motion remains test-lab/imagination gated and restores base transforms.
- `capture_combat_imagination.gd` uses an isolated `user://` repository and writes four untracked Vulkan captures to `output/combat-imagination/`.

## Verification

All headless checks passed:

```text
COMBAT_IMAGINATION_PRESENTATION: PASS
CHANNEL_BATTLE_VIEW_SMOKE: PASS responsive safe-view camera grid picking
CHANNEL_COMBAT_INPUT_REGRESSION: PASS cancel invalid-click move direct-damage
CHANNEL_CAMERA_ORBIT: PASS stable-scale free-orbit cutaway topology input
PRESENTATION_SETTINGS: PASS panel TAA DOF pixel parameters and feedback suppression
COMBAT_IMAGINATION_CAPTURE: SKIP graphical Vulkan display is required
```

The graphical Vulkan capture was also run successfully on the local RTX 4070:

```text
COMBAT_IMAGINATION_CAPTURE: PASS baseline imagination rotated entry
```

## Final review fixes: repeatable A/B state

The final review identified two stateful A/B failures. The imagination material pass now restores each saved original override (including a saved `null` override) before making its runtime copy, so repeated `B` selection cannot tint the already-tinted copy. The presentation entry tween is now owned separately from the combat state tween; switching to `A` settles its staged nodes to saved base transforms and cancels its idle state without interrupting the normal combat-entry lock.

The regression was extended to reproduce both cases. Before the production fix it failed with:

```text
COMBAT_IMAGINATION_PRESENTATION: baseline during entry must restore the hero's baseline scale
COMBAT_IMAGINATION_PRESENTATION: repeated imagination selection must not accumulate material tint
```

After the fix, all required checks passed:

```text
COMBAT_IMAGINATION_PRESENTATION: PASS
CHANNEL_BATTLE_VIEW_SMOKE: PASS responsive safe-view camera grid picking
CHANNEL_COMBAT_INPUT_REGRESSION: PASS cancel invalid-click move direct-damage
CHANNEL_CAMERA_ORBIT: PASS stable-scale free-orbit cutaway topology input
PRESENTATION_SETTINGS: PASS panel TAA DOF pixel parameters and feedback suppression
COMBAT_IMAGINATION_CAPTURE: SKIP graphical Vulkan display is required
COMBAT_IMAGINATION_CAPTURE: PASS baseline imagination rotated entry
```

Reviewed `output/combat-imagination/imagination.png` and `imagination-entry.png`: the active room, actors, walls and UI remain in frame, with no visible debug overlay or geometry breakage. Output images remain untracked by design.

## Post-fix final review: tween ownership and entry-ready fixture

The follow-up regression first ran red against the pre-fix implementation. It reported:

```text
COMBAT_IMAGINATION_PRESENTATION: baseline after repeated imagination entry selection must stop the first hero idle tween
COMBAT_IMAGINATION_PRESENTATION: rapid public card selection must restore the player scale before baseline
COMBAT_IMAGINATION_PRESENTATION: baseline must clear rapid public card selection feedback
CHANNEL_ENEMY_TURN_ANIMATION: enemy patrol tween must drive the temporary 3D model Walk loop
CHANNEL_ENEMY_TURN_ANIMATION: enemy rules position must finish on a different patrol cell
```

`channel_battle_world_renderer.gd` now gives both effects an explicit owner. Hero idle refuses to start while the entry stagger owns that hero, restores and kills any previous loop before replacement, and clears its saved transform metadata when stopped. Entry completion only starts its one idle loop if it still owns the stagger. Actor action feedback now replaces a prior feedback tween after restoring the actor's stored base scale; baseline and lab exit stop every actor feedback tween.

`combat_imagination_presentation_regression.gd` covers repeated B during entry followed by both baseline and direct lab exit, checks the original idle tween is no longer running and the hero returns to its baseline scale, and drives rapid `select_or_play_card(0)` / `cancel_selected_card()` calls through the public control path. `enemy_turn_animation_regression.gd` waits for the intentional combat-entry lock to release before it starts its patrol assertions.

Fresh verification exited 0 for the imagination presentation regression, battle view, combat input, camera orbit, camera dolly follow, presentation settings, presentation animation, dynamic effects, turn timing, multi-enemy presentation, room footprint, and enemy-turn animation regressions. The headless capture completed its expected graphical skip. A Forward+ Vulkan capture on the RTX 4070 Laptop GPU completed with `COMBAT_IMAGINATION_CAPTURE: PASS baseline imagination rotated entry`; all four regenerated images were reviewed and keep the hall, actors, furniture, and UI in frame.

## Review fix: isolated capture save cleanup

The scoped review found that an interrupted earlier capture could leave the dedicated `user://combat_imagination_capture.json` file behind. The capture regression now deliberately writes a stale dedicated file, verifies it exists, clears it before `start_combat_lab("hall")`, and verifies it is gone. The initial red run failed with:

```text
COMBAT_IMAGINATION_CAPTURE: capture lab must clear a stale isolated save before it starts
```

After the cleanup change, verification passed:

```text
COMBAT_IMAGINATION_CAPTURE: SKIP graphical Vulkan display is required
COMBAT_IMAGINATION_PRESENTATION: PASS
COMBAT_IMAGINATION_CAPTURE: PASS baseline imagination rotated entry
```

## Final motion review fix: entry-to-idle ownership handoff

The final motion review found that the entry tween still owned its staged hero when its completion callback tried to start idle motion. The idle-start guard correctly rejected that overlap, but natural entry therefore left the hero motionless until an extra A/B selection.

The presentation regression now starts a fresh imagination lab, waits for both the combat-entry lock and `imagination_entry_active` to settle, then verifies the hero has a running `imagination_idle_tween` and its Y position changes over the next 0.30 seconds. The red run against the pre-fix completion order exited 1 with:

```text
COMBAT_IMAGINATION_PRESENTATION: natural imagination entry must start the hero idle tween after stagger ownership releases
COMBAT_IMAGINATION_PRESENTATION: hero must move after natural imagination entry settles
```

The completion callback now removes entry-only transform metadata, releases `imagination_entry_tween` and `imagination_entry_nodes`, and only then starts the single hero idle loop. This retains the existing entry transforms and leaves repeated A/B cleanup, combat-entry locking, and direct lab exit behavior intact.

The green regression exited 0 with:

```text
COMBAT_IMAGINATION_PRESENTATION: PASS
```

All 12 scoped and related headless regressions exited 0:

```text
COMBAT_IMAGINATION_PRESENTATION: PASS
CHANNEL_ENEMY_TURN_ANIMATION: PASS lock tween settle
CHANNEL_BATTLE_VIEW_SMOKE: PASS responsive safe-view camera grid picking
CHANNEL_COMBAT_INPUT_REGRESSION: PASS cancel invalid-click move direct-damage
CHANNEL_CAMERA_ORBIT: PASS stable-scale free-orbit cutaway topology input
CHANNEL_CAMERA_DOLLY_FOLLOW: PASS intro dolly delayed follow rotation-preserved return
PRESENTATION_SETTINGS: PASS panel TAA DOF pixel parameters and feedback suppression
CHANNEL_PRESENTATION_ANIMATION: PASS 3d-model idle walk attack hurt fallback
CHANNEL_DYNAMIC_EFFECTS_SMOKE: PASS room-drop actor-walk hidden-reveal input-lock
CHANNEL_TURN_TIMING: PASS enemy-turn-no-deal draw-after-animation
CHANNEL_MULTI_ENEMY_PRESENTATION: PASS nodes camera targeting animation hud
CHANNEL_ROOM_FOOTPRINT: PASS tiers multi-cell occupancy shared-completion
```

The headless capture exited 0 with its expected graphical skip:

```text
COMBAT_IMAGINATION_CAPTURE: SKIP graphical Vulkan display is required
```

The Forward+ graphical capture also exited 0 on the NVIDIA GeForce RTX 4070 Laptop GPU:

```text
COMBAT_IMAGINATION_CAPTURE: PASS baseline imagination rotated entry
```

The engine reported its existing ObjectDB/resource-cleanup warnings on several successful exits; no scoped regression failed.
