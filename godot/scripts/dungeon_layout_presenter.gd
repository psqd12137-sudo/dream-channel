extends RefCounted

const Rules = preload("res://scripts/asset_diorama_rules.gd")
const Shell = preload("res://scripts/cardboard_shell_builder.gd")

## Spatial presentation only. This class never writes combat state.
static func build(layout: Dictionary, cols: int, rows: int, cell: float) -> Node3D:
	var root := Node3D.new()
	root.name = "AuthoredDungeonLayout"
	root.set_meta("layout_id", layout.get("dungeon_layout_id", ""))
	var cells := Rules.rotated_cells(str(layout.get("footprint_kind", "single")), int(layout.get("room_rotation_quarters", 0)))
	var bounds := Rules.room_bounds_world(cells)
	var center := Rules.room_center_world(cells)
	# Fit the editor's room bounds to the arena; preserve each object's authored
	# transform (including stacked assets) under a shared spatial transform.
	root.scale = Vector3(float(cols) * cell / bounds.size.x, 1.0, float(rows) * cell / bounds.size.z)
	root.position = Vector3(-center.x * root.scale.x, 0.41, -center.z * root.scale.z)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/editor/asset_catalog.json"))
	var by_id: Dictionary = {}
	for entry: Dictionary in catalog.get("assets", []):
		by_id[str(entry.get("id", ""))] = entry
	for asset: Dictionary in layout.get("assets", []):
		var entry: Dictionary = by_id.get(str(asset.get("asset_id", asset.get("id", ""))), {})
		var path := str(entry.get("path", ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			continue
		var node := packed.instantiate() as Node3D
		if node == null:
			continue
		node.position = _vec(asset.get("position", []))
		node.rotation.y = float(asset.get("yaw", 0.0))
		node.scale = _vec(asset.get("scale", [1, 1, 1]))
		root.add_child(node)
	for wall: Dictionary in layout.get("walls", []):
		var kind := str(wall.get("wall_kind", wall.get("kind", "cb_wall")))
		var axis := _vec(wall.get("wall_axis", wall.get("axis", [1, 0, 0])))
		var yaw := 0.0 if axis.x != 0 else PI * 0.5
		var position := _vec(wall.get("position", []))
		var node := Shell.build_doorway(position, yaw, 0) if kind == "cb_doorway" or bool(wall.get("is_door", false)) else Shell.build_wall(kind, position, yaw, 0)
		root.add_child(node)
		if wall.has("wall_start") and wall.has("wall_end"):
			node.scale.x = _vec(wall.wall_start).distance_to(_vec(wall.wall_end)) / Shell.WALL_SPAN
		node.set_meta("authored_wall", true)
	for fixture: Dictionary in layout.get("fixtures", []):
		root.add_child(Shell.build_fixture(str(fixture.get("kind", "cue_card")), _vec(fixture.get("position", [])), float(fixture.get("yaw", 0.0)), 0))
	return root


static func _vec(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2])) if value.size() >= 3 else Vector3.ZERO
