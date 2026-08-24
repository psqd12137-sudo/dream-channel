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
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	var living := _find_room(game.room_catalog, "living")
	game.start_combat(living)
	await process_frame
	_check(game.phase == "combat", "a combat room must enter combat phase")
	_check(game.combat.is_walkable(game.combat.player_pos), "player must spawn on the board")
	_check(_inside(game.combat.enemy_pos, game.combat.cols, game.combat.rows), "enemy must spawn on the board")
	var camera_yaw_before: float = game.battle_camera_yaw
	var camera_pitch_before: float = game.battle_camera_pitch
	var target_before: Vector3 = game.battle_camera_target
	_check(target_before.distance_to(game._battle_follow_target_position() + game._battle_camera_frame_offset()) < 0.5, "battle camera must start on the framed player-enemy midpoint")
	game.orbit_battle_camera(Vector2(24, -8))
	_check(not is_equal_approx(game.battle_camera_yaw, camera_yaw_before), "battle camera must rotate when the empty board drag gesture supplies motion")
	_check(is_equal_approx(game.battle_camera_pitch, camera_pitch_before), "battle orbit must ignore vertical drag and keep a fixed pitch")
	_check(game.battle_camera_target.is_equal_approx(target_before), "battle orbit must keep the framed player-enemy midpoint target")

	game.combat.hand.assign(["jab", "guard"])
	game.combat.energy = 4
	game.select_or_play_card(0)
	_check(game.selected_card == 0, "clicking a placement card must select it")
	game.select_or_play_card(0)
	_check(game.selected_card == -1, "clicking the selected card again must cancel placement mode")

	game.select_or_play_card(0)
	var hand_before: Array[String] = game.combat.hand.duplicate()
	var energy_before: int = game.combat.energy
	game.handle_battle_cell(game.combat.player_pos)
	_check(game.selected_card == -1, "an invalid placement click must not trap input in placement mode")
	_check(game.combat.hand == hand_before and game.combat.energy == energy_before, "invalid placement must not consume the card or AP")

	var move_target := _first_move_target(game.combat)
	_check(move_target != Vector2i(-1, -1), "combat room must expose a legal movement cell")
	if move_target != Vector2i(-1, -1):
		game.handle_battle_cell(move_target)
		_check(game.combat.player_pos == move_target, "movement must work immediately after placement cancellation")
		var far_target := _find_far_path_target(game.combat)
		_check(far_target != Vector2i(-1, -1), "combat room must expose a reachable distant target")
		if far_target != Vector2i(-1, -1):
			game.combat.energy = 20
			game.handle_battle_cell(far_target)
			_check(game.combat.player_pos == far_target, "clicking a reachable distant cell must auto-walk the player there")

	var attack_origin := Vector2i(maxi(0, game.combat.enemy_pos.x - 1), game.combat.enemy_pos.y)
	if attack_origin == game.combat.enemy_pos or not game.combat.is_walkable(attack_origin):
		attack_origin = Vector2i(game.combat.enemy_pos.x, maxi(0, game.combat.enemy_pos.y - 1))
	game.combat.player_pos = attack_origin
	game.combat.hand.assign(["jab"])
	game.combat.energy = 3
	game.selected_card = 0
	var hp_before: int = game.combat.enemy_hp
	_check(game.combat.can_target_place_card(0, game.combat.enemy_pos), "enemy cell must only be marked when a direct smash is valid")
	game.handle_battle_cell(game.combat.enemy_pos)
	_check(game.combat.enemy_hp < hp_before, "clicking a valid enemy target must deal combat damage")
	_check(game.battle_root.get_node_or_null("Enemy/DamageFeedback") is Label3D, "enemy HP loss must create a model-scale-independent damage popup")

	if game.combat.outcome == "":
		var hud: Control = game.get_node("HUD/HUDRoot")
		var round_before: int = game.combat.round_number
		var end_turn_click := InputEventMouseButton.new()
		end_turn_click.button_index = MOUSE_BUTTON_LEFT
		end_turn_click.pressed = true
		end_turn_click.position = hud.ui_offset + hud.END_TURN_RECT.get_center() * hud.ui_scale
		hud._gui_input(end_turn_click)
		_check(game.combat.round_number > round_before or game.combat.outcome != "", "end-turn button must win input priority over the expanded battle viewport")

	game.queue_free()
	await process_frame
	_finish()


func _first_move_target(combat) -> Vector2i:
	for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var target: Vector2i = combat.player_pos + direction
		if combat.can_move_player(target):
			return target
	return Vector2i(-1, -1)


func _find_far_path_target(combat) -> Vector2i:
	for y in range(combat.rows):
		for x in range(combat.cols):
			var target := Vector2i(x, y)
			var path: Array = combat.player_path_to(target)
			if path.size() >= 3 and combat.player_path_cost(path) <= 20:
				return target
	return Vector2i(-1, -1)


func _inside(cell: Vector2i, cols: int, rows: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


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
		print("CHANNEL_COMBAT_INPUT_REGRESSION: PASS cancel invalid-click move direct-damage")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_COMBAT_INPUT_REGRESSION: %s" % failure)
		quit(1)
