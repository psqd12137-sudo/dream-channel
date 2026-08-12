extends SceneTree

const WORLD_ROOT := "WorldLayer/WorldContainer/WorldViewport/WorldRoot"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://channel_3d.tscn")
	_check(packed != null, "channel_3d.tscn must load")
	if packed == null:
		_finish()
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_new_run(false)
	var hud = game.get_node("HUD/HUDRoot")
	var desktop_sizes: Array[Vector2] = [Vector2(1024, 640), Vector2(1280, 800), Vector2(1600, 900), Vector2(1920, 1080)]
	for viewport_size: Vector2 in desktop_sizes:
		var layout: Dictionary = hud.calculate_layout(viewport_size, "combat")
		var board: Rect2 = layout["board_rect"]
		_check(not board.intersects(layout["top_rect"]), "board must not overlap top HUD at %s" % viewport_size)
		_check(not board.intersects(layout["side_rect"]), "board must not overlap card sidebar at %s" % viewport_size)
		_check(not board.intersects(layout["coach_rect"]), "board must not overlap coach bar at %s" % viewport_size)
		_check(board.size.x >= 760.0 or viewport_size.x < 1280.0, "desktop board should retain useful width")

	game.choose_omen(0)
	var hall: Dictionary = _find_room(game.room_catalog, "hall")
	_check(not hall.is_empty(), "latest snapshot must contain hall")
	if hall.is_empty():
		game.queue_free()
		await process_frame
		_finish()
		return
	game.start_combat(hall)
	await process_frame
	await process_frame
	_check(game.combat.cols == 9 and game.combat.rows == 4, "hall must exercise the 9x4 arena")
	var battle_root: Node = game.get_node(WORLD_ROOT + "/BattleRoot")
	var camera: Camera3D = game.get_node(WORLD_ROOT + "/CameraRig/Camera3D")
	var world_viewport: SubViewport = game.get_node("WorldLayer/WorldContainer/WorldViewport")
	_check(_count_named_prefix(battle_root, "Cell_") == 36, "hall must render all 36 cells")
	_check(_all_cells_have_layers(battle_root), "each cell must have a frame and surface")
	_check(_count_named_prefix(battle_root, "Height") > 0, "height cells must render H markers")
	_check(_count_named_prefix(battle_root, "PortalLabel") == 2, "portal endpoints must render A/B markers")
	_check(_count_named_prefix(battle_root, "Blocker") == 2, "hall walls must render blocker meshes")

	for y in range(game.combat.rows):
		for x in range(game.combat.cols):
			var screen_pos: Vector2 = camera.unproject_position(game._battle_world(Vector2i(x, y)))
			_check(screen_pos.x >= 0.0 and screen_pos.y >= 0.0 and screen_pos.x <= world_viewport.size.x and screen_pos.y <= world_viewport.size.y, "auto-fit must keep cell %s visible" % Vector2i(x, y))

	var initial_size: float = camera.size
	game.pan_battle_camera(Vector2(120, -60))
	_check(game.battle_camera_target != Vector3.ZERO, "middle-drag pan must change the camera target")
	game.zoom_battle_camera(Vector2(world_viewport.size) * 0.5, 0.9)
	_check(camera.size < initial_size, "wheel-up must zoom in")
	_check(camera.size >= game.battle_camera_fit_size * game.CAMERA_ZOOM_MIN, "zoom must respect the minimum")
	game.reset_battle_camera()
	_check(is_equal_approx(camera.size, game.battle_camera_fit_size), "reset must restore fit size")

	var target_cell := Vector2i(2, 1)
	game.pan_battle_camera(Vector2(-90, 45))
	game.zoom_battle_camera(Vector2(world_viewport.size) * 0.5, 0.8)
	var projected: Vector2 = camera.unproject_position(game._battle_world(target_cell))
	_check(game.battle_cell_from_viewport(projected) == target_cell, "picking must survive pan and zoom")
	game.set_battle_hover(projected)
	await process_frame
	var hovered_node: Node = battle_root.get_node_or_null("Cell_%d_%d/Hover_0" % [target_cell.x, target_cell.y])
	_check(hovered_node is MeshInstance3D, "hovered cells must render corner markers")
	_check(_count_named_prefix(battle_root, "Valid_") > 0, "reachable cells must render green markers")

	game.queue_free()
	await process_frame
	_finish()


func _find_room(rooms: Array[Dictionary], id: String) -> Dictionary:
	for room: Dictionary in rooms:
		if str(room.get("id", "")) == id:
			return room
	return {}


func _all_cells_have_layers(root_node: Node) -> bool:
	for child: Node in root_node.get_children():
		if child.name.begins_with("Cell_"):
			if child.get_node_or_null("Frame") == null or child.get_node_or_null("Surface") == null:
				return false
	return true


func _count_named_prefix(node: Node, prefix: String) -> int:
	var count := 1 if node.name.begins_with(prefix) else 0
	for child: Node in node.get_children():
		count += _count_named_prefix(child, prefix)
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_BATTLE_VIEW_SMOKE: PASS responsive safe-view camera grid picking")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_BATTLE_VIEW_SMOKE: %s" % failure)
		quit(1)
