@tool
extends "res://scripts/pcg_diorama_stitch_lab.gd"

var layout_errors: Array[Dictionary] = []
var authored_piece_count := 0
var explicit_connection_edges: Dictionary = {}
@export var show_summary_title := true
var _last_layout_signature := ""
var _refresh_pending := false


func _ready() -> void:
	super._ready()
	_last_layout_signature = _layout_signature()
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or _refresh_pending:
		return
	var signature := _layout_signature()
	if signature == _last_layout_signature:
		return
	_last_layout_signature = signature
	_refresh_pending = true
	call_deferred("_refresh_authored_layout")


func _refresh_authored_layout() -> void:
	_refresh_pending = false
	if is_inside_tree():
		regenerate(generation_seed)


func _generate_room_layout() -> void:
	layout_errors.clear()
	authored_piece_count = 0
	var layout := get_node_or_null("Layout")
	if layout == null:
		return
	for piece: Node in layout.get_children():
		if not piece.has_method("grid_origin") or not piece.has_method("quarter_turns"):
			continue
		authored_piece_count += 1
		var shape_id := str(piece.get("shape_id"))
		var room_id := str(piece.get("room_id"))
		var origin: Vector2i = piece.grid_origin(CELL)
		var turns: int = piece.quarter_turns()
		var offsets := _rotated_shape(shape_id, turns)
		var candidate: Array[Vector2i] = []
		var overlap := false
		for offset: Vector2i in offsets:
			var cell := origin + offset
			if occupancy.has(cell):
				overlap = true
			candidate.append(cell)
		if overlap:
			layout_errors.append({"id": room_id, "position": Vector3(piece.position.x, 2.2, piece.position.z), "message": "占用格重叠"})
			continue
		var contacts: Array[Dictionary] = []
		for cell: Vector2i in candidate:
			for direction: Vector2i in DIRS:
				var neighbor := cell + direction
				if occupancy.has(neighbor):
					contacts.append({"source": neighbor, "target": cell, "key": _edge_key(neighbor, cell)})
		var room_index := rooms.size()
		var elevation := ELEVATION_STEP if bool(piece.get("elevated")) else 0.0
		_add_room(shape_id, candidate, elevation, room_id if not room_id.is_empty() else "R%02d" % room_index)
		var generated_room: Dictionary = rooms[room_index]
		generated_room["name"] = str(piece.get_meta("room_name", room_id))
		generated_room["revealed"] = bool(piece.get_meta("revealed", true))
		generated_room["visited"] = bool(piece.get_meta("visited", true))
		generated_room["completed"] = bool(piece.get_meta("completed", false))
		generated_room["is_current"] = bool(piece.get_meta("is_current", false))
		rooms[room_index] = generated_room
		if room_index == 0:
			continue
		if contacts.is_empty():
			layout_errors.append({"id": room_id, "position": Vector3(piece.position.x, 2.2, piece.position.z), "message": "没有接触之前的房间"})
			continue
		contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["key"]) < str(b["key"]))
		var chosen_contacts: Array[Dictionary] = []
		if explicit_connection_edges.is_empty():
			chosen_contacts.append(contacts[0])
		else:
			for contact: Dictionary in contacts:
				if explicit_connection_edges.has(str(contact["key"])):
					chosen_contacts.append(contact)
		if chosen_contacts.is_empty():
			layout_errors.append({"id": room_id, "position": Vector3(piece.position.x, 2.2, piece.position.z), "message": "接触边没有正式门连接"})
			continue
		for chosen: Dictionary in chosen_contacts:
			var source: Vector2i = chosen["source"]
			var target: Vector2i = chosen["target"]
			connection_edges[str(chosen["key"])] = {
				"source": source,
				"target": target,
				"source_room": int(occupancy[source]),
				"target_room": room_index,
			}
	room_target = rooms.size()


func _build_joined_diorama() -> void:
	super._build_joined_diorama()
	for error: Dictionary in layout_errors:
		var label := Label3D.new()
		label.name = "LayoutError_%s" % str(error.get("id", "room"))
		label.position = error.get("position", Vector3.ZERO)
		label.text = "⚠ %s\n%s" % [str(error.get("id", "room")), str(error.get("message", "布局错误"))]
		label.modulate = Color("ff5a62")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 46
		label.outline_size = 12
		label.pixel_size = 0.008
		generated_root.add_child(label)


func _build_title(_size: Vector2i) -> void:
	if not show_summary_title:
		return
	var label := Label3D.new()
	label.name = "GenerationSummary"
	var target := camera_target()
	label.position = target + Vector3(0.0, 3.2, -layout_extent * 0.28)
	label.text = "正式地图手摆模拟 · %d 房 / %d 格\n移动 Layout 子节点 · 旋转 Y 每次 90° · 红字表示无效" % [rooms.size(), occupancy.size()]
	label.modulate = Color("ffe3a3") if layout_errors.is_empty() else Color("ff8a82")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 48
	label.outline_size = 12
	label.pixel_size = 0.008
	generated_root.add_child(label)


func _cell_world(cell: Vector2i, _center: Vector2) -> Vector3:
	return Vector3(float(cell.x) * CELL, 0.0, float(cell.y) * CELL)


func camera_target() -> Vector3:
	if occupancy.is_empty():
		return Vector3.ZERO
	var bounds := _cell_bounds()
	var center := Vector2((bounds["min"] as Vector2i) + (bounds["max"] as Vector2i)) * 0.5
	return Vector3(center.x * CELL, 0.75, center.y * CELL)


func authored_layout_is_valid() -> bool:
	return authored_piece_count > 0 and layout_errors.is_empty() and rooms.size() == authored_piece_count and connection_edges.size() == maxi(0, rooms.size() - 1)


func authored_summary() -> String:
	return "%d 房 / %d 格 / %d 门洞 / %d 个布局错误" % [rooms.size(), occupancy.size(), doorway_count, layout_errors.size()]


func _layout_signature() -> String:
	var layout := get_node_or_null("Layout")
	if layout == null:
		return "missing"
	var parts: Array[String] = []
	for piece: Node in layout.get_children():
		if piece.has_method("layout_signature"):
			parts.append("%s:%s" % [piece.name, piece.layout_signature()])
	return ";".join(parts)
