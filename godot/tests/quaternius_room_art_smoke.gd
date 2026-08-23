extends SceneTree

const RoomArtRegistry = preload("res://scripts/room_art_registry.gd")
const RoomLayoutLab = preload("res://scenes/room_layout_lab.tscn")
const RoomFootprintCatalog = preload("res://scripts/room_footprint_catalog.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for path: String in RoomArtRegistry.asset_paths():
		_check(ResourceLoader.exists(path), "selected Quaternius asset must import: %s" % path)
	var layout: Node3D = RoomLayoutLab.instantiate()
	root.add_child(layout)
	await process_frame
	var expected_layout_rooms: Array[String] = []
	for room_id: String in RoomArtRegistry.LAYOUT_ROOM_NODES:
		expected_layout_rooms.append(str(RoomArtRegistry.LAYOUT_ROOM_NODES[room_id]))
	for layout_room: String in expected_layout_rooms:
		var room_node := layout.get_node_or_null(NodePath(layout_room)) as Node3D
		_check(room_node != null, "layout lab must expose editable room root: %s" % layout_room)
		if room_node != null and layout_room in ["Hall", "Parlor", "WestWing", "Cellar"]:
			_check(_count_grouped_children(room_node, &"room_prop") >= 3, "%s must keep at least three direct editable furniture instances" % layout_room)
		if room_node != null:
			var room_id := str(room_node.get_meta("_room_id", ""))
			var config: Dictionary = RoomFootprintCatalog.ROOM_CONFIG.get(room_id, {})
			var expected_shape: Array = RoomFootprintCatalog.SHAPES.get(str(config.get("shape", "single")), [[0, 0]])
			var authored_cells: Array = room_node.get("layout_cells")
			_check(authored_cells.size() == expected_shape.size(), "%s editor footprint must match its runtime 1/3/5 shape" % layout_room)
			var generated := room_node.get_node_or_null("GeneratedFootprint")
			_check(generated != null and generated.get_child_count() == maxi(0, authored_cells.size() - 1) * 2, "%s must render every extra footprint cell in the editor lab" % layout_room)
	_check(expected_layout_rooms.size() == 24, "layout lab must include all 24 catalog rooms")
	layout.queue_free()
	await process_frame

	var game: Node3D = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	# 正式游戏默认走 PCG composer；本测试专门验证旧房间美术注册表的独立 fallback，
	# 因此显式关闭 composer，避免把“正式链路不调用 legacy decorator”误报成资产缺失。
	game.kenney_build_lab_mode = false
	root.add_child(game)
	await process_frame
	await process_frame

	for room_id in ["hall", "west_wing", "cellar", "parlor"]:
		var room: Dictionary = game._find_catalog_room(room_id).duplicate(true)
		_check(not room.is_empty(), "art profile room must exist: %s" % room_id)
		if room.is_empty():
			continue
		room["revealed"] = true
		var room_node := Node3D.new()
		game.house_root.add_child(room_node)
		game._populate_room_visual(room_node, Vector2i.ZERO, room)
		_check(_count_named_prefix(room_node, "QuaterniusProp_") >= 3, "%s must receive a readable multi-prop vignette" % room_id)
		room_node.free()

	var hidden_hall: Dictionary = game._find_catalog_room("hall").duplicate(true)
	hidden_hall["revealed"] = false
	var hidden_node := Node3D.new()
	game.house_root.add_child(hidden_node)
	game._populate_room_visual(hidden_node, Vector2i.ZERO, hidden_hall)
	_check(_count_named_prefix(hidden_node, "QuaterniusProp_") == 0, "unknown rooms must not leak their contents through furniture")
	hidden_node.free()

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHANNEL_QUATERNIUS_ROOM_ART: PASS assets profiles hidden-fallback")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_QUATERNIUS_ROOM_ART: %s" % failure)
		quit(1)


func _count_named_prefix(node: Node, prefix: String) -> int:
	var count := 1 if str(node.name).begins_with(prefix) else 0
	for child: Node in node.get_children():
		count += _count_named_prefix(child, prefix)
	return count


func _count_grouped_children(node: Node, group_name: StringName) -> int:
	var count := 0
	for child: Node in node.get_children():
		if child.get_groups().has(group_name):
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
