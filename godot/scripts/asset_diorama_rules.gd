class_name AssetDioramaRules
extends RefCounted

const RoomFootprintCatalog = preload("res://scripts/room_footprint_catalog.gd")

const CELL := 1.55
const FINE_SNAP := CELL / 10.0
const SIZE_TIERS := [0.6, 1.0, 1.5]
const WALL_HEIGHT := 0.72
const WALL_SPAN := CELL - 0.28
const WALL_PANEL_THICKNESS := 0.10
const PAPER_COLOR := Color("f4ede0")
const PAPER_PALETTE: Array[Color] = [
	Color("d6afa5"),
	Color("9fb9ad"),
	Color("b9acd0"),
	Color("d2c27d"),
	Color("9eb8c7"),
	Color("d3b89b"),
]
const BOUNDARY_EPSILON := 0.001
const WALL_Y_OFFSET := 0.02
const WALL_BOUNDARY_EPSILON := 0.02
const WALL_KIND_IDS: Array[String] = ["cb_wall", "cb_wall_half", "cb_doorway", "cb_shelves"]


static func snap_free(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)


static func snap_fine(point: Vector3) -> Vector3:
	return Vector3(
		roundf(point.x / FINE_SNAP) * FINE_SNAP,
		0.0,
		roundf(point.z / FINE_SNAP) * FINE_SNAP
	)


static func rotated_cells(shape_id: String, rotation_quarters: int) -> Array[Vector2i]:
	var source: Array = RoomFootprintCatalog.SHAPES.get(shape_id, RoomFootprintCatalog.SHAPES["single"])
	var result: Array[Vector2i] = []
	var turns := posmod(rotation_quarters, 4)
	for raw_cell: Variant in source:
		var values := raw_cell as Array
		if values.size() < 2:
			continue
		var cell := Vector2i(int(values[0]), int(values[1]))
		for _turn in turns:
			cell = Vector2i(-cell.y, cell.x)
		result.append(cell)
	return result


static func room_center_world(cells: Array[Vector2i]) -> Vector3:
	if cells.is_empty():
		return Vector3.ZERO
	var minimum := cells[0]
	var maximum := cells[0]
	for cell in cells:
		minimum.x = mini(minimum.x, cell.x)
		minimum.y = mini(minimum.y, cell.y)
		maximum.x = maxi(maximum.x, cell.x)
		maximum.y = maxi(maximum.y, cell.y)
	return Vector3(
		(float(minimum.x + maximum.x) + 1.0) * CELL * 0.5,
		0.0,
		(float(minimum.y + maximum.y) + 1.0) * CELL * 0.5
	)


# Compatibility helper used by the first v2 scene implementation.
static func room_center_cells(cells: Array[Vector2i]) -> Vector2:
	var center := room_center_world(cells)
	return Vector2(center.x, center.z)


static func room_bounds_world(cells: Array[Vector2i]) -> AABB:
	if cells.is_empty():
		return AABB()
	var minimum := cells[0]
	var maximum := cells[0]
	for cell in cells:
		minimum.x = mini(minimum.x, cell.x)
		minimum.y = mini(minimum.y, cell.y)
		maximum.x = maxi(maximum.x, cell.x)
		maximum.y = maxi(maximum.y, cell.y)
	return AABB(
		Vector3(float(minimum.x) * CELL, 0.0, float(minimum.y) * CELL),
		Vector3(float(maximum.x - minimum.x + 1) * CELL, 0.0, float(maximum.y - minimum.y + 1) * CELL)
	)


static func point_in_room(point: Vector3, cells: Array[Vector2i]) -> bool:
	for cell in cells:
		var minimum_x := float(cell.x) * CELL - BOUNDARY_EPSILON
		var maximum_x := float(cell.x + 1) * CELL + BOUNDARY_EPSILON
		var minimum_z := float(cell.y) * CELL - BOUNDARY_EPSILON
		var maximum_z := float(cell.y + 1) * CELL + BOUNDARY_EPSILON
		if point.x >= minimum_x and point.x <= maximum_x and point.z >= minimum_z and point.z <= maximum_z:
			return true
	return false


static func aabb_in_room(aabb: AABB, cells: Array[Vector2i]) -> bool:
	var minimum := aabb.position
	var maximum := aabb.position + aabb.size
	var center := (minimum + maximum) * 0.5
	# The footprint is a union of compact axis-aligned cells. Four projected
	# corners plus the center are sufficient for the connected 1/3/5-cell set.
	var samples: Array[Vector3] = [
		Vector3(minimum.x, 0.0, minimum.z),
		Vector3(maximum.x, 0.0, minimum.z),
		Vector3(minimum.x, 0.0, maximum.z),
		Vector3(maximum.x, 0.0, maximum.z),
		Vector3(center.x, 0.0, center.z),
	]
	for sample in samples:
		if not point_in_room(sample, cells):
			return false
	return true


static func aabb_overlaps_xz(a: AABB, b: AABB) -> bool:
	var a_min := a.position
	var a_max := a.position + a.size
	var b_min := b.position
	var b_max := b.position + b.size
	# Touching edges are valid; only a positive-area XZ intersection is rejected.
	return (
		a_min.x < b_max.x - BOUNDARY_EPSILON
		and a_max.x > b_min.x + BOUNDARY_EPSILON
		and a_min.z < b_max.z - BOUNDARY_EPSILON
		and a_max.z > b_min.z + BOUNDARY_EPSILON
	)


static func aabb_overlaps(a: AABB, b: AABB) -> bool:
	# True 3D overlap: two assets may share XZ if they are vertically separated,
	# which is what enables stacking. A positive-volume intersection on all three
	# axes is rejected (touching faces/edges are valid).
	var a_min := a.position
	var a_max := a.position + a.size
	var b_min := b.position
	var b_max := b.position + b.size
	return (
		a_min.x < b_max.x - BOUNDARY_EPSILON
		and a_max.x > b_min.x + BOUNDARY_EPSILON
		and a_min.z < b_max.z - BOUNDARY_EPSILON
		and a_max.z > b_min.z + BOUNDARY_EPSILON
		and a_min.y < b_max.y - BOUNDARY_EPSILON
		and a_max.y > b_min.y + BOUNDARY_EPSILON
	)


static func wall_axis_from_drag(start: Vector3, end: Vector3) -> Vector3i:
	return Vector3i(1, 0, 0) if absf(end.x - start.x) >= absf(end.z - start.z) else Vector3i(0, 0, 1)


static func normalize_wall_kind(kind: String) -> String:
	match kind:
		"kaykit_wall":
			return "cb_wall"
		"kaykit_wall_half":
			return "cb_wall_half"
		"kaykit_wall_doorway":
			return "cb_doorway"
		"kaykit_wall_shelves":
			return "cb_shelves"
		"kaykit_wall_corner", "kaykit_pillar":
			return "cb_junction"
		_:
			return kind


static func wall_kind_is_valid(kind: String) -> bool:
	return normalize_wall_kind(kind) in WALL_KIND_IDS


static func wall_cells_from_drag(start: Vector3, end: Vector3, axis: Vector3i) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var horizontal: bool = absi(axis.x) >= absi(axis.z)
	var start_along := start.x if horizontal else start.z
	var end_along := end.x if horizontal else end.z
	var fixed := start.z if horizontal else start.x
	# The pointer anchors wall endpoints on CELL/2 coordinates, then the other
	# endpoint is quantized to whole CELL lengths so each result is one segment.
	start_along = roundf(start_along / (CELL * 0.5)) * (CELL * 0.5)
	fixed = roundf(fixed / CELL) * CELL
	var signed_steps: int = roundi((end_along - start_along) / CELL)
	if signed_steps == 0:
		signed_steps = 1 if end_along >= start_along else -1
	var direction: int = signi(signed_steps)
	var count: int = absi(signed_steps)
	for index in count:
		var along := start_along + (float(index) + 0.5) * CELL * float(direction)
		result.append(
			Vector3(along, WALL_Y_OFFSET, fixed)
			if horizontal
			else Vector3(fixed, WALL_Y_OFFSET, along)
		)
	return result


static func room_boundary_edges(cells: Array[Vector2i]) -> Array[Dictionary]:
	var edges: Array[Dictionary] = []
	var lookup := {}
	for cell in cells:
		lookup[cell] = true
	for cell in cells:
		var x0 := float(cell.x) * CELL
		var x1 := float(cell.x + 1) * CELL
		var z0 := float(cell.y) * CELL
		var z1 := float(cell.y + 1) * CELL
		if not lookup.has(cell + Vector2i(0, -1)):
			edges.append({"start": Vector3(x0, WALL_Y_OFFSET, z0), "end": Vector3(x1, WALL_Y_OFFSET, z0), "axis": Vector3i(1, 0, 0), "cell": cell})
		if not lookup.has(cell + Vector2i(0, 1)):
			edges.append({"start": Vector3(x0, WALL_Y_OFFSET, z1), "end": Vector3(x1, WALL_Y_OFFSET, z1), "axis": Vector3i(1, 0, 0), "cell": cell})
		if not lookup.has(cell + Vector2i(-1, 0)):
			edges.append({"start": Vector3(x0, WALL_Y_OFFSET, z0), "end": Vector3(x0, WALL_Y_OFFSET, z1), "axis": Vector3i(0, 0, 1), "cell": cell})
		if not lookup.has(cell + Vector2i(1, 0)):
			edges.append({"start": Vector3(x1, WALL_Y_OFFSET, z0), "end": Vector3(x1, WALL_Y_OFFSET, z1), "axis": Vector3i(0, 0, 1), "cell": cell})
	return edges


static func corner_anchors(cells: Array[Vector2i]) -> Array[Dictionary]:
	"""Return the de-duplicated outer footprint corners used as wall anchors."""
	var by_key: Dictionary = {}
	for edge in room_boundary_edges(cells):
		for endpoint_name in ["start", "end"]:
			var point: Vector3 = edge.get(endpoint_name, Vector3.ZERO)
			var key := "%d:%d" % [roundi(point.x * 1000.0), roundi(point.z * 1000.0)]
			if not by_key.has(key):
				by_key[key] = {
					"anchor_id": "anchor_%s" % key,
					"position": point,
					"edges": [],
				}
			var record := by_key[key] as Dictionary
			var edge_key := "%d:%d:%d" % [int(edge.get("cell", Vector2i.ZERO).x), int(edge.get("cell", Vector2i.ZERO).y), 1 if (edge.get("axis", Vector3i.ZERO) as Vector3i).x != 0 else 0]
			var edge_list := record.get("edges", []) as Array
			if edge_key not in edge_list:
				edge_list.append(edge_key)
				record["edges"] = edge_list
	return by_key.values()


static func snap_to_corner_anchor(point: Vector3, cells: Array[Vector2i], tolerance := 0.3) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for anchor in corner_anchors(cells):
		var anchor_point: Vector3 = anchor.get("position", Vector3.ZERO)
		var distance := Vector2(point.x - anchor_point.x, point.z - anchor_point.z).length()
		if distance < best_distance:
			best_distance = distance
			best = anchor
	if best_distance > float(tolerance):
		return {}
	return best


static func wall_position_in_room(pos: Vector3, cells: Array[Vector2i]) -> bool:
	for edge in room_boundary_edges(cells):
		var start: Vector3 = edge.get("start", Vector3.ZERO)
		var finish: Vector3 = edge.get("end", Vector3.ZERO)
		var axis: Vector3i = edge.get("axis", Vector3i.ZERO)
		if axis.x != 0:
			if absf(pos.z - start.z) <= WALL_BOUNDARY_EPSILON and pos.x >= minf(start.x, finish.x) - BOUNDARY_EPSILON and pos.x <= maxf(start.x, finish.x) + BOUNDARY_EPSILON:
				return true
		else:
			if absf(pos.x - start.x) <= WALL_BOUNDARY_EPSILON and pos.z >= minf(start.z, finish.z) - BOUNDARY_EPSILON and pos.z <= maxf(start.z, finish.z) + BOUNDARY_EPSILON:
				return true
	return false


static func next_size_tier(current: int) -> int:
	return posmod(current + 1, SIZE_TIERS.size())


static func nearest_size_tier(factor: float) -> int:
	var best := 0
	var best_distance := INF
	for index in SIZE_TIERS.size():
		var distance := absf(float(SIZE_TIERS[index]) - factor)
		if distance < best_distance:
			best = index
			best_distance = distance
	return best


static func make_template_json(
	shape_id: String,
	rotation_quarters: int,
	assets: Array,
	walls: Array,
	template_name,
	fixtures: Array = []
) -> Dictionary:
	var normalized_assets: Array[Dictionary] = []
	for raw_asset: Variant in assets:
		if not raw_asset is Dictionary:
			continue
		var asset := raw_asset as Dictionary
		var asset_id := str(asset.get("asset_id", asset.get("id", "")))
		var position: Array = asset.get("position", [])
		var scale_value: Array = asset.get("scale", [])
		if asset_id.is_empty() or position.size() < 3 or scale_value.size() < 3:
			continue
		normalized_assets.append({
			"id": asset_id,
			"position": [float(position[0]), float(position[1]), float(position[2])],
			"yaw": float(asset.get("yaw", 0.0)),
			"scale": [float(scale_value[0]), float(scale_value[1]), float(scale_value[2])],
		})
	var normalized_walls: Array[Dictionary] = []
	for raw_wall: Variant in walls:
		if not raw_wall is Dictionary:
			continue
		var wall := raw_wall as Dictionary
		var kind := str(wall.get("wall_kind", wall.get("kind", "")))
		var position: Array = wall.get("position", [])
		var axis: Array = wall.get("wall_axis", wall.get("axis", []))
		var cell: Array = wall.get("wall_cell", wall.get("cell", []))
		if kind.is_empty() or position.size() < 3 or axis.size() < 3 or cell.size() < 2:
			continue
		var normalized_wall := {
			"kind": normalize_wall_kind(kind),
			"position": [float(position[0]), float(position[1]), float(position[2])],
			"yaw": float(wall.get("yaw", 0.0)),
			"axis": [int(axis[0]), int(axis[1]), int(axis[2])],
			"cell": [int(cell[0]), int(cell[1])],
		}
		for optional_key in ["wall_start", "wall_end", "door_restore_start", "door_restore_end"]:
			if wall.has(optional_key) and wall.get(optional_key) is Array and (wall.get(optional_key) as Array).size() >= 3:
				normalized_wall[optional_key] = [float((wall.get(optional_key) as Array)[0]), float((wall.get(optional_key) as Array)[1]), float((wall.get(optional_key) as Array)[2])]
		for optional_key in ["is_door", "door_restore_kind"]:
			if wall.has(optional_key):
				normalized_wall[optional_key] = wall.get(optional_key)
		normalized_walls.append(normalized_wall)
	var normalized_fixtures: Array[Dictionary] = []
	for raw_fixture: Variant in fixtures:
		if not raw_fixture is Dictionary:
			continue
		var fixture := raw_fixture as Dictionary
		var fixture_kind := str(fixture.get("kind", fixture.get("fixture_kind", "")))
		var fixture_position: Array = fixture.get("position", [])
		if fixture_kind.is_empty() or fixture_position.size() < 3:
			continue
		normalized_fixtures.append({
			"kind": fixture_kind,
			"position": [float(fixture_position[0]), float(fixture_position[1]), float(fixture_position[2])],
			"yaw": float(fixture.get("yaw", 0.0)),
		})
	return {
		"schema_version": 2,
		"template_name": str(template_name),
		"room_shape": shape_id if RoomFootprintCatalog.SHAPES.has(shape_id) else "single",
		"room_rotation_quarters": posmod(rotation_quarters, 4),
		"saved_at": Time.get_datetime_string_from_system(false, false),
		"assets": normalized_assets,
		"walls": normalized_walls,
		"fixtures": normalized_fixtures,
	}


static func parse_template_json(text: String) -> Dictionary:
	var parser := JSON.new()
	var error := parser.parse(text)
	if error != OK or not parser.data is Dictionary:
		return {"ok": false, "error": "JSON 格式错误"}
	var data := parser.data as Dictionary
	if int(data.get("schema_version", -1)) != 2:
		return {"ok": false, "error": "schema_version 必须为 2"}
	var shape_id := str(data.get("room_shape", ""))
	if not RoomFootprintCatalog.SHAPES.has(shape_id):
		return {"ok": false, "error": "未知房间形状：%s" % shape_id}
	if not data.get("assets", null) is Array:
		return {"ok": false, "error": "assets 必须是数组"}
	if not data.get("walls", null) is Array:
		return {"ok": false, "error": "walls 必须是数组"}
	for raw_asset: Variant in data.get("assets", []):
		if not raw_asset is Dictionary:
			return {"ok": false, "error": "资产条目必须是对象"}
		var asset := raw_asset as Dictionary
		if str(asset.get("id", "")).is_empty():
			return {"ok": false, "error": "资产条目缺少 id"}
		if not _valid_vec_array(asset.get("position", null), 3) or not _valid_vec_array(asset.get("scale", null), 3):
			return {"ok": false, "error": "资产条目 transform 无效"}
	for raw_wall: Variant in data.get("walls", []):
		if not raw_wall is Dictionary:
			return {"ok": false, "error": "墙条目必须是对象"}
		var wall := raw_wall as Dictionary
		if str(wall.get("kind", "")).is_empty():
			return {"ok": false, "error": "墙条目缺少 kind"}
		if not _valid_vec_array(wall.get("position", null), 3) or not _valid_vec_array(wall.get("axis", null), 3) or not _valid_vec_array(wall.get("cell", null), 2):
			return {"ok": false, "error": "墙条目几何字段无效"}
		wall["kind"] = normalize_wall_kind(str(wall.get("kind", "")))
	if data.has("fixtures") and not data.get("fixtures") is Array:
		return {"ok": false, "error": "fixtures 必须是数组"}
	return {"ok": true, "data": data}


static func apply_template_entry(entry: Dictionary, catalog: Dictionary) -> Dictionary:
	var asset_id := str(entry.get("id", entry.get("asset_id", "")))
	var catalog_entry := _catalog_entry(asset_id, catalog)
	if catalog_entry.is_empty():
		return {}
	var position: Array = entry.get("position", [])
	var scale_value: Array = entry.get("scale", [])
	if position.size() < 3 or scale_value.size() < 3:
		return {}
	return {
		"asset_id": asset_id,
		"path": str(catalog_entry.get("path", "")),
		"position": Vector3(float(position[0]), float(position[1]), float(position[2])),
		"yaw": float(entry.get("yaw", 0.0)),
		"scale": Vector3(float(scale_value[0]), float(scale_value[1]), float(scale_value[2])),
	}


static func _valid_vec_array(value: Variant, size: int) -> bool:
	return value is Array and (value as Array).size() >= size


static func _catalog_entry(asset_id: String, catalog: Dictionary) -> Dictionary:
	for raw_entry: Variant in catalog.get("assets", []):
		if raw_entry is Dictionary and str((raw_entry as Dictionary).get("id", "")) == asset_id:
			return raw_entry as Dictionary
	return {}
