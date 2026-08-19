extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node3D = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_new_run(false, 2026081901)
	game.choose_omen(0)
	var house_center := Vector2(game.world_viewport.size) * 0.5
	var house_fit: float = game.camera.size
	for i in range(3):
		game.hud._gui_input(_wheel_event(game.world_view_rect.position + house_center, MOUSE_BUTTON_WHEEL_UP))
	_check(game.camera.size < house_fit, "house map wheel-up must zoom during exploration")
	var house_zoomed: float = game.camera.size
	var frontier: Vector2i = game.room_rules.frontiers()[0]
	game.begin_build(frontier)
	_check(is_equal_approx(game.camera.size, house_zoomed), "house zoom must survive rebuilding the placement preview")
	var house_target_before: Vector3 = game.house_camera_target
	game.pan_house_camera(Vector2(90, -45))
	_check(game.house_camera_target != house_target_before, "house map middle-drag logic must pan during room placement")
	game.reset_house_camera()
	_check(is_equal_approx(game.camera.size, game.house_camera_fit_size), "house map reset must restore auto-fit")
	game.start_combat_lab("hall")
	var center := Vector2(game.world_viewport.size) * 0.5
	var fit: float = game.camera.size
	for i in range(4):
		game.hud._gui_input(_wheel_event(game.world_view_rect.position + center, MOUSE_BUTTON_WHEEL_UP))
	_check(game.camera.size < fit * 0.8, "four wheel-up events must continue zooming instead of stopping after one")
	var zoomed: float = game.camera.size
	for i in range(3):
		game.hud._gui_input(_wheel_event(game.world_view_rect.position + center, MOUSE_BUTTON_WHEEL_DOWN))
	_check(game.camera.size > zoomed, "wheel-down must remain routed to combat after repeated zoom-in")

	game.combat.ambush_active = false
	game.combat.enemy_revealed = false
	game.combat.player_sees_enemy = false
	game.combat.enemy_sees_player = false
	game.combat.last_seen = game.combat.INVALID_CELL
	game.combat.patrol_goal = game.combat.INVALID_CELL
	game.build_battle_world()
	_check(_count_named_prefix(game.battle_root, "IntentMoveOverlay") > 0, "patrol movement intent must be rendered as colored map overlays")
	_check(_count_named_prefix(game.battle_root, "IntentMoveGlyph") > 0, "patrol movement cells must carry ordered map glyphs")

	game.combat.enemy_pos = game.combat.player_pos + Vector2i.RIGHT
	game.combat.enemy_sees_player = true
	game.combat.enemy_revealed = true
	game.combat.player_sees_enemy = true
	game.combat.last_seen = game.combat.player_pos
	game.build_battle_world()
	_check(_count_named_prefix(game.battle_root, "IntentAttackOverlay") == 1, "attack intent must paint its hurt cell directly on the map")
	_check(_count_named_prefix(game.battle_root, "IntentAttackGlyph") == 1, "attack map cell must carry a visible attack glyph")

	game.start_sideview_lab()
	var start_x: float = game.lab_player.position.x
	game.set_sideview_input(1.0, false)
	for i in range(20):
		game._update_sideview(1.0 / 60.0)
	_check(game.lab_player.position.x > start_x + 1.0, "held D input must visibly move the sideview player")
	game.set_sideview_input(0.0, true)
	game._update_sideview(1.0 / 60.0)
	_check(game.lab_velocity.y > 0.0, "W/up/space input must apply an upward jump impulse")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHANNEL_INPUT_INTENT: PASS repeated-zoom sideview map-intent")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_INPUT_INTENT: %s" % failure)
		quit(1)


func _wheel_event(position: Vector2, button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = button
	event.pressed = true
	return event


func _count_named_prefix(node: Node, prefix: String) -> int:
	var count := 1 if str(node.name).begins_with(prefix) else 0
	for child in node.get_children():
		count += _count_named_prefix(child, prefix)
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
