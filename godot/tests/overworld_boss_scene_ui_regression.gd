extends SceneTree

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://channel_3d.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_host_preview()
	game.animation_duration_scale = 0.0
	var preview_instances: Dictionary = {}
	for raw_pos: Variant in game.room_rules.placed.keys():
		var preview_pos: Vector2i = raw_pos
		var preview_room: Dictionary = game.room_rules.placed[preview_pos]
		var preview_instance_id := str(preview_room.get("instance_id", ""))
		if preview_instances.has(preview_instance_id):
			continue
		preview_instances[preview_instance_id] = true
		check(bool(preview_room.get("visited", false)), "Boss preview rooms must use the authored explored presentation state")
	var preview_composer: Node = game.house_root.get_node_or_null("KenneyFormalComposer")
	check(preview_composer != null, "Boss preview must use the formal room compositor")
	if preview_composer != null:
		check(preview_composer.find_children("UnvisitedCover_*", "MeshInstance3D", true, false).is_empty(), "Explored Boss rooms must not render unvisited floor covers")
		check(int(preview_composer.get("prop_count")) > 0, "Explored Boss rooms must retain authored furniture props")
		var ground_generated: Node = preview_composer.get_node_or_null("GeneratedMap")
		check(ground_generated != null, "正式房间合成器必须生成实际房间模型根节点")
		if ground_generated != null:
			check(ground_generated.find_children("RoomVisual_*", "Node3D", true, false).size() == 12, "地面层实际生成模型必须覆盖12个房间实例")
			check(ground_generated.find_children("LayoutError_*", "Label3D", true, false).is_empty(), "地面层正式房间不能产生布局错误标记")
	var upper_composer: Node = game.house_root.get_node_or_null("KenneyFormalComposer_Floor_1")
	var basement_composer: Node = game.house_root.get_node_or_null("KenneyFormalComposer_Floor_-1")
	check(upper_composer != null, "二楼必须使用独立的正式房间合成器")
	check(basement_composer != null, "地下室必须使用独立的正式房间合成器")
	if upper_composer != null:
		var upper_generated: Node = upper_composer.get_node_or_null("GeneratedMap")
		check(upper_generated != null, "二楼必须生成独立的实际房间模型根节点")
		if upper_generated != null:
			check(upper_generated.find_children("RoomVisual_*", "Node3D", true, false).size() == 3, "二楼实际生成模型必须覆盖3个房间实例")
			check(upper_generated.find_children("LayoutError_*", "Label3D", true, false).is_empty(), "二楼正式房间不能产生布局错误标记")
	if basement_composer != null:
		var basement_generated: Node = basement_composer.get_node_or_null("GeneratedMap")
		check(basement_generated != null, "地下室必须生成独立的实际房间模型根节点")
		if basement_generated != null:
			check(basement_generated.find_children("RoomVisual_*", "Node3D", true, false).size() == 3, "地下室实际生成模型必须覆盖3个房间实例")
			check(basement_generated.find_children("LayoutError_*", "Label3D", true, false).is_empty(), "地下室正式房间不能产生布局错误标记")
	var originals: Array = []
	for child in game.house_root.get_children():
		originals.append([child.get_instance_id(), child.transform])
	var room_meshes: Array = []
	for mesh in game.house_root.find_children("*", "MeshInstance3D", true, false):
		if not game.house_root.get_node("LiliToken").is_ancestor_of(mesh):
			room_meshes.append([mesh.get_instance_id(), mesh.mesh, mesh.material_override, mesh.transform])
	game._prepare_boss_ready()
	game.boss_id = "channel_host"
	game.begin_boss_combat()
	game.set_process(false)
	var r = game.combat
	check(game.house_floor_view == int(r.cell_floors.get(r.player_pos, 0)), "Boss进入时应默认显示玩家所在楼层")
	var upper_world: Vector3 = game._house_world(Vector2i(2, 7))
	var basement_world: Vector3 = game._house_world(Vector2i(3, -6))
	check(is_equal_approx(upper_world.x, game.HOUSE_CELL * 2.0) and is_equal_approx(upper_world.z, 0.0), "二楼房间必须归一到蛋糕塔的楼层本地坐标")
	check(is_equal_approx(basement_world.x, game.HOUSE_CELL * 3.0) and is_equal_approx(basement_world.z, game.HOUSE_CELL), "地下室房间必须归一到蛋糕塔的楼层本地坐标")
	var view_round: int = r.round_number
	var view_energy: int = r.energy
	mouse(game.hud, game.hud.FLOOR_RAIL_TOP_RECT.get_center(), true)
	check(game.house_floor_view == 1, "楼层滑轨应能切换到二楼视图")
	check(r.round_number == view_round and r.energy == view_energy, "切换楼层视图不能推进回合或消耗行动力")
	game.set_house_floor_view(game.FLOOR_VIEW_OVERVIEW)
	check(game.house_floor_view == game.FLOOR_VIEW_OVERVIEW, "总览按钮应恢复三层总览")
	game.set_house_floor_view(int(r.cell_floors.get(r.player_pos, 0)))
	check(game.house_floor_view == int(r.cell_floors.get(r.player_pos, 0)), "回到玩家按钮应恢复玩家所在楼层")
	game.set_house_floor_view(1)
	check(upper_composer != null and upper_composer.visible, "切到二楼时应显示二楼实际生成模型")
	check(preview_composer != null and not preview_composer.visible, "切到二楼时应隐藏地面层实际生成模型")
	check(basement_composer != null and not basement_composer.visible, "切到二楼时应隐藏地下室实际生成模型")
	game.set_house_floor_view(game.FLOOR_VIEW_OVERVIEW)
	check(preview_composer != null and preview_composer.visible, "三层总览应恢复地面层实际生成模型")
	check(upper_composer != null and upper_composer.visible, "三层总览应恢复二楼实际生成模型")
	check(basement_composer != null and basement_composer.visible, "三层总览应恢复地下室实际生成模型")
	var stair_overlay: Node = game.house_root.get_node("WorldBossOverlay/Hints")
	var stair_step_count: int = int(stair_overlay.find_children("StairStep_*", "MeshInstance3D", true, false).size())
	check(stair_step_count >= 6, "Boss地图应在楼梯入口和落点显示可见的三级楼梯标记")
	check(game.room_rules.instance_count() == 18, "Boss试玩必须包含三层正式终局的18个房间实例")
	var preview_floors: Dictionary = {}
	for raw_floor_pos: Variant in game.room_rules.placed.keys():
		var floor_room: Dictionary = game.room_rules.placed[raw_floor_pos]
		preview_floors[int(floor_room.get("floor", 0))] = true
	check(preview_floors.has(-1) and preview_floors.has(0) and preview_floors.has(1), "Boss试玩必须同时包含地下室、地面层和二楼")
	check(game.room_rules.stair_links.size() >= 2, "三层地图必须至少提供二楼与地下室楼梯连接")
	for entry in originals:
		var original = instance_from_id(entry[0])
		check(original != null, "Boss entry must retain each original house scene node")
		if original != null:
			check(original.transform == entry[1], "Boss entry must not reposition original assets or player")
	check(game.has_method("world_boss_stair_action"), "Boss战必须提供可交互的楼梯动作查询")
	check(game.has_method("use_world_boss_stair"), "Boss战必须提供可交互的楼梯使用动作")
	var upper_pick_cell := Vector2i(2, 7)
	game.set_house_floor_view(1)
	var upper_pick_world: Vector3 = game.house_root.to_global(game._house_world(upper_pick_cell))
	var upper_pick_view: Vector2 = game.camera.unproject_position(upper_pick_world)
	check(game.battle_cell_from_viewport(upper_pick_view) == upper_pick_cell, "二楼视图点击应按二楼高度拾取正确战斗格")
	var original_player_pos: Vector2i = r.player_pos
	var original_energy: int = r.energy
	var action_stair: Dictionary = r.stair_links[0]
	var action_stair_from: Vector2i = action_stair.get("from", Vector2i(-999, -999))
	var action_stair_to: Vector2i = action_stair.get("to", Vector2i(-999, -999))
	r.player_pos = action_stair_from
	r.energy = 5
	game._refresh_world_boss()
	if game.has_method("world_boss_stair_action") and game.has_method("use_world_boss_stair"):
		var stair_action: Dictionary = game.world_boss_stair_action()
		check(stair_action.get("destination", game.INVALID_CELL) == action_stair_to, "站在楼梯入口时应显示正确的目标楼层")
		var stair_cost := int(stair_action.get("cost", 0))
		check(stair_cost > 0 and bool(stair_action.get("can_use", false)), "楼梯动作应计算跨层AP并在行动力足够时可用")
		var used_stair: bool = game.use_world_boss_stair()
		check(used_stair and r.player_pos == action_stair_to, "使用楼梯应把玩家移动到目标楼层出口")
		check(r.energy == 5 - stair_cost, "使用楼梯应扣除包含跨层成本的行动力")
		check(game.house_floor_view == int(r.cell_floors.get(action_stair_to, 0)), "跨层后应自动切换到玩家所在楼层")
		r.player_pos = action_stair_to
		r.energy = 5
		game._refresh_world_boss()
		check(game.use_world_boss_stair() and r.player_pos == action_stair_from, "楼梯应支持从目标楼层返回原楼层")
	r.player_pos = original_player_pos
	r.energy = original_energy
	game._refresh_world_boss()
	r.player_pos = action_stair_from
	r.energy = 5
	game._refresh_world_boss()
	mouse(game.hud, game.hud.STAIR_ACTION_RECT.get_center(), true)
	check(r.player_pos == action_stair_to, "楼梯提示按钮应能触发玩家跨层")
	check(game.house_floor_view == int(r.cell_floors.get(action_stair_to, 0)), "楼梯提示按钮完成后应切换到目标楼层")
	r.player_pos = original_player_pos
	r.energy = original_energy
	game._refresh_world_boss()
	game.set_house_floor_view(int(r.cell_floors.get(r.player_pos, 0)))
	var boss = game.house_root.get_node("WorldBossOverlay/BossToken")
	var boss_identity: int = boss.get_instance_id()
	game._refresh_world_boss()
	check(is_instance_id_valid(boss_identity), "UI refresh must not replace the Boss actor")
	check(game.hud._design_world_rect("world_boss") == game.hud._design_world_rect("combat"), "Boss uses the existing combat viewport layout")
	check(r.graph.size() >= 24 and r.player_pos == Vector2i(0, 0), "Boss UI is backed by the expanded physical overworld grid")
	var has_upper_floor := false
	var has_basement := false
	for raw_elevation: Variant in r.cell_elevations.values():
		has_upper_floor = has_upper_floor or float(raw_elevation) > 0.0
		has_basement = has_basement or float(raw_elevation) < 0.0
	check(has_upper_floor and has_basement, "战斗格必须携带二楼与地下室高度")
	var stair_link_ok := false
	for stair: Dictionary in game.room_rules.stair_links:
		var stair_from_raw: Array = stair.get("from", [-999, -999])
		var stair_to_raw: Array = stair.get("to", [-999, -999])
		var stair_from := Vector2i(int(stair_from_raw[0]), int(stair_from_raw[1]))
		var stair_to := Vector2i(int(stair_to_raw[0]), int(stair_to_raw[1]))
		if r.graph.get(stair_from, []).has(stair_to) and r.graph.get(stair_to, []).has(stair_from):
			stair_link_ok = true
			break
	check(stair_link_ok, "楼梯必须成为大地图 Boss 战的双向战斗连接")
	if stair_link_ok:
		var first_stair: Dictionary = game.room_rules.stair_links[0]
		var first_from_raw: Array = first_stair.get("from", [0, 0])
		var first_to_raw: Array = first_stair.get("to", [0, 0])
		var first_from := Vector2i(int(first_from_raw[0]), int(first_from_raw[1]))
		var first_to := Vector2i(int(first_to_raw[0]), int(first_to_raw[1]))
		var saved_player_pos: Vector2i = r.player_pos
		r.player_pos = first_from
		check(r.player_move_cost(first_to) > r.move_cost, "跨楼层移动应增加楼梯行动力成本")
		r.player_pos = saved_player_pos
	check(str(game.room_rules.placed[Vector2i(1, 0)].get("id", "")) == "gallery" and str(game.room_rules.placed[Vector2i(4, 0)].get("id", "")) == "study", "Boss preview uses the formal three-cell and five-cell room definitions")
	r.player_pos = Vector2i(0, 0)
	r.energy = 5
	game.world_boss_click(Vector2i(0, 2))
	check(r.player_pos == Vector2i(0, 2), "clicking a distant map cell walks through each legal grid step")
	r.player_pos = Vector2i(0, 0)
	r.energy = 5
	var move_key := InputEventKey.new()
	move_key.keycode = KEY_D
	move_key.pressed = true
	game.hud._input(move_key)
	check(game.current_room_pos == Vector2i(1, 0), "existing D key follows the right-hand door into the three-cell gallery")
	# Exercise existing public controls, not the separate prototype action menu.
	game.selected_card = 0
	game.cancel_selected_card()
	check(game.selected_card == -1, "existing cancel control must work on the overworld")
	game.animation_duration_scale = 0.01
	var old_round: int = r.round_number
	game.end_combat_turn()
	check(r.round_number == old_round + 1, "existing end-turn control advances Boss combat")
	check(not game.battle_turn_events.is_empty(), "Boss end-turn must expose movement or attack events to the map presentation")
	for _frame in range(20):
		await process_frame
	check(not game.animation_busy, "Boss movement and attack presentation must finish before the next player action")
	# Real HUD gestures must select and drop a placement card onto the map.
	r.player_pos = r.graph[r.enemy_pos][0]
	r.energy = 5
	r.hand.assign(["jab", "keepsake"])
	game._refresh_world_boss()
	for frame in range(3):
		await process_frame
	var target_world: Vector3 = game.house_root.to_global(game._house_world(r.room_nodes[r.enemy_pos].cell))
	var target_view: Vector2 = game.camera.unproject_position(target_world)
	check(game.battle_cell_from_viewport(target_view) == r.enemy_pos, "shared target picking maps physical rooms to combat nodes")
	check(game.hud.combat_card_rects.size() == 2, "existing HUD renders the actual Boss hand")
	if game.hud.combat_card_rects.size() == 2:
		var card_point: Vector2 = game.hud.combat_card_rects[0].position + Vector2(16, 16)
		mouse(game.hud, card_point, true)
		check(game.selected_card == 0 and game.hud.dragged_combat_card == 0, "existing card press starts placement drag")
		game.set_battle_hover(target_view)
		check(game.hovered_battle_cell == r.enemy_pos, "dragging cards highlights the hovered map room")
		var hp: int = r.enemy_hp
		var drop := InputEventMouseButton.new()
		drop.button_index = MOUSE_BUTTON_LEFT
		drop.pressed = false
		drop.position = game.hud.world_view_rect_screen.position + target_view
		game.hud._gui_input(drop)
		check(r.enemy_hp == hp - 2 and r.hand.size() == 1, "dropping the existing spike card deals damage and consumes exactly one card")
	game.selected_card = 0
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game.hud._input(escape)
	check(game.selected_card == -1, "Escape cancels Boss card selection")
	var yaw: float = game.house_camera_yaw
	game.orbit_battle_camera(Vector2(20, 0))
	check(not is_equal_approx(yaw, game.house_camera_yaw), "shared orbit control drives the original map camera")
	var pan_before: Vector3 = game.house_camera_target
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	middle.position = game.hud.world_view_rect_screen.get_center()
	game.hud._gui_input(middle)
	var motion := InputEventMouseMotion.new()
	motion.position = middle.position + Vector2(20, 0)
	motion.relative = Vector2(20, 0)
	game.hud._gui_input(motion)
	middle.pressed = false
	game.hud._gui_input(middle)
	check(not pan_before.is_equal_approx(game.house_camera_target), "middle-button gesture pans the Boss map through the shared HUD")
	r.player_pos = r.anchors.keys()[0]
	r.energy = 5
	game._refresh_world_boss()
	var anchor_hp: int = r.anchors[r.player_pos]
	mouse(game.hud, game.hud.BOSS_ANCHOR_ACTION_RECT.get_center(), true)
	check(r.anchors[r.player_pos] == anchor_hp - 1 and r.energy == 3, "shared Boss mechanism button consumes 2 AP without moving player")
	for entry in room_meshes:
		var mesh = instance_from_id(entry[0])
		check(mesh != null, "room meshes survive Boss preparation, entry and combat actions")
		if mesh != null:
			check(mesh.mesh == entry[1] and mesh.material_override == entry[2] and mesh.transform == entry[3], "combat overlays must not replace room geometry, materials or layout")
	game.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("OVERWORLD_SCENE_UI: PASS")
	quit(0 if failures.is_empty() else 1)


func mouse(hud, design_point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = hud.ui_offset + design_point * hud.ui_scale
	hud._gui_input(event)
