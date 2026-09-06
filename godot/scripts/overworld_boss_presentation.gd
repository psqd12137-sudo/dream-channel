extends RefCounted

# Own only this overlay; never rebuild or reskin the original room assets.
static func refresh(game) -> void:
	var r = game.combat
	if r == null:
		return
	_apply_floor_visibility(game, r)
	var layer = game.house_root.get_node_or_null("WorldBossOverlay")
	if layer == null:
		layer = Node3D.new()
		layer.name = "WorldBossOverlay"
		game.house_root.add_child(layer)
	for child: Node in layer.get_children():
		if not child.name.begins_with("Anchor_"):
			continue
		var anchor_parts := child.name.trim_prefix("Anchor_").split("_")
		if anchor_parts.size() >= 2:
			var anchor_cell := Vector2i(int(anchor_parts[0]), int(anchor_parts[1]))
			child.visible = _floor_visible(game, int(r.cell_floors.get(anchor_cell, 0)))
	var boss = layer.get_node_or_null("BossToken")
	if boss == null:
		boss = Node3D.new()
		boss.name = "BossToken"
		layer.add_child(boss)
		var presenter = preload("res://scripts/character_presenter.gd").new()
		boss.add_child(presenter)
		presenter.configure("enemy", game.presentation.get("actors", {}).get("enemy", {}))
		presenter.scale = Vector3.ONE * 1.65
		_add_label(boss, "▼ Boss", Vector3(0, 3.0, 0), Color("ff6e96"))
	boss.position = game._house_world(r.room_nodes[r.enemy_pos].cell) + Vector3(0.65, 0.4, 0)
	boss.visible = r.enemy_hp > 0 and _floor_visible(game, int(r.room_nodes[r.enemy_pos].get("floor", 0)))
	var hints = layer.get_node_or_null("Hints")
	if hints != null:
		hints.free()
	hints = Node3D.new()
	hints.name = "Hints"
	layer.add_child(hints)
	var intent: Dictionary = r.preview_intent()
	for node: Vector2i in r.room_nodes:
		var record: Dictionary = r.room_nodes[node]
		if not _floor_visible(game, int(record.get("floor", 0))):
			continue
		var color := Color.TRANSPARENT
		if node in intent.get("impact_cells", []):
			color = Color("ef5268")
		elif node in r.host_fight.camera_cells:
			color = Color("f2b84b")
		elif node in r.graph[r.player_pos]:
			color = Color("4bc5bc")
		if node == game.hovered_battle_cell:
			color = Color("ffe092")
		if color.a > 0.0:
			# Outline only the room boundary, not the floor or internal grid.
			for cell: Vector2i in record.cells:
				for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
					if cell + direction in record.cells:
						continue
					var marker := MeshInstance3D.new()
					var mesh := BoxMesh.new()
					mesh.size = Vector3(0.055, 0.055, 3.0) if direction.x != 0 else Vector3(3.0, 0.055, 0.055)
					marker.mesh = mesh
					marker.material_override = _material(color)
					marker.position = game._house_world(cell) + Vector3(direction.x * 1.45, 0.34, direction.y * 1.45)
					hints.add_child(marker)
		if bool(record.get("is_room_origin", false)) and int(record.get("floor", 0)) != 0:
			_add_label(hints, str(record.get("floor_label", "楼层")), game._house_world(record.cell) + Vector3(0, 2.55, 0), Color("d8c8d2"))
		if r.anchors.has(node):
			var anchor_name := "Anchor_%d_%d" % [node.x, node.y]
			var anchor = layer.get_node_or_null(anchor_name)
			if anchor == null:
				anchor = MeshInstance3D.new()
				anchor.name = anchor_name
				var mesh := CylinderMesh.new()
				mesh.top_radius = 0.13
				mesh.bottom_radius = 0.32
				mesh.height = 1.1
				anchor.mesh = mesh
				anchor.position = game._house_world(record.cell) + Vector3(-0.65, 0.85, -0.65)
				layer.add_child(anchor)
			anchor.material_override = _material(Color("f2b84b") if int(r.anchors[node]) > 0 else Color("52706b"))
			anchor.visible = _floor_visible(game, int(record.get("floor", 0)))
			_add_label(hints, "%s · 锚余%d次" % [str(record.name), int(r.anchors[node])], anchor.position + Vector3(0, 1.3, 0), Color("ffe092"))
		if r.traps.has(node):
			var trap: Dictionary = r.traps[node]
			var card: Dictionary = r.cards.get(str(trap.get("card_id", "")), {})
			_add_label(hints, "▣ " + str(card.get("name", "陷阱")), game._house_world(record.cell) + Vector3(0, 1.4, 0), Color("4bc5bc"))
		if r.has_decoy() and r.decoy_pos == node:
			_add_label(hints, "纸影诱饵", game._house_world(record.cell) + Vector3(0, 1.0, 0), Color.WHITE)
	for stair_index in range(r.stair_links.size()):
		var stair: Dictionary = r.stair_links[stair_index]
		var from_cell: Vector2i = stair.get("from", Vector2i(-999, -999))
		var to_cell: Vector2i = stair.get("to", Vector2i(-999, -999))
		var from_world: Vector3
		var to_world: Vector3
		from_world = game._house_world(from_cell) as Vector3
		to_world = game._house_world(to_cell) as Vector3
		if _floor_visible(game, int(r.cell_floors.get(from_cell, 0))):
			_add_stair_steps(hints, "StairStep_%d_ground" % stair_index, from_world, str(stair.get("kind", "stair")))
			_add_label(hints, "↥ " + str(stair.get("label", "楼梯")), from_world + Vector3(0, 1.0, 0), Color("ffe092"))
		if _floor_visible(game, int(r.cell_floors.get(to_cell, 0))):
			_add_stair_steps(hints, "StairStep_%d_landing" % stair_index, to_world, str(stair.get("kind", "stair")))
			_add_label(hints, "↧ 楼梯出口", to_world + Vector3(0, 1.0, 0), Color("ffe092"))
	var player = game.house_root.get_node_or_null("LiliToken")
	if player != null:
		if layer.has_meta("player_node") and layer.get_meta("player_node") != r.player_pos:
			player.position = game._house_world(r.room_nodes[r.player_pos].cell) + Vector3(-0.45, 0.3, 0)
		player.visible = _floor_visible(game, int(r.room_nodes[r.player_pos].get("floor", 0)))
	layer.set_meta("player_node", r.player_pos)


static func _floor_visible(game, floor_index: int) -> bool:
	return game.house_floor_view == game.FLOOR_VIEW_OVERVIEW or floor_index == game.house_floor_view


static func _apply_floor_visibility(game, r) -> void:
	var overview: bool = game.house_floor_view == game.FLOOR_VIEW_OVERVIEW
	for child: Node in game.house_root.get_children():
		if child.name == "WorldBossOverlay":
			continue
		if child.name.begins_with("KenneyFormalComposer"):
			# The generated room models live below GeneratedMap. Visibility must be
			# applied to the composer root, not only to Layout authoring pieces.
			child.visible = overview or int(child.get_meta("floor", 0)) == game.house_floor_view
			continue
		if child.name == "LiliToken":
			child.visible = _floor_visible(game, int(r.room_nodes.get(r.player_pos, {}).get("floor", 0)))
			continue
		if child.has_meta("floor"):
			child.visible = overview or int(child.get_meta("floor", 0)) == game.house_floor_view
		elif child.name.begins_with("Room_"):
			var parts := child.name.trim_prefix("Room_").split("_")
			var raw_cell := Vector2i(int(parts[0]), int(parts[1])) if parts.size() >= 2 else Vector2i.ZERO
			child.visible = overview or int(r.cell_floors.get(raw_cell, 0)) == game.house_floor_view


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


static func _add_stair_steps(parent: Node3D, prefix: String, origin: Vector3, kind: String) -> void:
	var direction := 1.0 if kind == "up" else -1.0
	for index in range(3):
		var step := MeshInstance3D.new()
		step.name = "%s_%d" % [prefix, index]
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.1, 0.12 + float(index) * 0.08, 0.42)
		step.mesh = mesh
		step.material_override = _material(Color("f2b84b"))
		step.position = origin + Vector3(0, 0.08 + float(index) * 0.10, direction * (float(index) - 1.0) * 0.34)
		parent.add_child(step)


static func _add_label(parent: Node3D, caption: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = caption
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 32
	label.pixel_size = 0.012
	label.modulate = color
	parent.add_child(label)
