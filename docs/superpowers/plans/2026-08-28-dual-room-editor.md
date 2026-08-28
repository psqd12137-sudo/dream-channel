# Dual Room Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend Godot Asset Editor so the same 1/3/5-grid room types can edit independent overworld and dungeon-room spatial layouts.

**Architecture:** Keep `room_rules.placed` and existing overworld overrides as the world layer. Add a small data-driven dungeon layout catalog/manifest, then make `asset_editor_3d.gd` switch between world and dungeon targets while sharing the existing geometry and prop editing code.

**Tech Stack:** Godot 4.7 GDScript, JSON resources, SceneTree smoke tests, PowerShell Godot console runner.

**Spec:** `docs/superpowers/specs/2026-08-28-dual-room-editor-design.md`

## Global Constraints

- Preserve `room_rules.placed` one-instance semantics for every 1/3/5 footprint.
- Keep `room_size / footprint_kind / footprint` separate from encounter and combat data.
- Keep existing `data/editor/overrides/<room_id>.json` format and export behavior compatible.
- Dungeon layouts contain only spatial data: footprint, rotation, assets, walls and fixtures.
- Missing dungeon mappings/layouts must fall back deterministically without blocking the editor.
- Do not stage Godot-generated `.import`, `.uid`, `.TMP`, or unrelated editor files.

### Task 1: Add the dungeon layout catalog and manifest

**Files:**
- Create: `godot/scripts/dungeon_layout_catalog.gd`
- Create: `godot/data/editor/dungeon_layout_manifest.json`
- Test: `godot/tests/dungeon_layout_catalog_regression.gd`

**Interfaces:**
- Produces `DungeonLayoutCatalog.link_for(world_room_id: String) -> Dictionary`.
- Produces `DungeonLayoutCatalog.default_layout_id(world_room_id: String) -> String`.
- Produces `DungeonLayoutCatalog.layout_path(layout_id: String) -> String`.
- Produces `DungeonLayoutCatalog.make_payload(layout_id: String, world_room_id: String, state: Dictionary) -> Dictionary`.
- Produces `DungeonLayoutCatalog.load_layout(layout_id: String, world_room_id: String) -> Dictionary`.

- [x] **Step 1: Write the failing catalog regression test**

  Assert the manifest covers every room in `RoomFootprintCatalog.ROOM_CONFIG`, default IDs are unique and deterministic, default footprint sizes are 1/3/5, and a missing layout returns an empty dictionary rather than importing gameplay fields.

- [x] **Step 2: Run the test and verify the expected failure**

  Run:

  ```powershell
  & 'D:\godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'G:\dream-channel\godot' --script 'res://tests/dungeon_layout_catalog_regression.gd'
  ```

  Expected: failure because `dungeon_layout_catalog.gd` and its manifest do not exist yet.

- [x] **Step 3: Implement the manifest and catalog**

  Add one manifest link per formal room. Normalize invalid/missing links to `<world_room_id>_dungeon_01`, resolve `res://data/editor/dungeon_layouts/<layout_id>.json`, and validate loaded JSON as spatial data with `schema_version >= 1` and matching IDs.

- [x] **Step 4: Run the catalog test and verify it passes**

  Re-run the command from Step 2. Expected: `CHANNEL_DUNGEON_LAYOUT_CATALOG: PASS`.

- [x] **Step 5: Commit the catalog unit**

  ```powershell
  git add godot/scripts/dungeon_layout_catalog.gd godot/data/editor/dungeon_layout_manifest.json godot/tests/dungeon_layout_catalog_regression.gd
  git commit -m "feat(godot): add dungeon layout catalog"
  ```

### Task 2: Add Asset Editor layer switching and dungeon fallback loading

**Files:**
- Modify: `godot/scenes/asset_editor_3d.tscn`
- Modify: `godot/scripts/asset_editor_3d.gd`
- Test: `godot/tests/asset_editor_room_layers_regression.gd`

**Interfaces:**
- Adds `edit_layer_id: String` with values `world` and `dungeon`.
- Adds `_set_edit_layer(layer_id: String, record_undo := true) -> void`.
- Adds `_current_layout_target() -> Dictionary` returning layer, world room ID and target layout ID.
- Keeps `_load_formal_room_layout(room_id: String, record_undo := true) -> int` as the room selection entry point.
- Adds `_load_dungeon_layout(room_id: String, record_undo := true) -> int`.

- [x] **Step 1: Write the failing editor layer regression test**

  Instantiate `res://scenes/asset_editor_3d.tscn`, assert the default layer is world, switch to dungeon, assert the selected source room remains stable and the target ID is `<room_id>_dungeon_01`, then switch back and assert the world target is restored.

- [x] **Step 2: Run the test and verify the expected failure**

  Run:

  ```powershell
  & 'D:\godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'G:\dream-channel\godot' --script 'res://tests/asset_editor_room_layers_regression.gd'
  ```

  Expected: failure because the editor has no layer state or layer control.

- [x] **Step 3: Implement the shared layer state and UI**

  Add an `EditLayer` `OptionButton` to the top bar. Keep one selected formal source room, add `dungeon_layout_id` state, and route layer changes through `_set_edit_layer`. World mode keeps existing labels and export ID; dungeon mode updates labels, target ID and status text.

- [x] **Step 4: Implement dungeon fallback loading**

  Load a validated dungeon JSON when present. If absent, convert the existing formal world override into the editor snapshot while preserving the source room ID and default footprint. Do not modify the world override during dungeon edits.

- [x] **Step 5: Run the editor layer test and verify it passes**

  Re-run the command from Step 2. Expected: `CHANNEL_ASSET_EDITOR_ROOM_LAYERS: PASS`.

- [x] **Step 6: Commit the editor layer unit**

  ```powershell
  git add godot/scenes/asset_editor_3d.tscn godot/scripts/asset_editor_3d.gd godot/tests/asset_editor_room_layers_regression.gd
  git commit -m "feat(godot): add overworld and dungeon editor layers"
  ```

### Task 3: Add independent dungeon layout export

**Files:**
- Modify: `godot/scenes/asset_editor_3d.tscn`
- Modify: `godot/scripts/asset_editor_3d.gd`
- Test: `godot/tests/dungeon_layout_export_regression.gd`

**Interfaces:**
- Adds `_export_dungeon_layout(layout_id: String) -> String`.
- Keeps `_export_override(room_id: String) -> String` unchanged for world mode.

- [x] **Step 1: Write the failing export regression test**

  Switch an editor instance to dungeon mode, export `__smoke_dungeon__`, parse the returned JSON, assert schema/IDs/spatial keys, assert no `enemies`, `arena`, `cards`, or `rewards` keys, and remove the smoke file.

- [x] **Step 2: Run the test and verify the expected failure**

  Run the Godot console command for `res://tests/dungeon_layout_export_regression.gd`. Expected: failure because dungeon export is not defined.

- [x] **Step 3: Implement export and dynamic labels**

  Add a dungeon export button or reuse the existing export button with dynamic text. Use `DungeonLayoutCatalog.make_payload`, create `data/editor/dungeon_layouts/` if needed, and write only spatial fields. Switch the existing UI back to world-mode wording when the layer changes.

- [x] **Step 4: Run the export regression and existing formal export test**

  Run both:

  ```powershell
  & 'D:\godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'G:\dream-channel\godot' --script 'res://tests/dungeon_layout_export_regression.gd'
  & 'D:\godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'G:\dream-channel\godot' --script 'res://tests/formal_override_export_smoke.gd'
  ```

  Expected: both pass.

- [x] **Step 5: Commit the export unit**

  ```powershell
  git add godot/scenes/asset_editor_3d.tscn godot/scripts/asset_editor_3d.gd godot/tests/dungeon_layout_export_regression.gd
  git commit -m "feat(godot): export independent dungeon layouts"
  ```

### Task 4: Document and verify the complete flow

**Files:**
- Modify: `godot/README.md`
- Test: `godot/tests/room_footprint_regression.gd` (run only; modify only if an assertion exposes a real regression)

- [x] **Step 1: Update README room sections**

  Document the two editor layers, the mapping manifest, the dungeon layout path, fallback behavior and the fact that combat data remains separate.

- [x] **Step 2: Run the complete targeted verification set**

  Run:

  ```powershell
  & 'D:\godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'G:\dream-channel\godot' --script 'res://tests/dungeon_layout_catalog_regression.gd'
  & 'D:\godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'G:\dream-channel\godot' --script 'res://tests/asset_editor_room_layers_regression.gd'
  & 'D:\godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'G:\dream-channel\godot' --script 'res://tests/dungeon_layout_export_regression.gd'
  & 'D:\godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'G:\dream-channel\godot' --script 'res://tests/room_footprint_regression.gd'
  & 'D:\godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'G:\dream-channel\godot' --script 'res://tests/quaternius_room_art_smoke.gd'
  ```

  Expected: all commands exit 0 and print their PASS markers.

- [x] **Step 3: Check only intended files are staged**

  Run `git diff --cached --name-status` and ensure no `.import`, `.uid`, `.TMP`, or unrelated editor artifact is staged.

- [x] **Step 4: Commit the documentation and final verification record**

  ```powershell
  git add godot/README.md
  git commit -m "docs(godot): document dual room editing"
  ```
