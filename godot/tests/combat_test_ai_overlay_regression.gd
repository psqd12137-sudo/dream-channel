extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://channel_3d.tscn")
	var game: Node3D = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.animation_duration_scale = 0.0
	game.open_combat_test_mode()
	game.select_combat_test_scenario("hud_eight")
	_check(game.start_test_combat("manual"), "eight-enemy test must start")
	await process_frame
	var plans: Dictionary = game.combat.preview_all_tactical_plans()
	_check(plans.size() == 8, "AI overlay source must expose all eight plans")
	_check(game.test_focused_enemy_id == "eight_00", "overlay must focus the first stable enemy by default")
	game.focus_test_enemy("eight_07")
	_check(game.test_focused_enemy_id == "eight_07", "overlay focus must switch by enemy_id")
	game.select_battle_enemy("eight_07")
	var selected_node: Node3D = game.battle_world_renderer._enemy_node_for_id("eight_07")
	_check(selected_node != null and selected_node.get_node_or_null("EnemySelectionOutline") != null, "clicked enemy must show a selection outline")
	game.select_battle_enemy("eight_06")
	var previous_node: Node3D = game.battle_world_renderer._enemy_node_for_id("eight_07")
	var next_node: Node3D = game.battle_world_renderer._enemy_node_for_id("eight_06")
	_check(previous_node != null and previous_node.get_node_or_null("EnemySelectionOutline") == null, "selection outline must leave the previous enemy")
	_check(next_node != null and next_node.get_node_or_null("EnemySelectionOutline") != null, "selection outline must follow the clicked enemy")
	var hud = game.get_node("HUD/HUDRoot")
	_check(hud.TEST_AI_PANEL_RECT.size.x > 0.0 and hud.TEST_AI_STEP_RECT.size.x > 0.0, "AI overlay must expose clickable debug controls")
	var reason_bottom := hud.TEST_AI_PANEL_RECT.position.y + 114.0 + 4.0 * 14.0
	_check(hud.TEST_AI_ROW_RECT.position.y > reason_bottom, "AI reason text must not overlap the enemy list")
	_check(hud.TEST_AI_ROW_RECT.position.y + hud.TEST_AI_ROW_STEP * 8.0 <= hud.TEST_AI_STEP_RECT.position.y, "AI enemy list must stop before the control buttons")
	_check(hud.PLAYER_PROFILE.get_size().x >= 700.0, "Lily HUD portrait must use the complete profile asset")
	var renderer = game.battle_world_renderer
	_check(renderer.player_range_display_enabled, "player reachable range must be enabled by default")
	renderer.toggle_player_range_display()
	_check(not renderer.player_range_display_enabled, "player reachable range must be toggleable")
	renderer.toggle_player_range_display()
	_check(renderer.player_range_display_enabled, "player reachable range must be restorable")
	renderer.hovered_battle_cell = game.combat.enemy_by_id("eight_07").pos
	renderer.update_battle_hover()
	_check(renderer.battle_hover_markers.is_empty(), "hover feedback must not recreate four corner dots")
	game.active_animation_kind = "enemy_turn"
	renderer.refresh_battle_state(false, false)
	_check(not _intent_cells_contain_any_enemy(renderer._battle_intent_cells()), "enemy ranges must be hidden during the enemy turn")
	game.active_animation_kind = ""
	renderer.refresh_battle_state(false, false)
	var focused_cells: Dictionary = renderer._battle_intent_cells()
	_check(_intent_cells_only_contain_enemy(focused_cells, game.test_focused_enemy_id), "focused range mode must only publish the selected enemy range")
	var range_key := InputEventKey.new()
	range_key.keycode = KEY_1
	range_key.pressed = true
	hud._input(range_key)
	var all_cells: Dictionary = renderer._battle_intent_cells()
	_check(_intent_cells_contain_enemy(all_cells, "eight_07"), "all range mode must publish an unselected enemy range")
	renderer.cycle_enemy_range_display()
	var hidden_cells: Dictionary = renderer._battle_intent_cells()
	_check(not _intent_cells_contain_any_enemy(hidden_cells), "hidden range mode must remove all enemy range overlays")
	game.return_to_combat_test_menu()
	_check(game.phase == "test_combat_menu", "overlay test combat must return to test menu")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHANNEL_COMBAT_TEST_AI_OVERLAY: PASS eight-enemy-plans-focus-controls")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_COMBAT_TEST_AI_OVERLAY: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _intent_cells_only_contain_enemy(cells: Dictionary, enemy_id: String) -> bool:
	for raw_entry in cells.values():
		var entry: Dictionary = raw_entry
		for group_name in ["impact", "threat", "enemy_move", "path", "line"]:
			for raw_marker in (entry.get(group_name, []) as Array):
				if str((raw_marker as Dictionary).get("enemy_id", "")) != enemy_id:
					return false
	return true


func _intent_cells_contain_enemy(cells: Dictionary, enemy_id: String) -> bool:
	for raw_entry in cells.values():
		var entry: Dictionary = raw_entry
		for group_name in ["impact", "threat", "enemy_move", "path", "line"]:
			for raw_marker in (entry.get(group_name, []) as Array):
				if str((raw_marker as Dictionary).get("enemy_id", "")) == enemy_id:
					return true
	return false


func _intent_cells_contain_any_enemy(cells: Dictionary) -> bool:
	for raw_entry in cells.values():
		var entry: Dictionary = raw_entry
		for group_name in ["impact", "threat", "enemy_move", "path", "line"]:
			if not (entry.get(group_name, []) as Array).is_empty():
				return true
	return false
