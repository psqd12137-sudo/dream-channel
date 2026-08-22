class_name CardboardShellBuilder
extends RefCounted

## Shared paper-board set dressing for the room editor.
## The geometry follows pcg_diorama_stitch_lab.gd, but keeps the editor's
## deliberately lower wall height so the miniature room remains readable.

const CELL := 1.55
const KAYKIT_WALL_HEIGHT := 1.08
const WALL_HEIGHT := 0.72
const KAYKIT_JUNCTION_WIDTH := 0.28
const CARDBOARD_PANEL_THICKNESS := 0.10
const CARDBOARD_DOOR_OPENING := 0.66
const WALL_SPAN := CELL - KAYKIT_JUNCTION_WIDTH

const PAPER_PALETTE: Array[Color] = [
	Color("d6afa5"),
	Color("9fb9ad"),
	Color("b9acd0"),
	Color("d2c27d"),
	Color("9eb8c7"),
	Color("d3b89b"),
]
const TAPE_COLOR := Color("e5d49d")


static func build_wall(kind: String, position: Vector3, yaw: float, color_index: int) -> Node3D:
	var normalized_kind := normalize_kind(kind)
	var root := Node3D.new()
	root.name = "CardboardWall_%s" % normalized_kind.trim_prefix("cb_")
	root.position = position
	root.rotation.y = yaw
	root.set_meta("cardboard_shell", true)
	root.set_meta("cardboard_kind", normalized_kind)
	root.set_meta("wall_height", wall_height_for_kind(normalized_kind))
	root.set_meta("color_index", color_index)
	var height := wall_height_for_kind(normalized_kind)
	var base_color := shell_color(color_index)
	_add_box(root, "Panel", Vector3(0.0, height * 0.5, 0.0), Vector3(WALL_SPAN, height, CARDBOARD_PANEL_THICKNESS), base_color)
	_add_box(root, "TopFold", Vector3(0.0, height + 0.025, 0.0), Vector3(WALL_SPAN + 0.04, 0.05, CARDBOARD_PANEL_THICKNESS + 0.035), base_color.lightened(0.10))
	var seam_x := (float(posmod(root.name.hash(), 3)) - 1.0) * WALL_SPAN * 0.27
	_add_box(root, "TapeSeam", Vector3(seam_x, height * 0.54, -CARDBOARD_PANEL_THICKNESS * 0.54), Vector3(0.045, height * 0.76, 0.012), TAPE_COLOR, false)
	for raw_sign: Variant in [-1.0, 1.0]:
		var sign_value := float(raw_sign)
		_add_box(root, "BackFoot_%s" % str(sign_value), Vector3(WALL_SPAN * 0.34 * sign_value, 0.055, -0.14), Vector3(0.07, 0.11, 0.34), base_color.darkened(0.14))
	if normalized_kind == "cb_shelves":
		_add_box(root, "Shelf", Vector3(0.0, height * 0.42, -0.075), Vector3(WALL_SPAN * 0.68, 0.045, 0.16), base_color.lightened(0.04))
		_add_box(root, "ShelfLip", Vector3(0.0, height * 0.48, -0.15), Vector3(WALL_SPAN * 0.72, 0.035, 0.035), TAPE_COLOR, false)
	return root


static func build_doorway(position: Vector3, yaw: float, color_index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "CardboardDoorway"
	root.position = position
	root.rotation.y = yaw
	root.set_meta("cardboard_shell", true)
	root.set_meta("cardboard_kind", "cb_doorway")
	root.set_meta("door_opening", CARDBOARD_DOOR_OPENING)
	root.set_meta("wall_height", WALL_HEIGHT)
	root.set_meta("color_index", color_index)
	var side_width := (WALL_SPAN - CARDBOARD_DOOR_OPENING) * 0.5
	var door_height := WALL_HEIGHT * 0.72
	var base_color := shell_color(color_index).lightened(0.06)
	for raw_sign: Variant in [-1.0, 1.0]:
		var sign_value := float(raw_sign)
		var side_x := (CARDBOARD_DOOR_OPENING * 0.5 + side_width * 0.5) * sign_value
		_add_box(root, "Side_%s" % str(sign_value), Vector3(side_x, WALL_HEIGHT * 0.5, 0.0), Vector3(side_width, WALL_HEIGHT, CARDBOARD_PANEL_THICKNESS), base_color)
	var header_height := WALL_HEIGHT - door_height
	_add_box(root, "Header", Vector3(0.0, door_height + header_height * 0.5, 0.0), Vector3(CARDBOARD_DOOR_OPENING, header_height, CARDBOARD_PANEL_THICKNESS), base_color)
	_add_box(root, "TopFold", Vector3(0.0, WALL_HEIGHT + 0.025, 0.0), Vector3(WALL_SPAN + 0.04, 0.05, CARDBOARD_PANEL_THICKNESS + 0.035), base_color.lightened(0.10))
	var door_color := shell_color(color_index).darkened(0.12)
	_add_box(root, "DoorLeaf", Vector3(0.0, door_height * 0.47, -0.012), Vector3(CARDBOARD_DOOR_OPENING * 0.86, door_height * 0.90, 0.045), door_color)
	_add_box(root, "DoorCue", Vector3(CARDBOARD_DOOR_OPENING * 0.24, door_height * 0.48, -0.04), Vector3(0.045, 0.045, 0.035), Color("f1c24b"), false)
	return root


static func build_junction(position: Vector3, height := WALL_HEIGHT, color_index := 0, edge_keys: Array = []) -> Node3D:
	var root := Node3D.new()
	root.name = "CardboardJunction"
	root.position = position
	root.set_meta("cardboard_shell", true)
	root.set_meta("cardboard_kind", "cb_junction")
	root.set_meta("junction_edge_keys", edge_keys)
	root.set_meta("wall_height", height)
	root.set_meta("color_index", color_index)
	var base_color := shell_color(color_index).darkened(0.10)
	_add_box(root, "Post", Vector3(0.0, height * 0.5, 0.0), Vector3(KAYKIT_JUNCTION_WIDTH, height, KAYKIT_JUNCTION_WIDTH), base_color)
	_add_box(root, "PostCap", Vector3(0.0, height + 0.025, 0.0), Vector3(KAYKIT_JUNCTION_WIDTH + 0.035, 0.05, KAYKIT_JUNCTION_WIDTH + 0.035), base_color.lightened(0.10))
	_add_box(root, "TapeBand", Vector3(0.0, height * 0.68, 0.0), Vector3(KAYKIT_JUNCTION_WIDTH + 0.012, 0.045, KAYKIT_JUNCTION_WIDTH + 0.012), TAPE_COLOR, false)
	return root


static func build_join(position: Vector3, axis: Vector3i, color_index := 0) -> Node3D:
	var root := Node3D.new()
	root.name = "CardboardWallJoin"
	root.position = position
	root.rotation.y = 0.0 if axis.x != 0 else PI * 0.5
	root.set_meta("cardboard_shell", true)
	root.set_meta("cardboard_kind", "cb_join")
	root.set_meta("wall_run_join", true)
	var base_color := shell_color(color_index)
	_add_box(root, "JoinPanel", Vector3(0.0, WALL_HEIGHT * 0.5, 0.0), Vector3(KAYKIT_JUNCTION_WIDTH, WALL_HEIGHT, CARDBOARD_PANEL_THICKNESS), base_color)
	_add_box(root, "JoinTape", Vector3(0.0, WALL_HEIGHT * 0.54, -CARDBOARD_PANEL_THICKNESS * 0.54), Vector3(0.045, WALL_HEIGHT * 0.76, 0.012), TAPE_COLOR, false)
	return root


static func build_fixture(kind: String, position: Vector3, yaw: float, color_index := 0) -> Node3D:
	var root := Node3D.new()
	root.name = "ProductionFixture_%s" % kind
	root.position = position
	root.rotation.y = yaw
	root.set_meta("production_fixture", true)
	root.set_meta("fixture_kind", kind)
	root.set_meta("cardboard_shell", true)
	root.set_meta("color_index", color_index)
	match kind:
		"cue_card":
			_add_box(root, "Slate", Vector3.ZERO, Vector3(0.30, 0.20, 0.025), Color("25303b"), false)
			_add_box(root, "SlateTop", Vector3(0.0, 0.09, -0.018), Vector3(0.30, 0.045, 0.022), Color("f1c24b"), false)
			_add_box(root, "SlateLine", Vector3(0.0, -0.025, -0.018), Vector3(0.19, 0.018, 0.022), Color("f2e6c9"), false)
		"fake_window":
			_add_box(root, "WindowBlue", Vector3.ZERO, Vector3(0.31, 0.23, 0.025), Color("71c7cf"), false)
			_add_box(root, "FrameTop", Vector3(0.0, 0.115, -0.018), Vector3(0.35, 0.035, 0.025), Color("f2e6c9"), false)
			_add_box(root, "FrameBottom", Vector3(0.0, -0.115, -0.018), Vector3(0.35, 0.035, 0.025), Color("f2e6c9"), false)
			_add_box(root, "FrameLeft", Vector3(-0.16, 0.0, -0.018), Vector3(0.035, 0.24, 0.025), Color("f2e6c9"), false)
			_add_box(root, "FrameRight", Vector3(0.16, 0.0, -0.018), Vector3(0.035, 0.24, 0.025), Color("f2e6c9"), false)
		"on_air":
			_add_box(root, "OnAirBoard", Vector3.ZERO, Vector3(0.31, 0.17, 0.025), Color("c93471"), false)
			for index in range(3):
				var lamp_color := Color("f6dd67") if index != 1 else Color("70d4ca")
				_add_box(root, "Lamp_%d" % index, Vector3(-0.09 + float(index) * 0.09, 0.0, -0.022), Vector3(0.038, 0.038, 0.026), lamp_color, false)
		_:
			_add_box(root, "CueFallback", Vector3.ZERO, Vector3(0.28, 0.16, 0.025), shell_color(color_index), false)
	return root


static func normalize_kind(kind: String) -> String:
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


static func wall_height_for_kind(kind: String) -> float:
	return WALL_HEIGHT * 0.58 if normalize_kind(kind) == "cb_wall_half" else WALL_HEIGHT


static func shell_color(color_index: int) -> Color:
	return PAPER_PALETTE[posmod(color_index, PAPER_PALETTE.size())]


static func _add_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, color: Color, cast_shadow := true) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.98
	material.metallic = 0.0
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)
	return mesh_instance
