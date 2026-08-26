extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://channel_3d.tscn") as PackedScene).instantiate() as Node3D
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_new_run(false, 2026082001)
	game.choose_omen(0)
	await process_frame

	var camera: Camera3D = game.camera
	var composer: Node = game.house_root.get_node_or_null("KenneyFormalComposer")
	_check(composer != null, "the formal house composer must exist before camera checks")
	var house_size: float = camera.size
	var house_target: Vector3 = game.house_camera_target
	var house_yaw: float = game.house_camera_yaw
	var house_fingerprint: String = str(composer.generation_fingerprint()) if composer != null else ""
	var house_connections: int = int(composer.connection_edges.size()) if composer != null else -1
	var house_visual_edges: int = int(composer.visual_edge_records.size()) if composer != null else -1
	var room_rotation: int = int(game.offer_rotation)
	game.orbit_house_camera(Vector2(120.0, 0.0))
	_check(not is_equal_approx(game.house_camera_yaw, house_yaw), "house orbit must change continuous camera yaw")
	_check(is_equal_approx(camera.size, house_size), "house orbit must preserve visual scale")
	_check(game.house_camera_target.is_equal_approx(house_target), "house orbit must preserve the panned target")
	_check(game.offer_rotation == room_rotation, "house orbit must not rotate a build offer")
	_check(composer.generation_fingerprint() == house_fingerprint, "house orbit must not change the PCG generation fingerprint")
	_check(composer.connection_edges.size() == house_connections and composer.visual_edge_records.size() == house_visual_edges, "house orbit must preserve connection and visual edge ledgers")
	_check(composer.wall_bound_props_match_cutaway(), "house orbit must keep wall-bound props synchronized with cutaway walls")
	var house_zoom_target_before: Vector3 = game.house_camera_target
	game.zoom_house_camera(Vector2(120.0, 90.0), 0.8)
	_check(game.house_camera_target.is_equal_approx(house_zoom_target_before), "house zoom must not translate the camera target")
	_check(not game.house_camera_following, "house zoom must pause automatic camera following")

	var hud = game.hud
	var screen_center: Vector2 = game.world_view_rect.position + game.world_view_rect.size * 0.5
	var yaw_before_short_drag: float = game.house_camera_yaw
	hud._gui_input(_button_event(screen_center, true))
	hud._gui_input(_motion_event(screen_center + Vector2(3.0, 0.0), Vector2(3.0, 0.0)))
	_check(not hud.board_left_dragged and is_equal_approx(game.house_camera_yaw, yaw_before_short_drag), "house drag below five pixels must remain a click")
	hud._gui_input(_button_event(screen_center + Vector2(3.0, 0.0), false))
	var yaw_before_drag: float = game.house_camera_yaw
	hud._gui_input(_button_event(screen_center, true))
	hud._gui_input(_motion_event(screen_center + Vector2(12.0, 0.0), Vector2(12.0, 0.0)))
	hud._gui_input(_button_event(screen_center + Vector2(12.0, 0.0), false))
	_check(not is_equal_approx(game.house_camera_yaw, yaw_before_drag), "house drag beyond five pixels must orbit")
	_check(not hud.board_left_pressed and not hud.board_left_dragged, "house orbit release must clear gesture state")

	var frontier: Vector2i = game.room_rules.frontiers()[0]
	game.begin_build(frontier)
	var build_rotation: int = game.offer_rotation
	var build_size: float = camera.size
	game.orbit_house_camera(Vector2(-90.0, 0.0))
	_check(game.offer_rotation == build_rotation, "orbiting during build must not change room orientation")
	_check(is_equal_approx(camera.size, build_size), "orbiting during build must preserve map scale")
	game.reset_house_camera()
	_check(is_equal_approx(game.house_camera_yaw, atan2(game.HOUSE_CAMERA_DIRECTION.x, game.HOUSE_CAMERA_DIRECTION.z)), "house reset must restore the default view angle")
	_check(is_equal_approx(camera.size, game.house_camera_fit_size), "house reset must restore fit scale")

	game.start_combat_lab("hall")
	await process_frame
	var battle_fit: float = camera.size
	var battle_target: Vector3 = game.battle_camera_target
	var battle_yaw: float = game.battle_camera_yaw
	var logical_walls: int = game.combat.walls.size()
	for degrees: float in [45.0, 90.0, 180.0, 360.0]:
		game.battle_camera_yaw = battle_yaw
		game._apply_battle_camera()
		game.orbit_battle_camera(Vector2(deg_to_rad(degrees) / game.CAMERA_ORBIT_SENSITIVITY, 0.0))
		_check(is_equal_approx(camera.size, battle_fit), "battle orbit at %d degrees must preserve visual scale" % int(degrees))
		_check(game.battle_camera_target.is_equal_approx(battle_target), "battle orbit at %d degrees must preserve target" % int(degrees))
		_check(_all_battle_cells_visible(game, camera), "rotation-invariant fit must contain every cell at %d degrees" % int(degrees))
	_check(game.combat.walls.size() == logical_walls, "battle orbit and cutaway must not mutate logical blockers")

	game.reset_battle_camera()
	game.pan_battle_camera(Vector2(84.0, -42.0))
	var battle_zoom_target_before: Vector3 = game.battle_camera_target
	game.zoom_battle_camera(Vector2(game.world_viewport.size) * 0.5, 0.8)
	var adjusted_target: Vector3 = game.battle_camera_target
	var adjusted_size: float = camera.size
	var adjusted_ratio: float = game.battle_camera_zoom_ratio
	_check(game.battle_camera_target.is_equal_approx(battle_zoom_target_before), "battle zoom must not translate the camera target")
	game.orbit_battle_camera(Vector2(160.0, 0.0))
	_check(game.battle_camera_target.is_equal_approx(adjusted_target), "battle orbit must not discard user pan")
	_check(is_equal_approx(camera.size, adjusted_size) and is_equal_approx(game.battle_camera_zoom_ratio, adjusted_ratio), "battle orbit must preserve user zoom")

	var yaw_before_resize: float = game.battle_camera_yaw
	game.set_world_view_rect(Rect2(game.world_view_rect.position, Vector2(1180.0, 620.0)))
	_check(is_equal_approx(game.battle_camera_yaw, yaw_before_resize), "viewport resize must preserve battle yaw")
	_check(game.battle_camera_target.is_equal_approx(adjusted_target), "viewport resize must preserve battle pan")
	_check(is_equal_approx(game.battle_camera_zoom_ratio, adjusted_ratio), "viewport resize must preserve battle zoom ratio")

	var right_edge: Dictionary = _battle_edge_for_side(game, 1)
	_check(not right_edge.is_empty(), "battle shell must expose a right-side edge for hysteresis checks")
	if not right_edge.is_empty():
		game.battle_camera_yaw = asin(0.10)
		game._apply_battle_camera()
		game.battle_camera_yaw = asin(0.45)
		game._apply_battle_camera()
		_check((right_edge["cutaway"] as Node3D).visible, "wall must enter cutaway after crossing the high threshold")
		game.battle_camera_yaw = asin(0.35)
		game._apply_battle_camera()
		_check((right_edge["cutaway"] as Node3D).visible, "wall must remain cut away inside the hysteresis band")
		game.battle_camera_yaw = asin(0.20)
		game._apply_battle_camera()
		_check((right_edge["full"] as Node3D).visible, "wall must restore after crossing the low threshold")

	game.reset_battle_camera()
	_check(is_equal_approx(camera.size, game.battle_camera_fit_size), "battle reset must restore fit scale")
	_check(is_equal_approx(game.battle_camera_zoom_ratio, 1.0), "battle reset must restore zoom ratio")
	_check(is_equal_approx(game.battle_camera_yaw, atan2(game.CAMERA_DIRECTION.x, game.CAMERA_DIRECTION.z)), "battle reset must restore default yaw")

	game.queue_free()
	await process_frame
	_finish()


func _all_battle_cells_visible(game: Node3D, camera: Camera3D) -> bool:
	var viewport_size: Vector2 = game.world_viewport.size
	for y in range(game.combat.rows):
		for x in range(game.combat.cols):
			var screen_pos := camera.unproject_position(game._battle_world(Vector2i(x, y)))
			if screen_pos.x < 0.0 or screen_pos.y < 0.0 or screen_pos.x > viewport_size.x or screen_pos.y > viewport_size.y:
				return false
	return true


func _battle_edge_for_side(game: Node3D, side: int) -> Dictionary:
	for raw_record: Variant in game.battle_shell_edge_records.values():
		var record: Dictionary = raw_record
		if int(record.get("side", -1)) == side:
			return record
	return {}


func _button_event(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event


func _motion_event(position: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = relative
	return event


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_CAMERA_ORBIT: PASS stable-scale free-orbit cutaway topology input")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_CAMERA_ORBIT: %s" % failure)
		quit(1)
