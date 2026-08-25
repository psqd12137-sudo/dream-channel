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
	var hud = game.get_node("HUD/HUDRoot")
	_check(hud.TEST_AI_PANEL_RECT.size.x > 0.0 and hud.TEST_AI_STEP_RECT.size.x > 0.0, "AI overlay must expose clickable debug controls")
	var reason_bottom := hud.TEST_AI_PANEL_RECT.position.y + 114.0 + 4.0 * 14.0
	_check(hud.TEST_AI_ROW_RECT.position.y > reason_bottom, "AI reason text must not overlap the enemy list")
	_check(hud.TEST_AI_ROW_RECT.position.y + hud.TEST_AI_ROW_RECT.size.y * 6.0 <= hud.TEST_AI_STEP_RECT.position.y, "AI enemy list must stop before the control buttons")
	_check(hud.PLAYER_PROFILE.get_size().x >= 700.0, "Lily HUD portrait must use the complete profile asset")
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
