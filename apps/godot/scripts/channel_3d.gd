extends Node3D

const RoomRules = preload("res://scripts/room_rules.gd")
const CombatRules = preload("res://scripts/combat_rules.gd")
const WebContentAdapter = preload("res://scripts/web_content_adapter.gd")
const CharacterPresenter = preload("res://scripts/character_presenter.gd")

const EXE_SOURCE_ID := "CabinSlice_织梦频道.exe@EEC4C574CC22"
const SNAPSHOT_ROOT := "res://data/exe_snapshot/"
const PRESENTATION_MANIFEST := "res://data/presentation_manifest.json"
const RUN_SAVE_PATH := "user://channel_run_v1.json"
const HOUSE_CELL := 3.4
const BATTLE_CELL := 2.35

const COL_INK := Color("161b24")
const COL_PAPER := Color("f7e8c5")
const COL_TEAL := Color("23aa9b")
const COL_TEAL_DARK := Color("164f53")
const COL_GOLD := Color("f2a51e")
const COL_MAGENTA := Color("d63b72")
const COL_GREEN := Color("66b66d")
const COL_RED := Color("d9574f")
const COL_BLUE := Color("4c92bd")
const COL_GRID_DARK := Color("26343b")
const COL_GRID_A := Color("e8ddc4")
const COL_GRID_B := Color("d6e6da")
const COL_PORTAL := Color("7863a5")
const COL_FLOOR_H0 := Color("70777b")
const COL_FLOOR_H1 := Color("50575c")
const COL_FLOOR_H2 := Color("343b40")
const COL_WALL_GREEN := Color("3d6e53")

const CAMERA_DIRECTION := Vector3(9.5, 12.5, 11.5)
const CAMERA_ZOOM_MIN := 0.55
const CAMERA_ZOOM_MAX := 1.35
const INVALID_CELL := Vector2i(-999, -999)
const UNITY_ROOM_DROP_DURATION := 0.25
const UNITY_ROOM_DROP_HEIGHT_CELLS := 0.65
const UNITY_ROOM_START_SCALE := 0.94
const UNITY_ACTOR_STEP_DURATION := 0.25
const UNITY_ACTOR_SETTLE_DURATION := 0.12
const UNITY_CARD_HALF_FLIP_DURATION := 0.10
const ENEMY_STEP_DURATION := 0.18
const ENEMY_ATTACK_DURATION := 0.22

@onready var world_container: SubViewportContainer = $WorldLayer/WorldContainer
@onready var world_viewport: SubViewport = $WorldLayer/WorldContainer/WorldViewport
@onready var world_root: Node3D = $WorldLayer/WorldContainer/WorldViewport/WorldRoot
@onready var camera: Camera3D = $WorldLayer/WorldContainer/WorldViewport/WorldRoot/CameraRig/Camera3D
@onready var house_root: Node3D = $WorldLayer/WorldContainer/WorldViewport/WorldRoot/HouseRoot
@onready var battle_root: Node3D = $WorldLayer/WorldContainer/WorldViewport/WorldRoot/BattleRoot
@onready var hud: Control = $HUD/HUDRoot

@export_range(0.0, 4.0, 0.05) var animation_duration_scale := 1.0

var content: Dictionary = {}
var presentation: Dictionary = {}
var room_rules = RoomRules.new()
var combat = null
var rng := RandomNumberGenerator.new()

var run_seed := 2522061406
var phase := "omen"
var room_catalog: Array[Dictionary] = []
var remaining_rooms: Array[Dictionary] = []
var active_relics: Array[String] = []
var run_deck: Array[String] = []
var reward_options: Array[Dictionary] = []
var reward_origin := ""
var event_context := ""
var event_room_pos := Vector2i.ZERO
var omen_options: Array[String] = []
var selected_frontier := Vector2i.ZERO
var build_offers: Array[Dictionary] = []
var selected_offer := 0
var offer_rotation := 0
var current_room_pos := Vector2i.ZERO
var pending_room_pos := Vector2i.ZERO
var selected_card := -1
var run_progress := 1
var player_hp := 6
var player_max_hp := 6
var player_speed := 3
var status_message := "频道正在预热。"
var event_log: Array[String] = []
var world_view_rect := Rect2(20, 96, 952, 578)
var battle_camera_target := Vector3.ZERO
var battle_camera_fit_size := 12.0
var battle_camera_distance := 20.0
var hovered_battle_cell := INVALID_CELL
var animation_busy := false
var active_animation_kind := ""
var active_motion_tween: Tween = null
var build_preview_tween: Tween = null
var lab_root: Node3D = null
var home_tests_open := false
var lab_move_axis := 0.0
var lab_jump_held := false
var lab_jump_was_down := false
var lab_velocity := Vector3.ZERO
var lab_player: Node3D = null
var lab_platforms: Array[Dictionary] = []
var lab_collectibles: Array[Dictionary] = []
var lab_collected := 0
var puzzle_board: Array[int] = []
var puzzle_moves_left := 42
var puzzle_refreshes_left := 3
var puzzle_status := ""
var search_targets: Array[Dictionary] = []
var search_found := 0
var chase_sentence := "the signal hides behind the painted door"
var chase_typed := 0
var chase_police_progress := 0.0
var chase_player_progress := 5.0
var chase_started := false
var chase_countdown := 0.0
var chase_result := ""
var lab_camera_target := Vector3.ZERO
var lab_camera_yaw := 0.0
var lab_camera_pitch := 0.24
var lab_camera_distance := 14.0


func _ready() -> void:
	_configure_environment()
	presentation = _load_json_dictionary(PRESENTATION_MANIFEST)
	lab_root = Node3D.new()
	lab_root.name = "LabRoot"
	world_root.add_child(lab_root)
	hud.game = self
	hud.sync_layout()
	reset_run(run_seed)
	go_home()


func _process(delta: float) -> void:
	if phase == "lab_sideview":
		var keyboard_axis := 0.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			keyboard_axis -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			keyboard_axis += 1.0
		lab_move_axis = keyboard_axis
		var jump_down := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE)
		if jump_down and not lab_jump_was_down:
			lab_jump_held = true
		lab_jump_was_down = jump_down
		_update_sideview(delta)
	elif phase == "lab_chase":
		_update_chase(delta)


func _configure_environment() -> void:
	var environment_node: WorldEnvironment = $WorldLayer/WorldContainer/WorldViewport/WorldRoot/WorldEnvironment
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b171d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8bc8be")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment


func set_world_view_rect(rect: Rect2) -> void:
	if rect.size.x < 32.0 or rect.size.y < 32.0:
		return
	var changed := not world_view_rect.is_equal_approx(rect)
	world_view_rect = rect
	world_container.position = rect.position
	world_container.size = rect.size
	if not changed or camera == null:
		return
	if phase == "combat" and combat != null:
		reset_battle_camera()
	else:
		_set_house_camera()


func screen_to_world_view(screen_pos: Vector2) -> Vector2:
	return screen_pos - world_view_rect.position


func is_world_view_point(screen_pos: Vector2) -> bool:
	return world_view_rect.has_point(screen_pos)


func reset_run(seed_value: int = 0) -> void:
	_cancel_dynamic_effect()
	world_container.visible = true
	house_root.visible = true
	battle_root.visible = false
	if lab_root != null:
		lab_root.visible = false
	if seed_value != 0:
		run_seed = seed_value
	rng.seed = run_seed
	content = WebContentAdapter.new(SNAPSHOT_ROOT, EXE_SOURCE_ID).build_content(run_seed)
	room_catalog.clear()
	for raw_room in content.get("rooms", []):
		room_catalog.append((raw_room as Dictionary).duplicate(true))
	remaining_rooms = room_catalog.duplicate(true)
	room_rules.reset(content.get("start_room", {}))
	room_rules.placed[Vector2i.ZERO]["revealed"] = true
	room_rules.placed[Vector2i.ZERO]["visited"] = true
	active_relics.clear()
	run_deck.clear()
	for raw_card in content.get("starter_deck", []):
		run_deck.append(str(raw_card))
	reward_options.clear()
	reward_origin = ""
	event_context = ""
	omen_options.clear()
	var relic_pool: Array = content.get("relic_pool", []).duplicate()
	_shuffle_variants(relic_pool)
	for i in range(mini(2, relic_pool.size())):
		omen_options.append(str(relic_pool[i]))
	current_room_pos = Vector2i.ZERO
	pending_room_pos = Vector2i.ZERO
	selected_frontier = Vector2i.ZERO
	build_offers.clear()
	selected_offer = 0
	offer_rotation = 0
	selected_card = -1
	hovered_battle_cell = INVALID_CELL
	run_progress = 1
	player_hp = 6
	player_max_hp = 6
	player_speed = int(content.get("run_rules", {}).get("base_speed", 3))
	combat = null
	phase = "omen"
	event_log.clear()
	status_message = "行前先从两枚预兆里选一枚；玄关只作为出发坐标。"
	build_house_world()
	_set_house_camera()
	_refresh_hud()


func start_new_run(tutorial_mode: bool = false) -> void:
	reset_run(run_seed + 1 if phase != "home" else run_seed)
	status_message = "教学提示：先选预兆，再点黄色扩建格；战斗中绿色=移动、金色=放置。" if tutorial_mode else "先从两枚行前预兆中选一枚，节目就会正式开播。"
	_refresh_hud()
	_save_run()


func go_home() -> void:
	_cancel_dynamic_effect()
	phase = "home"
	home_tests_open = false
	house_root.visible = false
	battle_root.visible = false
	if lab_root != null:
		lab_root.visible = false
	world_container.visible = false
	status_message = "电视机预热完毕。"
	_refresh_hud()


func has_saved_run() -> bool:
	return FileAccess.file_exists(RUN_SAVE_PATH)


func continue_saved_run() -> bool:
	if not has_saved_run():
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(RUN_SAVE_PATH))
	if not parsed is Dictionary or str(parsed.get("source", "")) != EXE_SOURCE_ID:
		return false
	var save: Dictionary = parsed
	reset_run(int(save.get("seed", run_seed)))
	player_hp = int(save.get("player_hp", 6))
	player_max_hp = int(save.get("player_max_hp", 6))
	player_speed = int(save.get("player_speed", content.get("run_rules", {}).get("base_speed", 3)))
	run_progress = int(save.get("run_progress", 1))
	run_deck.assign(save.get("run_deck", content.get("starter_deck", [])))
	active_relics.assign(save.get("active_relics", []))
	reward_options.assign(save.get("reward_options", []))
	reward_origin = str(save.get("reward_origin", ""))
	room_rules.placed.clear()
	for raw_entry in save.get("placed", []):
		var entry: Dictionary = raw_entry
		var pos := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		var room: Dictionary = (entry.get("room", {}) as Dictionary).duplicate(true)
		room["pos"] = pos
		room_rules.placed[pos] = room
	var remaining_ids: Array = save.get("remaining_ids", [])
	remaining_rooms.clear()
	for room: Dictionary in room_catalog:
		if str(room.get("id", "")) in remaining_ids:
			remaining_rooms.append(room.duplicate(true))
	current_room_pos = _array_to_pos(save.get("current_room", [0, 0]))
	pending_room_pos = _array_to_pos(save.get("pending_room", [0, 0]))
	phase = str(save.get("phase", "explore"))
	if phase not in ["omen", "explore", "room_ready", "reward"]:
		phase = "room_ready" if not bool(current_room().get("completed", false)) else "explore"
	world_container.visible = true
	house_root.visible = true
	battle_root.visible = false
	status_message = "已接上上集：房间、生命、预兆和本局牌库都已恢复。"
	build_house_world()
	_set_house_camera()
	_refresh_hud()
	return true


func toggle_home_tests() -> void:
	if phase != "home":
		return
	home_tests_open = not home_tests_open
	_refresh_hud()


func start_combat_lab(room_id: String = "hall") -> void:
	var room := _find_catalog_room(room_id)
	if room.is_empty():
		return
	world_container.visible = true
	house_root.visible = false
	if lab_root != null:
		lab_root.visible = false
	start_combat(room)
	combat.hand.assign(["jab", "guard", "brace", "fling"])
	combat.energy = 4
	status_message = "意图实验：未揭示怪物最多埋伏一拍，随后会巡逻；蓝色编号显示逐步路径。"
	build_battle_world()
	_refresh_hud()


func _find_catalog_room(room_id: String) -> Dictionary:
	for room: Dictionary in room_catalog:
		if str(room.get("id", "")) == room_id:
			return room
	return {}


func start_sideview_lab() -> void:
	_prepare_lab("lab_sideview")
	lab_platforms = [
		{"x": -7.5, "y": 0.0, "w": 15.0},
		{"x": -4.6, "y": 1.4, "w": 2.6},
		{"x": -0.8, "y": 2.6, "w": 2.4},
		{"x": 3.2, "y": 1.7, "w": 3.0},
	]
	for platform: Dictionary in lab_platforms:
		_add_box(lab_root, "Platform", Vector3(float(platform["x"]) + float(platform["w"]) * 0.5, float(platform["y"]) - 0.2, 0.0), Vector3(float(platform["w"]), 0.4, 2.6), _material(COL_TEAL_DARK))
	lab_player = Node3D.new()
	lab_player.name = "SideviewLili"
	lab_player.position = Vector3(-6.3, 0.65, 0.0)
	lab_root.add_child(lab_player)
	_add_cylinder(lab_player, "Body", Vector3.ZERO, 0.35, 1.3, _material(COL_TEAL))
	_add_cylinder(lab_player, "Hat", Vector3(0, 0.76, 0), 0.46, 0.18, _material(COL_RED))
	lab_collectibles = [
		{"pos": Vector3(-3.7, 2.2, 0.0), "taken": false},
		{"pos": Vector3(0.2, 3.4, 0.0), "taken": false},
		{"pos": Vector3(4.1, 2.5, 0.0), "taken": false},
	]
	for i in range(lab_collectibles.size()):
		var item := Node3D.new()
		item.name = "Signal_%d" % i
		item.position = lab_collectibles[i]["pos"]
		lab_root.add_child(item)
		_add_cylinder(item, "Pickup", Vector3.ZERO, 0.28, 0.20, _material(COL_GOLD, false, 0.08))
		_add_label(item, "Glyph", "频", Vector3(0, 0.48, 0), COL_GOLD, 28)
	lab_velocity = Vector3.ZERO
	lab_jump_was_down = false
	lab_collected = 0
	status_message = "WASD / 方向键移动，W / ↑ / 空格跳跃。收集 3 枚频道信号。"
	_set_lab_camera(Vector3(0.0, 2.6, 0.0), 17.0)
	_refresh_hud()


func set_sideview_input(axis: float, jump_pressed: bool) -> void:
	lab_move_axis = clampf(axis, -1.0, 1.0)
	if jump_pressed:
		lab_jump_held = true


func _update_sideview(delta: float) -> void:
	if lab_player == null:
		return
	lab_velocity.x = lab_move_axis * 5.2
	var on_ground := _sideview_floor_at(lab_player.position.x, lab_player.position.y) > -100.0 and absf(lab_player.position.y - _sideview_floor_at(lab_player.position.x, lab_player.position.y)) < 0.08
	if lab_jump_held and on_ground:
		lab_velocity.y = 8.6
	lab_jump_held = false
	lab_velocity.y -= 22.0 * delta
	var previous_y := lab_player.position.y
	lab_player.position += lab_velocity * delta
	lab_player.position.x = clampf(lab_player.position.x, -7.1, 7.1)
	var floor_y := _sideview_floor_at(lab_player.position.x, previous_y)
	if lab_velocity.y <= 0.0 and lab_player.position.y <= floor_y:
		lab_player.position.y = floor_y
		lab_velocity.y = 0.0
	if lab_player.position.y < -3.0:
		lab_player.position = Vector3(-6.3, 0.65, 0.0)
		lab_velocity = Vector3.ZERO
	for i in range(lab_collectibles.size()):
		if bool(lab_collectibles[i]["taken"]):
			continue
		var pickup_pos: Vector3 = lab_collectibles[i]["pos"]
		if lab_player.position.distance_to(pickup_pos) < 0.9:
			lab_collectibles[i]["taken"] = true
			lab_collected += 1
			var pickup := lab_root.get_node_or_null("Signal_%d" % i)
			if pickup != null:
				pickup.visible = false
			status_message = "收到频道信号 %d/3。" % lab_collected
			_refresh_hud()


func _sideview_floor_at(x_value: float, previous_y: float) -> float:
	var best := -999.0
	for platform: Dictionary in lab_platforms:
		var left := float(platform["x"])
		var right := left + float(platform["w"])
		var top := float(platform["y"]) + 0.65
		if x_value >= left and x_value <= right and previous_y >= top - 0.35:
			best = maxf(best, top)
	return best


func start_puzzle_lab() -> void:
	_prepare_lab("lab_puzzle")
	event_context = ""
	_shuffle_puzzle()
	status_message = "雪花拼图：点击空格上下左右的数字，把 1–8 拼回顺序。"
	_refresh_hud()


func puzzle_slide(index: int) -> void:
	if phase != "lab_puzzle" or index < 0 or index >= puzzle_board.size() or puzzle_moves_left <= 0:
		return
	var empty := puzzle_board.find(0)
	if absi(index / 3 - empty / 3) + absi(index % 3 - empty % 3) != 1:
		puzzle_status = "只能推动空格旁边的数字。"
		_refresh_hud()
		return
	var value := puzzle_board[index]
	puzzle_board[index] = 0
	puzzle_board[empty] = value
	puzzle_moves_left -= 1
	puzzle_status = "拼合完成！" if puzzle_board == [1, 2, 3, 4, 5, 6, 7, 8, 0] else "继续拼。"
	if puzzle_board == [1, 2, 3, 4, 5, 6, 7, 8, 0] and event_context == "puzzle":
		finish_event_trial(true)
	elif puzzle_moves_left <= 0 and event_context == "puzzle":
		finish_event_trial(false)
	_refresh_hud()


func puzzle_refresh() -> void:
	if phase != "lab_puzzle" or puzzle_refreshes_left <= 0:
		return
	puzzle_refreshes_left -= 1
	_shuffle_puzzle(false)
	_refresh_hud()


func puzzle_slide_from_offset(offset: int) -> void:
	if phase != "lab_puzzle":
		return
	var empty := puzzle_board.find(0)
	var source := empty + offset
	if source >= 0 and source < puzzle_board.size():
		puzzle_slide(source)


func _shuffle_puzzle(reset_refreshes: bool = true) -> void:
	puzzle_board.assign([1, 2, 3, 4, 5, 6, 7, 8, 0])
	var previous_empty := -1
	for i in range(24):
		var empty := puzzle_board.find(0)
		var options: Array[int] = []
		for index in range(9):
			if index != previous_empty and absi(index / 3 - empty / 3) + absi(index % 3 - empty % 3) == 1:
				options.append(index)
		var choice := options[rng.randi_range(0, options.size() - 1)]
		previous_empty = empty
		puzzle_board[empty] = puzzle_board[choice]
		puzzle_board[choice] = 0
	puzzle_moves_left = 42
	if reset_refreshes:
		puzzle_refreshes_left = 3
	puzzle_status = "剩余步数 %d" % puzzle_moves_left


func start_search_lab() -> void:
	_prepare_lab("lab_search")
	event_context = ""
	search_targets = [
		{"name": "铜钥匙", "pos": Vector3(-3.7, 0.50, -1.65), "found": false},
		{"name": "红线轴", "pos": Vector3(0.4, 1.60, 1.35), "found": false},
		{"name": "坏磁带", "pos": Vector3(3.65, 1.93, -0.6), "found": false},
	]
	_add_box(lab_root, "Floor", Vector3(0.0, -0.12, 0.0), Vector3(10.5, 0.24, 7.0), _material(Color("8a795e")))
	_add_box(lab_root, "BackWall", Vector3(0.0, 2.0, -3.38), Vector3(10.5, 4.0, 0.24), _material(Color("355b58")))
	_add_box(lab_root, "LeftWall", Vector3(-5.13, 2.0, 0.0), Vector3(0.24, 4.0, 7.0), _material(Color("294745")))
	_add_box(lab_root, "Table", Vector3(0.4, 0.62, 1.35), Vector3(3.2, 1.24, 1.6), _material(Color("604934")))
	_add_box(lab_root, "Cabinet", Vector3(3.65, 0.92, -0.6), Vector3(1.8, 1.84, 1.8), _material(Color("3e625b")))
	_add_box(lab_root, "Rug", Vector3(-3.7, 0.08, -1.65), Vector3(2.9, 0.12, 2.1), _material(Color("8b4156")))
	_add_box(lab_root, "Sofa", Vector3(-1.8, 0.52, -2.35), Vector3(3.2, 1.0, 0.9), _material(Color("6a6f4c")))
	_add_box(lab_root, "SofaBack", Vector3(-1.8, 1.15, -2.72), Vector3(3.2, 1.4, 0.22), _material(Color("5b6041")))
	_add_box(lab_root, "Picture", Vector3(1.9, 2.35, -3.20), Vector3(1.6, 1.15, 0.12), _material(COL_PAPER))
	_add_label(lab_root, "PictureGlyph", "CH", Vector3(1.9, 2.55, -3.10), COL_RED, 30)
	for i in range(search_targets.size()):
		var item := Node3D.new()
		item.name = "SearchItem_%d" % i
		item.position = search_targets[i]["pos"]
		lab_root.add_child(item)
		if i == 0:
			_add_box(item, "KeyStem", Vector3.ZERO, Vector3(1.05, 0.16, 0.22), _material(COL_GOLD, false, 0.08))
			_add_cylinder(item, "KeyRing", Vector3(-0.55, 0.0, 0.0), 0.29, 0.16, _material(COL_GOLD, false, 0.08))
		elif i == 1:
			_add_cylinder(item, "Spool", Vector3.ZERO, 0.38, 0.58, _material(COL_RED, false, 0.08))
			_add_cylinder(item, "SpoolTop", Vector3(0, 0.34, 0), 0.48, 0.10, _material(COL_PAPER, false, 0.04))
		else:
			_add_box(item, "Tape", Vector3.ZERO, Vector3(0.95, 0.24, 0.66), _material(COL_GOLD, false, 0.08))
			_add_cylinder(item, "TapeCoreA", Vector3(-0.22, 0.15, 0), 0.13, 0.14, _material(COL_INK))
			_add_cylinder(item, "TapeCoreB", Vector3(0.22, 0.15, 0), 0.13, 0.14, _material(COL_INK))
	search_found = 0
	status_message = "3D 微缩搜物：中键拖动旋转、滚轮缩放；点击三件微微发光的小物。"
	_set_search_camera_defaults()
	_refresh_hud()


func search_pick_from_view(view_pos: Vector2) -> bool:
	if phase != "lab_search":
		return false
	var ray_origin := camera.project_ray_origin(view_pos)
	var ray_direction := camera.project_ray_normal(view_pos).normalized()
	var best_index := -1
	var best_distance := 0.82
	for i in range(search_targets.size()):
		if bool(search_targets[i]["found"]):
			continue
		var pos: Vector3 = search_targets[i]["pos"]
		var along_ray := maxf(0.0, (pos - ray_origin).dot(ray_direction))
		var closest_point := ray_origin + ray_direction * along_ray
		var distance := closest_point.distance_to(pos)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	if best_index < 0:
		return false
	search_targets[best_index]["found"] = true
	search_found += 1
	var node := lab_root.get_node_or_null("SearchItem_%d" % best_index)
	if node != null:
		node.visible = false
	status_message = "找到%s（%d/3）。" % [search_targets[best_index]["name"], search_found]
	_refresh_hud()
	return true


func start_chase_lab() -> void:
	_prepare_lab("lab_chase")
	event_context = ""
	_reset_chase()
	status_message = "点击开始追逐，倒计时结束后输入屏幕上的英文句子。"
	_refresh_hud()


func _reset_chase() -> void:
	chase_typed = 0
	chase_police_progress = 0.0
	chase_player_progress = 5.0
	chase_started = false
	chase_countdown = 0.0
	chase_result = ""


func begin_chase() -> void:
	if phase != "lab_chase" or chase_started or not chase_result.is_empty():
		return
	chase_started = true
	chase_countdown = 2.5
	status_message = "追逐即将开始……"
	_refresh_hud()


func chase_type_character(character: String) -> void:
	if phase != "lab_chase" or not chase_started or chase_countdown > 0.0 or not chase_result.is_empty() or character.is_empty():
		return
	var expected := chase_sentence.substr(chase_typed, 1)
	if character.to_lower() == expected.to_lower():
		chase_typed += 1
		chase_player_progress += 9.0 / float(chase_sentence.length())
		status_message = "输入正确：还剩 %d 个字符。" % (chase_sentence.length() - chase_typed)
		if chase_typed >= chase_sentence.length():
			_finish_chase(true)
	else:
		status_message = "打错了——进度保留，但警察还在靠近。"
	_refresh_hud()


func forfeit_chase() -> void:
	if phase == "lab_chase" and chase_result.is_empty():
		_finish_chase(false)


func _update_chase(delta: float) -> void:
	if not chase_started or not chase_result.is_empty():
		return
	if chase_countdown > 0.0:
		chase_countdown = maxf(0.0, chase_countdown - delta)
		if chase_countdown <= 0.0:
			status_message = "跑！输入完整句子，不要让警察追上。"
			_refresh_hud()
		return
	chase_police_progress += delta * 1.05
	if chase_police_progress + 0.7 >= chase_player_progress:
		_finish_chase(false)


func _finish_chase(success: bool) -> void:
	chase_result = "success" if success else "failure"
	chase_started = false
	status_message = "成功逃到门口！" if success else "警察追上来了。"
	_refresh_hud()
	if event_context == "chase":
		finish_event_trial(success)


func _prepare_lab(next_phase: String) -> void:
	_cancel_dynamic_effect()
	phase = next_phase
	world_container.visible = true
	house_root.visible = false
	battle_root.visible = false
	lab_root.visible = true
	_clear_children(lab_root)


func _set_lab_camera(target: Vector3, size_value: float) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size_value
	camera.position = target + Vector3(0.0, 3.0, 14.0)
	camera.look_at(target, Vector3.UP)


func _set_search_camera_defaults() -> void:
	lab_camera_target = Vector3(0.0, 0.9, -0.2)
	lab_camera_yaw = 0.0
	lab_camera_pitch = 0.24
	lab_camera_distance = 12.5
	_apply_search_camera()


func orbit_search_camera(relative: Vector2) -> void:
	if phase != "lab_search":
		return
	lab_camera_yaw -= relative.x * 0.008
	lab_camera_pitch = clampf(lab_camera_pitch - relative.y * 0.006, 0.10, 0.72)
	_apply_search_camera()


func zoom_search_camera(factor: float) -> void:
	if phase != "lab_search":
		return
	lab_camera_distance = clampf(lab_camera_distance * factor, 8.0, 20.0)
	_apply_search_camera()


func _apply_search_camera() -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 46.0
	var planar: float = cos(lab_camera_pitch) * lab_camera_distance
	var offset := Vector3(sin(lab_camera_yaw) * planar, sin(lab_camera_pitch) * lab_camera_distance, cos(lab_camera_yaw) * planar)
	camera.position = lab_camera_target + offset
	camera.look_at(lab_camera_target, Vector3.UP)


func choose_omen(index: int) -> void:
	if animation_busy or phase != "omen" or index < 0 or index >= omen_options.size():
		return
	var relic_id := omen_options[index]
	active_relics = [relic_id]
	var relic: Dictionary = content.get("relics", {}).get(relic_id, {})
	var effect: Dictionary = relic.get("effect", {})
	player_max_hp += int(effect.get("maxHp", 0))
	player_hp = player_max_hp
	phase = "explore"
	status_message = "获得%s。点亮黄色扩建格，抽取三张隐藏房间票根。" % str(relic.get("name", relic_id))
	event_log.append("获得%s" % str(relic.get("name", relic_id)))
	_refresh_hud()
	_save_run()


func begin_build(target: Vector2i) -> void:
	if animation_busy or phase != "explore" or not (target in room_rules.frontiers()):
		return
	selected_frontier = target
	build_offers = _make_build_offers(target)
	selected_offer = 0
	_select_first_valid_rotation()
	phase = "build"
	status_message = "扩建 %s：选择票根、旋转对门。房间内容要走进去才揭晓。" % target
	build_house_world()
	_refresh_hud()


func select_offer(index: int) -> void:
	if animation_busy or phase != "build" or index < 0 or index >= build_offers.size():
		return
	selected_offer = index
	_select_first_valid_rotation()
	build_house_world()
	_refresh_hud()


func rotate_offer() -> void:
	if animation_busy or phase != "build":
		return
	if build_preview_tween != null and build_preview_tween.is_valid():
		return
	offer_rotation = (offer_rotation + 1) % 4
	var preview := house_root.get_node_or_null("BuildPreview") as Node3D
	if preview != null:
		if build_preview_tween != null and build_preview_tween.is_valid():
			build_preview_tween.kill()
		build_preview_tween = create_tween()
		build_preview_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		build_preview_tween.tween_property(preview, "rotation:y", preview.rotation.y - PI * 0.5, 0.18 * maxf(0.25, animation_duration_scale))
		_update_build_preview_validity(preview)
	status_message = "房间预览已旋转到 %d°；门位会在大地图中实时变化。" % (offer_rotation * 90)
	_refresh_hud()


func cancel_build() -> void:
	if animation_busy or phase != "build":
		return
	phase = "explore"
	build_offers.clear()
	build_house_world()
	status_message = "取消扩建。选择另一个黄色格继续。"
	_refresh_hud()


func can_place_selected_offer() -> bool:
	if animation_busy or phase != "build" or build_offers.is_empty():
		return false
	return room_rules.can_place(selected_frontier, build_offers[selected_offer], offer_rotation)


func place_selected_offer() -> void:
	if animation_busy:
		return
	if not can_place_selected_offer():
		status_message = "这张票根的门还没对上。请旋转或选择另一张。"
		_refresh_hud()
		return
	var room: Dictionary = build_offers[selected_offer]
	if not room_rules.place(selected_frontier, room, offer_rotation):
		return
	var instance: Dictionary = room_rules.placed[selected_frontier]
	instance["revealed"] = false
	instance["visited"] = false
	room_rules.placed[selected_frontier] = instance
	pending_room_pos = selected_frontier
	_remove_remaining_room(str(room.get("id", "")))
	phase = "explore"
	build_offers.clear()
	var final_message := "摆下「%s」。它仍是未知房；走进去才揭示，也才算行程。" % str(room.get("name", "房间"))
	status_message = "房间正在翻转落位……"
	event_log.append(final_message)
	animation_busy = true
	active_animation_kind = "room_drop"
	build_house_world()
	_refresh_hud()
	_save_run()
	_animate_room_placement(pending_room_pos, final_message)


func _animate_room_placement(target: Vector2i, final_message: String) -> void:
	var room_node := _find_room_node(target)
	if room_node == null:
		status_message = final_message
		_complete_dynamic_effect()
		_refresh_hud()
		return
	var final_position := _house_world(target)
	room_node.position = final_position + Vector3.UP * HOUSE_CELL * UNITY_ROOM_DROP_HEIGHT_CELLS
	room_node.rotation = Vector3(deg_to_rad(-82.0), 0.0, 0.0)
	room_node.scale = Vector3.ONE * UNITY_ROOM_START_SCALE
	var drop_duration := UNITY_ROOM_DROP_DURATION * animation_duration_scale
	if drop_duration <= 0.0:
		room_node.position = final_position
		room_node.rotation = Vector3.ZERO
		room_node.scale = Vector3.ONE
		status_message = final_message
		_complete_dynamic_effect()
		_refresh_hud()
		return
	var tween := create_tween()
	active_motion_tween = tween
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_parallel(true)
	tween.tween_property(room_node, "position", final_position, drop_duration)
	tween.tween_property(room_node, "rotation", Vector3.ZERO, drop_duration)
	tween.tween_property(room_node, "scale", Vector3.ONE * 1.035, drop_duration)
	tween.set_parallel(false)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(room_node, "scale", Vector3.ONE, UNITY_ACTOR_SETTLE_DURATION * animation_duration_scale)
	await tween.finished
	if active_motion_tween != tween:
		return
	room_node.position = final_position
	room_node.rotation = Vector3.ZERO
	room_node.scale = Vector3.ONE
	status_message = final_message
	_complete_dynamic_effect()
	_refresh_hud()


func handle_screen_click(screen_pos: Vector2) -> void:
	if animation_busy:
		return
	if phase == "combat":
		_handle_battle_world_click(screen_pos)
	elif phase == "explore":
		_handle_house_world_click(screen_pos)


func _handle_house_world_click(screen_pos: Vector2) -> void:
	var hit: Variant = _screen_to_plane(screen_pos, 0.0)
	if hit == null:
		return
	var world: Vector3 = hit
	var target := Vector2i(roundi(world.x / HOUSE_CELL), roundi(world.z / HOUSE_CELL))
	if target in room_rules.frontiers():
		begin_build(target)
	elif room_rules.placed.has(target) and target != current_room_pos and _rooms_connected(current_room_pos, target):
		enter_room(target)


func enter_room(target: Vector2i) -> void:
	if animation_busy or not room_rules.placed.has(target) or not _rooms_connected(current_room_pos, target):
		return
	animation_busy = true
	active_animation_kind = "room_entry"
	status_message = "莉莉正走进未知房间……"
	_refresh_hud()
	_animate_enter_room(target)


func _animate_enter_room(target: Vector2i) -> void:
	var token := house_root.get_node_or_null("LiliToken") as Node3D
	var start_position := _house_world(current_room_pos)
	var target_position := _house_world(target)
	var move_duration := UNITY_ACTOR_STEP_DURATION * animation_duration_scale
	if token != null and move_duration > 0.0:
		var move_tween := create_tween()
		active_motion_tween = move_tween
		move_tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		move_tween.tween_method(_set_house_token_motion.bind(token, start_position, target_position), 0.0, 1.0, move_duration)
		move_tween.tween_property(token, "scale", Vector3(1.06, 0.90, 1.06), UNITY_ACTOR_SETTLE_DURATION * 0.5 * animation_duration_scale)
		move_tween.tween_property(token, "scale", Vector3.ONE, UNITY_ACTOR_SETTLE_DURATION * 0.5 * animation_duration_scale)
		await move_tween.finished
		if active_motion_tween != move_tween:
			return
	current_room_pos = target
	var room: Dictionary = room_rules.placed[target]
	var needs_reveal := not bool(room.get("revealed", false)) and not bool(room.get("completed", false))
	var room_node := _find_room_node(target)
	if needs_reveal and room_node != null and animation_duration_scale > 0.0:
		status_message = "未知房间正在翻面揭示……"
		_refresh_hud()
		var close_tween := create_tween()
		active_motion_tween = close_tween
		close_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		close_tween.tween_property(room_node, "scale", Vector3(1.0, 1.0, 0.04), UNITY_CARD_HALF_FLIP_DURATION * animation_duration_scale)
		await close_tween.finished
		if active_motion_tween != close_tween:
			return
		room["revealed"] = true
		room_rules.placed[target] = room
		_populate_room_visual(room_node, target, room)
		var open_tween := create_tween()
		active_motion_tween = open_tween
		open_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		open_tween.tween_property(room_node, "scale", Vector3.ONE, UNITY_CARD_HALF_FLIP_DURATION * animation_duration_scale)
		await open_tween.finished
		if active_motion_tween != open_tween:
			return
	_finish_enter_room(target)


func _set_house_token_motion(weight: float, token: Node3D, start_position: Vector3, target_position: Vector3) -> void:
	if not is_instance_valid(token):
		return
	var smooth_weight := weight * weight * (3.0 - 2.0 * weight)
	var hop := sin(smooth_weight * PI) * 0.34
	token.position = start_position.lerp(target_position, smooth_weight) + Vector3.UP * hop


func _finish_enter_room(target: Vector2i) -> void:
	current_room_pos = target
	var room: Dictionary = room_rules.placed[target]
	var first_visit := not bool(room.get("visited", false))
	room["revealed"] = true
	room_rules.placed[target] = room
	if first_visit and not bool(room.get("completed", false)):
		phase = "room_ready"
		status_message = str(room.get("description", "你推开了房门。"))
		event_log.append("你推开了通向%s的门。" % str(room.get("name", "房间")))
	else:
		phase = "explore"
		status_message = "回到%s。" % str(room.get("name", "房间"))
	build_house_world()
	_complete_dynamic_effect()
	_refresh_hud()
	_save_run()


func resolve_current_room() -> void:
	if animation_busy or phase != "room_ready":
		return
	var room: Dictionary = current_room()
	if str(room.get("kind", "quiet")) == "combat":
		start_combat(room)
	elif str(room.get("kind", "quiet")) == "event":
		start_event_trial(room)
	else:
		_complete_current_room()
		_start_quiet_reward()


func _complete_current_room() -> void:
	var room: Dictionary = current_room()
	if not bool(room.get("completed", false)):
		run_progress += 1
	room["completed"] = true
	room["visited"] = true
	room_rules.placed[current_room_pos] = room


func _collect_combat_deck() -> void:
	if combat == null:
		return
	var collected: Array[String] = []
	for pile in [combat.deck, combat.discard, combat.hand]:
		for raw_id in pile:
			var card_id := str(raw_id)
			var card: Dictionary = content.get("cards", {}).get(card_id, {})
			if not bool(card.get("temp", false)):
				collected.append(card_id)
	run_deck.assign(collected)


func _start_card_reward(origin: String) -> void:
	var pool: Array = content.get("reward_pool", []).duplicate()
	_shuffle_variants(pool)
	reward_options.clear()
	for i in range(mini(3, pool.size())):
		var card_id := str(pool[i])
		reward_options.append({"kind": "card", "id": card_id})
	reward_origin = origin
	phase = "reward"
	status_message = "惊吓解除：从三张新道具里选一张加入本局牌库，也可以跳过。"
	_save_run()
	_refresh_hud()


func _start_quiet_reward() -> void:
	var healed := 0
	if player_hp < player_max_hp:
		healed = 1
		player_hp += 1
	reward_options = [
		{"kind": "stat", "id": "heal", "name": "恢复 2 生命"},
		{"kind": "stat", "id": "max_hp", "name": "生命上限 +1，并治疗 1"},
		{"kind": "stat", "id": "speed", "name": "速度 +1"},
	]
	if run_progress >= 4:
		var available: Array = content.get("relic_pool", []).filter(func(id: Variant) -> bool: return str(id) not in active_relics)
		if not available.is_empty():
			reward_options[2] = {"kind": "relic", "id": str(available[rng.randi_range(0, available.size() - 1)])}
	reward_origin = "quiet"
	phase = "reward"
	status_message = "静室喘息恢复了 %d 生命；再选择一项成长，或空手离开。" % healed
	_save_run()
	_refresh_hud()


func choose_reward(index: int) -> void:
	if phase != "reward" or index < 0 or index >= reward_options.size():
		return
	var reward: Dictionary = reward_options[index]
	match str(reward.get("kind", "")):
		"card":
			var card_id := str(reward.get("id", ""))
			run_deck.append(card_id)
			status_message = "收下%s；本局牌库现在有 %d 张。" % [str(content.get("cards", {}).get(card_id, {}).get("name", card_id)), run_deck.size()]
		"relic":
			var relic_id := str(reward.get("id", ""))
			if relic_id not in active_relics:
				active_relics.append(relic_id)
			var effect: Dictionary = content.get("relics", {}).get(relic_id, {}).get("effect", {})
			player_max_hp += int(effect.get("maxHp", 0))
			player_hp = mini(player_max_hp, player_hp + int(effect.get("maxHp", 0)))
			status_message = "收下%s。" % str(content.get("relics", {}).get(relic_id, {}).get("name", relic_id))
		"stat":
			match str(reward.get("id", "")):
				"heal": player_hp = mini(player_max_hp, player_hp + 2)
				"max_hp":
					player_max_hp += 1
					player_hp = mini(player_max_hp, player_hp + 1)
				"speed": player_speed += 1
	_finish_reward()


func skip_reward() -> void:
	if phase == "reward":
		status_message = "你没有拿走奖励；牌库保持精简。"
		_finish_reward()


func _finish_reward() -> void:
	phase = "explore"
	reward_options.clear()
	reward_origin = ""
	build_house_world()
	_save_run()
	_refresh_hud()


func start_event_trial(room: Dictionary) -> void:
	event_room_pos = current_room_pos
	var event_type := str(room.get("event_type", "puzzle"))
	if event_type == "qte":
		_prepare_lab("lab_chase")
		event_context = "chase"
		_reset_chase()
		status_message = "事件房·警察抓小偷：开始后输入英文句子逃向门口。"
	else:
		_prepare_lab("lab_puzzle")
		event_context = "puzzle"
		_shuffle_puzzle()
		status_message = "事件房·雪花拼图：成功才能翻开静室奖励。"
	_refresh_hud()


func finish_event_trial(success: bool) -> void:
	if event_context.is_empty():
		return
	var context := event_context
	event_context = ""
	current_room_pos = event_room_pos
	_complete_current_room()
	lab_root.visible = false
	house_root.visible = true
	if success:
		if context == "chase":
			player_speed += 1
		_start_quiet_reward()
		status_message = "考验成功；奖励已经翻开。"
	else:
		if context == "chase" and run_deck.size() > 1:
			var stealable_indices: Array[int] = []
			for i in range(run_deck.size()):
				if bool(content.get("cards", {}).get(run_deck[i], {}).get("stealable", false)):
					stealable_indices.append(i)
			var stolen_index := stealable_indices[rng.randi_range(0, stealable_indices.size() - 1)] if not stealable_indices.is_empty() else rng.randi_range(0, run_deck.size() - 1)
			var stolen_id := run_deck[stolen_index]
			run_deck.remove_at(stolen_index)
			status_message = "考验失败：警察搜走了%s。" % str(content.get("cards", {}).get(stolen_id, {}).get("name", stolen_id))
		else:
			status_message = "考验失败：房间奖励消失了。"
		phase = "explore"
		build_house_world()
		_save_run()
		_refresh_hud()


func start_combat(room: Dictionary) -> void:
	combat = CombatRules.new()
	var enemy: Dictionary = room.get("enemy", {})
	var run_rules: Dictionary = content.get("run_rules", {}).duplicate(true)
	run_rules["player_hp"] = player_hp
	run_rules["base_speed"] = player_speed
	combat.setup(room.get("arena", {}), enemy, content.get("cards", {}), run_deck, run_seed + room_rules.placed.size() * 17, run_rules, active_relics)
	selected_card = -1
	hovered_battle_cell = INVALID_CELL
	phase = "combat"
	house_root.visible = false
	battle_root.visible = true
	build_battle_world()
	_set_battle_camera()
	status_message = str(room.get("arena", {}).get("spawnNote", "房门在身后合上。"))
	_refresh_hud()


func select_or_play_card(index: int) -> void:
	if animation_busy or phase != "combat" or combat == null or combat.has_pending_player_portal() or index < 0 or index >= combat.hand.size():
		return
	var card: Dictionary = combat.cards.get(combat.hand[index], {})
	if str(card.get("type", "")) == "place":
		if selected_card == index:
			cancel_selected_card("已取消%s；绿色角标恢复为移动目标。" % str(card.get("name", combat.hand[index])))
			return
		selected_card = index
		status_message = "已选%s：金色角标可放置；点敌人格可直接砸击。再次点牌、右键或 Esc 可取消。" % str(card.get("name", combat.hand[index]))
		build_battle_world()
		_play_actor_state("Player", "ready", "准备·%s" % str(card.get("name", combat.hand[index])))
	else:
		var enemy_hp_before: int = combat.enemy_hp
		var played: bool = combat.play_card(index, combat.enemy_pos)
		selected_card = -1
		if played:
			status_message = "已打出%s。" % str(card.get("name", "卡牌"))
			_after_combat_action()
			_play_actor_state("Player", "ready" if str(card.get("type", "")) == "ready" else "attack", str(card.get("name", "出手")))
			if combat.enemy_hp < enemy_hp_before:
				_play_actor_state("Enemy", "hurt", "-%d" % (enemy_hp_before - combat.enemy_hp))
		else:
			status_message = "%s当前条件不满足，卡牌没有消耗。" % str(card.get("name", "这张牌"))
	_refresh_hud()


func cancel_selected_card(message: String = "已取消选牌；绿色角标表示可以移动的格子。") -> void:
	if phase != "combat" or selected_card < 0:
		return
	selected_card = -1
	status_message = message
	build_battle_world()
	_refresh_hud()


func end_combat_turn() -> void:
	if animation_busy or phase != "combat" or combat == null or combat.outcome != "" or combat.has_pending_player_portal():
		return
	selected_card = -1
	hovered_battle_cell = INVALID_CELL
	var turn_events: Array[Dictionary] = combat.enemy_turn()
	animation_busy = true
	active_animation_kind = "enemy_turn"
	status_message = _enemy_turn_summary(turn_events)
	build_battle_world()
	_refresh_hud()
	_animate_enemy_turn(turn_events)


func _enemy_turn_summary(turn_events: Array[Dictionary]) -> String:
	if turn_events.is_empty():
		return "敌方回合：它在遮挡后重新判断方向。"
	var labels: Array[String] = []
	for event: Dictionary in turn_events:
		labels.append(str(event.get("label", event.get("kind", "动作"))))
	return "敌方回合：%s。" % " → ".join(labels)


func _animate_enemy_turn(turn_events: Array[Dictionary]) -> void:
	var enemy_node := battle_root.get_node_or_null("Enemy") as Node3D
	if turn_events.is_empty() or animation_duration_scale <= 0.0 or enemy_node == null:
		_complete_dynamic_effect()
		_after_combat_action()
		return
	var first_move: Dictionary = {}
	for event: Dictionary in turn_events:
		if str(event.get("kind", "")) == "move":
			first_move = event
			break
	if not first_move.is_empty():
		enemy_node.position = _battle_world(first_move.get("from", combat.enemy_pos))
	var player_hit := turn_events.any(func(event: Dictionary) -> bool:
		return str(event.get("kind", "")) == "attack" and event.get("target", INVALID_CELL) == combat.player_pos
	)
	if turn_events.any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "attack"):
		_play_actor_state("Enemy", "attack", "袭击!")
	if player_hit:
		_play_actor_state("Player", "hurt", "受击!")
	var tween := create_tween()
	active_motion_tween = tween
	for event: Dictionary in turn_events:
		var kind := str(event.get("kind", ""))
		if kind == "move":
			var source: Vector2i = event.get("from", combat.enemy_pos)
			var target: Vector2i = event.get("to", combat.enemy_pos)
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_method(_set_enemy_step_motion.bind(enemy_node, _battle_world(source), _battle_world(target)), 0.0, 1.0, ENEMY_STEP_DURATION * animation_duration_scale)
			tween.tween_interval(0.035 * animation_duration_scale)
		elif kind == "attack":
			tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(enemy_node, "scale", Vector3(1.22, 0.82, 1.22), ENEMY_ATTACK_DURATION * 0.45 * animation_duration_scale)
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(enemy_node, "scale", Vector3.ONE, ENEMY_ATTACK_DURATION * 0.55 * animation_duration_scale)
		else:
			tween.tween_interval(0.18 * animation_duration_scale)
	await tween.finished
	if active_motion_tween != tween:
		return
	_complete_dynamic_effect()
	_after_combat_action()


func _set_enemy_step_motion(weight: float, enemy_node: Node3D, start_position: Vector3, target_position: Vector3) -> void:
	if not is_instance_valid(enemy_node):
		return
	var smooth_weight := weight * weight * (3.0 - 2.0 * weight)
	enemy_node.position = start_position.lerp(target_position, smooth_weight) + Vector3.UP * sin(smooth_weight * PI) * 0.28


func _handle_battle_world_click(screen_pos: Vector2) -> void:
	if combat == null or combat.outcome != "":
		return
	var target := battle_cell_from_viewport(screen_pos)
	if target == INVALID_CELL:
		return
	handle_battle_cell(target)


func handle_battle_cell(target: Vector2i) -> void:
	if combat == null or combat.outcome != "" or combat.has_pending_player_portal() or target == INVALID_CELL:
		return
	if selected_card >= 0:
		var card_name := "所选卡牌"
		if selected_card < combat.hand.size():
			card_name = str(combat.cards.get(combat.hand[selected_card], {}).get("name", combat.hand[selected_card]))
		var enemy_hp_before: int = combat.enemy_hp
		if combat.play_card(selected_card, target):
			selected_card = -1
			status_message = "%s已生效。继续移动、出牌，或结束回合让敌人行动。" % card_name
			_after_combat_action()
			_play_actor_state("Player", "attack", card_name)
			if combat.enemy_hp < enemy_hp_before:
				_play_actor_state("Enemy", "hurt", "-%d" % (enemy_hp_before - combat.enemy_hp))
			return
		else:
			selected_card = -1
			status_message = "%s不能放在这里，已自动取消选牌；现在可点击绿色格移动。" % card_name
	else:
		if combat.move_player(target):
			status_message = "你站在传送门入口：选择穿过或留在这里。" if combat.has_pending_player_portal() else "移动完成。选择手牌布置陷阱，或直接砸向有视野的敌人格。"
			_after_combat_action()
			_play_actor_state("Player", "move")
			return
		else:
			status_message = "不能移动到该格：只能走相邻绿色格，且需要足够行动力。"
	_after_combat_action()


func resolve_player_portal(use_portal: bool) -> void:
	if animation_busy or phase != "combat" or combat == null:
		return
	if use_portal and not combat.can_use_pending_player_portal():
		status_message = "传送门出口被怪物占住了；你只能先留在入口。"
		_refresh_hud()
		return
	if not combat.resolve_player_portal(use_portal):
		return
	status_message = "你主动穿过传送门，到达成对出口。" if use_portal else "你决定留在入口格，传送门没有强制发动。"
	_after_combat_action()


func battle_cell_from_viewport(view_pos: Vector2) -> Vector2i:
	if combat == null:
		return INVALID_CELL
	var hit: Variant = _screen_to_plane(view_pos, 0.0)
	if hit == null:
		return INVALID_CELL
	var world: Vector3 = hit
	var grid_origin := Vector2(-float(combat.cols - 1) * BATTLE_CELL * 0.5, -float(combat.rows - 1) * BATTLE_CELL * 0.5)
	var target := Vector2i(roundi((world.x - grid_origin.x) / BATTLE_CELL), roundi((world.z - grid_origin.y) / BATTLE_CELL))
	if target.x < 0 or target.y < 0 or target.x >= combat.cols or target.y >= combat.rows:
		return INVALID_CELL
	return target


func set_battle_hover(view_pos: Vector2) -> void:
	if phase != "combat" or combat == null:
		return
	var next_hover := battle_cell_from_viewport(view_pos)
	if next_hover == hovered_battle_cell:
		return
	hovered_battle_cell = next_hover
	build_battle_world()


func clear_battle_hover() -> void:
	if hovered_battle_cell == INVALID_CELL:
		return
	hovered_battle_cell = INVALID_CELL
	if phase == "combat":
		build_battle_world()


func reset_battle_camera() -> void:
	if combat == null or camera == null:
		return
	var max_height := 0.0
	for raw_height in combat.heights.values():
		max_height = maxf(max_height, float(raw_height))
	battle_camera_target = Vector3(0.0, max_height * 0.18, 0.0)
	_apply_battle_camera()
	var half_x := (float(combat.cols - 1) * 0.5 + 0.65) * BATTLE_CELL
	var half_z := (float(combat.rows - 1) * 0.5 + 0.65) * BATTLE_CELL
	var max_y := max_height * 0.64 + 2.25
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y_projected := -INF
	var right := camera.global_transform.basis.x.normalized()
	var up := camera.global_transform.basis.y.normalized()
	for x_value in [-half_x, half_x]:
		for z_value in [-half_z, half_z]:
			for y_value in [0.0, max_y]:
				var relative := Vector3(x_value, y_value, z_value) - battle_camera_target
				var projected_x := relative.dot(right)
				var projected_y := relative.dot(up)
				min_x = minf(min_x, projected_x)
				max_x = maxf(max_x, projected_x)
				min_y = minf(min_y, projected_y)
				max_y_projected = maxf(max_y_projected, projected_y)
	var viewport_size := world_view_rect.size
	var aspect := viewport_size.x / maxf(1.0, viewport_size.y)
	var projected_width := max_x - min_x + 0.8
	var projected_height := max_y_projected - min_y + 0.8
	battle_camera_fit_size = maxf(6.0, maxf(projected_height, projected_width / maxf(0.5, aspect)) * 1.08)
	camera.size = battle_camera_fit_size
	_apply_battle_camera()


func pan_battle_camera(pixel_delta: Vector2) -> void:
	if phase != "combat" or combat == null:
		return
	var units_per_pixel := camera.size / maxf(1.0, world_view_rect.size.y)
	var right := Vector3(camera.global_transform.basis.x.x, 0.0, camera.global_transform.basis.x.z).normalized()
	var screen_up := Vector3(camera.global_transform.basis.y.x, 0.0, camera.global_transform.basis.y.z).normalized()
	battle_camera_target += (-right * pixel_delta.x + screen_up * pixel_delta.y) * units_per_pixel
	_clamp_battle_camera_target()
	_apply_battle_camera()


func zoom_battle_camera(view_pos: Vector2, zoom_factor: float) -> void:
	if phase != "combat" or combat == null:
		return
	var before: Variant = _screen_to_plane(view_pos, 0.0)
	camera.size = clampf(camera.size * zoom_factor, battle_camera_fit_size * CAMERA_ZOOM_MIN, battle_camera_fit_size * CAMERA_ZOOM_MAX)
	_apply_battle_camera()
	var after: Variant = _screen_to_plane(view_pos, 0.0)
	if before is Vector3 and after is Vector3:
		var anchor_shift: Vector3 = before - after
		battle_camera_target += Vector3(anchor_shift.x, 0.0, anchor_shift.z)
		_clamp_battle_camera_target()
		_apply_battle_camera()


func _clamp_battle_camera_target() -> void:
	if combat == null:
		return
	var limit_x := (float(combat.cols - 1) * 0.5 + 1.0) * BATTLE_CELL
	var limit_z := (float(combat.rows - 1) * 0.5 + 1.0) * BATTLE_CELL
	battle_camera_target.x = clampf(battle_camera_target.x, -limit_x, limit_x)
	battle_camera_target.z = clampf(battle_camera_target.z, -limit_z, limit_z)


func _apply_battle_camera() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = battle_camera_target + CAMERA_DIRECTION
	camera.look_at(battle_camera_target + Vector3(0, 0.2, 0), Vector3.UP)


func _after_combat_action() -> void:
	player_hp = combat.player_hp
	build_battle_world()
	if combat.outcome != "":
		status_message = "战斗胜利。" if combat.outcome == "victory" else "本集信号中断。"
	_refresh_hud()


func return_from_combat() -> void:
	if animation_busy or phase != "combat" or combat == null or combat.outcome == "":
		return
	if combat.outcome == "victory":
		_collect_combat_deck()
		_complete_current_room()
		_start_card_reward("combat")
		house_root.visible = true
		battle_root.visible = false
		build_house_world()
		_set_house_camera()
		_refresh_hud()
	else:
		_clear_run_save()
		go_home()


func current_room() -> Dictionary:
	return room_rules.placed.get(current_room_pos, {})


func current_room_name() -> String:
	return str(current_room().get("name", "玄关"))


func current_omen() -> Dictionary:
	if active_relics.is_empty():
		return {}
	return content.get("relics", {}).get(active_relics[0], {})


func reward_title(reward: Dictionary) -> String:
	var kind := str(reward.get("kind", ""))
	if kind == "card":
		return str(content.get("cards", {}).get(str(reward.get("id", "")), {}).get("name", reward.get("id", "道具")))
	if kind == "relic":
		return str(content.get("relics", {}).get(str(reward.get("id", "")), {}).get("name", reward.get("id", "预兆")))
	return str(reward.get("name", reward.get("id", "成长")))


func reward_description(reward: Dictionary) -> String:
	var kind := str(reward.get("kind", ""))
	if kind == "card":
		return str(content.get("cards", {}).get(str(reward.get("id", "")), {}).get("text", "加入本局牌库"))
	if kind == "relic":
		return str(content.get("relics", {}).get(str(reward.get("id", "")), {}).get("desc", "本局持续生效"))
	return "立即生效，并保留到本集结束。"


func _save_run() -> void:
	if phase == "home" or phase.begins_with("lab_") and event_context.is_empty():
		return
	var placed_entries: Array[Dictionary] = []
	for raw_pos in room_rules.placed.keys():
		var pos: Vector2i = raw_pos
		var room: Dictionary = room_rules.placed[pos].duplicate(true)
		room.erase("pos")
		placed_entries.append({"x": pos.x, "y": pos.y, "room": room})
	var remaining_ids: Array[String] = []
	for room: Dictionary in remaining_rooms:
		remaining_ids.append(str(room.get("id", "")))
	var payload := {
		"version": 1,
		"source": EXE_SOURCE_ID,
		"seed": run_seed,
		"phase": phase,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"player_speed": player_speed,
		"run_progress": run_progress,
		"run_deck": run_deck,
		"active_relics": active_relics,
		"reward_options": reward_options,
		"reward_origin": reward_origin,
		"current_room": [current_room_pos.x, current_room_pos.y],
		"pending_room": [pending_room_pos.x, pending_room_pos.y],
		"placed": placed_entries,
		"remaining_ids": remaining_ids,
	}
	var file := FileAccess.open(RUN_SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload))


func _clear_run_save() -> void:
	if FileAccess.file_exists(RUN_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_SAVE_PATH))


func _array_to_pos(raw_value: Variant) -> Vector2i:
	if raw_value is Array and raw_value.size() >= 2:
		return Vector2i(int(raw_value[0]), int(raw_value[1]))
	return Vector2i.ZERO


func latest_source_label() -> String:
	return "EXE 08-11 · EEC4C574CC22"


func build_house_world() -> void:
	if build_preview_tween != null and build_preview_tween.is_valid():
		build_preview_tween.kill()
	build_preview_tween = null
	_clear_children(house_root)
	for raw_pos in room_rules.placed.keys():
		var pos: Vector2i = raw_pos
		_add_room_mesh(pos, room_rules.placed[pos])
	_add_room_bridges()
	for frontier in room_rules.frontiers():
		_add_frontier_mesh(frontier, phase == "build" and frontier == selected_frontier)
	if phase == "build" and not build_offers.is_empty():
		_add_build_preview()
	_add_house_player()
	if phase != "combat":
		_set_house_camera()


func _add_room_mesh(pos: Vector2i, room: Dictionary) -> void:
	var node := Node3D.new()
	node.name = "Room_%d_%d" % [pos.x, pos.y]
	node.position = _house_world(pos)
	house_root.add_child(node)
	_populate_room_visual(node, pos, room)


func _populate_room_visual(node: Node3D, pos: Vector2i, room: Dictionary) -> void:
	_clear_children(node)
	var revealed := bool(room.get("revealed", false)) or bool(room.get("completed", false))
	var kind := str(room.get("kind", "quiet"))
	var accent := COL_TEAL
	if not revealed:
		accent = Color("46545b")
	elif kind == "combat":
		accent = COL_MAGENTA
	elif kind == "event":
		accent = Color("7964a5")
	if pos == current_room_pos:
		accent = COL_GOLD
	_add_box(node, "Base", Vector3.ZERO + Vector3(0, 0.14, 0), Vector3(3.05, 0.28, 3.05), _material(accent.darkened(0.35)))
	_add_box(node, "Floor", Vector3(0, 0.31, 0), Vector3(2.82, 0.12, 2.82), _material(COL_PAPER if revealed else Color("26363d")))
	var doors: Array = room.get("doors", [false, false, false, false])
	for side in range(4):
		_add_room_edge(node, side, bool(doors[side]), accent)
	var label_text := str(room.get("name", "房间")) if revealed else "?"
	_add_label(node, "Label", label_text, Vector3(0, 1.18, 0), accent if revealed else COL_GOLD, 44)


func _add_room_edge(parent: Node3D, side: int, has_door: bool, color: Color) -> void:
	var wall_height := 0.55
	var wall_thickness := 0.14
	if side == 0 or side == 2:
		var z := -1.42 if side == 0 else 1.42
		if has_door:
			_add_box(parent, "DoorEdge", Vector3(-1.02, 0.68, z), Vector3(0.72, wall_height, wall_thickness), _material(color))
			_add_box(parent, "DoorEdge", Vector3(1.02, 0.68, z), Vector3(0.72, wall_height, wall_thickness), _material(color))
		else:
			_add_box(parent, "Wall", Vector3(0, 0.68, z), Vector3(2.82, wall_height, wall_thickness), _material(color))
	else:
		var x := 1.42 if side == 1 else -1.42
		if has_door:
			_add_box(parent, "DoorEdge", Vector3(x, 0.68, -1.02), Vector3(wall_thickness, wall_height, 0.72), _material(color))
			_add_box(parent, "DoorEdge", Vector3(x, 0.68, 1.02), Vector3(wall_thickness, wall_height, 0.72), _material(color))
		else:
			_add_box(parent, "Wall", Vector3(x, 0.68, 0), Vector3(wall_thickness, wall_height, 2.82), _material(color))


func _add_room_bridges() -> void:
	for raw_pos in room_rules.placed.keys():
		var pos: Vector2i = raw_pos
		var room: Dictionary = room_rules.placed[pos]
		var doors: Array = room.get("doors", [])
		if doors.size() >= 4 and bool(doors[1]) and room_rules.placed.has(pos + Vector2i.RIGHT):
			_add_box(house_root, "Bridge", (_house_world(pos) + _house_world(pos + Vector2i.RIGHT)) * 0.5 + Vector3(0, 0.24, 0), Vector3(0.55, 0.12, 1.05), _material(COL_PAPER))
		if doors.size() >= 4 and bool(doors[2]) and room_rules.placed.has(pos + Vector2i.DOWN):
			_add_box(house_root, "Bridge", (_house_world(pos) + _house_world(pos + Vector2i.DOWN)) * 0.5 + Vector3(0, 0.24, 0), Vector3(1.05, 0.12, 0.55), _material(COL_PAPER))


func _add_frontier_mesh(pos: Vector2i, selected: bool) -> void:
	var node := Node3D.new()
	node.name = "Frontier_%d_%d" % [pos.x, pos.y]
	node.position = _house_world(pos)
	house_root.add_child(node)
	var color := COL_GOLD if selected else Color("c88b2f")
	var transparent := Color(color, 0.54 if selected else 0.28)
	_add_box(node, "BuildPad", Vector3(0, 0.11, 0), Vector3(2.75, 0.18, 2.75), _material(transparent, true))
	_add_label(node, "Plus", "+", Vector3(0, 0.72, 0), color, 70)


func _add_build_preview() -> void:
	var room: Dictionary = build_offers[selected_offer]
	var node := Node3D.new()
	node.name = "BuildPreview"
	node.position = _house_world(selected_frontier) + Vector3(0, 0.20, 0)
	node.rotation.y = -float(offer_rotation) * PI * 0.5
	house_root.add_child(node)
	var preview_room := room.duplicate(true)
	preview_room["revealed"] = false
	preview_room["completed"] = false
	preview_room["doors"] = room_rules.normalize_doors(room.get("doors", []))
	_populate_room_visual(node, selected_frontier, preview_room)
	var validity := _add_cylinder(node, "PreviewValidity", Vector3(0, 0.14, 0), 1.58, 0.08, _material(Color(COL_GREEN if can_place_selected_offer() else COL_RED, 0.72), true, 0.08))
	validity.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_label(node, "PreviewRotation", "%d°" % (offer_rotation * 90), Vector3(0, 1.68, 0), Color.WHITE, 30)
	_update_build_preview_validity(node)


func _update_build_preview_validity(preview: Node3D) -> void:
	var valid := can_place_selected_offer()
	var validity := preview.get_node_or_null("PreviewValidity") as MeshInstance3D
	if validity != null:
		validity.material_override = _material(Color(COL_GREEN if valid else COL_RED, 0.72), true, 0.08)
	var label := preview.get_node_or_null("PreviewRotation") as Label3D
	if label != null:
		label.text = "%d° · %s" % [offer_rotation * 90, "可摆" if valid else "门不合"]
		label.modulate = COL_GREEN if valid else COL_RED


func _add_house_player() -> void:
	var node := Node3D.new()
	node.name = "LiliToken"
	node.position = _house_world(current_room_pos)
	house_root.add_child(node)
	_add_cylinder(node, "Body", Vector3(0, 0.9, 0), 0.34, 1.15, _material(COL_TEAL))
	_add_cylinder(node, "Hat", Vector3(0, 1.58, 0), 0.46, 0.18, _material(COL_RED))
	_add_label(node, "Name", "LILI", Vector3(0, 2.0, 0), Color.WHITE, 34)


func build_battle_world() -> void:
	_clear_children(battle_root)
	if combat == null:
		return
	var intent: Dictionary = combat.preview_intent()
	_add_box(
		battle_root,
		"ArenaBase",
		Vector3(0, -0.13, 0),
		Vector3(float(combat.cols) * BATTLE_CELL + 0.36, 0.22, float(combat.rows) * BATTLE_CELL + 0.36),
		_material(Color("111a20"))
	)
	for y in range(combat.rows):
		for x in range(combat.cols):
			var pos := Vector2i(x, y)
			var world := _battle_world(pos)
			var cell_node := Node3D.new()
			cell_node.name = "Cell_%d_%d" % [x, y]
			cell_node.position = world
			battle_root.add_child(cell_node)
			var height := int(combat.heights.get(pos, 0))
			var platform_height := 0.28 + float(height) * 0.64
			var rim_color := Color("343a3e") if height == 0 else Color("2b3034") if height == 1 else Color("22272a")
			if pos in intent.get("hurt", []):
				rim_color = COL_RED
			elif pos in intent.get("path", []):
				rim_color = COL_BLUE
			var surface_color := COL_FLOOR_H0 if height == 0 else COL_FLOOR_H1 if height == 1 else COL_FLOOR_H2
			if (x + y) % 2 == 1:
				surface_color = surface_color.darkened(0.035)
			if combat.walls.has(pos):
				surface_color = COL_WALL_GREEN.darkened(0.12)
			_add_box(cell_node, "Frame", Vector3(0, platform_height * 0.5, 0), Vector3(BATTLE_CELL - 0.08, platform_height, BATTLE_CELL - 0.08), _material(rim_color, false, 0.04 if rim_color != COL_GRID_DARK else 0.0))
			_add_box(cell_node, "Surface", Vector3(0, platform_height + 0.055, 0), Vector3(BATTLE_CELL - 0.34, 0.11, BATTLE_CELL - 0.34), _material(surface_color))
			var top_y := platform_height + 0.13
			var is_hurt_cell: bool = pos in (intent.get("hurt", []) as Array)
			var path_index: int = (intent.get("path", []) as Array).find(pos)
			if is_hurt_cell:
				_add_box(cell_node, "IntentAttackOverlay", Vector3(0, top_y + 0.035, 0), Vector3(BATTLE_CELL - 0.43, 0.065, BATTLE_CELL - 0.43), _material(Color(COL_RED, 0.78), true, 0.08))
				_add_label(cell_node, "IntentAttackGlyph", "攻!", Vector3(0.0, top_y + 0.48, 0.0), Color.WHITE, 34)
			elif path_index >= 0:
				_add_box(cell_node, "IntentMoveOverlay", Vector3(0, top_y + 0.035, 0), Vector3(BATTLE_CELL - 0.43, 0.065, BATTLE_CELL - 0.43), _material(Color(COL_BLUE, 0.66), true, 0.06))
				_add_label(cell_node, "IntentMoveGlyph", "走%d" % (path_index + 1), Vector3(0.0, top_y + 0.45, 0.0), Color.WHITE, 29)
			if _is_valid_battle_target(pos):
				_add_corner_marks(cell_node, "Valid", COL_GOLD if selected_card >= 0 else COL_GREEN, top_y)
			if pos == hovered_battle_cell:
				_add_corner_marks(cell_node, "Hover", Color.WHITE, top_y + 0.055)
			if height > 0:
				_add_label(cell_node, "Height", "H%d" % height, Vector3(-0.65, top_y + 0.32, -0.65), COL_GRID_DARK, 24)
			if combat.portals.has(pos):
				_add_portal_marker(cell_node, pos, top_y)
			if combat.walls.has(pos):
				_add_box(cell_node, "Blocker", Vector3(0, platform_height + 0.82, 0), Vector3(BATTLE_CELL - 0.48, 1.45, BATTLE_CELL - 0.48), _material(COL_WALL_GREEN))
				_add_label(cell_node, "Blocked", "×", Vector3(0, platform_height + 1.72, 0), Color("f0c9b4"), 42)
			elif combat.traps.has(pos):
				var trap: Dictionary = combat.traps[pos]
				_add_cylinder(cell_node, "Trap", Vector3(0, top_y + 0.11, 0), 0.42, 0.18, _material(COL_GOLD, false, 0.05))
				var card_id := str(trap.get("card_id", ""))
				_add_trap_item_sprite(cell_node, card_id, top_y)
				_add_label(cell_node, "TrapGlyph", str(trap.get("glyph", "✦")), Vector3(0, top_y + 0.78, 0), COL_GOLD, 24)
	_add_battle_pawn(combat.player_pos, true, true)
	_add_battle_pawn(combat.enemy_pos, false, combat.enemy_revealed)
	_add_battle_stage_decor()


func _is_valid_battle_target(pos: Vector2i) -> bool:
	if combat == null or combat.outcome != "":
		return false
	if selected_card >= 0:
		if selected_card >= combat.hand.size():
			return false
		return combat.can_target_place_card(selected_card, pos)
	return combat.can_move_player(pos)


func _add_corner_marks(parent: Node3D, prefix: String, color: Color, y: float) -> void:
	var edge := BATTLE_CELL * 0.36
	for index in range(4):
		var sx := -1.0 if index % 2 == 0 else 1.0
		var sz := -1.0 if index < 2 else 1.0
		_add_box(parent, "%s_%d" % [prefix, index], Vector3(sx * edge, y, sz * edge), Vector3(0.28, 0.055, 0.28), _material(color, false, 0.08))


func _add_portal_marker(parent: Node3D, pos: Vector2i, y: float) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "PortalRing"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.50
	mesh.outer_radius = 0.72
	ring.mesh = mesh
	ring.position = Vector3(0, y + 0.15, 0)
	ring.material_override = _material(Color("9a70da"), false, 0.14)
	parent.add_child(ring)
	_add_label(parent, "PortalLabel", "门%s" % _portal_endpoint_label(pos), Vector3(0, y + 0.58, 0), Color("d9c5ff"), 28)


func _portal_endpoint_label(pos: Vector2i) -> String:
	if not combat.portals.has(pos):
		return ""
	var other: Vector2i = combat.portals[pos]
	return "A" if pos.x < other.x or (pos.x == other.x and pos.y < other.y) else "B"


func _add_battle_pawn(pos: Vector2i, is_player: bool, revealed: bool) -> void:
	var node := Node3D.new()
	node.name = "Player" if is_player else "Enemy"
	node.position = _battle_world(pos)
	battle_root.add_child(node)
	var floor_y := 0.39 + float(combat.heights.get(pos, 0)) * 0.64
	_add_cylinder(node, "PawnBase", Vector3(0, floor_y + 0.08, 0), 0.52, 0.16, _material(COL_TEAL if is_player else COL_RED if revealed else Color("1f2930"), false, 0.04))
	var presenter := CharacterPresenter.new()
	presenter.name = "Presenter"
	presenter.position = Vector3(0, floor_y + 0.05, 0)
	node.add_child(presenter)
	var actor_key := "player" if is_player else "enemy"
	presenter.configure(actor_key, (presentation.get("actors", {}).get(actor_key, {}) as Dictionary))
	presenter.state_changed.connect(_on_presenter_state_changed)
	if not revealed and not is_player and presenter.sprite != null:
		presenter.sprite.modulate = Color("30383d")
	_add_label(node, "PawnLabel", "你" if is_player else ("怪" if revealed else "?"), Vector3(0, floor_y + 2.05, 0), Color.WHITE if revealed or is_player else COL_GOLD, 31)


func _play_actor_state(actor_node_name: String, state: String, callout: String = "") -> void:
	var presenter := battle_root.get_node_or_null("%s/Presenter" % actor_node_name)
	if presenter != null and presenter.has_method("play_state"):
		presenter.play_state(state, callout)


func _on_presenter_state_changed(_state: String) -> void:
	if hud != null:
		hud.queue_redraw()


func _add_battle_stage_decor() -> void:
	if presentation.is_empty() or combat == null:
		return
	var decor: Dictionary = presentation.get("decor", {})
	var half_x := float(combat.cols) * BATTLE_CELL * 0.5
	var half_z := float(combat.rows) * BATTLE_CELL * 0.5
	_add_decor_sprite("StageDoor", str(decor.get("door", "")), Vector3(-half_x - 1.1, 1.35, -half_z + 0.8), 0.0060)
	_add_decor_sprite("StageWindow", str(decor.get("window", "")), Vector3(half_x + 0.9, 1.45, -half_z + 0.4), 0.0052)
	_add_decor_sprite("StageLamp", str(decor.get("pendant_lamp", "")), Vector3(0, 2.9, -half_z - 0.8), 0.0050)
	_add_decor_sprite("StageAnchor", str(decor.get("signal_anchor", "")), Vector3(half_x + 0.65, 0.65, half_z - 0.6), 0.0050)


func _add_decor_sprite(node_name: String, texture_path: String, local_position: Vector3, pixel_size: float) -> void:
	if texture_path.is_empty():
		return
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return
	var sprite := Sprite3D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.position = local_position
	sprite.pixel_size = pixel_size
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	battle_root.add_child(sprite)


func _add_trap_item_sprite(parent: Node3D, card_id: String, y: float) -> void:
	var item_path := str((presentation.get("items", {}) as Dictionary).get(card_id, ""))
	if item_path.is_empty():
		return
	var texture := load(item_path) as Texture2D
	if texture == null:
		return
	var sprite := Sprite3D.new()
	sprite.name = "ItemArt_%s" % card_id
	sprite.texture = texture
	sprite.position = Vector3(0, y + 0.42, 0)
	sprite.pixel_size = 0.0024
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	parent.add_child(sprite)


func _set_house_camera() -> void:
	if camera == null:
		return
	_set_battle_neutral_lighting(false)
	var points: Array[Vector3] = []
	for raw_pos in room_rules.placed.keys():
		points.append(_house_world(raw_pos))
	for frontier in room_rules.frontiers():
		points.append(_house_world(frontier))
	var center := Vector3.ZERO
	for point in points:
		center += point
	if not points.is_empty():
		center /= float(points.size())
	var span := 12.0
	for point in points:
		span = maxf(span, maxf(absf(point.x - center.x) * 2.2 + 5.0, absf(point.z - center.z) * 2.2 + 5.0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = minf(28.0, span)
	camera.position = center + Vector3(10.5, 13.5, 11.5)
	camera.look_at(center + Vector3(0, 0.2, 0), Vector3.UP)


func _set_battle_camera() -> void:
	_set_battle_neutral_lighting(true)
	reset_battle_camera()


func _set_battle_neutral_lighting(enabled: bool) -> void:
	var key_light := world_root.get_node_or_null("KeyLight") as DirectionalLight3D
	var fill_light := world_root.get_node_or_null("FillLight") as DirectionalLight3D
	var environment_node := world_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if key_light != null:
		key_light.light_color = Color("fff8ee") if enabled else Color("ffe0ad")
	if fill_light != null:
		fill_light.light_color = Color("bac1c3") if enabled else Color("6bc7d1")
	if environment_node != null and environment_node.environment != null:
		environment_node.environment.ambient_light_color = Color("aeb2b2") if enabled else Color("8bc8be")


func _house_world(pos: Vector2i) -> Vector3:
	return Vector3(float(pos.x) * HOUSE_CELL, 0.0, float(pos.y) * HOUSE_CELL)


func _battle_world(pos: Vector2i) -> Vector3:
	return Vector3((float(pos.x) - float(combat.cols - 1) * 0.5) * BATTLE_CELL, 0.0, (float(pos.y) - float(combat.rows - 1) * 0.5) * BATTLE_CELL)


func _screen_to_plane(screen_pos: Vector2, plane_y: float) -> Variant:
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	if absf(direction.y) < 0.0001:
		return null
	var distance := (plane_y - origin.y) / direction.y
	if distance < 0.0:
		return null
	return origin + direction * distance


func _make_build_offers(target: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var legal_room: Dictionary = {}
	for room in remaining_rooms:
		if not room_rules.valid_rotations(target, room).is_empty():
			legal_room = room
			break
	if not legal_room.is_empty():
		result.append(legal_room)
	var candidates: Array[Dictionary] = remaining_rooms.duplicate(true)
	_shuffle_variants(candidates)
	for room in candidates:
		if result.size() >= 3:
			break
		if not _contains_room(result, str(room.get("id", ""))):
			result.append(room)
	return result


func _select_first_valid_rotation() -> void:
	offer_rotation = 0
	if build_offers.is_empty():
		return
	var valid: Array[int] = room_rules.valid_rotations(selected_frontier, build_offers[selected_offer])
	if not valid.is_empty():
		offer_rotation = valid[0]


func _rooms_connected(a: Vector2i, b: Vector2i) -> bool:
	if not room_rules.placed.has(a) or not room_rules.placed.has(b):
		return false
	var delta := b - a
	var side := -1
	if delta == Vector2i.UP:
		side = 0
	elif delta == Vector2i.RIGHT:
		side = 1
	elif delta == Vector2i.DOWN:
		side = 2
	elif delta == Vector2i.LEFT:
		side = 3
	if side < 0:
		return false
	var doors: Array = room_rules.placed[a].get("doors", [])
	var other: Array = room_rules.placed[b].get("doors", [])
	return doors.size() >= 4 and other.size() >= 4 and bool(doors[side]) and bool(other[(side + 2) % 4])


func _contains_room(rooms: Array[Dictionary], room_id: String) -> bool:
	for room in rooms:
		if str(room.get("id", "")) == room_id:
			return true
	return false


func _remove_remaining_room(room_id: String) -> void:
	for i in range(remaining_rooms.size() - 1, -1, -1):
		if str(remaining_rooms[i].get("id", "")) == room_id:
			remaining_rooms.remove_at(i)


func _find_room_node(pos: Vector2i) -> Node3D:
	return house_root.get_node_or_null("Room_%d_%d" % [pos.x, pos.y]) as Node3D


func _cancel_dynamic_effect() -> void:
	if active_motion_tween != null and active_motion_tween.is_valid():
		active_motion_tween.kill()
	active_motion_tween = null
	animation_busy = false
	active_animation_kind = ""


func _complete_dynamic_effect() -> void:
	active_motion_tween = null
	animation_busy = false
	active_animation_kind = ""


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.free()


func _add_box(parent: Node3D, node_name: String, local_position: Vector3, box_size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = box_size
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, node_name: String, local_position: Vector3, radius: float, height: float, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _add_label(parent: Node3D, node_name: String, text_value: String, local_position: Vector3, color: Color, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = text_value
	label.position = local_position
	label.font_size = font_size
	label.pixel_size = 0.012
	label.modulate = color
	label.outline_modulate = COL_INK
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	return label


func _material(color: Color, transparent: bool = false, emission_strength: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	if transparent or color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = emission_strength > 0.0
	if material.emission_enabled:
		material.emission = Color(color, 1.0) * emission_strength
	return material


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _shuffle_variants(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = items[i]
		items[i] = items[j]
		items[j] = temp


func _refresh_hud() -> void:
	if hud != null:
		hud.sync_layout()
		hud.queue_redraw()
