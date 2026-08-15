extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://channel_3d.tscn")
	_check(packed != null, "channel_3d.tscn must load")
	if packed == null:
		_finish()
		return

	var game: Node3D = packed.instantiate()
	game.animation_duration_scale = 0.4
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_new_run(false)

	game.choose_omen(0)
	var frontiers: Array[Vector2i] = game.room_rules.frontiers()
	_check(not frontiers.is_empty(), "the foyer must expose a placement target")
	if frontiers.is_empty():
		game.queue_free()
		_finish()
		return

	var target := frontiers[0]
	game.begin_build(target)
	game.place_selected_offer()
	var room_node: Node3D = game._find_room_node(target)
	_check(game.animation_busy, "room placement must lock interaction while it animates")
	_check(game.active_animation_kind == "room_drop", "room placement must expose the room_drop animation state")
	_check(room_node != null, "the placed room must have a single animated root")
	if room_node != null:
		_check(room_node.position.y > 1.0, "the room must begin raised above its settled position")
		_check(absf(room_node.rotation.x) > 0.5, "the room must begin visibly flipped")
		_check(room_node.scale.x < 1.0, "the room must begin at Unity's compact scale")
	game.enter_room(target)
	_check(game.current_room_pos != target, "entering must be ignored while the room is still landing")
	await _wait_for_effect(game, 2.0)

	room_node = game._find_room_node(target)
	_check(not game.animation_busy, "room placement animation must complete")
	if room_node != null:
		_check(is_zero_approx(room_node.position.y), "the room must settle onto the house plane")
		_check(room_node.rotation.is_equal_approx(Vector3.ZERO), "the room must finish face-up")
		_check(room_node.scale.is_equal_approx(Vector3.ONE), "the room must finish at full scale")
	var hidden_room: Dictionary = game.room_rules.placed[target]
	_check(not bool(hidden_room.get("revealed", true)), "landing must not reveal the room")

	game.enter_room(target)
	_check(game.animation_busy, "walking into a room must lock interaction")
	_check(game.active_animation_kind == "room_entry", "entering must expose the room_entry animation state")
	_check(game.current_room_pos != target, "logical movement must wait for the walk animation")
	await _wait_for_effect(game, 2.0)

	var revealed_room: Dictionary = game.room_rules.placed[target]
	_check(game.current_room_pos == target, "the actor must arrive in the target room")
	_check(bool(revealed_room.get("revealed", false)), "the unknown room must flip to its revealed face")
	_check(game.phase == "room_ready", "first entry must still preserve room resolution rules")
	_check(not game.animation_busy, "room reveal must release interaction")
	var expected_house_yaw := atan2(float(target.x), float(target.y))
	var arrived_token := game.house_root.get_node_or_null("LiliToken") as Node3D
	_check(arrived_token != null and is_equal_approx(arrived_token.rotation.y, expected_house_yaw), "house-map Lili must keep facing the room she just entered after the map rebuild")

	var combat_room: Dictionary = _find_room(game.room_catalog, "hall")
	_check(not combat_room.is_empty(), "combat entry animation test requires the hall")
	if not combat_room.is_empty():
		game.start_combat(combat_room, true)
		_check(game.animation_busy and game.active_animation_kind == "combat_entry", "entering combat from a room must lock input during the stage build")
		_check(game.battle_root.scale.y < 0.10, "the combat room must begin folded flat before it builds")
		var entry_player: Node3D = game.battle_root.get_node_or_null("Player") as Node3D
		game.set_battle_hover(Vector2(game.world_viewport.size) * 0.5)
		game.clear_battle_hover()
		_check(is_instance_valid(entry_player) and game.battle_root.get_node_or_null("Player") == entry_player, "mouse hover must not rebuild and free actors during combat entry")
		await _wait_for_effect(game, 2.0)
		var player: Node3D = game.battle_root.get_node_or_null("Player") as Node3D
		var enemy: Node3D = game.battle_root.get_node_or_null("Enemy") as Node3D
		_check(not game.animation_busy and game.battle_root.scale.is_equal_approx(Vector3.ONE), "the combat room build must settle before input unlocks")
		_check(player != null and enemy != null and player.visible and enemy.visible, "player and enemy must finish their combat entrance")

	game.queue_free()
	await process_frame
	_finish()


func _wait_for_effect(game: Node, timeout_seconds: float) -> void:
	var started := Time.get_ticks_msec()
	while game.animation_busy and float(Time.get_ticks_msec() - started) / 1000.0 < timeout_seconds:
		await process_frame


func _find_room(rooms: Array[Dictionary], room_id: String) -> Dictionary:
	for room: Dictionary in rooms:
		if str(room.get("id", "")) == room_id:
			return room
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_DYNAMIC_EFFECTS_SMOKE: PASS room-drop actor-walk hidden-reveal input-lock")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_DYNAMIC_EFFECTS_SMOKE: %s" % failure)
		quit(1)
