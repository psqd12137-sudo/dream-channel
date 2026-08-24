extends Node3D

const Rules = preload("res://scripts/asset_diorama_rules.gd")
const RoomFootprintCatalog = preload("res://scripts/room_footprint_catalog.gd")
const RoomPropCatalog = preload("res://scripts/room_prop_catalog.gd")
const CardboardShellBuilder = preload("res://scripts/cardboard_shell_builder.gd")
const RoomShellGraph = preload("res://scripts/room_shell_graph.gd")

const CELL := 1.55
const FINE_SNAP := CELL / 10.0
const CATALOG_PATH := "res://data/editor/asset_catalog.json"
const PRESENTATION_MANIFEST_PATH := "res://data/presentation_manifest.json"
const TEMPLATE_DIR := "user://diorama_templates/"
const PRESET_TEMPLATE_DIR := "res://data/editor/preset_templates/"
const FORMAL_OVERRIDE_DIR := "res://data/editor/overrides/"
const MAIN_SCENE_PATH := "res://channel_3d.tscn"
const INVALID_POINT := Vector3(INF, INF, INF)
const INVALID_CELL := Vector2i(999999, 999999)
const UNDO_LIMIT := 50
const FORMAL_BASE_LAYOUT_SEED := 20260816
const GHOST_CHECK_INTERVAL_MS := 50
const GHOST_CHECK_DISTANCE := 0.05
const GOLD := Color("#f3a51f")
const INVALID_RED := Color("#d63b72")
## Reference actor height in world metres: a toy-doll figure that fits the
## paper-board diorama (wall height 0.72m, cell 1.55m) instead of a full-size
## person. The game-facing model_scale (1.68) would tower over the room.
const REFERENCE_ACTOR_HEIGHT := 0.55
const GROUND_COLOR := Color("#356c58")
const MAT_FINE_GRID := Color("#d8ead626")
const MAT_MAJOR_GRID := Color("#f0df9d70")
const MAT_AXIS_GRID := Color("#f5c95cbb")
const WALL_TOOL_IDS: Array[String] = [
	"cb_wall", "cb_wall_half", "cb_doorway", "cb_shelves",
]
const WALL_TOOL_NAMES := {
	"cb_wall": "纸板直墙",
	"cb_wall_half": "纸板半墙",
	"cb_doorway": "纸板门洞",
	"cb_shelves": "纸板壁架墙",
}
const ROOM_SHAPE_ORDER: Array[String] = [
	"single", "line3", "l3", "plus5", "t5", "p5", "stair5", "u5",
]
const ROOM_SHAPE_NAMES := {
	"single": "1格 单格房",
	"line3": "3格 长条房",
	"l3": "3格 L 形房",
	"plus5": "5格 十字房",
	"t5": "5格 T 形房",
	"p5": "5格 P 形房",
	"stair5": "5格 阶梯房",
	"u5": "5格 U 形房",
}
const FORMAL_DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var catalog: Dictionary = {}
var failed_paths: Array[String] = []
var selected_asset := ""
var ghost_yaw := 0.0
var ghost_size_tier := 1
var ghost_valid := true
var ghost_invalid_reason := ""
var last_rejection_reason := ""
var place_counter := 0

var wall_mode := false
var wall_kind := ""
var wall_dragging := false
var wall_drag_start := Vector3.ZERO
var wall_drag_end := Vector3.ZERO
var wall_preview_valid := false
var wall_graph: Dictionary = {}
var tool_mode := "move"
var gizmo_dragging := false
var gizmo_handle := ""
var gizmo_drag_start_mouse := Vector2.ZERO
var gizmo_drag_start_world := INVALID_POINT
var gizmo_drag_start_position := Vector3.ZERO
var gizmo_drag_start_yaw := 0.0
var gizmo_drag_start_scale := Vector3.ONE
var gizmo_drag_start_tier := 1
var gizmo_drag_snapshot: Dictionary = {}
var endpoint_dragging := false
var endpoint_wall: Node3D = null
var endpoint_index := 0
var endpoint_drag_snapshot: Dictionary = {}

var selection: Node3D = null
var dragging := false
var rotating_selection := false
var rotating_ghost := false
var drag_from := Vector3.ZERO
var drag_yaw_from := 0.0
var drag_valid := true
var drag_snapshot: Dictionary = {}
var room_shape_id := "single"
var room_rotation_quarters := 0
var room_cells: Array[Vector2i] = []
var formal_room_id := "living"
var suppress_formal_room_ui := false
var suppress_room_ui := false

var cam_yaw_target := PI * 0.5
var cam_pitch_target := 0.92
var cam_distance_target := 8.5
var cam_yaw_current := PI * 0.5
var cam_pitch_current := 0.92
var cam_distance_current := 8.5
var orbit_center := Vector3.ZERO
var orbit_center_current := Vector3.ZERO

var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var last_ghost_check_ms := 0
var last_ghost_check_position := Vector3(INF, INF, INF)
var selection_ring_material: StandardMaterial3D
var actor_visible := true
var template_items: Array[Dictionary] = []

@onready var ground_mesh: MeshInstance3D = $GroundMesh
@onready var room_base: Node3D = $RoomBase
@onready var placements: Node3D = $Placements
@onready var walls: Node3D = $Walls
@onready var corners: Node3D = $Corners
@onready var wall_joins: Node3D = $WallJoins
@onready var fixtures: Node3D = $Fixtures
@onready var cardboard_shell: Node3D = $CardboardShell
@onready var editor_overlay: Node3D = $EditorOverlay
@onready var gizmo: Node3D = $EditorOverlay/Gizmo3D
@onready var anchor_nodes: Node3D = $EditorOverlay/Anchors
@onready var wall_handles: Node3D = $EditorOverlay/WallHandles
@onready var ghost: Node3D = $Ghost
@onready var selection_ring: MeshInstance3D = $SelectionRing
@onready var reference_actor: Node3D = $ReferenceActor
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var catalog_list: VBoxContainer = $UI/Panel/VBox/CatalogScroll/CatalogList
@onready var status_label: Label = $UI/Panel/VBox/Status
@onready var formal_room: OptionButton = $UI/TopBar/FormalRoom
@onready var room_shape: OptionButton = $UI/TopBar/RoomShape
@onready var rotate_room_button: Button = $UI/TopBar/RotateRoom
@onready var tool_pan_button: Button = $UI/ToolDock/ToolRow/ToolPan
@onready var tool_move_button: Button = $UI/ToolDock/ToolRow/ToolMove
@onready var tool_rotate_button: Button = $UI/ToolDock/ToolRow/ToolRotate
@onready var tool_scale_button: Button = $UI/ToolDock/ToolRow/ToolScale
@onready var place_door_button: Button = $UI/TopBar/PlaceDoor
@onready var toggle_actor_button: Button = $UI/TopBar/ToggleActor
@onready var template_name: LineEdit = $UI/TemplateBar/TemplateName
@onready var override_room_id: LineEdit = $UI/TemplateBar/OverrideRoomId
@onready var export_override_button: Button = $UI/TemplateBar/ExportOverride
@onready var template_save: Button = $UI/TemplateBar/TemplateSave
@onready var template_load: Button = $UI/TemplateBar/TemplateLoad
@onready var template_list: OptionButton = $UI/TemplateBar/TemplateList
@onready var template_refresh: Button = $UI/TemplateBar/TemplateRefresh
@onready var template_delete: Button = $UI/TemplateBar/TemplateDelete
@onready var clear_button: Button = $UI/TemplateBar/ClearBtn
@onready var return_home_button: Button = $UI/ReturnHome
@onready var help_label: Label = $UI/HelpLabel


func _ready() -> void:
	_load_catalog()
	_validate_catalog_paths()
	_build_catalog_panel()
	_prepare_selection_ring()
	_populate_formal_rooms()
	_populate_room_shapes()
	_prepare_ground()
	_make_ground_grid()
	room_cells = Rules.rotated_cells(room_shape_id, room_rotation_quarters)
	_rebuild_room(true)
	_build_reference_actor()
	_load_formal_room_layout(formal_room_id, false)
	formal_room.item_selected.connect(_on_formal_room_selected)
	room_shape.item_selected.connect(_on_room_shape_selected)
	rotate_room_button.pressed.connect(_rotate_room)
	tool_pan_button.pressed.connect(func(): _set_tool_mode("pan"))
	tool_move_button.pressed.connect(func(): _set_tool_mode("move"))
	tool_rotate_button.pressed.connect(func(): _set_tool_mode("rotate"))
	tool_scale_button.pressed.connect(func(): _set_tool_mode("scale"))
	place_door_button.pressed.connect(_replace_selected_wall_with_door)
	toggle_actor_button.pressed.connect(_toggle_actor)
	template_save.pressed.connect(func(): _save_template(template_name.text))
	export_override_button.pressed.connect(func(): _export_override(override_room_id.text))
	template_load.pressed.connect(func(): _load_template(_selected_template_name()))
	template_refresh.pressed.connect(func(): _refresh_templates(_selected_template_name()))
	template_delete.pressed.connect(func(): _delete_template(_selected_template_name()))
	template_list.item_selected.connect(_on_template_selected)
	clear_button.pressed.connect(func(): _clear_all(true))
	return_home_button.pressed.connect(return_to_title)
	_refresh_templates()
	selection_ring.visible = false
	ghost.visible = false
	_rebuild_corner_anchors()
	_set_tool_mode("move")
	_update_camera_transform()
	_update_status()
	_update_help()


func return_to_title() -> bool:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		status_label.text = "无法返回标题：主场景没有找到。"
		return false
	get_tree().change_scene_to_packed(packed)
	return true


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-delta * 8.0)
	cam_yaw_current = lerp_angle(cam_yaw_current, cam_yaw_target, weight)
	cam_pitch_current = lerpf(cam_pitch_current, cam_pitch_target, weight)
	cam_distance_current = lerpf(cam_distance_current, cam_distance_target, weight)
	orbit_center_current = orbit_center_current.lerp(orbit_center, weight)
	_update_camera_transform()
	if selection != null and is_instance_valid(selection) and gizmo.visible:
		gizmo.global_position = selection.global_position + Vector3(0.0, 0.35, 0.0)
		# Unity keeps handles readable at different camera distances.
		gizmo.scale = Vector3.ONE * clampf(cam_distance_current / 8.5, 0.72, 2.1)
	_update_wall_handles()


func _toggle_tool_mode(requested: String) -> void:
	# Kept as a compatibility entry point for tests and older UI scenes. Unity's
	# tool hotkeys select a persistent tool; pressing W/E/R twice does not cancel it.
	_set_tool_mode(requested)


func _set_tool_mode(next_mode: String) -> void:
	if next_mode not in ["select", "pan", "move", "rotate", "scale"]:
		next_mode = "select"
	tool_mode = next_mode
	if gizmo != null and is_instance_valid(gizmo):
		var can_use_gizmo := tool_mode in ["move", "rotate", "scale"] and selection != null and is_instance_valid(selection) and not bool(selection.get_meta("is_wall", false))
		if can_use_gizmo:
			gizmo.set_target(selection, tool_mode)
		else:
			gizmo.clear_target()
	_update_tool_buttons()
	_update_wall_handles()
	_update_help()
	_update_status()


func _update_tool_buttons() -> void:
	for pair in [[tool_pan_button, "pan"], [tool_move_button, "move"], [tool_rotate_button, "rotate"], [tool_scale_button, "scale"]]:
		var button := pair[0] as Button
		if button == null:
			continue
		button.modulate = GOLD if tool_mode == str(pair[1]) else Color.WHITE


func _gizmo_hit(mouse: Vector2) -> Dictionary:
	if gizmo == null or not gizmo.visible:
		return {}
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	return gizmo.hit_test(origin, direction)


func _begin_gizmo_drag(mouse: Vector2, hit: Dictionary) -> bool:
	if selection == null or not is_instance_valid(selection) or hit.is_empty():
		return false
	if bool(selection.get_meta("is_wall", false)):
		return false
	gizmo_dragging = true
	gizmo_handle = str(hit.get("handle", ""))
	gizmo_drag_start_mouse = mouse
	gizmo_drag_start_position = selection.position
	gizmo_drag_start_world = _gizmo_drag_world_point(mouse, gizmo_handle)
	gizmo_drag_start_yaw = selection.rotation.y
	gizmo_drag_start_scale = selection.scale
	gizmo_drag_start_tier = int(selection.get_meta("size_tier", 1))
	gizmo_drag_snapshot = _snapshot_state()
	drag_valid = true
	return true


func _update_gizmo_drag(mouse: Vector2) -> void:
	if not gizmo_dragging or selection == null or not is_instance_valid(selection):
		return
	var delta := mouse - gizmo_drag_start_mouse
	if gizmo_handle.begins_with("move_"):
		if gizmo_handle == "move_y":
			selection.position.y = gizmo_drag_start_position.y - delta.y * cam_distance_current * 0.0015
		else:
			var point := _gizmo_drag_world_point(mouse, gizmo_handle)
			var start_point := gizmo_drag_start_world
			if not _point_is_valid(point) or not _point_is_valid(start_point):
				return
			var offset := point - start_point
			match gizmo_handle:
				"move_x":
					selection.position = gizmo_drag_start_position + Vector3(offset.x, 0.0, 0.0)
				"move_z":
					selection.position = gizmo_drag_start_position + Vector3(0.0, 0.0, offset.z)
				# Plane handles: lock the drag to one axis-pair plane.
				"move_xy":
					selection.position = gizmo_drag_start_position + Vector3(offset.x, offset.y, 0.0)
				"move_yz":
					selection.position = gizmo_drag_start_position + Vector3(0.0, offset.y, offset.z)
				"move_xz":
					selection.position = gizmo_drag_start_position + Vector3(offset.x, 0.0, offset.z)
			# Apply fine-snap/CTRL on the ground-plane components only (keep Y free).
			var snapped := _position_for_mode(selection.position)
			selection.position.x = snapped.x
			selection.position.z = snapped.z
	elif gizmo_handle == "rotate_y":
		# Godot's positive Y rotation matches a rightward screen drag from the
		# default editor camera. The old minus sign made left/right feel mirrored.
		selection.rotation.y = gizmo_drag_start_yaw + delta.x * 0.01
	elif gizmo_handle.begins_with("scale_"):
		# Continuous scale. Uniform handle scales XYZ together; per-axis handles
		# stretch a single axis. Factor derived from horizontal mouse delta.
		var factor := exp(delta.x * 0.008)
		var base := gizmo_drag_start_scale
		match gizmo_handle:
			"scale_uniform":
				selection.scale = base * factor
			"scale_x":
				selection.scale = Vector3(base.x * factor, base.y, base.z)
			"scale_y":
				selection.scale = Vector3(base.x, base.y * factor, base.z)
			"scale_z":
				selection.scale = Vector3(base.x, base.y, base.z * factor)
		selection.scale = selection.scale.max(Vector3.ONE * 0.01)
	drag_valid = bool(_placement_valid(selection, selection).get("ok", false))
	_set_selection_invalid(not drag_valid)
	selection_ring.global_position = Vector3(selection.global_position.x, 0.025, selection.global_position.z)


func _finish_gizmo_drag() -> void:
	if not gizmo_dragging:
		return
	if not drag_valid:
		_rebuild_from_state(gizmo_drag_snapshot)
	else:
		_push_undo_snapshot(gizmo_drag_snapshot)
	gizmo_dragging = false
	gizmo_handle = ""
	gizmo_drag_start_world = INVALID_POINT
	gizmo_drag_snapshot.clear()
	_set_selection_invalid(false)
	_update_status()


func _gizmo_drag_world_point(mouse: Vector2, handle: String) -> Vector3:
	if selection == null or not is_instance_valid(selection):
		return INVALID_POINT
	var plane_point := gizmo_drag_start_position
	match handle:
		"move_xy":
			return _mouse_plane_point(mouse, Vector3.FORWARD, plane_point)
		"move_yz":
			return _mouse_plane_point(mouse, Vector3.RIGHT, plane_point)
		"move_x", "move_z", "move_xz":
			return _mouse_plane_point(mouse, Vector3.UP, plane_point)
	return INVALID_POINT


func _mouse_plane_point(mouse: Vector2, plane_normal: Vector3, plane_point: Vector3) -> Vector3:
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var denominator := plane_normal.dot(direction)
	if absf(denominator) < 0.00001:
		return INVALID_POINT
	var distance := plane_normal.dot(plane_point - origin) / denominator
	return origin + direction * distance if distance >= 0.0 else INVALID_POINT


func _rebuild_corner_anchors() -> void:
	if anchor_nodes == null:
		return
	for child in anchor_nodes.get_children():
		child.free()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = GOLD
	material.emission_enabled = true
	material.emission = GOLD
	material.emission_energy_multiplier = 1.7
	for anchor in Rules.corner_anchors(room_cells):
		var marker := MeshInstance3D.new()
		marker.name = "CornerAnchor_%s" % str(anchor.get("anchor_id", ""))
		var mesh := SphereMesh.new()
		mesh.radius = 0.10
		mesh.height = 0.20
		marker.mesh = mesh
		marker.material_override = material
		marker.position = anchor.get("position", Vector3.ZERO)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.set_meta("editor_overlay", true)
		marker.set_meta("anchor_id", str(anchor.get("anchor_id", "")))
		anchor_nodes.add_child(marker)
	anchor_nodes.visible = wall_mode


func _snap_to_corner_anchor(point: Vector3) -> Dictionary:
	return Rules.snap_to_corner_anchor(point, room_cells, 0.3)


func _load_catalog() -> void:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("Asset editor catalog missing: %s" % CATALOG_PATH)
		catalog = {"schema_version": 1, "categories": [], "assets": []}
		return
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not parser.data is Dictionary:
		push_error("Asset editor catalog JSON is invalid: %s" % CATALOG_PATH)
		catalog = {"schema_version": 1, "categories": [], "assets": []}
		return
	catalog = parser.data as Dictionary


func _validate_catalog_paths() -> void:
	failed_paths.clear()
	for raw_entry: Variant in catalog.get("assets", []):
		var entry := raw_entry as Dictionary
		var asset_id := str(entry.get("id", ""))
		var path := str(entry.get("path", ""))
		if path.is_empty() or load(path) == null:
			failed_paths.append(asset_id)
			push_warning("Asset editor missing asset: %s (%s)" % [asset_id, path])


func _build_catalog_panel() -> void:
	for child in catalog_list.get_children():
		child.free()
	var assets: Array = catalog.get("assets", [])
	for raw_category: Variant in catalog.get("categories", []):
		var category := raw_category as Dictionary
		var category_id := str(category.get("id", ""))
		var title := Label.new()
		title.text = str(category.get("name", category_id))
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", GOLD)
		catalog_list.add_child(title)
		if category_id == "structure":
			for wall_id in WALL_TOOL_IDS:
				var wall_button := Button.new()
				wall_button.text = str(WALL_TOOL_NAMES.get(wall_id, wall_id))
				wall_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
				wall_button.set_meta("asset_id", wall_id)
				wall_button.tooltip_text = "纸板片场墙工具：沿房间外轮廓拖动"
				wall_button.pressed.connect(_on_asset_pressed.bind(wall_id))
				catalog_list.add_child(wall_button)
		for raw_entry: Variant in assets:
			var entry := raw_entry as Dictionary
			if str(entry.get("category", "")) != category_id:
				continue
			var button := Button.new()
			button.text = str(entry.get("name", entry.get("id", "")))
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var asset_id := str(entry.get("id", ""))
			button.set_meta("asset_id", asset_id)
			button.disabled = asset_id in failed_paths
			button.pressed.connect(_on_asset_pressed.bind(asset_id))
			catalog_list.add_child(button)


func _populate_room_shapes() -> void:
	suppress_room_ui = true
	room_shape.clear()
	for shape_id in ROOM_SHAPE_ORDER:
		room_shape.add_item(str(ROOM_SHAPE_NAMES.get(shape_id, shape_id)))
		room_shape.set_item_metadata(room_shape.item_count - 1, shape_id)
	_sync_room_shape_ui()
	suppress_room_ui = false


func _populate_formal_rooms() -> void:
	suppress_formal_room_ui = true
	formal_room.clear()
	var room_ids: Array[String] = []
	for raw_id: Variant in RoomFootprintCatalog.ROOM_CONFIG.keys():
		room_ids.append(str(raw_id))
	room_ids.sort()
	for room_id in room_ids:
		var config: Dictionary = RoomFootprintCatalog.ROOM_CONFIG.get(room_id, {})
		var shape_id := str(config.get("shape", "single"))
		var cell_count := (RoomFootprintCatalog.SHAPES.get(shape_id, RoomFootprintCatalog.SHAPES["single"]) as Array).size()
		formal_room.add_item("%s · %d格 · %s" % [room_id, cell_count, ROOM_SHAPE_NAMES.get(shape_id, shape_id)])
		formal_room.set_item_metadata(formal_room.item_count - 1, room_id)
	_sync_formal_room_ui()
	suppress_formal_room_ui = false


func _sync_formal_room_ui() -> void:
	formal_room.select(-1)
	for index in formal_room.item_count:
		if str(formal_room.get_item_metadata(index)) == formal_room_id:
			formal_room.select(index)
			return


func _sync_room_shape_ui() -> void:
	for index in room_shape.item_count:
		if str(room_shape.get_item_metadata(index)) == room_shape_id:
			room_shape.select(index)
			return


func _on_asset_pressed(asset_id) -> void:
	var id := str(asset_id)
	if _find_asset_entry(id).is_empty() and not id in WALL_TOOL_IDS:
		return
	_cancel_transform()
	_deselect()
	selected_asset = id
	ghost_yaw = 0.0
	ghost_size_tier = 1
	wall_mode = id in WALL_TOOL_IDS
	wall_kind = id if wall_mode else ""
	wall_dragging = false
	_rebuild_corner_anchors()
	_clear_ghost()
	if not wall_mode:
		_rebuild_ghost()
	_update_status()


func _rebuild_ghost() -> void:
	_clear_ghost()
	var entry := _find_asset_entry(selected_asset)
	if entry.is_empty() or wall_mode:
		return
	var instance := _instantiate_asset(entry)
	if instance == null:
		return
	instance.scale = _base_scale(entry) * float(Rules.SIZE_TIERS[ghost_size_tier])
	_set_ghost_transparency(instance)
	ghost.add_child(instance)
	ghost.rotation.y = ghost_yaw
	ghost.set_meta("asset_id", selected_asset)
	ghost.set_meta("overlay", bool(entry.get("overlay", false)))
	ghost.visible = true
	_update_ghost_validity(true)


func _clear_ghost() -> void:
	for child in ghost.get_children():
		child.free()
	ghost.position = Vector3.ZERO
	ghost.rotation = Vector3.ZERO
	ghost.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.ctrl_pressed and key.keycode in [KEY_Z, KEY_Y]:
			# Undo (Ctrl+Z) / Redo (Ctrl+Y, Ctrl+Shift+Z).
			if key.pressed and not key.echo and not _keyboard_captured_by_ui():
				if key.keycode == KEY_Y or key.shift_pressed:
					_redo()
				else:
					_undo()
			return
		if key.ctrl_pressed and key.keycode == KEY_D:
			if key.pressed and not key.echo and not _keyboard_captured_by_ui():
				_duplicate_selected()
			return
		if not key.pressed or key.echo or _keyboard_captured_by_ui():
			return
		# Unity tool overlay: Q=view/pan, W=move, E=rotate, R=scale.
		match key.keycode:
			KEY_Q:
				_set_tool_mode("pan")
				return
			KEY_W:
				_set_tool_mode("move")
				return
			KEY_E:
				_set_tool_mode("rotate")
				return
			KEY_R:
				_set_tool_mode("scale")
				return
		if key.keycode == KEY_F:
			_focus_active()
			return
		if key.keycode == KEY_G:
			_replace_selected_wall_with_door()
			return
		if key.keycode == KEY_DELETE and selection != null:
			_delete_selected()
			return
		if key.keycode == KEY_ESCAPE:
			_cancel_active_mode()
			return

	if (event is InputEventMouseButton or event is InputEventMouseMotion) and get_viewport().gui_get_hovered_control() != null:
		return

	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var camera_step := -1.0 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			cam_distance_target *= exp(camera_step * 0.12)
			_clamp_camera_targets()
			return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			cam_yaw_target -= motion.relative.x * 0.008
			cam_pitch_target += motion.relative.y * 0.008
			_clamp_camera_targets()
			return
		if (motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
			_pan_orbit(motion.relative)
			return
		# Q "pan" tool: left-drag pans the view (Unity pan behaves like this).
		if tool_mode == "pan" and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_pan_orbit(motion.relative)
			return
		if gizmo_dragging and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_update_gizmo_drag(motion.position)
			return
		if endpoint_dragging and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_update_endpoint_drag(motion.position)
			return
		if wall_dragging and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_update_wall_preview(motion.position)
			return
		if rotating_ghost and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			ghost_yaw += motion.relative.x * 0.01
			ghost.rotation.y = ghost_yaw
			_update_ghost_validity(true)
			_update_status()
			return
		if dragging and selection != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if rotating_selection and not bool(selection.get_meta("is_wall", false)):
				_rotate_selected_by_motion(motion.relative.x)
			else:
				var drag_point := _mouse_ground_point(motion.position)
				if _point_is_valid(drag_point):
					_move_selected_to(_position_for_mode(drag_point))
					drag_valid = _selected_transform_valid()
					_set_selection_invalid(not drag_valid)
			return
		if not selected_asset.is_empty() and not wall_mode:
			_update_ghost_position(motion.position)
		return

	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
			# Q "pan" tool: left-drag is view-only panning, never selects/places.
			if tool_mode == "pan":
				return
			var gizmo_hit := _gizmo_hit(click.position)
			if not gizmo_hit.is_empty() and _begin_gizmo_drag(click.position, gizmo_hit):
				return
			var endpoint_hit := _endpoint_hit(click.position)
			if not endpoint_hit.is_empty() and _begin_endpoint_drag(click.position, endpoint_hit):
				return
			if wall_mode:
				_begin_wall_drag(click.position)
			elif not selected_asset.is_empty():
				# 放置模式：先尝试点中已存在的物品/墙体 → 退出放置并选中它（Unity 语义：
				# 点击已有物体永远优先选择，而不是把它当成放置目标）。只有点中空白地面才放置。
				var picked_existing := _pick_placement(click.position)
				if picked_existing != null:
					_select(picked_existing)
					_begin_wall_slide_if_needed(picked_existing)
				else:
					_update_ghost_position(click.position)
					_place_ghost()
			else:
				var picked := _pick_placement(click.position)
				if picked != null:
					_select(picked)
					_begin_wall_slide_if_needed(picked)
				else:
					_deselect()
			return
		if click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
			if gizmo_dragging:
				_finish_gizmo_drag()
			elif endpoint_dragging:
				_finish_endpoint_drag()
			elif wall_dragging:
				_finish_wall_drag(click.position)
			elif rotating_ghost:
				rotating_ghost = false
			elif dragging:
				_finish_transform()
			return


func _begin_wall_slide_if_needed(node: Node3D) -> void:
	# Furniture follows Unity selection semantics and only moves through Gizmos.
	# Structural walls have no transform gizmo; retain their boundary-only slide.
	if not bool(node.get_meta("is_wall", false)):
		return
	drag_from = node.position
	drag_yaw_from = node.rotation.y
	drag_snapshot = _snapshot_state()
	dragging = true
	rotating_selection = false
	drag_valid = true


func _keyboard_captured_by_ui() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit


func _mouse_ground_point(mouse_pos) -> Vector3:
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	if absf(direction.y) < 0.0001:
		return INVALID_POINT
	var distance := -origin.y / direction.y
	if distance < 0.0:
		return INVALID_POINT
	return origin + direction * distance


func _position_for_mode(point: Vector3) -> Vector3:
	return Rules.snap_fine(point) if Input.is_key_pressed(KEY_CTRL) else Rules.snap_free(point)


func _update_ghost_position(mouse) -> void:
	var point := _mouse_ground_point(mouse)
	if not _point_is_valid(point):
		ghost.visible = false
		return
	ghost.position = _position_for_mode(point)
	if bool(ghost.get_meta("overlay", false)):
		ghost.position.y = 0.005
	elif ghost.get_child_count() > 0:
		# Stacking: if the drop point sits over an existing prop's footprint, land
		# the ghost on its top surface instead of the ground plane.
		var ghost_aabb := _node_world_aabb(ghost)
		ghost.position.y = _drop_y_on_top(ghost.position, ghost_aabb)
	ghost.visible = true
	_update_ghost_validity(false)


## Find the highest surface directly under (pos.x, pos.z) among non-overlay props,
## so a dropped asset lands on top of it (stacking). Returns the world Y for the
## asset's base; if nothing is underneath, returns 0 (the room floor).
func _drop_y_on_top(pos: Vector3, candidate_aabb: AABB) -> float:
	var target_bottom := pos.y
	var best_top := 0.0
	var best_found := false
	for container in [placements]:
		for child in container.get_children():
			var placed := child as Node3D
			if placed == null or placed == selection or bool(placed.get_meta("overlay", false)):
				continue
			var other_aabb := _node_world_aabb(placed)
			if other_aabb.size == Vector3.ZERO:
				continue
			if not Rules.aabb_overlaps_xz(candidate_aabb, other_aabb):
				continue
			var other_top := other_aabb.position.y + other_aabb.size.y
			if other_top <= target_bottom + 0.05 and (not best_found or other_top > best_top):
				best_top = other_top
				best_found = true
	return best_top if best_found else 0.0


func _update_ghost_validity(force := false) -> Dictionary:
	if ghost.get_child_count() == 0 or not ghost.visible:
		ghost_valid = false
		ghost_invalid_reason = "missing_ghost"
		return {"ok": false, "reason": ghost_invalid_reason}
	var now := Time.get_ticks_msec()
	if not force and now - last_ghost_check_ms < GHOST_CHECK_INTERVAL_MS and ghost.position.distance_to(last_ghost_check_position) < GHOST_CHECK_DISTANCE:
		return {"ok": ghost_valid, "reason": ghost_invalid_reason}
	last_ghost_check_ms = now
	last_ghost_check_position = ghost.position
	var result := _placement_valid(ghost)
	ghost_valid = bool(result.get("ok", false))
	ghost_invalid_reason = str(result.get("reason", ""))
	_set_ghost_invalid(not ghost_valid)
	return result


func _place_ghost() -> Node3D:
	var validity := _update_ghost_validity(true)
	if not bool(validity.get("ok", false)):
		last_rejection_reason = str(validity.get("reason", "invalid"))
		_update_status("拒绝放置：%s" % _reason_text(last_rejection_reason))
		return null
	var entry := _find_asset_entry(selected_asset)
	var actual_scale := _base_scale(entry) * float(Rules.SIZE_TIERS[ghost_size_tier])
	var before := _snapshot_state()
	var placed := _place_at_free(ghost.position, selected_asset, ghost_yaw, actual_scale, false)
	if placed != null:
		placed.set_meta("size_tier", ghost_size_tier)
		_push_undo_snapshot(before)
	_update_status()
	return placed


func _place_at_free(position: Vector3, asset_id: String, yaw: float, actual_scale: Vector3, validate := true) -> Node3D:
	last_rejection_reason = ""
	var entry := _find_asset_entry(asset_id)
	if entry.is_empty():
		last_rejection_reason = "missing_asset"
		push_warning("Asset editor unknown asset id: %s" % asset_id)
		return null
	var instance := _instantiate_asset(entry)
	if instance == null:
		last_rejection_reason = "missing_asset"
		return null
	place_counter += 1
	instance.name = "place_%04d" % place_counter
	instance.position = position
	if bool(entry.get("overlay", false)) and is_zero_approx(instance.position.y):
		instance.position.y = 0.005
	instance.rotation.y = yaw
	instance.scale = actual_scale
	instance.set_meta("asset_id", asset_id)
	instance.set_meta("overlay", bool(entry.get("overlay", false)))
	var factor := _scale_factor_from_actual(actual_scale, entry)
	instance.set_meta("size_tier", Rules.nearest_size_tier(factor))
	placements.add_child(instance)
	_set_asset_shadows(instance, true)
	if validate:
		var validity := _placement_valid(instance, instance)
		if not bool(validity.get("ok", false)):
			last_rejection_reason = str(validity.get("reason", "invalid"))
			placements.remove_child(instance)
			instance.free()
			place_counter -= 1
			return null
	return instance


func _instantiate_asset(entry: Dictionary) -> Node3D:
	var packed := load(str(entry.get("path", ""))) as PackedScene
	if packed == null:
		push_warning("Asset editor failed to load: %s" % entry.get("path", ""))
		return null
	return packed.instantiate() as Node3D


func _placement_valid(node_or_ghost, ignore_node: Node3D = null) -> Dictionary:
	var candidate := node_or_ghost as Node3D
	if candidate == null:
		return {"ok": false, "reason": "missing_geometry"}
	var candidate_aabb := _node_world_aabb(candidate)
	if candidate_aabb.size == Vector3.ZERO:
		return {"ok": false, "reason": "missing_geometry"}
	if not Rules.aabb_in_room(candidate_aabb, room_cells):
		return {"ok": false, "reason": "out_of_bounds"}
	if bool(candidate.get_meta("overlay", false)):
		return {"ok": true, "reason": ""}
	for container in [placements, walls]:
		for child in container.get_children():
			var placed := child as Node3D
			if placed == null or placed == ignore_node or placed == candidate or bool(placed.get_meta("overlay", false)):
				continue
			var other_aabb := _node_world_aabb(placed)
			if other_aabb.size != Vector3.ZERO and Rules.aabb_overlaps(candidate_aabb, other_aabb):
				return {"ok": false, "reason": "overlap"}
	return {"ok": true, "reason": ""}


func _pick_placement(mouse) -> Node3D:
	var ray_origin := camera.project_ray_origin(mouse)
	var ray_direction := camera.project_ray_normal(mouse)
	var best: Node3D = null
	var best_distance := INF
	for container in [placements, walls]:
		for child in container.get_children():
			var placed := child as Node3D
			if placed == null:
				continue
			var hit_distance := _ray_aabb_distance(ray_origin, ray_direction, _node_world_aabb(placed))
			if hit_distance >= 0.0 and hit_distance < best_distance:
				best_distance = hit_distance
				best = placed
	return best


func _select(node) -> void:
	selection = node as Node3D
	if selection == null:
		_deselect()
		return
	selected_asset = ""
	wall_mode = false
	wall_kind = ""
	_rebuild_corner_anchors()
	_clear_ghost()
	selection_ring.global_position = Vector3(selection.global_position.x, 0.025, selection.global_position.z)
	selection_ring.visible = true
	_set_selection_invalid(false)
	_set_tool_mode(tool_mode)
	_update_wall_handles()
	_update_status()


func _deselect() -> void:
	selection = null
	dragging = false
	rotating_selection = false
	selection_ring.visible = false
	if gizmo != null and is_instance_valid(gizmo):
		gizmo.clear_target()
	_update_tool_buttons()
	_update_wall_handles()
	_set_selection_invalid(false)
	_update_status()


func _move_selected_to(point: Vector3) -> void:
	if selection == null or not is_instance_valid(selection):
		return
	if bool(selection.get_meta("is_wall", false)):
		var old_position := selection.position
		var axis: Vector3i = selection.get_meta("wall_axis", Vector3i(1, 0, 0))
		if axis.x != 0:
			selection.position.x = roundf((point.x - CELL * 0.5) / CELL) * CELL + CELL * 0.5
		else:
			selection.position.z = roundf((point.z - CELL * 0.5) / CELL) * CELL + CELL * 0.5
		selection.position.y = Rules.WALL_Y_OFFSET
		var shift := selection.position - old_position
		var endpoints := _endpoint_positions_for_wall(selection)
		if endpoints.size() == 2:
			selection.set_meta("wall_start", endpoints[0] + shift)
			selection.set_meta("wall_end", endpoints[1] + shift)
			if bool(selection.get_meta("is_door", false)):
				var restore_start: Vector3 = selection.get_meta("door_restore_start", endpoints[0])
				var restore_end: Vector3 = selection.get_meta("door_restore_end", endpoints[1])
				selection.set_meta("door_restore_start", restore_start + shift)
				selection.set_meta("door_restore_end", restore_end + shift)
	else:
		selection.position = point
		if bool(selection.get_meta("overlay", false)):
			selection.position.y = 0.005
		else:
			# Stacking: dragging an existing prop over another prop's footprint lands
			# it on that prop's top surface instead of snapping through to the floor.
			var sel_aabb := _node_world_aabb(selection)
			selection.position.y = _drop_y_on_top(selection.position, sel_aabb)
	selection_ring.global_position = Vector3(selection.global_position.x, 0.025, selection.global_position.z)


func _rotate_selected_by_motion(relative_x: float) -> void:
	if selection == null or bool(selection.get_meta("is_wall", false)):
		return
	selection.rotation.y += relative_x * 0.01
	drag_valid = bool(_placement_valid(selection, selection).get("ok", false))
	_set_selection_invalid(not drag_valid)


func _selected_transform_valid() -> bool:
	if selection == null:
		return false
	if bool(selection.get_meta("is_wall", false)):
		var axis: Vector3i = selection.get_meta("wall_axis", Vector3i.ZERO)
		return bool(_wall_position_valid(selection.position, axis, selection).get("ok", false))
	return bool(_placement_valid(selection, selection).get("ok", false))


func _finish_transform() -> void:
	if selection == null or not is_instance_valid(selection):
		_cancel_transform()
		return
	if not drag_valid:
		selection.position = drag_from
		selection.rotation.y = drag_yaw_from
		selection_ring.global_position = Vector3(selection.global_position.x, 0.025, selection.global_position.z)
		_update_status("变换被拒绝：越界、重叠或墙段脱离边界")
	elif not selection.position.is_equal_approx(drag_from) or not is_equal_approx(selection.rotation.y, drag_yaw_from):
		if bool(selection.get_meta("is_wall", false)):
			selection.set_meta("wall_cell", _boundary_cell_for_wall(selection.position, selection.get_meta("wall_axis", Vector3i.ZERO)))
			_rebuild_wall_graph()
		_push_undo_snapshot(drag_snapshot)
	_cancel_transform()
	_set_selection_invalid(false)
	_update_status()


func _cancel_transform() -> void:
	dragging = false
	rotating_selection = false
	rotating_ghost = false
	drag_snapshot.clear()


func _cycle_size_tier() -> bool:
	if selection != null and is_instance_valid(selection) and not bool(selection.get_meta("is_wall", false)):
		var before := _snapshot_state()
		var entry := _find_asset_entry(str(selection.get_meta("asset_id", "")))
		var old_tier := int(selection.get_meta("size_tier", Rules.nearest_size_tier(_scale_factor_from_actual(selection.scale, entry))))
		var old_scale := selection.scale
		var next_tier := Rules.next_size_tier(old_tier)
		selection.scale = _base_scale(entry) * float(Rules.SIZE_TIERS[next_tier])
		selection.set_meta("size_tier", next_tier)
		var validity := _placement_valid(selection, selection)
		if not bool(validity.get("ok", false)):
			selection.scale = old_scale
			selection.set_meta("size_tier", old_tier)
			_set_selection_invalid(true)
			_update_status("大小档切换被拒绝：%s" % _reason_text(str(validity.get("reason", "invalid"))))
			return false
		_push_undo_snapshot(before)
		_set_selection_invalid(false)
		_update_status()
		return true
	if not selected_asset.is_empty() and not wall_mode:
		ghost_size_tier = Rules.next_size_tier(ghost_size_tier)
		var entry := _find_asset_entry(selected_asset)
		var instance := ghost.get_child(0) as Node3D if ghost.get_child_count() > 0 else null
		if instance != null:
			instance.scale = _base_scale(entry) * float(Rules.SIZE_TIERS[ghost_size_tier])
		_update_ghost_validity(true)
		_update_status()
		return true
	return false


func _duplicate_selected() -> Node3D:
	if selection == null or not is_instance_valid(selection):
		return null
	var before := _snapshot_state()
	var duplicate: Node3D = null
	if bool(selection.get_meta("is_wall", false)):
		var axis: Vector3i = selection.get_meta("wall_axis", Vector3i(1, 0, 0))
		for direction_value in [1.0, -1.0]:
			var direction := float(direction_value)
			var target: Vector3 = selection.position + Vector3(axis.x, 0.0, axis.z) * CELL * direction
			if bool(_wall_position_valid(target, axis).get("ok", false)):
				duplicate = _place_wall_segment(str(selection.get_meta("wall_kind", "cb_wall")), target, axis, _boundary_cell_for_wall(target, axis), false)
				break
		if duplicate != null:
			_rebuild_wall_graph()
	else:
		var asset_id := str(selection.get_meta("asset_id", ""))
		for offset in [Vector3(0.5, 0.0, 0.5), Vector3(-0.5, 0.0, -0.5)]:
			duplicate = _place_at_free(selection.position + offset, asset_id, selection.rotation.y, selection.scale, true)
			if duplicate != null:
				break
	if duplicate == null:
		_update_status("复制被拒绝：没有合法空位")
		return null
	_push_undo_snapshot(before)
	_select(duplicate)
	_update_status("已复制选中对象")
	return duplicate


func _delete_selected() -> void:
	if selection == null or not is_instance_valid(selection):
		return
	var before := _snapshot_state()
	var was_wall := bool(selection.get_meta("is_wall", false))
	var was_door := was_wall and bool(selection.get_meta("is_door", false))
	if was_door:
		_restore_door_wall(selection)
		_push_undo_snapshot(before)
		_update_status("已拆门并恢复实体墙")
		return
	var doomed := selection
	selection = null
	selection_ring.visible = false
	_update_wall_handles()
	if gizmo != null and is_instance_valid(gizmo):
		gizmo.clear_target()
	doomed.free()
	if was_wall:
		_rebuild_wall_graph()
	_push_undo_snapshot(before)
	_update_status()


func _replace_selected_wall_with_door() -> Node3D:
	if selection == null or not is_instance_valid(selection) or not bool(selection.get_meta("is_wall", false)) or bool(selection.get_meta("is_door", false)):
		_update_status("请先选中一段实体墙再放门")
		return null
	var before := _snapshot_state()
	var old := selection
	var old_position := old.position
	var axis: Vector3i = old.get_meta("wall_axis", Vector3i(1, 0, 0))
	var cell: Vector2i = old.get_meta("wall_cell", _boundary_cell_for_wall(old.position, axis))
	var start: Vector3 = old.get_meta("wall_start", old.position - Vector3(axis.x, 0.0, axis.z) * CELL * 0.5)
	var finish: Vector3 = old.get_meta("wall_end", old.position + Vector3(axis.x, 0.0, axis.z) * CELL * 0.5)
	var old_kind := Rules.normalize_wall_kind(str(old.get_meta("wall_kind", "cb_wall")))
	walls.remove_child(old)
	old.free()
	var door := _place_wall_segment("cb_doorway", (start + finish) * 0.5, axis, cell, false, start, finish)
	if door == null:
		_rebuild_walls_from_snapshot([{"wall_kind": old_kind, "position": [old_position.x, Rules.WALL_Y_OFFSET, old_position.z], "wall_axis": [axis.x, axis.y, axis.z], "wall_cell": [cell.x, cell.y], "wall_start": [start.x, start.y, start.z], "wall_end": [finish.x, finish.y, finish.z]}])
		_rebuild_wall_graph()
		_update_status("放门失败：无法生成门洞")
		return null
	door.set_meta("is_door", true)
	door.set_meta("door_restore_kind", old_kind)
	door.set_meta("door_restore_start", start)
	door.set_meta("door_restore_end", finish)
	door.set_meta("door_restore_cell", cell)
	_rebuild_wall_graph()
	_push_undo_snapshot(before)
	_select(door)
	_update_status("已剔除墙段并放置门洞")
	return door


func _restore_door_wall(door: Node3D) -> Node3D:
	var before_position := door.position
	var axis: Vector3i = door.get_meta("wall_axis", Vector3i(1, 0, 0))
	var cell: Vector2i = door.get_meta("door_restore_cell", door.get_meta("wall_cell", Vector2i.ZERO))
	var start: Vector3 = door.get_meta("door_restore_start", door.position - Vector3(axis.x, 0.0, axis.z) * CELL * 0.5)
	var finish: Vector3 = door.get_meta("door_restore_end", door.position + Vector3(axis.x, 0.0, axis.z) * CELL * 0.5)
	var kind := Rules.normalize_wall_kind(str(door.get_meta("door_restore_kind", "cb_wall")))
	walls.remove_child(door)
	door.free()
	selection = null
	var restored := _place_wall_segment(kind, before_position, axis, cell, false, start, finish)
	_rebuild_wall_graph()
	if restored != null:
		_select(restored)
	return restored


func _endpoint_positions_for_wall(wall: Node3D) -> Array[Vector3]:
	if wall == null:
		return []
	var axis: Vector3i = wall.get_meta("wall_axis", Vector3i(1, 0, 0))
	var axis_vec := Vector3(axis.x, 0.0, axis.z)
	var start: Vector3 = wall.get_meta("wall_start", wall.position - axis_vec * CELL * 0.5)
	var finish: Vector3 = wall.get_meta("wall_end", wall.position + axis_vec * CELL * 0.5)
	return [start, finish]


func _update_wall_handles() -> void:
	if wall_handles == null:
		return
	for child in wall_handles.get_children():
		child.free()
	wall_handles.visible = selection != null and is_instance_valid(selection) and bool(selection.get_meta("is_wall", false))
	if not wall_handles.visible:
		return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = GOLD
	material.emission_enabled = true
	material.emission = GOLD
	material.emission_energy_multiplier = 2.0
	var endpoints := _endpoint_positions_for_wall(selection)
	for index in endpoints.size():
		var handle := MeshInstance3D.new()
		handle.name = "Endpoint_%d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * 0.18
		handle.mesh = mesh
		handle.material_override = material
		handle.position = endpoints[index]
		handle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		handle.set_meta("editor_overlay", true)
		handle.set_meta("endpoint_index", index)
		wall_handles.add_child(handle)


func _endpoint_hit(mouse: Vector2) -> Dictionary:
	if not wall_handles.visible:
		return {}
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var best := {}
	var best_distance := INF
	for child in wall_handles.get_children():
		var handle := child as Node3D
		var distance := _ray_aabb_distance(origin, direction, _node_world_aabb(handle))
		if distance >= 0.0 and distance < best_distance:
			best_distance = distance
			best = {"endpoint_index": int(handle.get_meta("endpoint_index", 0)), "distance": distance}
	return best


func _begin_endpoint_drag(mouse: Vector2, hit: Dictionary) -> bool:
	if selection == null or not bool(selection.get_meta("is_wall", false)) or hit.is_empty():
		return false
	endpoint_dragging = true
	endpoint_wall = selection
	endpoint_index = int(hit.get("endpoint_index", 0))
	endpoint_drag_snapshot = _snapshot_state()
	return true


func _update_endpoint_drag(mouse: Vector2) -> void:
	if not endpoint_dragging or endpoint_wall == null or not is_instance_valid(endpoint_wall):
		return
	var point := _mouse_ground_point(mouse)
	if not _point_is_valid(point):
		return
	var snapped := _snap_to_room_boundary(point)
	if snapped.is_empty():
		return
	var endpoints := _endpoint_positions_for_wall(endpoint_wall)
	if endpoints.size() != 2:
		return
	var next_point: Vector3 = snapped.get("point", point)
	endpoints[endpoint_index] = next_point
	endpoint_wall = _rebuild_wall_from_endpoints(endpoint_wall, endpoints[0], endpoints[1])


func _finish_endpoint_drag() -> void:
	if not endpoint_dragging:
		return
	endpoint_dragging = false
	endpoint_wall = null
	if endpoint_drag_snapshot.is_empty():
		return
	_push_undo_snapshot(endpoint_drag_snapshot)
	endpoint_drag_snapshot.clear()
	_update_wall_handles()
	_update_status("已调整墙段端点")


func _rebuild_wall_from_endpoints(old_wall: Node3D, start: Vector3, finish: Vector3) -> Node3D:
	if old_wall == null or not is_instance_valid(old_wall):
		return null
	var kind := Rules.normalize_wall_kind(str(old_wall.get_meta("wall_kind", "cb_wall")))
	var old_kind := kind
	walls.remove_child(old_wall)
	old_wall.free()
	var rebuilt: Node3D = null
	var spans: Array = []
	if not is_equal_approx(start.x, finish.x) and not is_equal_approx(start.z, finish.z):
		# A perpendicular endpoint drag becomes an L. Try both elbows so an L
		# footprint can choose the path that remains on its outer boundary.
		spans = [[start, Vector3(finish.x, Rules.WALL_Y_OFFSET, start.z)], [Vector3(finish.x, Rules.WALL_Y_OFFSET, start.z), finish]]
		var first_check := _wall_segments_for_drag(spans[0][0], spans[0][1])
		var second_check := _wall_segments_for_drag(spans[1][0], spans[1][1])
		if not bool(first_check.get("ok", false)) or not bool(second_check.get("ok", false)):
			spans = [[start, Vector3(start.x, Rules.WALL_Y_OFFSET, finish.z)], [Vector3(start.x, Rules.WALL_Y_OFFSET, finish.z), finish]]
	else:
		spans = [[start, finish]]
	for span in spans:
		var span_start: Vector3 = span[0]
		var span_end: Vector3 = span[1]
		var data := _wall_segments_for_drag(span_start, span_end)
		if not bool(data.get("ok", false)):
			continue
		var axis: Vector3i = data.get("axis", Vector3i(1, 0, 0))
		for raw_position: Variant in data.get("positions", []):
			var position := raw_position as Vector3
			var segment_start := position - Vector3(axis.x, 0.0, axis.z) * CELL * 0.5
			var segment_end := position + Vector3(axis.x, 0.0, axis.z) * CELL * 0.5
			var segment := _place_wall_segment(old_kind, position, axis, _boundary_cell_for_wall(position, axis), false, segment_start, segment_end)
			if rebuilt == null:
				rebuilt = segment
	_rebuild_wall_graph()
	return rebuilt


func _begin_wall_drag(mouse: Vector2) -> void:
	var point := _mouse_ground_point(mouse)
	if not _point_is_valid(point):
		return
	var snapped := _snap_to_corner_anchor(point)
	if snapped.is_empty():
		_update_status("画墙必须从金色角柱锚点开始")
		return
	wall_drag_start = snapped.get("position", Vector3.ZERO)
	wall_drag_end = wall_drag_start
	wall_dragging = true
	_update_wall_preview(mouse)


func _update_wall_preview(mouse: Vector2) -> Dictionary:
	var point := _mouse_ground_point(mouse)
	if not _point_is_valid(point):
		wall_preview_valid = false
		return {"ok": false, "reason": "invalid_pointer"}
	var corner := _snap_to_corner_anchor(point)
	wall_drag_end = corner.get("position", _snap_to_room_boundary(point).get("point", point)) if not corner.is_empty() else _snap_to_room_boundary(point).get("point", point)
	return _show_wall_preview(wall_drag_start, wall_drag_end, wall_kind)


func _show_wall_preview(start: Vector3, end: Vector3, kind := "cb_wall") -> Dictionary:
	wall_kind = Rules.normalize_wall_kind(kind)
	var data := _wall_segments_for_drag(start, end)
	_clear_ghost()
	var axis: Vector3i = data.get("axis", Vector3i(1, 0, 0))
	for raw_position: Variant in data.get("positions", []):
		var instance: Node3D = _build_wall_visual(wall_kind, raw_position as Vector3, _wall_yaw(axis), _cardboard_color_index())
		if instance == null:
			continue
		_set_ghost_transparency(instance)
		ghost.add_child(instance)
	ghost.visible = ghost.get_child_count() > 0
	wall_preview_valid = bool(data.get("ok", false))
	_set_ghost_invalid(not wall_preview_valid)
	_update_status("画墙预览：%d 段 · %s" % [(data.get("positions", []) as Array).size(), "合法" if wall_preview_valid else _reason_text(str(data.get("reason", "invalid")))])
	return data


func _finish_wall_drag(mouse: Vector2) -> int:
	_update_wall_preview(mouse)
	var count := _draw_wall(wall_drag_start, wall_drag_end, wall_kind, true) if wall_preview_valid else 0
	wall_dragging = false
	_clear_ghost()
	_update_status("已生成 %d 段墙" % count if count > 0 else "画墙被拒绝：墙必须沿房间外轮廓且不能重叠")
	return count


func _draw_wall(start: Vector3, end: Vector3, kind := "cb_wall", record_undo := true) -> int:
	kind = Rules.normalize_wall_kind(kind)
	if not kind in WALL_TOOL_IDS:
		last_rejection_reason = "invalid_wall_kind"
		return 0
	var data := _wall_segments_for_drag(start, end)
	if not bool(data.get("ok", false)):
		last_rejection_reason = str(data.get("reason", "invalid_wall"))
		return 0
	var before := _snapshot_state()
	var axis: Vector3i = data.get("axis", Vector3i(1, 0, 0))
	var created := 0
	for raw_position: Variant in data.get("positions", []):
		var position := raw_position as Vector3
		var cell := _boundary_cell_for_wall(position, axis)
		var segment_start := position - Vector3(axis.x, 0.0, axis.z) * CELL * 0.5
		var segment_end := position + Vector3(axis.x, 0.0, axis.z) * CELL * 0.5
		if _place_wall_segment(kind, position, axis, cell, false, segment_start, segment_end) != null:
			created += 1
	if created > 0:
		_rebuild_wall_graph()
		if record_undo:
			_push_undo_snapshot(before)
	return created


func _wall_segments_for_drag(start: Vector3, end: Vector3) -> Dictionary:
	var axis := Rules.wall_axis_from_drag(start, end)
	var constrained_end := end
	if axis.x != 0:
		constrained_end.z = start.z
	else:
		constrained_end.x = start.x
	var positions := Rules.wall_cells_from_drag(start, constrained_end, axis)
	if positions.is_empty():
		return {"ok": false, "reason": "empty_wall", "axis": axis, "positions": positions}
	for position in positions:
		var validity := _wall_position_valid(position, axis)
		if not bool(validity.get("ok", false)):
			return {"ok": false, "reason": validity.get("reason", "invalid_wall"), "axis": axis, "positions": positions}
	return {"ok": true, "reason": "", "axis": axis, "positions": positions}


func _wall_position_valid(position: Vector3, axis: Vector3i, ignore_node: Node3D = null) -> Dictionary:
	if _boundary_cell_for_wall(position, axis) == INVALID_CELL:
		return {"ok": false, "reason": "wall_not_boundary"}
	for child in walls.get_children():
		var wall := child as Node3D
		if wall == null or wall == ignore_node:
			continue
		if wall.position.distance_to(position) < 0.03:
			return {"ok": false, "reason": "wall_overlap"}
	return {"ok": true, "reason": ""}


func _place_wall_segment(kind: String, position: Vector3, axis: Vector3i, cell: Vector2i, validate := true, span_start := INVALID_POINT, span_end := INVALID_POINT) -> Node3D:
	last_rejection_reason = ""
	kind = Rules.normalize_wall_kind(kind)
	if not kind in WALL_TOOL_IDS:
		last_rejection_reason = "missing_asset"
		return null
	if validate:
		var validity := _wall_position_valid(position, axis)
		if not bool(validity.get("ok", false)):
			last_rejection_reason = str(validity.get("reason", "invalid_wall"))
			return null
	var instance: Node3D = _build_wall_visual(kind, Vector3(position.x, Rules.WALL_Y_OFFSET, position.z), _wall_yaw(axis), _cardboard_color_index())
	if instance == null:
		last_rejection_reason = "missing_asset"
		return null
	place_counter += 1
	instance.name = "wall_%04d" % place_counter
	instance.set_meta("is_wall", true)
	instance.set_meta("wall_kind", kind)
	instance.set_meta("wall_axis", axis)
	instance.set_meta("wall_cell", cell)
	var start := span_start if _point_is_valid(span_start) else position - Vector3(axis.x, 0.0, axis.z) * CELL * 0.5
	var finish := span_end if _point_is_valid(span_end) else position + Vector3(axis.x, 0.0, axis.z) * CELL * 0.5
	instance.set_meta("wall_start", start)
	instance.set_meta("wall_end", finish)
	instance.set_meta("wall_height", Rules.WALL_HEIGHT)
	walls.add_child(instance)
	_set_asset_shadows(instance, true)
	return instance


func _wall_yaw(axis: Vector3i) -> float:
	# CardboardShellBuilder's panel long axis is local X. Keep X-edge walls
	# along X, and rotate only Z-edge walls by 90 degrees.
	return 0.0 if axis.x != 0 else PI * 0.5


func _cardboard_color_index() -> int:
	return posmod(room_shape_id.hash() + room_rotation_quarters, CardboardShellBuilder.PAPER_PALETTE.size())


func _build_wall_visual(kind: String, position: Vector3, yaw: float, color_index: int) -> Node3D:
	var normalized_kind := Rules.normalize_wall_kind(kind)
	if normalized_kind == "cb_doorway":
		return CardboardShellBuilder.build_doorway(position, yaw, color_index)
	if normalized_kind == "cb_junction":
		return CardboardShellBuilder.build_junction(position, Rules.WALL_HEIGHT, color_index, [])
	return CardboardShellBuilder.build_wall(normalized_kind, position, yaw, color_index)


func _snap_to_room_boundary(point: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for edge in Rules.room_boundary_edges(room_cells):
		var start: Vector3 = edge.get("start", Vector3.ZERO)
		var finish: Vector3 = edge.get("end", Vector3.ZERO)
		var segment := finish - start
		var amount := clampf((point - start).dot(segment) / maxf(segment.length_squared(), 0.000001), 0.0, 1.0)
		var closest := start + segment * amount
		var distance := Vector2(point.x - closest.x, point.z - closest.z).length()
		if distance < best_distance:
			best_distance = distance
			best = {"point": closest, "axis": edge.get("axis", Vector3i.ZERO), "cell": edge.get("cell", Vector2i.ZERO)}
	return best


func _boundary_cell_for_wall(position: Vector3, axis: Vector3i) -> Vector2i:
	for edge in Rules.room_boundary_edges(room_cells):
		var edge_axis: Vector3i = edge.get("axis", Vector3i.ZERO)
		if edge_axis != axis:
			continue
		var start: Vector3 = edge.get("start", Vector3.ZERO)
		var finish: Vector3 = edge.get("end", Vector3.ZERO)
		if axis.x != 0:
			if absf(position.z - start.z) <= 0.02 and position.x >= minf(start.x, finish.x) - 0.001 and position.x <= maxf(start.x, finish.x) + 0.001:
				return edge.get("cell", INVALID_CELL)
		else:
			if absf(position.x - start.x) <= 0.02 and position.z >= minf(start.z, finish.z) - 0.001 and position.z <= maxf(start.z, finish.z) + 0.001:
				return edge.get("cell", INVALID_CELL)
	return INVALID_CELL


func _rebuild_corners() -> int:
	for child in corners.get_children():
		child.free()
	var endpoint_axes := {}
	var endpoint_positions := {}
	for child in walls.get_children():
		var wall := child as Node3D
		if wall == null:
			continue
		var axis: Vector3i = wall.get_meta("wall_axis", Vector3i.ZERO)
		var axis_vec := Vector3(axis.x, 0.0, axis.z)
		for endpoint in [wall.position - axis_vec * CELL * 0.5, wall.position + axis_vec * CELL * 0.5]:
			var key := _point_key(endpoint)
			if not endpoint_axes.has(key):
				endpoint_axes[key] = {"x": false, "z": false}
				endpoint_positions[key] = endpoint
			var flags := endpoint_axes[key] as Dictionary
			flags["x" if axis.x != 0 else "z"] = true
	var created := 0
	for key: String in endpoint_axes:
		var flags := endpoint_axes[key] as Dictionary
		if not bool(flags.get("x", false)) or not bool(flags.get("z", false)):
			continue
		var instance: Node3D = CardboardShellBuilder.build_junction(endpoint_positions[key], Rules.WALL_HEIGHT, _cardboard_color_index(), [])
		if instance == null:
			continue
		instance.name = "corner_%02d" % (created + 1)
		instance.set_meta("junction_axes", flags)
		corners.add_child(instance)
		_set_asset_shadows(instance, true)
		created += 1
	return created


func _point_key(point: Vector3) -> String:
	return "%d:%d" % [roundi(point.x * 1000.0), roundi(point.z * 1000.0)]


func _clear_all(record_undo := true) -> void:
	if record_undo and (placements.get_child_count() > 0 or walls.get_child_count() > 0 or fixtures.get_child_count() > 0):
		_push_undo_snapshot()
	_deselect()
	wall_dragging = false
	_clear_ghost()
	_clear_edit_nodes()
	_update_status("已清空当前房间")


func _clear_edit_nodes() -> void:
	for container in [placements, walls, corners, wall_joins, fixtures]:
		for child in container.get_children():
			child.free()
	place_counter = 0
	wall_graph = {}


func _snapshot_placements() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for child in placements.get_children():
		var placed := child as Node3D
		if placed == null:
			continue
		snapshot.append({
			"asset_id": str(placed.get_meta("asset_id", "")),
			"position": [placed.position.x, placed.position.y, placed.position.z],
			"yaw": placed.rotation.y,
			"scale": [placed.scale.x, placed.scale.y, placed.scale.z],
		})
	return snapshot


func _snapshot_walls() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for child in walls.get_children():
		var wall := child as Node3D
		if wall == null:
			continue
		var axis: Vector3i = wall.get_meta("wall_axis", Vector3i.ZERO)
		var cell: Vector2i = wall.get_meta("wall_cell", Vector2i.ZERO)
		snapshot.append({
			"wall_kind": Rules.normalize_wall_kind(str(wall.get_meta("wall_kind", "cb_wall"))),
			"position": [wall.position.x, wall.position.y, wall.position.z],
			"yaw": wall.rotation.y,
			"wall_axis": [axis.x, axis.y, axis.z],
			"wall_cell": [cell.x, cell.y],
			"run_id": str(wall.get_meta("wall_run_id", "")),
			"wall_start": _vec3_array(wall.get_meta("wall_start", wall.position - Vector3(axis.x, 0.0, axis.z) * CELL * 0.5)),
			"wall_end": _vec3_array(wall.get_meta("wall_end", wall.position + Vector3(axis.x, 0.0, axis.z) * CELL * 0.5)),
			"is_door": bool(wall.get_meta("is_door", false)),
			"door_restore_kind": str(wall.get_meta("door_restore_kind", "")),
			"door_restore_start": _vec3_array(wall.get_meta("door_restore_start", Vector3.ZERO)),
			"door_restore_end": _vec3_array(wall.get_meta("door_restore_end", Vector3.ZERO)),
		})
	return snapshot


func _rebuild_wall_graph() -> void:
	for child in wall_joins.get_children():
		child.free()
	wall_graph = RoomShellGraph.compile(room_cells, _snapshot_walls())
	var graph_walls: Array = wall_graph.get("walls", [])
	for index in min(walls.get_child_count(), graph_walls.size()):
		var wall := walls.get_child(index) as Node3D
		var record := graph_walls[index] as Dictionary
		if wall == null or record == null:
			continue
		wall.set_meta("wall_run_id", str(record.get("run_id", "")))
		wall.set_meta("wall_line", int(record.get("line", 0)))
	for raw_join: Variant in wall_graph.get("joins", []):
		var join := raw_join as Dictionary
		var join_node := CardboardShellBuilder.build_join(join.get("position", Vector3.ZERO), join.get("axis", Vector3i.ZERO), _cardboard_color_index())
		join_node.set_meta("wall_run_id", str(join.get("run_id", "")))
		wall_joins.add_child(join_node)
	_rebuild_corners()


func _snapshot_fixtures() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for child in fixtures.get_children():
		var fixture := child as Node3D
		if fixture == null:
			continue
		snapshot.append({
			"kind": str(fixture.get_meta("fixture_kind", "cue_card")),
			"position": [fixture.position.x, fixture.position.y, fixture.position.z],
			"yaw": fixture.rotation.y,
		})
	return snapshot


func _snapshot_state() -> Dictionary:
	return {
		"room_shape": room_shape_id,
		"room_rotation_quarters": room_rotation_quarters,
		"formal_room_id": formal_room_id,
		"assets": _snapshot_placements(),
		"walls": _snapshot_walls(),
		"fixtures": _snapshot_fixtures(),
	}


func _rebuild_from_state(state: Dictionary) -> int:
	room_shape_id = str(state.get("room_shape", room_shape_id))
	room_rotation_quarters = posmod(int(state.get("room_rotation_quarters", room_rotation_quarters)), 4)
	formal_room_id = str(state.get("formal_room_id", formal_room_id))
	if not RoomFootprintCatalog.ROOM_CONFIG.has(formal_room_id):
		formal_room_id = ""
	room_cells = Rules.rotated_cells(room_shape_id, room_rotation_quarters)
	_sync_formal_room_ui()
	suppress_room_ui = true
	_sync_room_shape_ui()
	suppress_room_ui = false
	_rebuild_room(false)
	_clear_edit_nodes()
	var loaded := _rebuild_assets_from_snapshot(state.get("assets", []))
	loaded += _rebuild_walls_from_snapshot(state.get("walls", []))
	loaded += _rebuild_fixtures_from_snapshot(state.get("fixtures", []))
	_rebuild_wall_graph()
	return loaded


func _rebuild_assets_from_snapshot(snapshot: Array) -> int:
	var loaded := 0
	for raw_description: Variant in snapshot:
		if not raw_description is Dictionary:
			continue
		var description := raw_description as Dictionary
		var entry_data := Rules.apply_template_entry(description, catalog)
		if entry_data.is_empty():
			push_warning("Asset editor skipped unknown template asset: %s" % description.get("asset_id", description.get("id", "")))
			continue
		var placed := _place_at_free(entry_data.get("position", Vector3.ZERO), str(entry_data.get("asset_id", "")), float(entry_data.get("yaw", 0.0)), entry_data.get("scale", Vector3.ONE), false)
		if placed != null:
			loaded += 1
	return loaded


func _rebuild_walls_from_snapshot(snapshot: Array) -> int:
	var loaded := 0
	for raw_description: Variant in snapshot:
		if not raw_description is Dictionary:
			continue
		var description := raw_description as Dictionary
		var position := _array_vec3(description.get("position", []))
		var axis := _array_vec3i(description.get("wall_axis", description.get("axis", [])))
		var cell := _array_vec2i(description.get("wall_cell", description.get("cell", [])))
		var kind := Rules.normalize_wall_kind(str(description.get("wall_kind", description.get("kind", "cb_wall"))))
		var start := _array_vec3(description.get("wall_start", [])) if description.has("wall_start") else INVALID_POINT
		var finish := _array_vec3(description.get("wall_end", [])) if description.has("wall_end") else INVALID_POINT
		var wall := _place_wall_segment(kind, position, axis, cell, false, start, finish)
		if wall != null:
			if bool(description.get("is_door", false)) or kind == "cb_doorway":
				var fallback_start: Vector3 = start if _point_is_valid(start) else position - Vector3(axis.x, 0.0, axis.z) * CELL * 0.5
				var fallback_end: Vector3 = finish if _point_is_valid(finish) else position + Vector3(axis.x, 0.0, axis.z) * CELL * 0.5
				wall.set_meta("is_door", true)
				wall.set_meta("door_restore_kind", str(description.get("door_restore_kind", "cb_wall")))
				wall.set_meta("door_restore_start", _array_vec3(description.get("door_restore_start", _vec3_array(fallback_start))))
				wall.set_meta("door_restore_end", _array_vec3(description.get("door_restore_end", _vec3_array(fallback_end))))
			loaded += 1
	return loaded


func _rebuild_fixtures_from_snapshot(snapshot: Array) -> int:
	var loaded := 0
	for raw_description: Variant in snapshot:
		if not raw_description is Dictionary:
			continue
		var description := raw_description as Dictionary
		var kind := str(description.get("kind", description.get("fixture_kind", "")))
		var position := _array_vec3(description.get("position", []))
		if kind.is_empty():
			continue
		var fixture := CardboardShellBuilder.build_fixture(kind, position, float(description.get("yaw", 0.0)), _cardboard_color_index())
		fixture.set_meta("fixture_kind", kind)
		fixtures.add_child(fixture)
		loaded += 1
	return loaded


func _push_undo_snapshot(snapshot_override: Dictionary = {}) -> void:
	var snapshot := snapshot_override.duplicate(true) if not snapshot_override.is_empty() else _snapshot_state()
	undo_stack.append(snapshot)
	if undo_stack.size() > UNDO_LIMIT:
		undo_stack.pop_front()
	redo_stack.clear()


func _undo() -> bool:
	if undo_stack.is_empty():
		_update_status("没有可撤销的操作")
		return false
	redo_stack.append(_snapshot_state())
	var state: Dictionary = undo_stack.pop_back()
	_rebuild_from_state(state)
	_deselect()
	_update_status("已撤销")
	return true


func _redo() -> bool:
	if redo_stack.is_empty():
		_update_status("没有可重做的操作")
		return false
	undo_stack.append(_snapshot_state())
	var state: Dictionary = redo_stack.pop_back()
	_rebuild_from_state(state)
	_deselect()
	_update_status("已重做")
	return true


func _on_room_shape_selected(index: int) -> void:
	if suppress_room_ui:
		return
	_change_room(str(room_shape.get_item_metadata(index)), 0, true)
	formal_room_id = ""
	_sync_formal_room_ui()


func _on_formal_room_selected(index: int) -> void:
	if suppress_formal_room_ui:
		return
	var selected_id := str(formal_room.get_item_metadata(index))
	_load_formal_room_layout(selected_id, true)


func _load_formal_room_layout(room_id: String, record_undo := true) -> int:
	if not RoomFootprintCatalog.ROOM_CONFIG.has(room_id):
		_update_status("正式房间不存在：%s" % room_id)
		return -1
	var before := _snapshot_state()
	var state := _formal_override_state(room_id)
	var source := "正式 override"
	if state.is_empty():
		state = _generated_formal_room_state(room_id)
		source = "Unpacking 式房间初稿"
	var loaded := _rebuild_from_state(state)
	if record_undo:
		_push_undo_snapshot(before)
	override_room_id.text = room_id
	template_name.text = "override_%s" % room_id
	_sync_formal_room_ui()
	_update_status("已载入 %s：%s · %d格 · %d件家具 · %d段墙（可直接修改）" % [source, room_id, room_cells.size(), placements.get_child_count(), walls.get_child_count()])
	return loaded


func _formal_override_state(room_id: String) -> Dictionary:
	var path := FORMAL_OVERRIDE_DIR + room_id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("Asset editor ignored invalid formal override: %s" % path)
		return {}
	var data := parsed as Dictionary
	if int(data.get("schema_version", 0)) < 3 or str(data.get("room_id", room_id)) != room_id:
		push_warning("Asset editor ignored incompatible formal override: %s" % path)
		return {}
	return {
		"room_shape": str(data.get("room_shape", (RoomFootprintCatalog.ROOM_CONFIG[room_id] as Dictionary).get("shape", "single"))),
		"room_rotation_quarters": int(data.get("room_rotation_quarters", 0)),
		"formal_room_id": room_id,
		"assets": (data.get("assets", []) as Array).duplicate(true),
		"walls": (data.get("walls", []) as Array).duplicate(true),
		"fixtures": (data.get("fixtures", []) as Array).duplicate(true),
	}


func _generated_formal_room_state(room_id: String) -> Dictionary:
	var config: Dictionary = RoomFootprintCatalog.ROOM_CONFIG.get(room_id, {})
	var shape_id := str(config.get("shape", "single"))
	var cells := Rules.rotated_cells(shape_id, 0)
	var walls_snapshot := _formal_perimeter_walls(cells)
	var room := {
		"id": room_id,
		"room_type": room_id,
		"size": cells.size(),
		"room_size": cells.size(),
	}
	var request := RoomPropCatalog.unpacking_template_request(room, 0, FORMAL_BASE_LAYOUT_SEED)
	var candidates := _formal_prop_candidates(cells, walls_snapshot)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(request.get("seed", FORMAL_BASE_LAYOUT_SEED))
	var placed_records: Array[Dictionary] = []
	var assets_snapshot: Array[Dictionary] = []
	for raw_item: Variant in request.get("items", []):
		var item := raw_item as Dictionary
		var placement := _take_formal_prop_placement(str(request.get("theme", "living")), str(item.get("slot", RoomPropCatalog.SLOT_ACCENT)), str(item.get("asset_id", "")), candidates, placed_records, rng)
		if placement.is_empty():
			continue
		var entry := placement.get("entry", {}) as Dictionary
		var candidate := placement.get("candidate", {}) as Dictionary
		var editor_id := _catalog_id_for_path(str(entry.get("path", "")))
		var catalog_entry := _find_asset_entry(editor_id)
		if editor_id.is_empty() or catalog_entry.is_empty():
			continue
		var position: Vector3 = candidate.get("position", Vector3.ZERO)
		var surface_placement := _formal_surface_prop_position(entry, placed_records, rng)
		if not surface_placement.is_empty():
			position = surface_placement.get("position", position)
		elif RoomPropCatalog.is_surface_prop(str(entry.get("id", ""))):
			# A lamp/book/pillow without a suitable support is worse than leaving it
			# in the box for the designer to add later.
			continue
		elif bool(entry.get("overlay", false)):
			position.y = 0.005
		var yaw := float(candidate.get("yaw", 0.0))
		if str(candidate.get("slot", "")) in [RoomPropCatalog.SLOT_MAIN, RoomPropCatalog.SLOT_ACCENT]:
			yaw += float(rng.randi_range(0, 3)) * PI * 0.5
		var actual_scale := _base_scale(catalog_entry)
		assets_snapshot.append({
			"asset_id": editor_id,
			"position": [position.x, position.y, position.z],
			"yaw": yaw,
			"scale": [actual_scale.x, actual_scale.y, actual_scale.z],
		})
		placed_records.append({
			"asset_id": str(entry.get("id", "")),
			"position": position,
			"footprint": entry.get("footprint", Vector2(0.3, 0.3)),
			"overlay": bool(entry.get("overlay", false)),
			"surface_height": RoomPropCatalog.surface_height_for(str(entry.get("id", ""))),
			"surface_load": 0,
		})
	return {
		"room_shape": shape_id,
		"room_rotation_quarters": 0,
		"formal_room_id": room_id,
		"assets": assets_snapshot,
		"walls": walls_snapshot,
		"fixtures": [],
	}


func _formal_perimeter_walls(cells: Array[Vector2i]) -> Array[Dictionary]:
	var boundary_edges := Rules.room_boundary_edges(cells)
	var doorway_index := _formal_doorway_edge_index(boundary_edges)
	var result: Array[Dictionary] = []
	for index in range(boundary_edges.size()):
		var edge := boundary_edges[index] as Dictionary
		var start: Vector3 = edge.get("start", Vector3.ZERO)
		var finish: Vector3 = edge.get("end", Vector3.ZERO)
		var axis: Vector3i = edge.get("axis", Vector3i.ZERO)
		var cell: Vector2i = edge.get("cell", Vector2i.ZERO)
		var position := (start + finish) * 0.5
		var is_door := index == doorway_index
		result.append({
			"wall_kind": "cb_doorway" if is_door else "cb_wall",
			"position": [position.x, Rules.WALL_Y_OFFSET, position.z],
			"yaw": _wall_yaw(axis),
			"wall_axis": [axis.x, axis.y, axis.z],
			"wall_cell": [cell.x, cell.y],
			"wall_start": [start.x, start.y, start.z],
			"wall_end": [finish.x, finish.y, finish.z],
			"is_door": is_door,
			"door_restore_kind": "cb_wall" if is_door else "",
			"door_restore_start": [start.x, start.y, start.z] if is_door else [0.0, 0.0, 0.0],
			"door_restore_end": [finish.x, finish.y, finish.z] if is_door else [0.0, 0.0, 0.0],
		})
	return result


func _formal_doorway_edge_index(edges: Array[Dictionary]) -> int:
	var best_index := 0
	var best_score := -INF
	for index in range(edges.size()):
		var edge := edges[index] as Dictionary
		var start: Vector3 = edge.get("start", Vector3.ZERO)
		var finish: Vector3 = edge.get("end", Vector3.ZERO)
		var midpoint := (start + finish) * 0.5
		var axis: Vector3i = edge.get("axis", Vector3i.ZERO)
		# Prefer the camera-facing +X side, then the widest +Z edge. This leaves the
		# generated baseline readable before the user starts moving walls.
		var score := midpoint.x * 100.0 + midpoint.z + (10.0 if axis.z != 0 else 0.0)
		if score > best_score:
			best_score = score
			best_index = index
	return best_index


func _formal_prop_candidates(cells: Array[Vector2i], walls_snapshot: Array[Dictionary]) -> Dictionary:
	var result := {
		RoomPropCatalog.SLOT_MAIN: [],
		RoomPropCatalog.SLOT_WALL: [],
		RoomPropCatalog.SLOT_CORNER: [],
		RoomPropCatalog.SLOT_ACCENT: [],
	}
	var lookup := {}
	for cell in cells:
		lookup[cell] = true
	var doorway_positions: Array[Vector3] = []
	for wall: Dictionary in walls_snapshot:
		if bool(wall.get("is_door", false)):
			doorway_positions.append(_array_vec3(wall.get("position", [])))
	for cell in cells:
		var base := Vector3((float(cell.x) + 0.5) * CELL, 0.0, (float(cell.y) + 0.5) * CELL)
		(result[RoomPropCatalog.SLOT_MAIN] as Array).append({"slot": RoomPropCatalog.SLOT_MAIN, "cell": cell, "position": base, "yaw": 0.0})
		for offset in [Vector2(-0.25, -0.20), Vector2(0.25, 0.20)]:
			(result[RoomPropCatalog.SLOT_ACCENT] as Array).append({"slot": RoomPropCatalog.SLOT_ACCENT, "cell": cell, "position": base + Vector3(offset.x * CELL, 0.0, offset.y * CELL), "yaw": 0.0})
		var wall_sides: Array[int] = []
		for side in range(FORMAL_DIRS.size()):
			var direction: Vector2i = FORMAL_DIRS[side]
			if lookup.has(cell + direction):
				continue
			wall_sides.append(side)
			var position := base + Vector3(float(direction.x) * CELL * 0.31, 0.0, float(direction.y) * CELL * 0.31)
			var by_door := false
			for doorway_position in doorway_positions:
				if Vector2(position.x - doorway_position.x, position.z - doorway_position.z).length() < CELL * 0.35:
					by_door = true
					break
			if not by_door:
				(result[RoomPropCatalog.SLOT_WALL] as Array).append({"slot": RoomPropCatalog.SLOT_WALL, "cell": cell, "position": position, "yaw": _formal_direction_yaw(-direction)})
		for side in wall_sides:
			var next_side := (side + 1) % FORMAL_DIRS.size()
			if next_side not in wall_sides:
				continue
			var direction_a: Vector2i = FORMAL_DIRS[side]
			var direction_b: Vector2i = FORMAL_DIRS[next_side]
			(result[RoomPropCatalog.SLOT_CORNER] as Array).append({
				"slot": RoomPropCatalog.SLOT_CORNER,
				"cell": cell,
				"position": base + Vector3(float(direction_a.x + direction_b.x) * CELL * 0.27, 0.0, float(direction_a.y + direction_b.y) * CELL * 0.27),
				"yaw": _formal_direction_yaw(-direction_a),
			})
	return result


func _take_formal_prop_placement(theme: String, requested_slot: String, preferred_id: String, candidates: Dictionary, placed: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	var slot_order: Array[String] = [requested_slot]
	for fallback_slot in [RoomPropCatalog.SLOT_ACCENT, RoomPropCatalog.SLOT_CORNER, RoomPropCatalog.SLOT_WALL, RoomPropCatalog.SLOT_MAIN]:
		if fallback_slot not in slot_order:
			slot_order.append(fallback_slot)
	for slot in slot_order:
		var entries := RoomPropCatalog.entries_for(theme, slot)
		_formal_shuffle(entries, rng)
		if slot == requested_slot and not preferred_id.is_empty():
			for preferred_index in range(entries.size()):
				if str(entries[preferred_index].get("id", "")) == preferred_id:
					var preferred: Dictionary = entries.pop_at(preferred_index)
					entries.push_front(preferred)
					break
		var slot_candidates: Array = (candidates.get(slot, []) as Array).duplicate()
		_formal_shuffle(slot_candidates, rng)
		for entry: Dictionary in entries:
			if not bool(entry.get("repeatable", false)):
				var already_used := false
				for previous: Dictionary in placed:
					if str(previous.get("asset_id", "")) == str(entry.get("id", "")):
						already_used = true
						break
				if already_used:
					continue
			for candidate: Dictionary in slot_candidates:
				if _formal_prop_candidate_clear(candidate, entry, placed):
					# Loose props are moved onto their semantic support after this
					# selection; they must not consume a floor placement slot.
					if not bool(entry.get("overlay", false)):
						(candidates[slot] as Array).erase(candidate)
					return {"entry": entry, "candidate": candidate}
	return {}


func _formal_prop_candidate_clear(candidate: Dictionary, entry: Dictionary, placed: Array[Dictionary]) -> bool:
	if bool(entry.get("overlay", false)):
		return true
	var position: Vector3 = candidate.get("position", Vector3.ZERO)
	var footprint: Vector2 = entry.get("footprint", Vector2(0.3, 0.3))
	var radius := maxf(footprint.x, footprint.y) * 0.5
	for previous: Dictionary in placed:
		if bool(previous.get("overlay", false)):
			continue
		var previous_position: Vector3 = previous.get("position", Vector3.ZERO)
		var previous_footprint: Vector2 = previous.get("footprint", Vector2(0.3, 0.3))
		var previous_radius := maxf(previous_footprint.x, previous_footprint.y) * 0.5
		if Vector2(position.x - previous_position.x, position.z - previous_position.z).length() < (radius + previous_radius) * 0.55:
			return false
	return true


func _formal_surface_prop_position(entry: Dictionary, placed: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	var asset_id := str(entry.get("id", ""))
	if not RoomPropCatalog.is_surface_prop(asset_id):
		return {}
	var targets := RoomPropCatalog.surface_targets_for(asset_id)
	var supports: Array[Dictionary] = []
	for previous: Dictionary in placed:
		if str(previous.get("asset_id", "")) in targets and float(previous.get("surface_height", 0.0)) > 0.0:
			supports.append(previous)
	if supports.is_empty():
		return {}
	var support := supports[rng.randi_range(0, supports.size() - 1)]
	var load_index := int(support.get("surface_load", 0))
	support["surface_load"] = load_index + 1
	var base: Vector3 = support.get("position", Vector3.ZERO)
	var side := -1.0 if load_index % 2 == 0 else 1.0
	var lane := float(load_index / 2) * 0.08
	var offset := Vector3(side * (0.07 + lane), 0.0, (float(posmod(load_index, 3)) - 1.0) * 0.055)
	return {
		"position": base + offset + Vector3.UP * (float(support.get("surface_height", 0.0)) + 0.008),
		"support_asset_id": str(support.get("asset_id", "")),
	}


func _formal_shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary


func _catalog_id_for_path(path: String) -> String:
	for raw_entry: Variant in catalog.get("assets", []):
		var entry := raw_entry as Dictionary
		if str(entry.get("path", "")) == path:
			return str(entry.get("id", ""))
	return ""


func _formal_direction_yaw(direction: Vector2i) -> float:
	if direction == Vector2i.RIGHT:
		return -PI * 0.5
	if direction == Vector2i.LEFT:
		return PI * 0.5
	if direction == Vector2i.DOWN:
		return PI
	return 0.0


func _rotate_room() -> void:
	_change_room(room_shape_id, room_rotation_quarters + 1, true)


func _change_room(shape_id: String, rotation_quarters: int, record_undo := true) -> void:
	if record_undo:
		_push_undo_snapshot()
	_clear_edit_nodes()
	_deselect()
	selected_asset = ""
	wall_mode = false
	wall_kind = ""
	wall_dragging = false
	_clear_ghost()
	room_shape_id = shape_id if RoomFootprintCatalog.SHAPES.has(shape_id) else "single"
	room_rotation_quarters = posmod(rotation_quarters, 4)
	room_cells = Rules.rotated_cells(room_shape_id, room_rotation_quarters)
	suppress_room_ui = true
	_sync_room_shape_ui()
	suppress_room_ui = false
	_rebuild_room(false)
	_rebuild_corner_anchors()
	_update_status("已切换房间：%s" % ROOM_SHAPE_NAMES.get(room_shape_id, room_shape_id))


func _rebuild_room(snap_camera := false) -> void:
	for child in room_base.get_children():
		child.free()
	if room_cells.is_empty():
		room_cells = Rules.rotated_cells("single", 0)
	var bounds := Rules.room_bounds_world(room_cells)
	var center := Rules.room_center_world(room_cells)
	var shadow_material := StandardMaterial3D.new()
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow_material.albedo_color = Color("#00000050")
	var shadow_mesh := QuadMesh.new()
	shadow_mesh.size = Vector2(bounds.size.x + 0.3, bounds.size.z + 0.3)
	shadow_mesh.material = shadow_material
	var shadow := MeshInstance3D.new()
	shadow.name = "ShadowQuad"
	shadow.mesh = shadow_mesh
	shadow.position = Vector3(center.x, -0.005, center.z)
	shadow.rotation_degrees.x = -90.0
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room_base.add_child(shadow)

	var paper_material := StandardMaterial3D.new()
	paper_material.albedo_color = Color("#f4ede0")
	paper_material.roughness = 0.92
	var outline_material := StandardMaterial3D.new()
	outline_material.albedo_color = GOLD
	outline_material.emission_enabled = true
	outline_material.emission = GOLD
	outline_material.emission_energy_multiplier = 1.35
	var cell_lookup := {}
	for cell in room_cells:
		cell_lookup[cell] = true
		var box := CSGBox3D.new()
		box.name = "Cell_%d_%d" % [cell.x, cell.y]
		box.size = Vector3(CELL, 0.32, CELL)
		box.position = Vector3((float(cell.x) + 0.5) * CELL, -0.16, (float(cell.y) + 0.5) * CELL)
		box.material = paper_material
		box.use_collision = false
		box.set_meta("room_cell", cell)
		room_base.add_child(box)
	var outline_index := 0
	for edge in Rules.room_boundary_edges(room_cells):
		outline_index += 1
		var start: Vector3 = edge.get("start", Vector3.ZERO)
		var finish: Vector3 = edge.get("end", Vector3.ZERO)
		var axis: Vector3i = edge.get("axis", Vector3i.ZERO)
		var outline := CSGBox3D.new()
		outline.name = "Outline_%02d" % outline_index
		outline.size = Vector3(CELL, 0.34, 0.04) if axis.x != 0 else Vector3(0.04, 0.34, CELL)
		outline.position = (start + finish) * 0.5
		outline.position.y = -0.15
		outline.material = outline_material
		outline.use_collision = false
		room_base.add_child(outline)
	var label := Label3D.new()
	label.name = "RoomLabel"
	label.text = ("%s · %s" % [formal_room_id, ROOM_SHAPE_NAMES.get(room_shape_id, room_shape_id)]) if not formal_room_id.is_empty() else str(ROOM_SHAPE_NAMES.get(room_shape_id, room_shape_id))
	label.position = Vector3(center.x, 0.12, center.z)
	label.font_size = 36
	label.pixel_size = 0.004
	label.modulate = Color("#6b4b2a")
	label.outline_modulate = Color("#f4ede0")
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	room_base.add_child(label)
	orbit_center = center
	if snap_camera:
		orbit_center_current = orbit_center
	_position_reference_actor()
	_rebuild_corner_anchors()


func _room_cell_box_count() -> int:
	var count := 0
	for child in room_base.get_children():
		if child.has_meta("room_cell"):
			count += 1
	return count


func _prepare_ground() -> void:
	var material := ground_mesh.get_active_material(0) as StandardMaterial3D
	if material != null:
		material = material.duplicate() as StandardMaterial3D
		material.albedo_color = GROUND_COLOR
		ground_mesh.material_override = material


func _build_reference_actor() -> void:
	for child in reference_actor.get_children():
		child.free()
	var actor_data: Dictionary = {}
	var file := FileAccess.open(PRESENTATION_MANIFEST_PATH, FileAccess.READ)
	if file != null:
		var parser := JSON.new()
		if parser.parse(file.get_as_text()) == OK and parser.data is Dictionary:
			actor_data = (((parser.data as Dictionary).get("actors", {}) as Dictionary).get("player", {}) as Dictionary)
		file.close()
	var model_path := str(actor_data.get("model_path", ""))
	var packed := load(model_path) as PackedScene if not model_path.is_empty() else null
	if packed != null:
		var model := packed.instantiate() as Node3D
		model.name = "LiliModel"
		model.position.y = float(actor_data.get("model_y", 0.0))
		model.rotation.y = float(actor_data.get("model_yaw", 0.0))
		reference_actor.add_child(model)
		# Scale the reference actor to a fixed toy-doll height (REFERENCE_ACTOR_HEIGHT)
		# so it reads as a miniature figure inside the paper-board diorama, rather
		# than a full-size person that towers over the 1.55m cell (the game-facing
		# model_scale=1.68 is inappropriate for the set-piece aesthetic).
		#
		# IMPORTANT: the model must be inside the tree before we measure its AABB —
		# an FBX not yet added reads only its local mesh bounds (0.37m), but once
		# parented the engine applies the import transform to a ~1.0m world height.
		# Measuring before parenting produced a wrong scale factor (≈1.5) and a
		# 1.5m-tall actor instead of the intended 0.55m toy doll.
		var source_height := _measure_actor_height(model)
		var target_scale := REFERENCE_ACTOR_HEIGHT / source_height if source_height > 0.0 else 1.0
		model.scale = Vector3.ONE * target_scale
		_set_asset_shadows(model, true)
	else:
		push_warning("Asset editor reference actor missing; using capsule fallback: %s" % model_path)
		var fallback := MeshInstance3D.new()
		fallback.name = "LiliFallback"
		var capsule := CapsuleMesh.new()
		capsule.height = 0.5
		capsule.radius = 0.13
		fallback.mesh = capsule
		fallback.position.y = 0.25
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("#8f979e")
		fallback.material_override = material
		reference_actor.add_child(fallback)
	var label := Label3D.new()
	label.name = "ReferenceLabel"
	label.text = "比例参照 · 莉莉"
	label.position.y = REFERENCE_ACTOR_HEIGHT + 0.18
	label.font_size = 28
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("#f4ede0")
	label.outline_modulate = Color("#2a2e36")
	label.outline_size = 8
	reference_actor.add_child(label)
	reference_actor.visible = actor_visible
	_position_reference_actor()


func _position_reference_actor() -> void:
	if not is_instance_valid(reference_actor) or room_cells.is_empty():
		return
	var bounds := Rules.room_bounds_world(room_cells)
	var center := Rules.room_center_world(room_cells)
	reference_actor.position = Vector3(bounds.position.x + bounds.size.x + 1.2 * CELL, 0.0, bounds.position.z + bounds.size.z - 0.3 * CELL)
	var direction := center - reference_actor.position
	reference_actor.rotation.y = atan2(direction.x, direction.z)


## Measure the actor model's world-space height (at scale 1.0) so the reference
## actor can be rescaled to REFERENCE_ACTOR_HEIGHT regardless of the source FBX.
func _measure_actor_height(model: Node3D) -> float:
	var merged := AABB()
	var found := false
	for mesh_instance in _mesh_instances_in(model):
		if mesh_instance.mesh == null:
			continue
		var box: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		merged = box if not found else merged.merge(box)
		found = true
	return merged.size.y if found else 0.0


func _toggle_actor() -> void:
	actor_visible = not actor_visible
	reference_actor.visible = actor_visible
	toggle_actor_button.text = "参照物：显示" if actor_visible else "参照物：隐藏"


func _focus_active() -> void:
	if selection != null and is_instance_valid(selection):
		orbit_center = selection.global_position
		orbit_center.y = 0.0
	else:
		orbit_center = Rules.room_center_world(room_cells)


func _save_template(name) -> String:
	var clean_name := _clean_template_name(str(name))
	var payload := Rules.make_template_json(room_shape_id, room_rotation_quarters, _snapshot_placements(), _snapshot_walls(), clean_name, _snapshot_fixtures())
	var json_text := JSON.stringify(payload, "\t")
	var absolute_dir := ProjectSettings.globalize_path(TEMPLATE_DIR)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		_update_status("保存失败：无法创建 %s" % absolute_dir)
		return json_text
	var file_path := TEMPLATE_DIR + clean_name + ".json"
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		_update_status("保存失败：无法写入 %s" % file_path)
		return json_text
	file.store_string(json_text)
	file.close()
	template_name.text = clean_name
	_refresh_templates(clean_name)
	_update_status("已保存模板：%s" % file_path)
	return json_text


func _export_override(room_id: String) -> String:
	var requested_id := str(room_id).strip_edges()
	if requested_id.is_empty() or requested_id == "template":
		requested_id = formal_room_id
	var clean_id := _clean_template_name(requested_id).split("@")[0]
	if clean_id.is_empty() or clean_id == "template":
		_update_status("导出失败：请输入正式房间 ID，例如 living")
		return ""
	var payload := Rules.make_template_json(room_shape_id, room_rotation_quarters, _snapshot_placements(), _snapshot_walls(), "override_%s" % clean_id, _snapshot_fixtures())
	payload["schema_version"] = 3
	payload["room_id"] = clean_id
	var json_text := JSON.stringify(payload, "\t")
	var absolute_dir := ProjectSettings.globalize_path(FORMAL_OVERRIDE_DIR)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		_update_status("正式数据导出失败：无法创建 %s" % absolute_dir)
		return json_text
	var file_path := FORMAL_OVERRIDE_DIR + clean_id + ".json"
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		_update_status("正式数据导出失败：无法写入 %s" % file_path)
		return json_text
	file.store_string(json_text)
	file.close()
	override_room_id.text = clean_id
	_update_status("已导出正式房间覆盖：%s" % file_path)
	return json_text


func _load_template(name) -> int:
	var clean_name := _clean_template_name(str(name))
	var file_path := _resolve_template_path(clean_name)
	if file_path.is_empty():
		_update_status("加载失败：找不到模板 %s" % clean_name)
		return -1
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		_update_status("加载失败：无法读取 %s" % file_path)
		return -1
	var parsed := Rules.parse_template_json(file.get_as_text())
	file.close()
	if not bool(parsed.get("ok", false)):
		_update_status("加载失败：%s" % parsed.get("error", "模板无效"))
		return -1
	var data := parsed.get("data", {}) as Dictionary
	var state := {
		"room_shape": str(data.get("room_shape", "single")),
		"room_rotation_quarters": int(data.get("room_rotation_quarters", 0)),
		"formal_room_id": str(data.get("room_id", formal_room_id)),
		"assets": (data.get("assets", []) as Array).duplicate(true),
		"walls": (data.get("walls", []) as Array).duplicate(true),
		"fixtures": (data.get("fixtures", []) as Array).duplicate(true),
	}
	var before := _snapshot_state()
	var loaded := _rebuild_from_state(state)
	_push_undo_snapshot(before)
	template_name.text = clean_name
	_refresh_templates(clean_name)
	_update_status("已加载%s模板：%s（%d 件）" % ["内置" if file_path.begins_with(PRESET_TEMPLATE_DIR) else "用户", clean_name, loaded])
	return loaded


func _resolve_template_path(clean_name: String) -> String:
	var user_path := TEMPLATE_DIR + clean_name + ".json"
	if FileAccess.file_exists(user_path):
		return user_path
	var preset_path := PRESET_TEMPLATE_DIR + clean_name + ".json"
	if FileAccess.file_exists(preset_path):
		return preset_path
	return ""


func _refresh_templates(preferred := "") -> int:
	template_list.clear()
	template_items.clear()
	_collect_templates(PRESET_TEMPLATE_DIR, true)
	_collect_templates(TEMPLATE_DIR, false)
	template_items.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("name", "")) < str(b.get("name", "")))
	for item in template_items:
		var display := _template_display_name(str(item.get("name", "")), bool(item.get("preset", false)))
		template_list.add_item(display)
		template_list.set_item_metadata(template_list.item_count - 1, item)
	var desired := str(preferred).strip_edges()
	for index in template_list.item_count:
		var metadata := template_list.get_item_metadata(index) as Dictionary
		if str(metadata.get("name", "")) == desired:
			template_list.select(index)
			break
	_on_template_selected(template_list.selected if template_list.item_count > 0 else -1)
	return template_items.size()


func _template_display_name(item_name: String, preset: bool) -> String:
	if not preset:
		return item_name
	match item_name:
		"preset_kitchen_01":
			return "厨房 01（内置）"
		"preset_bedroom_l3_01":
			return "卧室 L3（内置）"
		"preset_hall_t5_01":
			return "大厅 T5（内置）"
		_:
			return "%s（内置）" % item_name.trim_prefix("preset_")


func _collect_templates(directory_path: String, preset: bool) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.get_extension().to_lower() == "json":
			template_items.append({"name": file_name.get_basename(), "path": directory_path + file_name, "preset": preset})
		file_name = directory.get_next()
	directory.list_dir_end()


func _on_template_selected(index: int) -> void:
	if index < 0 or index >= template_list.item_count:
		template_delete.disabled = true
		return
	var metadata := template_list.get_item_metadata(index) as Dictionary
	template_delete.disabled = bool(metadata.get("preset", false))


func _selected_template_name() -> String:
	if template_list.item_count > 0 and template_list.selected >= 0:
		var metadata := template_list.get_item_metadata(template_list.selected) as Dictionary
		return str(metadata.get("name", ""))
	return _clean_template_name(template_name.text)


func _delete_template(name) -> bool:
	var clean_name := _clean_template_name(str(name))
	var file_path := TEMPLATE_DIR + clean_name + ".json"
	if not FileAccess.file_exists(file_path):
		_update_status("删除失败：内置模板只读，或用户模板不存在")
		return false
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	if error != OK:
		_update_status("删除失败：%s" % file_path)
		return false
	_refresh_templates()
	_update_status("已删除模板：%s" % file_path)
	return true


func _clean_template_name(raw_name: String) -> String:
	var value := raw_name.strip_edges().trim_suffix(".json")
	if value.is_empty():
		value = "template"
	for invalid_character in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		value = value.replace(invalid_character, "_")
	return value


func _prepare_selection_ring() -> void:
	var source: Material = selection_ring.material_override
	if source == null and selection_ring.mesh != null and selection_ring.mesh.get_surface_count() > 0:
		source = selection_ring.mesh.surface_get_material(0)
	selection_ring_material = source.duplicate() as StandardMaterial3D if source is StandardMaterial3D else StandardMaterial3D.new()
	selection_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	selection_ring.material_override = selection_ring_material
	_set_selection_invalid(false)


func _set_selection_invalid(invalid: bool) -> void:
	if selection_ring_material == null:
		return
	var color := INVALID_RED if invalid else GOLD
	color.a = 0.92
	selection_ring_material.albedo_color = color
	selection_ring_material.emission_enabled = true
	selection_ring_material.emission = INVALID_RED if invalid else GOLD
	selection_ring_material.emission_energy_multiplier = 2.2


func _set_ghost_transparency(node: Node3D) -> void:
	for mesh_instance in _mesh_instances_in(node):
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh_instance.mesh == null:
			continue
		var base_colors: Array[Color] = []
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source := mesh_instance.get_surface_override_material(surface_index)
			if source == null:
				source = mesh_instance.mesh.surface_get_material(surface_index)
			var material: StandardMaterial3D = source.duplicate() as StandardMaterial3D if source is StandardMaterial3D else StandardMaterial3D.new()
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var color := material.albedo_color
			color.a = 0.45
			material.albedo_color = color
			base_colors.append(color)
			mesh_instance.set_surface_override_material(surface_index, material)
		mesh_instance.set_meta("ghost_base_colors", base_colors)


func _set_ghost_invalid(invalid: bool) -> void:
	for mesh_instance in _mesh_instances_in(ghost):
		if mesh_instance.mesh == null:
			continue
		var base_colors: Array = mesh_instance.get_meta("ghost_base_colors", [])
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_surface_override_material(surface_index) as StandardMaterial3D
			if material == null:
				continue
			var base_color: Color = base_colors[surface_index] if surface_index < base_colors.size() else Color(1.0, 1.0, 1.0, 0.45)
			var next_color := base_color.lerp(INVALID_RED, 0.55) if invalid else base_color
			next_color.a = base_color.a
			material.albedo_color = next_color


func _make_ground_grid() -> void:
	var previous := ground_mesh.get_node_or_null("GridLines")
	if previous != null:
		previous.free()
	var immediate := ImmediateMesh.new()
	_add_grid_surface(immediate, FINE_SNAP, MAT_FINE_GRID, 0.011)
	_add_grid_surface(immediate, CELL, MAT_MAJOR_GRID, 0.012)
	_add_cutting_mat_guides(immediate, 0.014)
	var grid_lines := MeshInstance3D.new()
	grid_lines.name = "GridLines"
	grid_lines.mesh = immediate
	grid_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_mesh.add_child(grid_lines)


func _add_grid_surface(immediate: ImmediateMesh, spacing: float, color: Color, height: float) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var line := -16.0
	while line <= 16.0001:
		immediate.surface_set_color(color)
		immediate.surface_add_vertex(Vector3(line, height, -16.0))
		immediate.surface_add_vertex(Vector3(line, height, 16.0))
		immediate.surface_add_vertex(Vector3(-16.0, height, line))
		immediate.surface_add_vertex(Vector3(16.0, height, line))
		line += spacing
	immediate.surface_end()


func _add_cutting_mat_guides(immediate: ImmediateMesh, height: float) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var extent := 15.75
	var tick := 0.16
	# Warm center axes and stitched outer border make the surface read as a
	# physical cutting/craft mat rather than an infinite engine grid.
	for pair in [
		[Vector3(-extent, height, 0.0), Vector3(extent, height, 0.0)],
		[Vector3(0.0, height, -extent), Vector3(0.0, height, extent)],
		[Vector3(-extent, height, -extent), Vector3(extent, height, -extent)],
		[Vector3(extent, height, -extent), Vector3(extent, height, extent)],
		[Vector3(extent, height, extent), Vector3(-extent, height, extent)],
		[Vector3(-extent, height, extent), Vector3(-extent, height, -extent)],
	]:
		immediate.surface_set_color(MAT_AXIS_GRID)
		immediate.surface_add_vertex(pair[0])
		immediate.surface_add_vertex(pair[1])
	var marker := -15.5
	while marker <= 15.5001:
		immediate.surface_set_color(MAT_MAJOR_GRID)
		immediate.surface_add_vertex(Vector3(marker, height, -extent))
		immediate.surface_add_vertex(Vector3(marker, height, -extent + tick))
		immediate.surface_add_vertex(Vector3(marker, height, extent))
		immediate.surface_add_vertex(Vector3(marker, height, extent - tick))
		immediate.surface_add_vertex(Vector3(-extent, height, marker))
		immediate.surface_add_vertex(Vector3(-extent + tick, height, marker))
		immediate.surface_add_vertex(Vector3(extent, height, marker))
		immediate.surface_add_vertex(Vector3(extent - tick, height, marker))
		marker += CELL
	immediate.surface_end()


func _base_scale(entry: Dictionary) -> Vector3:
	var value: Variant = entry.get("scale", 1.0)
	if value is Array:
		var components := value as Array
		if components.size() >= 3:
			return Vector3(float(components[0]), float(components[1]), float(components[2]))
	return Vector3.ONE * float(value)


func _scale_factor_from_actual(actual_scale: Vector3, entry: Dictionary) -> float:
	var base := _base_scale(entry)
	return actual_scale.x / base.x if absf(base.x) > 0.000001 else 1.0


func _find_asset_entry(asset_id) -> Dictionary:
	for raw_entry: Variant in catalog.get("assets", []):
		var entry := raw_entry as Dictionary
		if str(entry.get("id", "")) == str(asset_id):
			return entry
	return {}


func _mesh_instances_in(root_node: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root_node is MeshInstance3D:
		result.append(root_node as MeshInstance3D)
	for child: Node in root_node.find_children("*", "MeshInstance3D", true, false):
		result.append(child as MeshInstance3D)
	return result


func _set_asset_shadows(root_node: Node3D, enabled: bool) -> void:
	for mesh_instance in _mesh_instances_in(root_node):
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _node_world_aabb(root_node: Node3D) -> AABB:
	var merged := AABB()
	var has_aabb := false
	for mesh_instance in _mesh_instances_in(root_node):
		if mesh_instance.mesh == null:
			continue
		var world_aabb: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		if not has_aabb:
			merged = world_aabb
			has_aabb = true
		else:
			merged = merged.merge(world_aabb)
	return merged if has_aabb else AABB()


func _ray_aabb_distance(origin: Vector3, direction: Vector3, box: AABB) -> float:
	if box.size == Vector3.ZERO:
		return -1.0
	var minimum := box.position
	var maximum := box.position + box.size
	var near_distance := 0.0
	var far_distance := INF
	for axis in 3:
		var ray_value := direction[axis]
		var origin_value := origin[axis]
		if absf(ray_value) < 0.000001:
			if origin_value < minimum[axis] or origin_value > maximum[axis]:
				return -1.0
			continue
		var first := (minimum[axis] - origin_value) / ray_value
		var second := (maximum[axis] - origin_value) / ray_value
		if first > second:
			var swap := first
			first = second
			second = swap
		near_distance = maxf(near_distance, first)
		far_distance = minf(far_distance, second)
		if near_distance > far_distance:
			return -1.0
	return near_distance if far_distance >= 0.0 else -1.0


func _pan_orbit(relative: Vector2) -> void:
	var right := camera.global_transform.basis.x
	var forward := -camera.global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	right = right.normalized()
	forward = forward.normalized()
	var offset := (-right * relative.x + forward * relative.y) * (0.01 * cam_distance_target)
	offset.y = 0.0
	orbit_center += offset


func _clamp_camera_targets() -> void:
	cam_pitch_target = clampf(cam_pitch_target, 0.12, 1.45)
	cam_distance_target = clampf(cam_distance_target, 6.0, 40.0)


func _update_camera_transform() -> void:
	var direction := Vector3(cos(cam_pitch_current) * cos(cam_yaw_current), sin(cam_pitch_current), cos(cam_pitch_current) * sin(cam_yaw_current))
	camera.global_position = orbit_center_current + direction * cam_distance_current
	camera.look_at(orbit_center_current, Vector3.UP)


func _cancel_active_mode() -> void:
	if wall_dragging:
		wall_dragging = false
		_clear_ghost()
	elif wall_mode:
		wall_mode = false
		wall_kind = ""
		selected_asset = ""
		_clear_ghost()
		_rebuild_corner_anchors()
	elif not selected_asset.is_empty():
		selected_asset = ""
		ghost_yaw = 0.0
		ghost_size_tier = 1
		_clear_ghost()
	else:
		_deselect()
	if gizmo != null and is_instance_valid(gizmo) and selection != null and is_instance_valid(selection):
		gizmo.set_target(selection, tool_mode)
	_update_status()


func _point_is_valid(point: Vector3) -> bool:
	return not is_inf(point.x) and not is_inf(point.y) and not is_inf(point.z)


func _array_vec3(value: Variant) -> Vector3:
	var values := value as Array
	return Vector3(float(values[0]), float(values[1]), float(values[2])) if values.size() >= 3 else Vector3.ZERO


func _vec3_array(value: Variant) -> Array:
	if value is Vector3:
		var vector: Vector3 = value
		return [vector.x, vector.y, vector.z]
	return [0.0, 0.0, 0.0]


func _array_vec3i(value: Variant) -> Vector3i:
	var values := value as Array
	return Vector3i(int(values[0]), int(values[1]), int(values[2])) if values.size() >= 3 else Vector3i.ZERO


func _array_vec2i(value: Variant) -> Vector2i:
	var values := value as Array
	return Vector2i(int(values[0]), int(values[1])) if values.size() >= 2 else Vector2i.ZERO


func _reason_text(reason: String) -> String:
	match reason:
		"out_of_bounds":
			return "超出房间外轮廓"
		"overlap":
			return "与已有资产或墙重叠"
		"wall_not_boundary":
			return "墙不在房间外轮廓"
		"wall_overlap":
			return "该边界已有墙段"
		"missing_geometry":
			return "资产缺少可检测几何"
		"missing_asset":
			return "资产不存在"
		_:
			return reason


func _update_status(message := "") -> void:
	if not is_instance_valid(status_label):
		return
	if not str(message).is_empty():
		status_label.text = str(message)
		return
	var room_name := str(ROOM_SHAPE_NAMES.get(room_shape_id, room_shape_id))
	if not formal_room_id.is_empty():
		room_name = "%s · %s" % [formal_room_id, room_name]
	if not failed_paths.is_empty():
		status_label.text = "资产缺失：%s" % ", ".join(failed_paths)
	elif wall_mode:
		status_label.text = "%s · 画墙：%s · 左键沿外轮廓拖动" % [room_name, WALL_TOOL_NAMES.get(wall_kind, wall_kind)]
	elif not selected_asset.is_empty():
		var entry := _find_asset_entry(selected_asset)
		var validity := "合法" if ghost_valid else _reason_text(ghost_invalid_reason)
		status_label.text = "%s · 放置：%s · %s" % [room_name, entry.get("name", selected_asset), validity]
	elif selection != null and is_instance_valid(selection):
		status_label.text = "%s · 已选中：%s · %s" % [room_name, selection.name, "门洞（G 放门不可用 / Delete 恢复实体墙）" if bool(selection.get_meta("is_door", false)) else ("墙段（端点拖动 / G 放门 / Delete 删除）" if bool(selection.get_meta("is_wall", false)) else "工具 %s · 拖 Gizmo" % tool_mode)]
	elif tool_mode == "pan":
		status_label.text = "%s · Q 视图工具 · 左键拖动平移 · W/E/R 切换变换工具" % room_name
	else:
		status_label.text = "%s · 家具 %d · 墙段 %d · 墙带 %d · 自由摆放（Ctrl 细吸附）" % [room_name, placements.get_child_count(), walls.get_child_count(), (wall_graph.get("runs", []) as Array).size()]


func _update_help() -> void:
	help_label.text = "Unity 操作：Q=视图  W=移动  E=旋转  R=缩放；工具保持激活，点击物体只负责选中\n移动 Gizmo：X/Y/Z 箭头锁单轴 · XY/YZ/XZ 方片锁正交平面；绿色圆环绕 Y 轴旋转\n右键拖动：环绕   中键拖动：平移   滚轮：缩放相机   F：聚焦   Ctrl+D：复制\nCtrl+拖动：吸附细网格   Delete：删除（门洞恢复实体墙）   Ctrl+Z/Y：撤销/重做   Esc：取消\n墙工具：从金色角柱锚点拖到外轮廓形成连续墙带；选中墙段可拖两端端点，自动重算转角\n资产可相互堆叠：用移动 Gizmo 把资产落到另一资产顶面"
