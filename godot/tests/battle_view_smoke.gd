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
	game.start_new_run(false, 2026081901)
	var hud = game.get_node("HUD/HUDRoot")
	var visual_layout: Dictionary = hud.combat_visual_layout_spec()
	_check(not visual_layout.is_empty(), "combat HUD must expose a compact visual layout spec")
	var formal_composer := game.house_root.get_node_or_null("KenneyFormalComposer") as Node3D
	_check(formal_composer != null and str(formal_composer.get_meta("visual_style", "")) == "memphis_clay", "formal house composer must expose the Memphis clay visual style")
	var board_design: Rect2 = visual_layout.get("board", Rect2())
	for panel_name: String in ["player", "enemy", "action", "boss", "hand"]:
		var panel: Rect2 = visual_layout.get(panel_name, Rect2())
		_check(panel.size.x > 0.0 and panel.size.y > 0.0, "combat visual layout must define %s" % panel_name)
		_check(not board_design.intersects(panel), "combat board must have a clear edge from %s panel" % panel_name)
	_check(float(visual_layout.get("hand_min_height", 0.0)) >= 150.0, "combat hand must reserve a complete card staging area")
	var desktop_sizes: Array[Vector2] = [Vector2(1024, 640), Vector2(1280, 800), Vector2(1600, 900), Vector2(1920, 1080), Vector2(2560, 1440)]
	for viewport_size: Vector2 in desktop_sizes:
		var layout: Dictionary = hud.calculate_layout(viewport_size, "combat")
		var board: Rect2 = layout["board_rect"]
		_check(not board.intersects(layout["top_rect"]), "board must not overlap top HUD at %s" % viewport_size)
		var layout_scale: float = layout["scale"]
		_check(board.size.x >= 740.0 * layout_scale, "combat board should preserve a wide readable playfield at %s" % viewport_size)
		_check(board.size.y >= 480.0 * layout_scale, "combat board should preserve a tall readable playfield at %s" % viewport_size)
		var hand_design: Rect2 = visual_layout["hand"]
		var hand_screen := Rect2(Vector2(layout["offset"]) + hand_design.position * layout_scale, hand_design.size * layout_scale)
		_check(hand_screen.position.y >= board.end.y and hand_screen.end.y <= float(layout["offset"].y) + 800.0 * layout_scale, "hand cards must occupy the dedicated lower staging area inside the canvas at %s" % viewport_size)

	game.choose_omen(0)
	var hall: Dictionary = _find_room(game.room_catalog, "hall")
	_check(not hall.is_empty(), "latest snapshot must contain hall")
	if hall.is_empty():
		game.queue_free()
		await process_frame
		_finish()
		return
	var camera: Camera3D = game.get_node(WORLD_ROOT + "/CameraRig/Camera3D")
	game.start_combat(hall)
	await process_frame
	await process_frame
	# The compact board changes the aspect ratio more than the legacy layout;
	# allow the existing camera smoothing to settle before validating edges.
	for _frame in range(24):
		await process_frame
	game.reset_battle_camera()
	_check(game.combat.cols == 9 and game.combat.rows == 4, "hall must exercise the 9x4 arena")
	for raw_overlay: Variant in game.battle_world_renderer.battle_intent_overlay_nodes.values():
		var intent_overlay := raw_overlay as Control
		var intent_badge: Panel = null
		if intent_overlay != null:
			intent_badge = intent_overlay.get_node_or_null("Badge") as Panel
		var intent_icon: TextureRect = null
		var intent_value: Label = null
		if intent_badge != null:
			intent_icon = intent_badge.get_node_or_null("Icon") as TextureRect
			intent_value = intent_badge.get_node_or_null("Value") as Label
		if intent_icon != null and intent_value != null:
			_check(intent_icon.get_parent() == intent_value.get_parent(), "enemy intent icon and value must share one overlay layer")
			_check(intent_icon.z_index == intent_value.z_index, "enemy intent icon and value must share one z layer")
	var battle_root: Node = game.battle_board_root
	var world_viewport: SubViewport = game.get_node("WorldLayer/WorldContainer/WorldViewport")
	_check(_count_named_prefix(battle_root, "Cell_") == 36, "hall must render all 36 cells")
	_check(_all_cells_have_layers(battle_root), "each cell must have a base layer and logical walkable surface")
	_check(_count_named_prefix(battle_root, "Height") == 0, "height must be communicated by furniture silhouettes rather than debug H labels")
	var h1_cells := 0
	for raw_height: Variant in game.combat.heights.values():
		if int(raw_height) == 1:
			h1_cells += 1
	var h1_context_props := _count_named_prefix(battle_root, "TerrainAsset_H1_")
	var h1_decks := _count_meta_recursive(battle_root, "battle_raised_deck")
	_check(h1_context_props > 0 and h1_context_props + h1_decks == h1_cells, "H1 cells must combine one inherited hero prop with connected timber decks instead of a furniture array")
	_check(_count_named_prefix(battle_root, "TerrainAsset_H2_") > 0, "H2 cells must use current furniture assets instead of tall cubes")
	_check(_count_named_prefix(battle_root, "WalkableAssetTop") > 0, "height assets must retain logical standing-surface markers")
	_check(_all_named_prefix_hidden(battle_root, "WalkableAssetTop"), "logical standing surfaces must stay hidden until interaction needs them")
	_check(_count_named_prefix(battle_root, "PortalLabel") == 2, "portal endpoints must render A/B markers")
	_check(_count_named_prefix(battle_root, "Blocker") >= 2 and _count_named_prefix(battle_root, "BlockerAsset_") == 2, "logical blockers must be dressed with inherited room assets instead of plain cubes")
	_check(_count_named_prefix(battle_root, "Blocked") == 0, "blocker silhouettes must communicate collision without floating debug glyphs")
	var active_footprint_cells := _count_meta_value_recursive(battle_root, "room_footprint_active", true)
	_check(active_footprint_cells > 0 and active_footprint_cells < game.combat.cols * game.combat.rows, "the hall arena floor must visibly preserve its five-cell plus footprint")
	var shell_state: Dictionary = game.battle_room_shell_debug_state()
	_check(game.battle_room_shell_is_consistent(), "the combat room shell must pair each full wall with one camera-facing cutaway sill")
	_check(int(shell_state["edges"]) == game._battle_footprint_boundary_edges().size(), "the combat shell must follow every mapped room-footprint boundary segment")
	_check(int(shell_state["entrances"]) == 1, "the player spawn side must expose one explicit room entrance threshold")
	_check(int(shell_state["logical_walls"]) == game.combat.walls.size(), "presentation shell edges must stay separate from logical combat blockers")
	_check(str(shell_state.get("room_type", "")) == "hall" and str(shell_state.get("theme", "")) == "study", "combat presentation must inherit the big-map room identity and art theme")
	_check(str(shell_state.get("context_source", "")) == "unpacking_seed", "rooms without an authored override must inherit their Unpacking-style room seed")
	_check(int(shell_state.get("context_props", 0)) >= 4, "combat presentation must carry representative room props instead of an empty perimeter")
	_check(_count_meta_recursive(battle_root, "battle_context_prop") >= 2, "battle terrain and blockers must use assets inherited from the big-map room composition")
	_check(_count_meta_recursive(battle_root, "house_floor_spec") == active_footprint_cells, "active room cells must reuse the formal big-map timber floor specification")
	_check(_count_meta_recursive(battle_root, "battle_backstage") == game.combat.cols * game.combat.rows - active_footprint_cells, "cells outside the room footprint must read as a green cutting-mat backstage")
	_check(_count_meta_recursive(game.battle_board_root.get_node_or_null("BattleRoomShell"), "cardboard_shell") > 0, "combat walls must use the same cardboard construction language as the big-map room")
	_check(_count_named_prefix(battle_root, "BattleShellJunction") < int(shell_state["edges"]), "wall junctions must exist only on contour turns, never as a picket fence at every cell seam")
	_check(_all_named_prefix_hidden(game.battle_board_root.get_node_or_null("BattleRoomShell"), "BackFoot_"), "battle wall support feet must stay hidden so they do not scatter table-like blocks across the arena")
	_check(game.battle_board_root.get_node_or_null("BattleRoomShell/BattleRoomStateLabel") == null, "the room shell must not carry a floating debug title")
	var trap_cell := _first_empty_cell(game)
	game.combat.traps[trap_cell] = {"card_id": "jab", "glyph": "刺", "damage": 2}
	game.build_battle_world()
	var trap_mesh := game.battle_board_root.get_node_or_null("Cell_%d_%d/Trap" % [trap_cell.x, trap_cell.y]) as MeshInstance3D
	var trap_art := game.battle_board_root.get_node_or_null("Cell_%d_%d/ItemArt_jab" % [trap_cell.x, trap_cell.y]) as Sprite3D
	var trap_radius := (trap_mesh.mesh as CylinderMesh).top_radius if trap_mesh != null else 99.0
	var art_span := trap_art.pixel_size * float(maxi(trap_art.texture.get_width(), trap_art.texture.get_height())) if trap_art != null else 99.0
	_check(trap_radius * 2.0 <= game.BATTLE_CELL * 0.30, "trap bases must stay comfortably inside a battle cell")
	_check(art_span <= game.BATTLE_CELL * 0.56, "trap artwork must scale to at most about half a battle cell")

	for y in range(game.combat.rows):
		for x in range(game.combat.cols):
			var screen_pos: Vector2 = camera.unproject_position(game._battle_world(Vector2i(x, y)))
			_check(screen_pos.x >= 0.0 and screen_pos.y >= 0.0 and screen_pos.x <= world_viewport.size.x and screen_pos.y <= world_viewport.size.y, "auto-fit must keep cell %s visible" % Vector2i(x, y))
	var logical_wall_count: int = game.combat.walls.size()
	game.orbit_battle_camera(Vector2(196, 0))
	_check(game.battle_room_shell_is_consistent(), "rotating the camera must swap near walls for sills without losing shell edges")
	_check(game.combat.walls.size() == logical_wall_count, "camera-facing shell cutaway must not mutate combat wall logic")
	for y in range(game.combat.rows):
		for x in range(game.combat.cols):
			var rotated_screen_pos: Vector2 = camera.unproject_position(game._battle_world(Vector2i(x, y)))
			_check(rotated_screen_pos.x >= 0.0 and rotated_screen_pos.y >= 0.0 and rotated_screen_pos.x <= world_viewport.size.x and rotated_screen_pos.y <= world_viewport.size.y, "rotation-invariant fit must keep rotated cell %s visible" % Vector2i(x, y))
	game.reset_battle_camera()

	var initial_size: float = camera.size
	game.pan_battle_camera(Vector2(120, -60))
	_check(game.battle_camera_target != Vector3.ZERO, "middle-drag pan must change the camera target")
	game.zoom_battle_camera(Vector2(world_viewport.size) * 0.5, 0.9)
	# 缩放改为逐帧平滑追赶目标，等待一帧后再验证镜头已经开始缩放。
	await process_frame
	_check(camera.size < initial_size, "wheel-up must zoom in")
	_check(game.battle_camera_zoom_ratio >= game.CAMERA_ZOOM_MIN, "zoom ratio must respect the minimum")
	game.reset_battle_camera()
	_check(is_equal_approx(camera.size, game.battle_camera_fit_size), "reset must restore fit size")

	var target_cell := Vector2i(2, 1)
	var stable_cell: Node = game.battle_board_root.get_node("Cell_%d_%d" % [target_cell.x, target_cell.y])
	game.pan_battle_camera(Vector2(-90, 45))
	game.zoom_battle_camera(Vector2(world_viewport.size) * 0.5, 0.8)
	var projected: Vector2 = camera.unproject_position(game._battle_world(target_cell))
	_check(game.battle_cell_from_viewport(projected) == target_cell, "picking must survive pan and zoom")
	game.set_battle_hover(projected)
	await process_frame
	var hovered_node: Node = game.battle_board_root.get_node_or_null("Cell_%d_%d/HoverValidFill" % [target_cell.x, target_cell.y])
	if hovered_node == null:
		hovered_node = game.battle_board_root.get_node_or_null("Cell_%d_%d/HoverInvalidFill" % [target_cell.x, target_cell.y])
	_check(hovered_node is MeshInstance3D, "悬停格必须渲染整格覆层")
	_check(game.battle_board_root.get_node("Cell_%d_%d" % [target_cell.x, target_cell.y]) == stable_cell, "hovering must not rebuild the battle board")
	var valid_hover_cell := _first_valid_battle_target(game)
	var valid_projected: Vector2 = camera.unproject_position(game._battle_world(valid_hover_cell))
	game.set_battle_hover(valid_projected)
	await process_frame
	_check(_count_named_prefix(battle_root, "HoverValidFill") > 0, "可用悬停格必须渲染绿色覆层")
	var entrance_key := str(shell_state.get("entrance_key", ""))
	var original_player_pos: Vector2i = game.combat.player_pos
	game.combat.player_pos = Vector2i(game.combat.cols - 1, 0)
	game.build_battle_world()
	var moved_player_shell: Dictionary = game.battle_room_shell_debug_state()
	_check(str(moved_player_shell.get("entrance_key", "")) == entrance_key, "room entrance must not move when the player moves")
	game.combat.player_pos = original_player_pos
	game.build_battle_world()

	game.queue_free()
	await process_frame
	_finish()


func _find_room(rooms: Array[Dictionary], id: String) -> Dictionary:
	for room: Dictionary in rooms:
		if str(room.get("id", "")) == id:
			return room
	return {}


func _all_named_prefix_hidden(root: Node, prefix: String) -> bool:
	for child: Node in root.find_children("%s*" % prefix, "", true, false):
		if child is Node3D and (child as Node3D).visible:
			return false
	return true


func _all_cells_have_layers(root_node: Node) -> bool:
	for child: Node in root_node.get_children():
		if child.name.begins_with("Cell_"):
			var has_base := child.get_node_or_null("Frame") != null or child.get_node_or_null("TerrainFoot") != null
			if not has_base or child.get_node_or_null("Surface") == null:
				return false
	return true


func _first_empty_cell(game: Node3D) -> Vector2i:
	for y in range(game.combat.rows):
		for x in range(game.combat.cols):
			var cell := Vector2i(x, y)
			if game.combat.is_walkable(cell) and cell != game.combat.player_pos and cell != game.combat.enemy_pos:
				return cell
	return Vector2i.ZERO


func _first_valid_battle_target(game: Node3D) -> Vector2i:
	for y in range(game.combat.rows):
		for x in range(game.combat.cols):
			var cell := Vector2i(x, y)
			if game._is_valid_battle_target(cell):
				return cell
	return game.combat.player_pos


func _count_named_prefix(node: Node, prefix: String) -> int:
	var count := 1 if node.name.begins_with(prefix) else 0
	for child: Node in node.get_children():
		count += _count_named_prefix(child, prefix)
	return count


func _count_meta_recursive(node: Node, meta_key: String) -> int:
	if node == null:
		return 0
	var count := 1 if bool(node.get_meta(meta_key, false)) else 0
	for child: Node in node.get_children():
		count += _count_meta_recursive(child, meta_key)
	return count


func _count_meta_value_recursive(node: Node, meta_key: String, expected: Variant) -> int:
	if node == null:
		return 0
	var count := 1 if node.has_meta(meta_key) and node.get_meta(meta_key) == expected else 0
	for child: Node in node.get_children():
		count += _count_meta_value_recursive(child, meta_key, expected)
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
var _smb_tail_padding := """
:
			push_error("CHANNEL_BATTLE_VIEW_SMOKE: %s" % failure)
		quit(1)

Shared-volume padding keeps obsolete tail bytes inert after layout-test rewrites.
"""
# SMB_FINAL_PADDING_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ
