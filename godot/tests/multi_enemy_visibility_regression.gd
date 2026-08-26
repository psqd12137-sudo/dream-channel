extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://channel_3d.tscn") as PackedScene
	_check(packed != null, "channel scene must load")
	if packed == null:
		_finish()
		return
	var game := packed.instantiate() as Node3D
	game.animation_duration_scale = 0.0
	game.active_relics.clear()
	root.add_child(game)
	await process_frame
	await process_frame
	var room := {
		"id": "visibility_room",
		"name": "信息边界验收",
		"arena": {"cols": 6, "rows": 3, "player": [0, 1], "walls": []},
		"enemies": [
			{"id": "hidden", "name": "隐藏者", "spawn": [5, 0], "hp": 9, "toughness": 4, "archetype": "execute"},
			{"id": "visible", "name": "已揭示", "spawn": [4, 1], "hp": 6, "toughness": 2, "archetype": "patrol"},
		],
	}
	game.start_combat(room)
	await process_frame
	var combat = game.combat
	var hidden = combat.enemy_by_id("hidden")
	var visible = combat.enemy_by_id("visible")
	# Visibility is normally recomputed from line of sight during a refresh;
	# force the post-refresh state here so this test isolates HUD/camera privacy.
	hidden.revealed = false
	visible.revealed = true
	game.battle_focused_enemy_id = "hidden"
	game.battle_world_renderer.update_battle_feedback_overlay()
	var hud: Control = game.get_node("HUD/HUDRoot")
	_check(not game.enemy_intel_visible(), "formal combat must not expose enemy intel without test mode or relic")
	_check(str(hud.call("_turn_order_enemy_label", hidden, 0)) == "??", "hidden enemy turn-order chip must stay generic")
	# Do not re-plan here: a fresh vision refresh is allowed to reveal the
	# synthetic hidden enemy. Rebuild only the presentation from the existing
	# snapshot after forcing the visibility boundary.
	game.battle_world_renderer._refresh_battle_intent_arrows()
	var intent_cells: Dictionary = game.battle_world_renderer._battle_intent_cells()
	for raw_entry: Variant in intent_cells.values():
		var entry: Dictionary = raw_entry
		for group_name: String in ["impact", "threat", "enemy_move", "path", "line"]:
			for raw_marker: Variant in entry.get(group_name, []):
				var marker: Dictionary = raw_marker
				_check(str(marker.get("enemy_id", "")) != "hidden", "hidden enemy must not add board intent markers")
	for child: Node in game.battle_world_renderer.battle_intent_line_root.get_children():
		_check(not child.name.contains("hidden"), "hidden enemy must not add a visible path arrow")
	var hidden_display: Dictionary = hud.call("_enemy_panel_display_data", combat, hidden)
	_check(str(hidden_display.get("title", "")) == "??", "hidden enemy panel must use a generic title")
	_check(int(hidden_display.get("hp", 0)) == -1 and int(hidden_display.get("max_hp", 0)) == 0, "hidden enemy panel must not expose HP values")
	_check(int(hidden_display.get("max_toughness", 0)) == 0, "hidden enemy panel must not expose toughness capacity")
	_check(not str(hidden_display.get("footer", "")).contains("execute"), "hidden enemy panel must not expose archetype")
	_check(str(hud.call("_enemy_intent_sentence", hidden)) == "？？", "hidden enemy intent sentence must stay generic")
	_check(hud.call("_focused_enemy_state") == visible, "hidden focused enemy must fall back to the first revealed living enemy")
	var expected_follow: Vector3 = (game._battle_pawn_world(combat.player_pos, true) + game._battle_pawn_world(visible.pos, false, visible.id)) * 0.5
	_check(game._battle_follow_target_position().distance_to(expected_follow) < 0.01, "battle camera must frame only the player and revealed enemies")
	for raw_overlay: Variant in game.battle_world_renderer.battle_intent_overlay_nodes.values():
		var overlay := raw_overlay as Control
		if overlay != null and overlay.name.contains("hidden"):
			_check(overlay.visible, "hidden enemy must retain a generic intent overlay")
			var value := overlay.get_node_or_null("Badge/Value") as Label
			_check(value != null and value.text == "？？", "hidden enemy intent overlay must display ？？")
	game.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_MULTI_ENEMY_VISIBILITY: PASS hidden HUD camera intent boundary")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_MULTI_ENEMY_VISIBILITY: %s" % failure)
		quit(1)
