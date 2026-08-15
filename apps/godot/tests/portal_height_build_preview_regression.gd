extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node3D = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 1.0
	root.add_child(game)
	await process_frame
	await process_frame

	game.start_combat_lab("hall")
	var h0 := _first_cell_at_height(game, 0)
	var h1 := _first_cell_at_height(game, 1)
	var h2 := _first_cell_at_height(game, 2)
	var c0 := _surface_color(game, h0)
	var c1 := _surface_color(game, h1)
	var c2 := _surface_color(game, h2)
	_check(c0.get_luminance() > c1.get_luminance() and c1.get_luminance() > c2.get_luminance(), "H0/H1/H2 surfaces must descend from light gray to medium gray to dark gray")
	var wall: Vector2i = game.combat.walls.keys()[0]
	var blocker := game.battle_root.get_node_or_null("Cell_%d_%d/Blocker" % [wall.x, wall.y]) as MeshInstance3D
	var wall_color: Color = blocker.material_override.albedo_color if blocker != null else Color.BLACK
	_check(blocker != null and wall_color.g > wall_color.r and wall_color.g > wall_color.b, "wall/column blockers must use a recognizable green material")
	_check(_count_named_prefix(game.battle_root, "PortalRing") == 2, "paired portal cells must each render a dedicated ring mesh")

	var entrance: Vector2i = game.combat.portals.keys()[0]
	var exit: Vector2i = game.combat.portals[entrance]
	var neighbor := _walkable_neighbor(game, entrance)
	game.combat.player_pos = neighbor
	game.combat.energy = 5
	_check(game.combat.move_player(entrance), "player must be able to step onto a portal entrance")
	_check(game.combat.player_pos == entrance, "stepping onto a portal must not teleport immediately")
	_check(game.combat.pending_player_portal == exit, "portal entrance must publish the paired exit as a pending choice")
	_check(not game.combat.can_move_player(neighbor), "movement must pause while the portal choice is unresolved")
	_check(game.combat.resolve_player_portal(false) and game.combat.player_pos == entrance, "choosing stay must keep the player on the entrance cell")
	game.combat.player_pos = neighbor
	game.combat.energy = 5
	game.combat.move_player(entrance)
	_check(game.combat.resolve_player_portal(true) and game.combat.player_pos == exit, "choosing use must move the player to the paired exit")
	game.combat.player_pos = neighbor
	game.combat.enemy_pos = exit
	game.combat.energy = 5
	game.combat.move_player(entrance)
	_check(not game.combat.resolve_player_portal(true) and game.combat.player_pos == entrance, "an occupied exit must block teleport instead of overlapping the enemy")
	_check(game.combat.has_pending_player_portal(), "a blocked exit must keep the choice open so the player can choose stay")

	game.go_home()
	game.start_new_run(false)
	game.choose_omen(0)
	var frontier: Vector2i = game.room_rules.frontiers()[0]
	game.begin_build(frontier)
	var preview := game.house_root.get_node_or_null("BuildPreview") as Node3D
	_check(preview != null, "build mode must show the selected room directly on the large map")
	var before: float = preview.rotation.y if preview != null else 0.0
	var rotation_before: int = game.offer_rotation
	game.rotate_offer()
	game.rotate_offer()
	game.rotate_offer()
	await create_timer(0.24).timeout
	preview = game.house_root.get_node_or_null("BuildPreview") as Node3D
	var expected_rotation := (rotation_before + 3) % 4
	var expected_angle := -float(expected_rotation) * PI * 0.5
	_check(preview != null and absf(preview.rotation.y - before) > 1.2, "pressing rotate must visibly turn the map preview")
	_check(game.offer_rotation == expected_rotation and preview != null and absf(angle_difference(preview.rotation.y, expected_angle)) < 0.12, "rapid rotate clicks must keep the large-map room synchronized with the selected direction")
	_check(preview != null and preview.get_node_or_null("PreviewRotation") != null, "map preview must explain its current rotation and placement validity")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHANNEL_PORTAL_HEIGHT_BUILD: PASS grayscale wall portal-choice live-preview")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_PORTAL_HEIGHT_BUILD: %s" % failure)
		quit(1)


func _first_cell_at_height(game: Node3D, height: int) -> Vector2i:
	for raw: Vector2i in game.combat.heights.keys():
		if int(game.combat.heights[raw]) == height:
			return raw
	if height == 0:
		for y in range(game.combat.rows):
			for x in range(game.combat.cols):
				var cell := Vector2i(x, y)
				if not game.combat.heights.has(cell) and not game.combat.walls.has(cell):
					return cell
	return Vector2i.ZERO


func _surface_color(game: Node3D, cell: Vector2i) -> Color:
	var surface := game.battle_root.get_node_or_null("Cell_%d_%d/Surface" % [cell.x, cell.y]) as MeshInstance3D
	return surface.material_override.albedo_color if surface != null else Color.BLACK


func _walkable_neighbor(game: Node3D, cell: Vector2i) -> Vector2i:
	for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var candidate := cell + direction
		if game.combat.is_walkable(candidate) and candidate != game.combat.enemy_pos:
			return candidate
	return cell


func _count_named_prefix(node: Node, prefix: String) -> int:
	var count := 1 if str(node.name).begins_with(prefix) else 0
	for child in node.get_children():
		count += _count_named_prefix(child, prefix)
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
