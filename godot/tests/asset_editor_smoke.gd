extends SceneTree

const Rules = preload("res://scripts/asset_diorama_rules.gd")
const CardboardShellBuilder = preload("res://scripts/cardboard_shell_builder.gd")
const RoomShellGraph = preload("res://scripts/room_shell_graph.gd")
const RoomFootprintCatalog = preload("res://scripts/room_footprint_catalog.gd")
const RoomPropCatalog = preload("res://scripts/room_prop_catalog.gd")

const CATALOG_PATH := "res://data/editor/asset_catalog.json"
const SCENE_PATH := "res://scenes/asset_editor_3d.tscn"
const PRESET_DIR := "res://data/editor/preset_templates/"
const TEMPLATE_PATH := "user://diorama_templates/__smoke_tpl.json"
const CELL := 1.55

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := _load_catalog()
	_run_rule_tests()
	_run_preset_file_tests()

	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "asset editor scene must load")
	if packed == null:
		_finish()
		return
	var editor := packed.instantiate() as Node3D
	_check(editor != null, "asset editor scene must instantiate")
	if editor == null:
		_finish()
		return
	root.add_child(editor)
	await process_frame
	await process_frame

	_run_scene_structure_tests(editor, catalog)
	_run_free_placement_tests(editor)
	_run_boundary_and_overlap_tests(editor)
	_run_wall_tests(editor)
	_run_size_rotation_copy_tests(editor)
	_run_reference_and_focus_tests(editor)
	_run_undo_redo_tests(editor)
	_run_template_tests(editor)
	_run_camera_tests(editor)
	_run_select_interaction_regression(editor)

	var count_before_missing: int = editor.get_node("Placements").get_child_count()
	var missing: Node3D = editor._place_at_free(Vector3(0.8, 0.0, 0.8), "not_exist", 0.0, Vector3.ONE)
	_check(missing == null, "unknown asset id must return null")
	_check(editor.get_node("Placements").get_child_count() == count_before_missing, "unknown asset id must not create a placement")

	if FileAccess.file_exists(TEMPLATE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMPLATE_PATH))
	editor.queue_free()
	await process_frame
	_finish()


func _load_catalog() -> Dictionary:
	var catalog_file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	_check(catalog_file != null, "catalog must load")
	if catalog_file == null:
		return {}
	var parser := JSON.new()
	var parse_error := parser.parse(catalog_file.get_as_text())
	catalog_file.close()
	_check(parse_error == OK and parser.data is Dictionary, "catalog JSON must parse")
	var catalog: Dictionary = parser.data as Dictionary if parse_error == OK and parser.data is Dictionary else {}
	_check((catalog.get("assets", []) as Array).size() < 56, "catalog must remove the legacy KayKit wall/floor entries")
	_check((catalog.get("categories", []) as Array).size() == 4, "catalog must remain unchanged at four categories")
	for raw_entry: Variant in catalog.get("assets", []):
		var asset_id := str((raw_entry as Dictionary).get("id", ""))
		_check(not asset_id.begins_with("kaykit_wall") and asset_id not in ["kaykit_pillar", "kaykit_floor_wood", "kaykit_floor_dark", "kaykit_stairs"], "legacy structure asset must be removed: %s" % asset_id)
	return catalog


func _run_rule_tests() -> void:
	# 1. Free and fine placement.
	_check(Rules.snap_free(Vector3(0.333, 8.0, 0.4)).is_equal_approx(Vector3(0.333, 0.0, 0.4)), "snap_free must preserve XZ and zero Y")
	_check(Rules.snap_fine(Vector3(0.333, 2.0, 0.4)).is_equal_approx(Vector3(0.31, 0.0, 0.465)), "fine snap must use the 0.155m grid")
	# 2. Footprint rotation. The plan sample's (-1,1) is inconsistent with its
	# required transform and repository l3; the mathematically correct cell is (-1,0).
	_check(Rules.rotated_cells("l3", 1) == [Vector2i(0, 0), Vector2i(0, 1), Vector2i(-1, 0)], "l3 must use (x,y)->(-y,x)")
	_check(Rules.room_center_world([Vector2i(0, 0), Vector2i(1, 0)]).is_equal_approx(Vector3(CELL, 0.0, CELL * 0.5)), "room center must use outer bounds")
	# 3-5. Room point/AABB union rules.
	var single: Array[Vector2i] = [Vector2i.ZERO]
	_check(Rules.point_in_room(Vector3(0.5, 0.0, 0.5), single), "point inside single room must pass")
	_check(not Rules.point_in_room(Vector3(1.6, 0.0, 0.5), single), "point outside single room must fail")
	_check(Rules.aabb_in_room(AABB(Vector3(0.375, 0.0, 0.375), Vector3(0.8, 1.0, 0.8)), single), "centered asset must fit a single room")
	_check(not Rules.aabb_in_room(AABB(Vector3(-0.1, 0.0, -0.1), Vector3(0.8, 1.0, 0.8)), single), "edge-crossing asset must fail")
	_check(Rules.aabb_in_room(AABB(Vector3(1.15, 0.0, 0.375), Vector3(0.8, 1.0, 0.8)), [Vector2i(0, 0), Vector2i(1, 0)]), "asset may cross an internal room edge")
	# 6. XZ-only overlap.
	_check(Rules.aabb_overlaps_xz(AABB(Vector3.ZERO, Vector3.ONE), AABB(Vector3(0.5, 8.0, 0.5), Vector3.ONE)), "XZ overlap must ignore Y")
	_check(not Rules.aabb_overlaps_xz(AABB(Vector3.ZERO, Vector3.ONE), AABB(Vector3(2.0, 0.0, 2.0), Vector3.ONE)), "separated rectangles must not overlap")
	# 7-9. Wall geometry.
	_check(Rules.wall_axis_from_drag(Vector3(0.4, 0.0, 0.2), Vector3(2.2, 0.0, 0.4)) == Vector3i(1, 0, 0), "horizontal drag must select X axis")
	_check(Rules.wall_axis_from_drag(Vector3(0.2, 0.0, 0.4), Vector3(0.4, 0.0, 2.2)) == Vector3i(0, 0, 1), "vertical drag must select Z axis")
	var segments := Rules.wall_cells_from_drag(Vector3(0.775, 0.0, 0.0), Vector3(3.875, 0.0, 0.0), Vector3i(1, 0, 0))
	_check(segments.size() == 2, "3.1m boundary drag must generate two wall segments")
	if segments.size() == 2:
		_check(segments[0].is_equal_approx(Vector3(1.55, Rules.WALL_Y_OFFSET, 0.0)) and segments[1].is_equal_approx(Vector3(3.1, Rules.WALL_Y_OFFSET, 0.0)), "wall segment midpoints must be quantized")
	_check(Rules.wall_position_in_room(Vector3(0.775, 0.02, 0.0), single), "outer boundary wall position must pass")
	_check(not Rules.wall_position_in_room(Vector3(0.775, 0.02, 0.775), single), "room interior wall position must fail")
	var anchors: Array = Rules.corner_anchors(single)
	_check(anchors.size() == 4, "single room must expose four de-duplicated corner anchors")
	_check(not Rules.snap_to_corner_anchor(Vector3(0.1, 0.0, 0.1), single, 0.3).is_empty(), "nearby corner must snap to an anchor")
	_check(Rules.snap_to_corner_anchor(Vector3(0.7, 0.0, 0.7), single, 0.3).is_empty(), "far interior point must not snap to an anchor")
	# 10. Size tiers.
	_check(Rules.SIZE_TIERS == [0.6, 1.0, 1.5], "size tiers must be 0.6/1.0/1.5")
	_check(Rules.next_size_tier(0) == 1 and Rules.next_size_tier(2) == 0, "size tier index must cycle")
	# 11. Paper-board shell construction and legacy migration.
	var paper_wall := CardboardShellBuilder.build_wall("cb_wall", Vector3.ZERO, 0.0, 0)
	_check(paper_wall != null and paper_wall.get_meta("cardboard_shell", false), "paper wall must be tagged as cardboard shell")
	var panel := paper_wall.get_node_or_null("Panel") as MeshInstance3D if paper_wall != null else null
	_check(panel != null and (panel.mesh as BoxMesh).size.is_equal_approx(Vector3(1.27, 0.72, 0.10)), "paper wall panel must use 1.27 x 0.72 x 0.10 geometry")
	var wall_material := panel.material_override as StandardMaterial3D if panel != null else null
	_check(wall_material != null and is_equal_approx(wall_material.roughness, 0.98) and is_zero_approx(wall_material.metallic), "paper wall material must be matte")
	var doorway := CardboardShellBuilder.build_doorway(Vector3.ZERO, 0.0, 0)
	_check(doorway.get_node_or_null("Header") != null and doorway.get_node_or_null("DoorLeaf") != null and doorway.get_node_or_null("DoorCue") != null, "paper doorway must expose header, leaf and cue")
	var junction := CardboardShellBuilder.build_junction(Vector3.ZERO)
	_check(junction.get_node_or_null("Post") != null and junction.get_node_or_null("PostCap") != null and junction.get_node_or_null("TapeBand") != null, "paper junction must expose post, cap and tape")
	_check(Rules.normalize_wall_kind("kaykit_wall") == "cb_wall" and Rules.normalize_wall_kind("kaykit_wall_doorway") == "cb_doorway", "legacy wall ids must migrate to cardboard ids")
	_check(is_equal_approx(Rules.WALL_HEIGHT, 0.72), "editor wall height must be 0.72 for A2/A8")
	var graph := RoomShellGraph.compile(single, [
		{"kind": "cb_wall", "position": [0.775, 0.02, 0.0], "axis": [1, 0, 0], "cell": [0, 0]},
		{"kind": "cb_wall", "position": [2.325, 0.02, 0.0], "axis": [1, 0, 0], "cell": [0, 0]},
		{"kind": "cb_wall", "position": [0.0, 0.02, 0.775], "axis": [0, 0, 1], "cell": [0, 0]},
	])
	_check((graph.get("runs", []) as Array).size() == 2, "semantic graph must group contiguous wall segments into runs")
	_check((graph.get("joins", []) as Array).size() == 1, "semantic graph must create one internal join for a continuous wall run")
	if (graph.get("walls", []) as Array).size() >= 2:
		_check(str(((graph.get("walls", []) as Array)[0] as Dictionary).get("run_id", "")) == str(((graph.get("walls", []) as Array)[1] as Dictionary).get("run_id", "")), "contiguous wall segments must share a run id")
	_check((graph.get("boundary_sockets", []) as Array).size() == 4, "single room must expose four connection sockets")
	# 12. Template walls round trip.
	var payload := Rules.make_template_json(
		"single",
		0,
		[{"asset_id": "kk_couch", "position": [0.7, 0.0, 0.7], "yaw": 0.2, "scale": [0.28, 0.28, 0.28]}],
		[{"wall_kind": "kaykit_wall", "position": [0.775, 0.02, 0.0], "yaw": PI * 0.5, "wall_axis": [1, 0, 0], "wall_cell": [0, 0]}],
		"rules_smoke"
	)
	var parsed := Rules.parse_template_json(JSON.stringify(payload))
	_check(bool(parsed.get("ok", false)), "schema v2 template with walls must parse")
	if bool(parsed.get("ok", false)):
		var data := parsed.get("data", {}) as Dictionary
		_check((data.get("assets", []) as Array).size() == 1 and (data.get("walls", []) as Array).size() == 1, "template round trip must retain assets and walls")
		_check(str(((data.get("walls", []) as Array)[0] as Dictionary).get("kind", "")) == "cb_wall", "template round trip must normalize legacy wall kind")


func _run_preset_file_tests() -> void:
	for preset_name in ["preset_kitchen_01", "preset_bedroom_l3_01", "preset_hall_t5_01"]:
		var path: String = PRESET_DIR + str(preset_name) + ".json"
		var file := FileAccess.open(path, FileAccess.READ)
		_check(file != null, "preset must exist: %s" % preset_name)
		if file == null:
			continue
		var parsed := Rules.parse_template_json(file.get_as_text())
		file.close()
		_check(bool(parsed.get("ok", false)), "preset must follow schema v2: %s" % preset_name)
		if bool(parsed.get("ok", false)):
			var data := parsed.get("data", {}) as Dictionary
			_check((data.get("assets", []) as Array).size() >= 3, "preset must contain at least three themed assets: %s" % preset_name)
			var preset_walls := data.get("walls", []) as Array
			_check(not preset_walls.is_empty(), "preset must contain perimeter walls: %s" % preset_name)
			_check((data.get("fixtures", []) as Array).size() >= 1, "preset must contain a production fixture: %s" % preset_name)
			var has_doorway := false
			for raw_wall: Variant in preset_walls:
				if str((raw_wall as Dictionary).get("kind", "")) == "cb_doorway":
					has_doorway = true
			_check(has_doorway, "preset must contain at least one doorway: %s" % preset_name)


func _run_scene_structure_tests(editor: Node3D, catalog: Dictionary) -> void:
	_check(editor.failed_paths.is_empty(), "all catalog resource paths must load: %s" % str(editor.failed_paths))
	_run_formal_baseline_tests(editor)
	var catalog_list := editor.get_node("UI/Panel/VBox/CatalogScroll/CatalogList") as VBoxContainer
	var expected_children := (catalog.get("categories", []) as Array).size() + (catalog.get("assets", []) as Array).size() + 4
	_check(catalog_list.get_child_count() == expected_children, "catalog panel must include four categories, paper wall tools and all assets")
	_check((editor.get_node("UI/TopBar/RoomShape") as OptionButton).item_count == 8, "room selector must contain eight footprints")
	var formal_room_selector := editor.get_node("UI/TopBar/FormalRoom") as OptionButton
	_check(formal_room_selector.item_count == RoomFootprintCatalog.ROOM_CONFIG.size(), "formal room selector must expose every ROOM_CONFIG id")
	var living_index := -1
	for index in formal_room_selector.item_count:
		if str(formal_room_selector.get_item_metadata(index)) == "living":
			living_index = index
			break
	_check(living_index >= 0, "formal room selector must include living")
	if living_index >= 0:
		editor._on_formal_room_selected(living_index)
		_check(editor.formal_room_id == "living" and editor.room_shape_id == str(RoomFootprintCatalog.ROOM_CONFIG["living"].get("shape", "single")), "formal room selection must sync shape and override id")
		_check(editor.get_node("Placements").get_child_count() == 5 and editor.get_node("Walls").get_child_count() == 4, "formal room selection must load the authored living override instead of an empty footprint")
	var hall_index := -1
	for index in formal_room_selector.item_count:
		if str(formal_room_selector.get_item_metadata(index)) == "hall":
			hall_index = index
			break
	_check(hall_index >= 0, "formal room selector must include hall")
	if hall_index >= 0:
		editor._on_formal_room_selected(hall_index)
		_check(editor.formal_room_id == "hall" and editor.room_shape_id == "plus5" and editor.room_cells.size() == 5, "formal room baseline must retain the formal 5-cell footprint")
		_check(editor.get_node("Placements").get_child_count() >= 6, "formal room without an override must load the current PCG furniture composition")
		_check(editor.get_node("Walls").get_child_count() == Rules.room_boundary_edges(editor.room_cells).size(), "generated formal baseline must wrap the complete outer footprint")
		var doorway_count := 0
		for wall in editor.get_node("Walls").get_children():
			if bool(wall.get_meta("is_door", false)):
				doorway_count += 1
		_check(doorway_count == 1, "generated formal baseline must expose one editable doorway")
	if living_index >= 0:
		editor._on_formal_room_selected(living_index)
		editor.formal_room_id = ""
		editor._sync_formal_room_ui()
	_check(editor.has_node("Walls") and editor.has_node("Corners") and editor.has_node("WallJoins") and editor.has_node("Fixtures") and editor.has_node("CardboardShell") and editor.has_node("ReferenceActor") and editor.has_node("EditorOverlay/Gizmo3D") and editor.has_node("EditorOverlay/Anchors") and editor.has_node("EditorOverlay/WallHandles"), "scene must expose semantic wall/corner/join/fixture/reference/gizmo containers")
	_check(editor.get_node("ReferenceActor").get_child_count() >= 2, "reference actor must contain model/fallback and label")
	_check(editor._room_cell_box_count() == 1 and editor.has_node("RoomBase/ShadowQuad") and editor.has_node("RoomBase/RoomLabel"), "room base must include cell, shadow and label")
	var ground_material := (editor.get_node("GroundMesh") as MeshInstance3D).material_override as StandardMaterial3D
	_check(ground_material != null and ground_material.albedo_color.is_equal_approx(Color("#356c58")), "ground must use the green handmade cutting-mat color")
	var grid := editor.get_node("GroundMesh/GridLines") as MeshInstance3D
	_check(grid != null and grid.mesh.get_surface_count() == 3, "ground must contain fine grid, major grid and cutting-mat ruler guides")
	_check(editor._refresh_templates() >= 3, "template list must discover the three built-in presets")
	_check(editor.tool_mode == "move", "editor must start with Unity's W move tool active")
	_check(editor.has_node("UI/ToolDock/ToolRow/ToolPan") and editor.has_node("UI/ToolDock/ToolRow/ToolMove") and editor.has_node("UI/ToolDock/ToolRow/ToolRotate") and editor.has_node("UI/ToolDock/ToolRow/ToolScale"), "Unity Q/W/E/R tools must live in a dedicated overlay")
	_check(editor.has_node("UI/TemplateBar/TemplateName") and editor.has_node("UI/TemplateBar/ExportOverride"), "room controls and template controls must be separated into readable rows")
	_check(editor.get_node("EditorOverlay/Gizmo3D").get_meta("editor_gizmo", false), "gizmo root must be tagged as editor-only")


func _run_formal_baseline_tests(editor: Node3D) -> void:
	var stacked_detail_found := false
	for raw_room_id: Variant in RoomFootprintCatalog.ROOM_CONFIG.keys():
		var room_id := str(raw_room_id)
		var config := RoomFootprintCatalog.ROOM_CONFIG[room_id] as Dictionary
		var shape_id := str(config.get("shape", "single"))
		var cells := Rules.rotated_cells(shape_id, 0)
		var state: Dictionary = editor._generated_formal_room_state(room_id)
		var assets := state.get("assets", []) as Array
		var walls := state.get("walls", []) as Array
		# The request stays at 7-9 for a three-cell room, while collision and
		# support checks may deliberately leave one loose duplicate in the box.
		var expected_min_assets := 10 if cells.size() >= 5 else (6 if cells.size() >= 3 else 4)
		var request := RoomPropCatalog.unpacking_template_request({"id": room_id, "room_type": room_id, "size": cells.size()}, 0, editor.FORMAL_BASE_LAYOUT_SEED)
		var density_range := RoomPropCatalog.unpacking_count_range_for_size(cells.size())
		_check(str(request.get("generation_mode", "")) == "unpacking_seed", "formal room seeds must use the Unpacking-style semantic generator: %s" % room_id)
		_check(int(request.get("count", 0)) >= density_range.x and int(request.get("count", 0)) <= density_range.y, "Unpacking seed density must match the 1/3/5-room range: %s" % room_id)
		_check(assets.size() >= expected_min_assets, "every formal room must expose a dense editable Unpacking baseline: %s" % room_id)
		_check(walls.size() == Rules.room_boundary_edges(cells).size(), "formal room baseline walls must follow its complete outer footprint: %s" % room_id)
		var doorway_count := 0
		for raw_wall: Variant in walls:
			if bool((raw_wall as Dictionary).get("is_door", false)):
				doorway_count += 1
		_check(doorway_count == 1, "formal room baseline must have one doorway: %s" % room_id)
		for raw_asset: Variant in assets:
			var asset := raw_asset as Dictionary
			var asset_id := str(asset.get("asset_id", ""))
			_check(not editor._find_asset_entry(asset_id).is_empty(), "formal room baseline must map PCG assets into the editor catalog: %s/%s" % [room_id, asset_id])
			var position := asset.get("position", []) as Array
			if position.size() >= 3 and float(position[1]) > 0.08:
				stacked_detail_found = true
	_check(stacked_detail_found, "Unpacking-style baselines must place at least one loose detail on a semantic support surface")


func _run_free_placement_tests(editor: Node3D) -> void:
	editor._change_room("line3", 0, false)
	var position := Vector3(0.43, 0.0, 0.37)
	var scale_value := Vector3.ONE * 0.28
	var couch: Node3D = editor._place_at_free(position, "kk_couch", 0.73, scale_value, false)
	_check(couch != null, "free placement must instantiate a couch")
	if couch != null:
		_check(couch.position.is_equal_approx(position), "free placement must preserve continuous position")
		_check(is_equal_approx(couch.rotation.y, 0.73), "free placement must preserve continuous yaw")
		_check(couch.scale.is_equal_approx(scale_value), "free placement must preserve catalog-scaled tier")
	editor._clear_all(false)


func _run_boundary_and_overlap_tests(editor: Node3D) -> void:
	editor._change_room("single", 0, false)
	var rejected: Node3D = editor._place_at_free(Vector3(0.2, 0.0, 0.2), "kk_bed_double", 0.0, Vector3.ONE * 0.28, true)
	_check(rejected == null and editor.last_rejection_reason == "out_of_bounds", "single-room edge crossing must be rejected")
	var center := Vector3(CELL * 0.5, 0.0, CELL * 0.5)
	var first: Node3D = editor._place_at_free(center, "kk_chair_a", 0.0, Vector3.ONE * 0.28, true)
	var second: Node3D = editor._place_at_free(center, "kk_chair_b", 0.0, Vector3.ONE * 0.28, true)
	_check(first != null and second == null and editor.last_rejection_reason == "overlap", "solid overlap must be rejected")
	var rug: Node3D = editor._place_at_free(center, "kk_rug_oval", 0.0, Vector3.ONE * 0.28, true)
	_check(rug != null, "overlay rug must be exempt from overlap rejection")
	editor._clear_all(false)


func _run_wall_tests(editor: Node3D) -> void:
	# Draw two perpendicular walls and verify one automatic corner.
	editor._change_room("single", 0, false)
	var horizontal: int = editor._draw_wall(Vector3(0.0, 0.0, 0.0), Vector3(CELL, 0.0, 0.0), "cb_wall", false)
	var vertical: int = editor._draw_wall(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, CELL), "cb_wall_half", false)
	_check(horizontal == 1 and vertical == 1, "perpendicular single-cell drags must create one segment each")
	_check(editor.get_node("Walls").get_child_count() == 2, "wall container must keep generated segments separate")
	_check(editor.get_node("Corners").get_child_count() == 1, "perpendicular wall endpoints must create one automatic corner")
	_check(editor.get_node("WallJoins").get_child_count() == 0, "perpendicular-only wall test must not create a false straight join")
	for child in editor.get_node("Walls").get_children():
		var wall := child as Node3D
		_check(Rules.wall_position_in_room(wall.position, editor.room_cells), "generated wall must sit on room outer boundary")
		var wall_axis: Vector3i = wall.get_meta("wall_axis", Vector3i.ZERO)
		var expected_yaw := 0.0 if wall_axis.x != 0 else PI * 0.5
		_check(is_equal_approx(wall.rotation.y, expected_yaw), "generated wall yaw must follow its boundary axis")
		var wall_aabb: AABB = editor._node_world_aabb(wall)
		_check((wall_axis.x != 0 and wall_aabb.size.x > wall_aabb.size.z) or (wall_axis.z != 0 and wall_aabb.size.z > wall_aabb.size.x), "wall mesh long axis must lie along its room boundary")
		_check(bool(wall.get_meta("cardboard_shell", false)) and wall.get_node_or_null("Panel") != null, "generated wall must be a paper-board shell, not a gltf")
		_check(float(wall.get_meta("wall_height", 0.0)) <= Rules.WALL_HEIGHT + 0.001, "generated wall must not exceed the low 0.72 height")

	# A continuous drag creates one semantic run and an internal cardboard join.
	editor._change_room("line3", 0, false)
	_check(editor._draw_wall(Vector3(0.0, 0.0, 0.0), Vector3(CELL * 2.0, 0.0, 0.0), "cb_wall", false) == 2, "continuous line3 drag must create two segments")
	_check(editor.get_node("WallJoins").get_child_count() == 1 and (editor.wall_graph.get("runs", []) as Array).size() == 1, "continuous drag must auto-join into one wall run")
	editor._clear_all(false)
	# A loaded/drawn wall can be slid along its boundary, then removed.
	editor._change_room("line3", 0, false)
	_check(editor._draw_wall(Vector3(0.0, 0.0, 0.0), Vector3(CELL, 0.0, 0.0), "cb_wall", false) == 1, "line3 setup wall must draw")
	var wall := editor.get_node("Walls").get_child(0) as Node3D
	editor._select(wall)
	editor._begin_wall_slide_if_needed(wall)
	_check(editor.dragging, "structural walls must retain their boundary-only direct slide")
	editor._move_selected_to(Vector3(2.2, 0.0, 0.0))
	editor.drag_valid = editor._selected_transform_valid()
	editor._finish_transform()
	_check(wall.position.is_equal_approx(Vector3(2.325, Rules.WALL_Y_OFFSET, 0.0)), "wall drag must slide one CELL along its existing boundary axis")
	var walls_before_delete: int = editor.get_node("Walls").get_child_count()
	editor._select(wall)
	editor._delete_selected()
	_check(editor.get_node("Walls").get_child_count() == walls_before_delete - 1, "selected wall must be individually removable")

	# v4: an entity wall is replaced by a doorway and deleting the doorway restores it.
	editor._clear_all(false)
	_check(editor._draw_wall(Vector3(0.0, 0.0, 0.0), Vector3(CELL, 0.0, 0.0), "cb_wall", false) == 1, "door replacement setup must draw a wall")
	var solid_wall := editor.get_node("Walls").get_child(0) as Node3D
	editor._select(solid_wall)
	var doorway: Node3D = editor._replace_selected_wall_with_door()
	_check(doorway != null and bool(doorway.get_meta("is_door", false)) and str(doorway.get_meta("wall_kind", "")) == "cb_doorway", "placing a door must replace the selected wall segment")
	if doorway != null:
		editor._select(doorway)
		editor._delete_selected()
		_check(editor.get_node("Walls").get_child_count() == 1 and not bool((editor.get_node("Walls").get_child(0) as Node3D).get_meta("is_door", false)), "deleting a doorway must restore a solid wall")

	# v4: endpoint editing can turn a single boundary segment into an L.
	editor._clear_all(false)
	editor._draw_wall(Vector3(0.0, 0.0, 0.0), Vector3(CELL, 0.0, 0.0), "cb_wall", false)
	var endpoint_wall := editor.get_node("Walls").get_child(0) as Node3D
	var rebuilt_endpoint: Node3D = editor._rebuild_wall_from_endpoints(endpoint_wall, Vector3(0.0, Rules.WALL_Y_OFFSET, 0.0), Vector3(CELL, Rules.WALL_Y_OFFSET, CELL))
	_check(rebuilt_endpoint != null and editor.get_node("Walls").get_child_count() == 2 and editor.get_node("Corners").get_child_count() >= 1, "perpendicular endpoint drag must create an L wall with a corner")


func _run_size_rotation_copy_tests(editor: Node3D) -> void:
	editor._change_room("line3", 0, false)
	var asset: Node3D = editor._place_at_free(Vector3(0.55, 0.0, 0.55), "kk_book_single", 0.0, Vector3.ONE * 0.28, false)
	editor._select(asset)
	editor.dragging = false
	editor._begin_wall_slide_if_needed(asset)
	_check(not editor.dragging, "clicking furniture must only select it; transforms must start from a Gizmo handle")
	# Continuous rotation via gizmo motion (E tool).
	var old_yaw: float = asset.rotation.y
	editor._rotate_selected_by_motion(20.0)
	_check(is_equal_approx(asset.rotation.y, old_yaw + 0.2), "rightward rotation drag must rotate right instead of mirroring the Y axis")
	editor.drag_valid = true
	var duplicate: Node3D = editor._duplicate_selected()
	_check(duplicate != null and editor.get_node("Placements").get_child_count() == 2, "Ctrl+D must duplicate a valid selected asset")
	if duplicate != null:
		_check(str(duplicate.get_meta("asset_id", "")) == "kk_book_single", "duplicate must preserve metadata")
	editor._set_tool_mode("move")
	_check(editor.tool_mode == "move" and editor.get_node("EditorOverlay/Gizmo3D").visible, "move tool must show the gizmo for furniture")
	# v5: move gizmo exposes three single-axis arrows AND three plane handles.
	var gizmo := editor.get_node("EditorOverlay/Gizmo3D")
	_check(gizmo.get_node_or_null("MoveArrows/Arrow_X") != null and gizmo.get_node_or_null("MoveArrows/Arrow_Y") != null and gizmo.get_node_or_null("MoveArrows/Arrow_Z") != null, "move gizmo must expose X/Y/Z arrows")
	_check(gizmo.get_node_or_null("MoveArrows/Plane_XY") != null and gizmo.get_node_or_null("MoveArrows/Plane_YZ") != null and gizmo.get_node_or_null("MoveArrows/Plane_XZ") != null, "move gizmo must expose XY/YZ/XZ plane handles")
	var xy_box: AABB = gizmo._node_world_aabb(gizmo.get_node("MoveArrows/Plane_XY"))
	var yz_box: AABB = gizmo._node_world_aabb(gizmo.get_node("MoveArrows/Plane_YZ"))
	var xz_box: AABB = gizmo._node_world_aabb(gizmo.get_node("MoveArrows/Plane_XZ"))
	_check(xy_box.size.z < xy_box.size.x and xy_box.size.z < xy_box.size.y, "XY handle must be a vertical XY plane")
	_check(yz_box.size.x < yz_box.size.y and yz_box.size.x < yz_box.size.z, "YZ handle must be a vertical YZ plane")
	_check(xz_box.size.y < xz_box.size.x and xz_box.size.y < xz_box.size.z, "XZ handle must be a horizontal XZ plane")
	editor._deselect()
	_check(editor.tool_mode == "move", "clicking empty space/deselecting must keep the active Unity tool")
	editor._select(asset)
	editor._set_tool_mode("rotate")
	_check(editor.tool_mode == "rotate" and editor.get_node("EditorOverlay/Gizmo3D/RotateRing").visible, "rotate tool must show the yaw ring")
	editor._set_tool_mode("scale")
	# v5: scale gizmo exposes a uniform handle plus per-axis handles (continuous scale).
	_check(editor.tool_mode == "scale" and editor.get_node("EditorOverlay/Gizmo3D/ScaleHandle").visible, "scale tool must show the scale handle")
	_check(gizmo.get_node_or_null("ScaleHandle/Uniform") != null and gizmo.get_node_or_null("ScaleHandle/X") != null and gizmo.get_node_or_null("ScaleHandle/Y") != null and gizmo.get_node_or_null("ScaleHandle/Z") != null, "scale gizmo must expose uniform + X/Y/Z handles")
	editor._set_tool_mode("select")
	editor._cancel_active_mode()


func _run_reference_and_focus_tests(editor: Node3D) -> void:
	var actor := editor.get_node("ReferenceActor") as Node3D
	var before_position := actor.position
	var before_visibility := actor.visible
	editor._toggle_actor()
	_check(actor.visible != before_visibility, "reference actor top-bar toggle must change visibility")
	editor._toggle_actor()
	editor._change_room("t5", 0, false)
	_check(not actor.position.is_equal_approx(before_position), "reference actor must move when room bounds change")
	_check(not Rules.point_in_room(actor.position, editor.room_cells), "reference actor must stand outside the editable room")
	editor._focus_active()
	_check(editor.orbit_center.is_equal_approx(Rules.room_center_world(editor.room_cells)), "F with no selection must focus room center")
	var asset: Node3D = editor._place_at_free(Vector3(0.75, 0.0, 2.3), "kk_book_single", 0.0, Vector3.ONE * 0.28, false)
	editor._select(asset)
	editor._focus_active()
	_check(editor.orbit_center.is_equal_approx(Vector3(asset.global_position.x, 0.0, asset.global_position.z)), "F with selection must focus selected asset")


func _run_undo_redo_tests(editor: Node3D) -> void:
	editor._change_room("line3", 0, false)
	editor.undo_stack.clear()
	editor.redo_stack.clear()
	var before_first: Dictionary = editor._snapshot_state()
	editor._place_at_free(Vector3(0.45, 0.0, 0.55), "kk_book_single", 0.0, Vector3.ONE * 0.28, false)
	editor._push_undo_snapshot(before_first)
	var before_second: Dictionary = editor._snapshot_state()
	editor._place_at_free(Vector3(1.35, 0.0, 0.55), "kk_book_single", 0.0, Vector3.ONE * 0.28, false)
	editor._push_undo_snapshot(before_second)
	editor._draw_wall(Vector3(0.0, 0.0, 0.0), Vector3(CELL, 0.0, 0.0), "cb_wall", true)
	_check(editor.get_node("Placements").get_child_count() == 2 and editor.get_node("Walls").get_child_count() == 1, "undo setup must contain two assets and one wall")
	_check(editor._undo() and editor.get_node("Walls").get_child_count() == 0, "first undo must remove the complete wall draw operation")
	_check(editor._undo() and editor.get_node("Placements").get_child_count() == 1, "second undo must remove the second asset")
	_check(editor._redo() and editor._redo(), "redo twice must restore asset and wall")
	_check(editor.get_node("Placements").get_child_count() == 2 and editor.get_node("Walls").get_child_count() == 1, "redo must restore full assets+walls state")


func _run_template_tests(editor: Node3D) -> void:
	var kitchen_file := FileAccess.open(PRESET_DIR + "preset_kitchen_01.json", FileAccess.READ)
	var kitchen_parsed := Rules.parse_template_json(kitchen_file.get_as_text()) if kitchen_file != null else {"ok": false}
	if kitchen_file != null:
		kitchen_file.close()
	var kitchen_data := kitchen_parsed.get("data", {}) as Dictionary
	var expected_assets := (kitchen_data.get("assets", []) as Array).size()
	var expected_walls := (kitchen_data.get("walls", []) as Array).size()
	var expected_fixtures := (kitchen_data.get("fixtures", []) as Array).size()
	_check(editor._load_template("preset_kitchen_01") == expected_assets + expected_walls + expected_fixtures, "built-in kitchen template must load assets, walls and fixture")
	_check(editor.get_node("Placements").get_child_count() == expected_assets and editor.get_node("Walls").get_child_count() == expected_walls and editor.get_node("Fixtures").get_child_count() == expected_fixtures, "built-in template counts must match JSON")
	_check(editor._load_template("preset_bedroom_l3_01") > 0, "built-in bedroom template must load")
	_check(editor._load_template("preset_hall_t5_01") > 0, "built-in hall template must load")

	var before: Dictionary = editor._snapshot_state()
	var json_text: String = editor._save_template("__smoke_tpl")
	var parsed := Rules.parse_template_json(json_text)
	_check(bool(parsed.get("ok", false)), "user template save must use schema v2 with walls")
	if FileAccess.file_exists(TEMPLATE_PATH):
		editor._clear_all(false)
		_check(editor._load_template("__smoke_tpl") == (before.get("assets", []) as Array).size() + (before.get("walls", []) as Array).size() + (before.get("fixtures", []) as Array).size(), "user template must restore assets, walls and fixtures")
		var after: Dictionary = editor._snapshot_state()
		_check((after.get("assets", []) as Array).size() == (before.get("assets", []) as Array).size(), "user template must preserve asset count")
		_check((after.get("walls", []) as Array).size() == (before.get("walls", []) as Array).size(), "user template must preserve wall count")
		_check((after.get("fixtures", []) as Array).size() == (before.get("fixtures", []) as Array).size(), "user template must preserve fixture count")
		_check(editor._delete_template("__smoke_tpl"), "user template must be deletable")
		_check(not FileAccess.file_exists(TEMPLATE_PATH), "deleted user template file must be absent")
	else:
		print("CHANNEL_ASSET_EDITOR: NOTE user:// write unavailable (sandbox)")
	_check(not editor._delete_template("preset_kitchen_01"), "built-in template must be read-only")


func _run_camera_tests(editor: Node3D) -> void:
	editor.cam_pitch_target = 2.0
	editor.cam_distance_target = 99.0
	editor._clamp_camera_targets()
	_check(is_equal_approx(editor.cam_pitch_target, 1.45), "camera pitch must clamp at 1.45")
	_check(is_equal_approx(editor.cam_distance_target, 40.0), "camera distance must clamp at 40")
	editor.cam_pitch_target = -1.0
	editor.cam_distance_target = 1.0
	editor._clamp_camera_targets()
	_check(is_equal_approx(editor.cam_pitch_target, 0.12), "camera pitch lower clamp must prevent ground penetration")
	_check(is_equal_approx(editor.cam_distance_target, 6.0), "camera minimum distance must be 6")


func _run_select_interaction_regression(editor: Node3D) -> void:
	# Regression for the "cannot select anything after picking from the asset panel"
	# bug: after _on_asset_pressed/_place_ghost, selected_asset stayed non-empty, so a
	# subsequent left-click on an existing prop always took the place-branch and never
	# reached the pick/select branch. After the fix (place mode first attempts to pick
	# an existing placement), clicking an existing prop must exit place mode and select it.
	editor._change_room("line3", 0, false)
	editor._clear_all(false)
	# Enter place mode for a couch, then place it on empty ground.
	editor._on_asset_pressed("kk_couch")
	_check(not editor.selected_asset.is_empty() and editor.ghost.visible, "picking an asset from the panel must enter place mode with a ghost")
	editor.ghost.position = Vector3(0.45, 0.0, 0.55)
	editor._rebuild_ghost()
	editor.ghost.position = Vector3(0.45, 0.0, 0.55)
	var placed_couch: Node3D = editor._place_ghost()
	_check(placed_couch != null, "placing on empty ground must succeed")
	_check(editor.get_node("Placements").get_child_count() == 1, "one couch must exist after place")
	# Now, while still in place mode, click the existing couch: the fix must select it
	# (switch to selection) instead of trying to place another one on top of it.
	var cam := editor.get_node("CameraRig/Camera3D") as Camera3D
	var screen_pos := cam.unproject_position(placed_couch.global_position)
	var picked: Node3D = editor._pick_placement(screen_pos)
	_check(picked != null and picked == placed_couch, "place mode must pick the existing prop on click")
	editor._select(picked)
	_check(editor.selection != null and editor.selection == placed_couch, "clicking an existing prop must select it and leave place mode")
	_check(editor.selected_asset.is_empty(), "selecting an existing prop must clear place-mode selected_asset")
	# Select a wall the same way.
	editor._clear_all(false)
	editor._change_room("single", 0, false)
	editor._draw_wall(Vector3(0.0, 0.0, 0.0), Vector3(CELL, 0.0, 0.0), "cb_wall", false) 
	var wall := editor.get_node("Walls").get_child(0) as Node3D
	editor._select(wall)
	_check(editor.selection == wall and bool(wall.get_meta("is_wall", false)), "a wall must be selectable for door placement")
	editor._clear_all(false)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_ASSET_EDITOR: PASS v5 qwer-tools plane-handles continuous-scale stacking actors preset undo select-regression")
		quit(0)
	else:
		for failure in failures:
			push_error("CHANNEL_ASSET_EDITOR: %s" % failure)
		quit(1)
