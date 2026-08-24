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
	var initial_seed: int = game.run_seed
	var initial_hp: int = game.player_hp
	var initial_progress: int = game.run_progress
	var initial_deck: Array[String] = game.run_deck.duplicate()
	_check(game.phase == "home", "game must boot to title")
	game.toggle_home_tests()
	var hud = game.get_node("HUD/HUDRoot") as Control
	_click(hud, hud.HOME_TEST_COMBAT_RECT)
	_check(game.phase == "test_combat_menu", "existing combat test entry must open the test desk")
	_check(game.phase == "test_combat_menu", "combat test entry must use an isolated test menu phase")
	_check(not game.world_container.visible, "test menu must not show the formal world behind it")
	_check(game.test_mode_selected_id == "baseline_single", "test menu must select a deterministic first scenario")
	game.select_combat_test_scenario("squad_roles")
	_check(game.test_mode_selected_id == "squad_roles", "test desk must allow scenario selection")
	_check(game.start_test_combat("manual"), "selected scenario must start a manual test combat")
	await process_frame
	_check(game.phase == "combat" and game.test_combat_active, "test combat must use the formal battle phase with an isolated session")
	_check(game.world_container.visible, "test combat must restore the 3D world viewport after the test menu hid it")
	_check(game.combat.enemy_order.size() == 3, "squad roles test combat must create three enemies")
	_check(game.combat.player_hp == 60, "test combat must use the scenario player HP")
	game.return_to_combat_test_menu()
	_check(game.phase == "test_combat_menu", "test combat must return to the test desk")
	_check(game.combat == null and not game.test_combat_active, "returning must discard the test combat session")
	_check(game.run_seed == initial_seed and game.player_hp == initial_hp and game.run_progress == initial_progress, "test combat must restore formal run scalars")
	_check(game.run_deck == initial_deck, "test combat must restore the formal deck")
	for scenario_id in game.test_catalog.ids():
		game.select_combat_test_scenario(scenario_id)
		_check(game.start_test_combat("manual"), "scenario %s must start" % scenario_id)
		_check(game.combat != null and game.combat.enemy_order.size() > 0, "scenario %s must build enemies" % scenario_id)
		game.return_to_combat_test_menu()
	game.go_home()
	_check(game.phase == "home", "test desk must return to title")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHANNEL_COMBAT_TEST_ENTRY: PASS menu-selection-isolation-return")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_COMBAT_TEST_ENTRY: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _click(hud: Control, design_rect: Rect2) -> void:
	var point: Vector2 = hud.ui_offset + (design_rect.position + design_rect.size * 0.5) * hud.ui_scale
	var press := InputEventMouseButton.new()
	press.position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	hud._gui_input(press)
	var release := InputEventMouseButton.new()
	release.position = point
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	hud._gui_input(release)
