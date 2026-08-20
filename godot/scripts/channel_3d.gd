extends Node3D

const RoomRules = preload("res://scripts/room_rules.gd")
const RoomFootprintCatalog = preload("res://scripts/room_footprint_catalog.gd")
const CombatRules = preload("res://scripts/combat_rules.gd")
const WebContentAdapter = preload("res://scripts/web_content_adapter.gd")
const CharacterPresenter = preload("res://scripts/character_presenter.gd")
const RoomArtRegistry = preload("res://scripts/room_art_registry.gd")
const DIORAMA_ART_LAB = preload("res://scenes/diorama_art_lab.tscn")
const PCG_DIORAMA_STITCH_LAB = preload("res://scenes/pcg_diorama_stitch_lab.tscn")
const PCG_HAND_LAYOUT_LAB = preload("res://scenes/pcg_hand_layout_lab.tscn")
const PCG_HAND_ROOM_SCRIPT = preload("res://scripts/pcg_hand_room.gd")
const KAYKIT_DUNGEON_ROOT := "res://assets/third_party/kaykit_dungeon/models/"

const EXE_SOURCE_ID := "CabinSlice_织梦频道.exe@EEC4C574CC22"
const SNAPSHOT_ROOT := "res://data/exe_snapshot/"
const PRESENTATION_MANIFEST := "res://data/presentation_manifest.json"
const RUN_SAVE_PATH := "user://channel_run_v1.json"
const DISPLAY_SETTINGS_PATH := "user://channel_display.cfg"
const DISPLAY_RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const BATTLE_HEIGHT_ASSET_ROOT := "res://assets/quaternius/ultimate_house_interior/"
const BATTLE_HEIGHT_ASSETS := {
	1: ["Table_RoundLarge.fbx", "Couch_Medium1.fbx", "Kitchen_Oven.fbx"],
	2: ["Bookshelf.fbx", "Kitchen_Fridge.fbx", "Fireplace.fbx"],
}
const HOUSE_CELL := 3.4
const BATTLE_CELL := 2.35
const BATTLE_SHELL_WALL_HEIGHT := 1.65
const BATTLE_SHELL_JUNCTION_WIDTH := 0.22

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
const HOUSE_CAMERA_DIRECTION := Vector3(10.5, 13.5, 11.5)
const CAMERA_ZOOM_MIN := 0.55
const CAMERA_ZOOM_MAX := 1.35
const CAMERA_ORBIT_SENSITIVITY := 0.008
const CAMERA_INTRO_FAR_SCALE := 2.4
const CAMERA_INTRO_DURATION := 1.35
const HOUSE_CAMERA_FOLLOW_RATE := 3.4
const HOUSE_CAMERA_FRAME_OFFSET := 0.15
const HOUSE_CAMERA_RETURN_DELAY := 1.5
const HOUSE_CAMERA_RETURN_DURATION := 1.05
const BATTLE_CAMERA_FOLLOW_RATE := 4.5
const BATTLE_CAMERA_FRAME_OFFSET := 0.12
const BATTLE_CAMERA_RETURN_DELAY := 1.5
const BATTLE_CAMERA_RETURN_DURATION := 0.9
const INVALID_CELL := Vector2i(-999, -999)
const UNITY_ROOM_DROP_DURATION := 0.25
const UNITY_ROOM_DROP_HEIGHT_CELLS := 0.65
const UNITY_ROOM_START_SCALE := 0.94
const UNITY_ACTOR_STEP_DURATION := 0.25
const UNITY_ACTOR_SETTLE_DURATION := 0.12
const UNITY_CARD_HALF_FLIP_DURATION := 0.10
const ENEMY_STEP_DURATION := 0.18
const ENEMY_ATTACK_DURATION := 0.22
const BATTLE_STAGE_BUILD_DURATION := 0.34
const BATTLE_ACTOR_ENTRY_DURATION := 0.30
const CHASE_TRACK_LENGTH := 14.0
const CHASE_PLAYER_START := 5.0
const CHASE_POLICE_START := 0.0
const CHASE_POLICE_SPEED := 0.12
const CHASE_SENTENCE_STEP := 10.0
const CHASE_COUNTDOWN_DURATION := 2.8
const CHASE_CATCH_DISTANCE := 0.05
const CHASE_MISS_FLASH_DURATION := 0.22
const CHASE_FINISH_DELAY := 0.52
const CHASE_SENTENCES := [
	"run for the cabin door now",
	"keep your boots quiet please",
	"dash past the rusted gate",
	"the hallway still bites hard",
	"slip through the mud and go",
	"climb the attic stair fast",
	"hide behind the salt line",
	"kick open the back door",
]
const CHASE_COUNTDOWN_LABELS := ["3", "2", "1", "跑！"]
const CHASE_COUNTDOWN_STEP_DURATION := 0.75
const CHASE_COUNTDOWN_RUN_DURATION := 0.55
const MAX_RANDOM_RUN_SEED := 2_147_483_646
const MAX_RUN_SEED_CODE := 9_999_999_999
const RUN_LAYOUT_PROFILES := [
	{"id": "compact", "label": "紧凑街屋", "weights": {"single": 6, "line3": 3, "l3": 3, "large": 1}},
	{"id": "branching", "label": "分枝旅馆", "weights": {"single": 2, "line3": 4, "l3": 6, "large": 3}},
	{"id": "courtyard", "label": "庭院大宅", "weights": {"single": 1, "line3": 3, "l3": 3, "large": 7}},
	{"id": "mixed", "label": "错层公寓", "weights": {"single": 3, "line3": 5, "l3": 4, "large": 5}},
]
const LARGE_ROOM_TEST_SEQUENCE := [1, 3, 3, 5, 3, 1, 3, 5, 3, 1, 3, 1]
const LARGE_ROOM_TEST_TARGETS := {1: 4, 3: 6, 5: 2}
const LARGE_ROOM_TEST_SHAPE_OVERRIDES := {
	"living": "l3",
	"kitchen": "line3",
	"greenhouse": "l3",
	"bedroom": "line3",
	"nursery": "l3",
	"yard": "plus5",
}

@onready var world_container: SubViewportContainer = $WorldLayer/WorldContainer
@onready var world_viewport: SubViewport = $WorldLayer/WorldContainer/WorldViewport
@onready var world_root: Node3D = $WorldLayer/WorldContainer/WorldViewport/WorldRoot
@onready var camera: Camera3D = $WorldLayer/WorldContainer/WorldViewport/WorldRoot/CameraRig/Camera3D
@onready var house_root: Node3D = $WorldLayer/WorldContainer/WorldViewport/WorldRoot/HouseRoot
@onready var battle_root: Node3D = $WorldLayer/WorldContainer/WorldViewport/WorldRoot/BattleRoot
@onready var hud: Control = $HUD/HUDRoot
@onready var home_video: VideoStreamPlayer = $WorldLayer/HomeVideo

@export_range(0.0, 4.0, 0.05) var animation_duration_scale := 1.0

var content: Dictionary = {}
var presentation: Dictionary = {}
var room_rules = RoomRules.new()
var combat = null
var rng := RandomNumberGenerator.new()

var run_seed := 2522061406
var run_layout_profile: Dictionary = {}
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
var house_camera_target := Vector3.ZERO
var house_camera_fit_size := 12.0
var house_camera_zoom_ratio := 1.0
var house_camera_user_adjusted := false
var house_camera_distance := HOUSE_CAMERA_DIRECTION.length()
var house_camera_yaw := atan2(HOUSE_CAMERA_DIRECTION.x, HOUSE_CAMERA_DIRECTION.z)
var house_camera_pitch := atan2(HOUSE_CAMERA_DIRECTION.y, Vector2(HOUSE_CAMERA_DIRECTION.x, HOUSE_CAMERA_DIRECTION.z).length())
var house_player_facing_yaw := 0.0
var house_actor_slot_assignments: Dictionary = {}
var battle_camera_target := Vector3.ZERO
var battle_camera_fit_size := 12.0
var battle_camera_zoom_ratio := 1.0
var battle_camera_distance := 20.0
var battle_camera_yaw := atan2(CAMERA_DIRECTION.x, CAMERA_DIRECTION.z)
var battle_camera_pitch := atan2(CAMERA_DIRECTION.y, Vector2(CAMERA_DIRECTION.x, CAMERA_DIRECTION.z).length())
var battle_player_facing_yaw := 0.0
var battle_enemy_facing_yaw := PI
var house_camera_following := false
var house_camera_user_hold := false
var house_camera_return_delay := 0.0
var house_camera_returning := false
var house_camera_intro_weight := 1.0
var house_camera_intro_tween: Tween = null
var house_camera_return_tween: Tween = null
var battle_camera_following := false
var battle_camera_user_hold := false
var battle_camera_return_delay := 0.0
var battle_camera_returning := false
var battle_camera_return_tween: Tween = null
var battle_room_title := "房间"
var battle_shell_edge_records: Dictionary = {}
var battle_shell_culled_count := 0
var battle_shell_visible_count := 0
var hovered_battle_cell := INVALID_CELL
var hovered_house_cell := INVALID_CELL
var animation_busy := false
var active_animation_kind := ""
var active_motion_tween: Tween = null
var build_preview_tween: Tween = null
var lab_root: Node3D = null
var home_tests_open := false
var show_house_diagnostics := false
var large_room_mix_test_mode := false
var character_animation_demo_mode := false
var kenney_build_lab_mode := true  # 桌模建造已转正：主游玩默认用 Kaykit/Kenney 桌模渲染房间
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
var chase_sentence := ""
var chase_typed := 0
var chase_police_progress := CHASE_POLICE_START
var chase_player_progress := CHASE_PLAYER_START
var chase_started := false
var chase_phase := "idle"
var chase_countdown := 0.0
var chase_countdown_index := 0
var chase_countdown_step_remaining := 0.0
var chase_countdown_text := ""
var chase_miss_flash_remaining := 0.0
var chase_used_sentences: Array[String] = []
var chase_finish_delay_remaining := 0.0
var chase_event_result_pending := false
var chase_result := ""
var lab_camera_target := Vector3.ZERO
var lab_camera_yaw := 0.0
var lab_camera_pitch := 0.24
var lab_camera_distance := 14.0
var pcg_diorama_seed := 20260816
var display_resolution_index := 2
var display_fullscreen := false
var display_change_generation := 0


func _ready() -> void:
	_load_display_settings()
	_configure_environment()
	_configure_home_video()
	presentation = _load_json_dictionary(PRESENTATION_MANIFEST)
	lab_root = Node3D.new()
	lab_root.name = "LabRoot"
	world_root.add_child(lab_root)
	hud.game = self
	hud.sync_layout()
	reset_run(run_seed)
	go_home()


func display_resolution_label() -> String:
	var resolution: Vector2i = DISPLAY_RESOLUTIONS[display_resolution_index]
	return "%d×%d" % [resolution.x, resolution.y]


func display_mode_label() -> String:
	return "全屏" if display_fullscreen else "窗口"


func cycle_display_resolution() -> void:
	display_resolution_index = (display_resolution_index + 1) % DISPLAY_RESOLUTIONS.size()
	_apply_display_settings(true)
	_refresh_hud()


func toggle_display_mode() -> void:
	display_fullscreen = not display_fullscreen
	_apply_display_settings(true)
	_refresh_hud()


func quit_game() -> void:
	get_tree().quit()


func _load_display_settings() -> void:
	var settings := ConfigFile.new()
	if settings.load(DISPLAY_SETTINGS_PATH) == OK:
		display_resolution_index = clampi(int(settings.get_value("display", "resolution_index", 2)), 0, DISPLAY_RESOLUTIONS.size() - 1)
		display_fullscreen = bool(settings.get_value("display", "fullscreen", false))
	_apply_display_settings(false)


func _apply_display_settings(save_settings: bool) -> void:
	display_change_generation += 1
	var generation := display_change_generation
	var requested_fullscreen := display_fullscreen
	if display_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await get_tree().process_frame
	if generation != display_change_generation:
		return
	if not requested_fullscreen:
		var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		var resolution := _fit_windowed_resolution(DISPLAY_RESOLUTIONS[display_resolution_index], usable.size)
		DisplayServer.window_set_size(resolution)
		DisplayServer.window_set_position(usable.position + (usable.size - resolution) / 2)
	await get_tree().process_frame
	if generation != display_change_generation:
		return
	var actual_mode := DisplayServer.window_get_mode()
	display_fullscreen = actual_mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if hud != null:
		hud.sync_layout()
	if save_settings:
		var settings := ConfigFile.new()
		settings.set_value("display", "resolution_index", display_resolution_index)
		settings.set_value("display", "fullscreen", display_fullscreen)
		settings.save(DISPLAY_SETTINGS_PATH)
	_refresh_hud()


func _fit_windowed_resolution(requested: Vector2i, usable_size: Vector2i) -> Vector2i:
	var maximum := Vector2i(maxi(640, usable_size.x - 64), maxi(360, usable_size.y - 96))
	if requested.x <= maximum.x and requested.y <= maximum.y:
		return requested
	var ratio := minf(float(maximum.x) / float(requested.x), float(maximum.y) / float(requested.y))
	return Vector2i(maxi(640, roundi(float(requested.x) * ratio)), maxi(360, roundi(float(requested.y) * ratio)))


func _configure_home_video() -> void:
	if home_video == null:
		return
	var stream := VideoStreamTheora.new()
	stream.file = "res://assets/ui/menu_video.ogv"
	home_video.stream = stream
	home_video.loop = true


func _set_home_video(active: bool) -> void:
	if home_video == null:
		return
	home_video.visible = active
	if active:
		home_video.paused = false
		home_video.play()
	else:
		home_video.paused = true
		home_video.stop()


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
	_update_camera_follow(delta)


func _update_camera_follow(delta: float) -> void:
	if house_camera_return_delay > 0.0:
		house_camera_return_delay = maxf(0.0, house_camera_return_delay - delta)
		if house_camera_return_delay <= 0.0 and not house_camera_user_hold:
			_start_house_camera_return()
	if phase in ["explore", "build", "room_ready"] and camera != null:
		if house_camera_following and not house_camera_user_hold and not house_camera_returning:
			var follow_target := _house_follow_target_position() + _house_camera_frame_offset()
			var factor := 1.0 - exp(-HOUSE_CAMERA_FOLLOW_RATE * delta)
			var next_target := house_camera_target.lerp(follow_target, factor)
			if not next_target.is_equal_approx(house_camera_target):
				house_camera_target = next_target
				_clamp_house_camera_target()
				_apply_house_camera()
	elif phase == "combat" and combat != null and camera != null:
		if battle_camera_return_delay > 0.0:
			battle_camera_return_delay = maxf(0.0, battle_camera_return_delay - delta)
			if battle_camera_return_delay <= 0.0 and not battle_camera_user_hold:
				_start_battle_camera_return()
		if battle_camera_following and not battle_camera_user_hold and not battle_camera_returning:
			var follow_target := _battle_follow_target_position() + _battle_camera_frame_offset()
			var factor := 1.0 - exp(-HOUSE_CAMERA_FOLLOW_RATE * delta)
			var next_target := battle_camera_target.lerp(follow_target, factor)
			if not next_target.is_equal_approx(battle_camera_target):
				battle_camera_target = next_target
				_clamp_battle_camera_target()
				_apply_battle_camera()


func _house_follow_target_position() -> Vector3:
	var token := house_root.get_node_or_null("LiliToken") as Node3D
	if token != null:
		return Vector3(token.position.x, 0.0, token.position.z)
	return _house_world(current_room_pos)


func _house_camera_frame_offset() -> Vector3:
	if camera == null:
		return Vector3.ZERO
	return camera.global_transform.basis.y * (camera.size * HOUSE_CAMERA_FRAME_OFFSET)


func _battle_camera_frame_offset() -> Vector3:
	if camera == null:
		return Vector3.ZERO
	return camera.global_transform.basis.y * (camera.size * BATTLE_CAMERA_FRAME_OFFSET)


func _battle_follow_target_position() -> Vector3:
	if combat == null:
		return Vector3.ZERO
	var player_world := _battle_pawn_world(combat.player_pos, true)
	var enemy_world := _battle_world(combat.enemy_pos)
	return (player_world + enemy_world) * 0.5


func release_battle_camera_gesture() -> void:
	battle_camera_user_hold = false
	if not battle_camera_returning:
		battle_camera_return_delay = BATTLE_CAMERA_RETURN_DELAY


func _cancel_battle_camera_return() -> void:
	battle_camera_return_delay = 0.0
	battle_camera_returning = false
	if battle_camera_return_tween != null and battle_camera_return_tween.is_valid():
		battle_camera_return_tween.kill()
		battle_camera_return_tween = null


func _start_battle_camera_return() -> void:
	if camera == null or combat == null:
		return
	battle_camera_returning = true
	var player_pos := _battle_follow_target_position() + _battle_camera_frame_offset()
	var duration := BATTLE_CAMERA_RETURN_DURATION * animation_duration_scale
	if duration <= 0.0:
		battle_camera_target = player_pos
		battle_camera_returning = false
		_clamp_battle_camera_target()
		_apply_battle_camera()
		return
	var start_target := battle_camera_target
	battle_camera_return_tween = create_tween()
	battle_camera_return_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	battle_camera_return_tween.tween_method(func(weight: float) -> void:
		battle_camera_target = start_target.lerp(player_pos, weight)
		_clamp_battle_camera_target()
		_apply_battle_camera()
	, 0.0, 1.0, duration)
	battle_camera_return_tween.finished.connect(func() -> void:
		battle_camera_returning = false
		battle_camera_return_delay = 0.0
		battle_camera_return_tween = null
		_clamp_battle_camera_target()
		_apply_battle_camera()
	)


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
		_refit_battle_camera(true)
	elif phase in ["lab_search", "lab_diorama", "lab_pcg_diorama", "lab_hand_diorama"]:
		_apply_search_camera()
	else:
		_set_house_camera()


func screen_to_world_view(screen_pos: Vector2) -> Vector2:
	return screen_pos - world_view_rect.position


func is_world_view_point(screen_pos: Vector2) -> bool:
	return world_view_rect.has_point(screen_pos)


func reset_run(seed_value: int = 0) -> void:
	_cancel_dynamic_effect()
	show_house_diagnostics = false
	large_room_mix_test_mode = false
	character_animation_demo_mode = false
	camera.environment = null
	world_container.visible = true
	house_root.visible = true
	battle_root.visible = false
	if lab_root != null:
		lab_root.visible = false
	if seed_value != 0:
		run_seed = seed_value
	rng.seed = run_seed
	run_layout_profile = (RUN_LAYOUT_PROFILES[posmod(run_seed, RUN_LAYOUT_PROFILES.size())] as Dictionary).duplicate(true)
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
	hovered_house_cell = INVALID_CELL
	house_camera_target = Vector3.ZERO
	house_camera_fit_size = 12.0
	house_camera_zoom_ratio = 1.0
	house_camera_user_adjusted = false
	house_camera_yaw = atan2(HOUSE_CAMERA_DIRECTION.x, HOUSE_CAMERA_DIRECTION.z)
	house_camera_pitch = atan2(HOUSE_CAMERA_DIRECTION.y, Vector2(HOUSE_CAMERA_DIRECTION.x, HOUSE_CAMERA_DIRECTION.z).length())
	house_camera_distance = HOUSE_CAMERA_DIRECTION.length()
	house_camera_following = false
	house_camera_user_hold = false
	house_camera_return_delay = 0.0
	house_camera_returning = false
	battle_camera_following = false
	house_player_facing_yaw = 0.0
	house_actor_slot_assignments.clear()
	battle_player_facing_yaw = 0.0
	battle_enemy_facing_yaw = PI
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
	_start_camera_intro()
	_refresh_hud()


func start_new_run(tutorial_mode: bool = false, seed_override: int = 0) -> void:
	_set_home_video(false)
	var next_seed := seed_override if seed_override != 0 else _random_run_seed()
	reset_run(next_seed)
	status_message = "教学提示：先选预兆，再点黄色扩建格；战斗中绿色=移动、金色=放置。" if tutorial_mode else "本集格局：%s。先从两枚行前预兆中选一枚。" % current_layout_profile_label()
	_refresh_hud()
	_save_run()


func _random_run_seed() -> int:
	var entropy_rng := RandomNumberGenerator.new()
	entropy_rng.randomize()
	var candidate := entropy_rng.randi_range(1, MAX_RANDOM_RUN_SEED)
	if candidate == run_seed:
		candidate = 1 if candidate == MAX_RANDOM_RUN_SEED else candidate + 1
	return candidate


func current_layout_profile_label() -> String:
	return str(run_layout_profile.get("label", "随机片场"))


func start_run_from_seed_text(seed_text: String, tutorial_mode: bool = false) -> bool:
	var normalized := seed_text.strip_edges()
	if not normalized.is_valid_int():
		return false
	var requested_seed := int(normalized)
	if requested_seed <= 0 or requested_seed > MAX_RUN_SEED_CODE:
		return false
	start_new_run(tutorial_mode, requested_seed)
	return true


func copy_current_seed() -> void:
	DisplayServer.clipboard_set(str(run_seed))


func go_home() -> void:
	_cancel_dynamic_effect()
	character_animation_demo_mode = false
	camera.environment = null
	house_camera_following = false
	house_camera_user_hold = false
	house_camera_return_delay = 0.0
	house_camera_returning = false
	house_camera_intro_weight = 1.0
	battle_camera_following = false
	if house_camera_return_tween != null and house_camera_return_tween.is_valid():
		house_camera_return_tween.kill()
		house_camera_return_tween = null
	if house_camera_intro_tween != null and house_camera_intro_tween.is_valid():
		house_camera_intro_tween.kill()
	phase = "home"
	home_tests_open = false
	house_root.visible = false
	battle_root.visible = false
	if lab_root != null:
		lab_root.visible = false
	world_container.visible = false
	_set_home_video(true)
	status_message = "电视机预热完毕。"
	_refresh_hud()


func has_saved_run() -> bool:
	return FileAccess.file_exists(RUN_SAVE_PATH)


func continue_saved_run() -> bool:
	_set_home_video(false)
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
	house_player_facing_yaw = float(save.get("house_player_facing_yaw", 0.0))
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
	_set_home_video(false)
	world_container.visible = true
	house_root.visible = false
	if lab_root != null:
		lab_root.visible = false
	start_combat(room)
	combat.hand.assign(["jab", "guard", "brace", "fling"])
	status_message = "意图实验：未揭示怪物最多埋伏一拍，随后会巡逻；蓝色编号显示逐步路径。"
	build_battle_world()
	_refresh_hud()


func start_kenney_build_lab() -> void:
	_set_home_video(false)
	kenney_build_lab_mode = true
	reset_run(run_seed + 101)
	show_house_diagnostics = true
	large_room_mix_test_mode = true
	_apply_large_room_test_catalog()
	camera.environment = _make_visual_polish_environment()
	phase = "explore"
	omen_options.clear()
	status_message = "大房间节奏实验：三选一优先展示不同尺寸；生活房升格，整房统一地板，正式开局暂不受影响。"
	build_house_world()
	_set_house_camera()
	_refresh_hud()


func start_diorama_art_lab() -> void:
	_prepare_lab("lab_diorama")
	var comparison := DIORAMA_ART_LAB.instantiate() as Node3D
	comparison.name = "DioramaArtComparison"
	lab_root.add_child(comparison)
	camera.environment = _make_visual_polish_environment()
	status_message = "A 验证暖色焦点、接触阴影、实体剖切墙与信号发光；B/C 保留资产基线，便于直接判断增强是否真的改善层次。"
	_set_diorama_camera_defaults()
	_refresh_hud()


func start_character_animation_lab() -> void:
	character_animation_demo_mode = true
	start_combat_lab("hall")
	character_animation_demo_mode = true
	combat.energy = maxi(combat.energy, 20)
	status_message = "角色动画实景检查：使用正式战斗房、地格、家具、镜头与移动链路。右侧按钮可重复检查待机、走格、攻击和受击。"
	_refresh_hud()


func demo_character_idle() -> void:
	if not character_animation_demo_mode or phase != "combat":
		return
	var presenter := battle_root.get_node_or_null("Player/Presenter")
	if presenter != null and presenter.has_method("preview_model_animation"):
		presenter.preview_model_animation("idle")
	status_message = "待机：正在播放 FBX preset_biped_idle。"
	_refresh_hud()


func demo_character_grid_step() -> void:
	if not character_animation_demo_mode or phase != "combat" or animation_busy:
		return
	combat.energy = maxi(combat.energy, 20)
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var target: Vector2i = combat.player_pos + direction
		if combat.can_move_player(target):
			handle_battle_cell(target)
			status_message = "走一格：调用正式寻路、占格、朝向和 0.25 秒跳格动画。"
			_refresh_hud()
			return
	status_message = "当前格四周没有可走地格，请用镜头查看阻挡。"
	_refresh_hud()


func demo_character_attack() -> void:
	if not character_animation_demo_mode or phase != "combat":
		return
	var presenter := battle_root.get_node_or_null("Player/Presenter")
	var duration := 0.0
	if presenter != null and presenter.has_method("preview_model_animation"):
		duration = presenter.preview_model_animation("attack", 1.5)
	status_message = "攻击：完整预览 FBX preset_biped_slash（%.1f 秒），结束后自动回到待机。" % duration
	_refresh_hud()


func demo_character_hurt() -> void:
	if not character_animation_demo_mode or phase != "combat":
		return
	var presenter := battle_root.get_node_or_null("Player/Presenter")
	var duration := 0.0
	if presenter != null and presenter.has_method("preview_model_animation"):
		duration = presenter.preview_model_animation("hurt", 1.25)
	status_message = "受击：完整预览 FBX preset_biped_afraid（%.1f 秒），不改变生命值。" % duration
	_refresh_hud()


func start_pcg_diorama_lab() -> void:
	_prepare_lab("lab_pcg_diorama")
	var generator := PCG_DIORAMA_STITCH_LAB.instantiate() as Node3D
	generator.name = "PcgDioramaStitch"
	generator.generation_seed = pcg_diorama_seed
	lab_root.add_child(generator)
	_set_pcg_diorama_camera(generator)
	status_message = "先看 R00·1格 整块接入 R01·5格，再继续拼 3/1/5 格；编号保留房间归属，门洞标记跨房连接，整房依次落位。"
	_refresh_hud()


func reroll_pcg_diorama() -> void:
	if phase != "lab_pcg_diorama":
		return
	var generator := lab_root.get_node_or_null("PcgDioramaStitch")
	if generator == null:
		return
	pcg_diorama_seed += 1
	generator.regenerate(pcg_diorama_seed)
	_set_pcg_diorama_camera(generator)
	status_message = "已换 Seed %d 并重播建造：%d 房 / %d 格 / %d 门洞 / %d 外墙 / %d 楼梯。" % [pcg_diorama_seed, generator.rooms.size(), generator.occupancy.size(), generator.doorway_count, generator.external_wall_count, generator.stair_count]
	_refresh_hud()


func start_pcg_hand_layout_lab() -> void:
	_prepare_lab("lab_hand_diorama")
	var composer := PCG_HAND_LAYOUT_LAB.instantiate() as Node3D
	composer.name = "PcgHandLayout"
	lab_root.add_child(composer)
	_set_pcg_diorama_camera(composer)
	status_message = "这是正式地图手摆模拟：在 Godot 编辑器打开 pcg_hand_layout_lab.tscn，移动 Layout 下的房间根节点；运行这里检查镜头、拼接和整房落位动画。当前 %s。" % composer.authored_summary()
	_refresh_hud()


func _set_pcg_diorama_camera(generator: Node3D) -> void:
	lab_camera_target = generator.camera_target()
	lab_camera_yaw = -0.62
	lab_camera_pitch = 0.40
	lab_camera_distance = generator.suggested_camera_distance()
	_apply_search_camera()


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
	status_message = "用鼠标点开始——倒计时后再碰键盘。"
	_refresh_hud()


func _reset_chase() -> void:
	chase_sentence = ""
	chase_typed = 0
	chase_police_progress = CHASE_POLICE_START
	chase_player_progress = CHASE_PLAYER_START
	chase_started = false
	chase_phase = "ready"
	chase_countdown = 0.0
	chase_countdown_index = 0
	chase_countdown_step_remaining = 0.0
	chase_countdown_text = ""
	chase_miss_flash_remaining = 0.0
	chase_used_sentences.clear()
	chase_finish_delay_remaining = 0.0
	chase_event_result_pending = false
	chase_result = ""


func begin_chase() -> void:
	if phase != "lab_chase" or chase_phase != "ready" or not chase_result.is_empty():
		return
	chase_started = true
	chase_phase = "countdown"
	chase_countdown = CHASE_COUNTDOWN_DURATION
	chase_countdown_index = 0
	chase_countdown_step_remaining = CHASE_COUNTDOWN_STEP_DURATION
	chase_countdown_text = str(CHASE_COUNTDOWN_LABELS[0])
	status_message = "盯着倒计时，准备打一整句。"
	_refresh_hud()


func chase_type_character(character: String) -> void:
	if phase != "lab_chase" or chase_phase != "race" or not chase_started or not chase_result.is_empty() or character.length() != 1:
		return
	var expected := chase_sentence.substr(chase_typed, 1)
	var matches := character == " " if expected == " " else character.to_lower() == expected.to_lower()
	if matches:
		chase_typed += 1
		chase_miss_flash_remaining = 0.0
		if chase_typed >= chase_sentence.length():
			chase_player_progress = minf(CHASE_TRACK_LENGTH, chase_player_progress + CHASE_SENTENCE_STEP)
			if chase_player_progress >= CHASE_TRACK_LENGTH - 0.01:
				_finish_chase(true)
			else:
				_next_chase_sentence()
				status_message = "一句打完，继续下一句！"
	else:
		chase_miss_flash_remaining = CHASE_MISS_FLASH_DURATION
		status_message = "打错了——进度还在，再打这个字。"
	_refresh_hud()


func forfeit_chase() -> void:
	if phase == "lab_chase" and chase_phase != "done":
		_finish_chase(false, "你举手投降——警察给节目组鞠躬。")


func _update_chase(delta: float) -> void:
	if chase_phase == "done":
		_update_chase_finish_delay(delta)
		return
	if not chase_started:
		return
	chase_miss_flash_remaining = maxf(0.0, chase_miss_flash_remaining - delta)
	if chase_phase == "countdown":
		_update_chase_countdown(delta)
		if hud != null:
			hud.queue_redraw()
		return
	if chase_phase != "race":
		return
	var race_delta := minf(0.05, delta)
	chase_police_progress = minf(CHASE_TRACK_LENGTH, chase_police_progress + race_delta * CHASE_POLICE_SPEED)
	if hud != null:
		hud.queue_redraw()
	if chase_police_progress >= chase_player_progress - CHASE_CATCH_DISTANCE:
		_finish_chase(false)


func _update_chase_countdown(delta: float) -> void:
	chase_countdown = maxf(0.0, chase_countdown - delta)
	var remaining_delta := delta
	while chase_phase == "countdown" and remaining_delta >= chase_countdown_step_remaining:
		remaining_delta -= chase_countdown_step_remaining
		chase_countdown_index += 1
		if chase_countdown_index >= CHASE_COUNTDOWN_LABELS.size():
			chase_phase = "race"
			chase_countdown = 0.0
			chase_countdown_step_remaining = 0.0
			chase_countdown_text = ""
			_next_chase_sentence()
			status_message = "打完整句往前跑。打错只闪一下，进度不清空。"
			return
		chase_countdown_text = str(CHASE_COUNTDOWN_LABELS[chase_countdown_index])
		chase_countdown_step_remaining = CHASE_COUNTDOWN_RUN_DURATION if chase_countdown_index == CHASE_COUNTDOWN_LABELS.size() - 1 else CHASE_COUNTDOWN_STEP_DURATION
	if chase_phase == "countdown":
		chase_countdown_step_remaining -= remaining_delta


func _next_chase_sentence() -> void:
	var pool: Array[String] = []
	for candidate: String in CHASE_SENTENCES:
		if candidate not in chase_used_sentences:
			pool.append(candidate)
	if pool.is_empty():
		pool.assign(CHASE_SENTENCES)
	var next_sentence: String = pool[rng.randi_range(0, pool.size() - 1)]
	chase_used_sentences.append(next_sentence)
	if chase_used_sentences.size() >= CHASE_SENTENCES.size():
		chase_used_sentences.clear()
	chase_sentence = next_sentence
	chase_typed = 0
	chase_miss_flash_remaining = 0.0


func _finish_chase(success: bool, message: String = "") -> void:
	if chase_phase == "done":
		return
	chase_result = "success" if success else "failure"
	chase_started = false
	chase_phase = "done"
	chase_countdown_text = ""
	chase_miss_flash_remaining = 0.0
	status_message = message if not message.is_empty() else ("你踹开门溜进雾里——速度涨了一截。" if success else "警察抓住了你——节目组大笑。")
	chase_event_result_pending = event_context == "chase"
	chase_finish_delay_remaining = CHASE_FINISH_DELAY if chase_event_result_pending else 0.0
	_refresh_hud()


func _update_chase_finish_delay(delta: float) -> void:
	if not chase_event_result_pending:
		return
	chase_finish_delay_remaining = maxf(0.0, chase_finish_delay_remaining - delta)
	if chase_finish_delay_remaining <= 0.0:
		chase_event_result_pending = false
		finish_event_trial(chase_result == "success")


func _prepare_lab(next_phase: String) -> void:
	_cancel_dynamic_effect()
	_set_home_video(false)
	camera.environment = null
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


func _set_diorama_camera_defaults() -> void:
	lab_camera_target = Vector3(0.0, 0.85, 0.15)
	lab_camera_yaw = 0.0
	lab_camera_pitch = 0.34
	lab_camera_distance = 16.0
	_apply_search_camera()


func _make_visual_polish_environment() -> Environment:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071116")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("58717a")
	environment.ambient_light_energy = 0.24
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.ssao_radius = 2.2
	environment.ssao_intensity = 2.0
	environment.ssao_power = 1.4
	environment.ssil_enabled = true
	environment.ssil_radius = 3.0
	environment.ssil_intensity = 0.8
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	return environment


func orbit_search_camera(relative: Vector2) -> void:
	if phase not in ["lab_search", "lab_diorama", "lab_pcg_diorama", "lab_hand_diorama"]:
		return
	lab_camera_yaw -= relative.x * 0.008
	lab_camera_pitch = clampf(lab_camera_pitch - relative.y * 0.006, 0.10, 0.72)
	_apply_search_camera()


func zoom_search_camera(factor: float) -> void:
	if phase not in ["lab_search", "lab_diorama", "lab_pcg_diorama", "lab_hand_diorama"]:
		return
	lab_camera_distance = clampf(lab_camera_distance * factor, 8.0, 28.0)
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
	offer_rotation = (offer_rotation + 1) % 4
	var preview := house_root.get_node_or_null("BuildPreview") as Node3D
	if preview != null:
		if build_preview_tween != null and build_preview_tween.is_valid():
			build_preview_tween.kill()
		build_preview_tween = create_tween()
		build_preview_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_parallel(true)
		build_preview_tween.tween_property(preview, "rotation:y", -float(offer_rotation) * PI * 0.5, 0.18 * maxf(0.25, animation_duration_scale))
		var room: Dictionary = build_offers[selected_offer]
		var preview_origin := room_rules.placement_origin(selected_frontier, room, offer_rotation)
		build_preview_tween.tween_property(preview, "position", _house_world(preview_origin) + Vector3(0, 0.20, 0), 0.18 * maxf(0.25, animation_duration_scale))
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
	room_rules.set_instance_flag(selected_frontier, "revealed", false)
	room_rules.set_instance_flag(selected_frontier, "visited", false)
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
	var room_nodes := _find_room_instance_nodes(target)
	if room_nodes.is_empty():
		status_message = final_message
		_complete_dynamic_effect()
		_refresh_hud()
		return
	var final_positions: Dictionary = {}
	var drop_height := (1.55 if kenney_build_lab_mode else HOUSE_CELL) * UNITY_ROOM_DROP_HEIGHT_CELLS
	for room_node: Node3D in room_nodes:
		final_positions[room_node] = room_node.position
		room_node.position += Vector3.UP * drop_height
		room_node.rotation = Vector3(deg_to_rad(-82.0), 0.0, 0.0)
		room_node.scale = Vector3.ONE * UNITY_ROOM_START_SCALE
	var drop_duration := UNITY_ROOM_DROP_DURATION * animation_duration_scale
	if drop_duration <= 0.0:
		for room_node: Node3D in room_nodes:
			room_node.position = final_positions[room_node]
			room_node.rotation = Vector3.ZERO
			room_node.scale = Vector3.ONE
		status_message = final_message
		_complete_dynamic_effect()
		_refresh_hud()
		return
	var tween := create_tween()
	active_motion_tween = tween
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_parallel(true)
	for room_node: Node3D in room_nodes:
		tween.tween_property(room_node, "position", final_positions[room_node], drop_duration)
		tween.tween_property(room_node, "rotation", Vector3.ZERO, drop_duration)
		tween.tween_property(room_node, "scale", Vector3.ONE * 1.035, drop_duration)
	tween.set_parallel(false)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var settle_duration := UNITY_ACTOR_SETTLE_DURATION * animation_duration_scale
	for room_index in range(room_nodes.size()):
		var room_node: Node3D = room_nodes[room_index]
		if room_index == 0:
			tween.tween_property(room_node, "scale", Vector3.ONE, settle_duration)
		else:
			tween.parallel().tween_property(room_node, "scale", Vector3.ONE, settle_duration)
	await tween.finished
	if active_motion_tween != tween:
		return
	for room_node: Node3D in room_nodes:
		room_node.position = final_positions[room_node]
		room_node.rotation = Vector3.ZERO
		room_node.scale = Vector3.ONE
	status_message = final_message
	_complete_dynamic_effect()
	_refresh_hud()


func _find_room_instance_nodes(target: Vector2i) -> Array[Node3D]:
	var result: Array[Node3D] = []
	if not room_rules.placed.has(target):
		return result
	var instance_id := str(room_rules.placed[target].get("instance_id", ""))
	if kenney_build_lab_mode:
		var generated := house_root.get_node_or_null("KenneyFormalComposer/GeneratedMap")
		if generated != null:
			for child: Node in generated.get_children():
				if child is Node3D and str(child.get_meta("room_id", "")) == instance_id:
					result.append(child as Node3D)
					return result
	for raw_cell: Variant in room_rules.placed.keys():
		var cell: Vector2i = raw_cell
		if str(room_rules.placed[cell].get("instance_id", "")) != instance_id:
			continue
		var room_node := _find_room_node(cell)
		if room_node != null:
			result.append(room_node)
	return result


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
	house_camera_following = true
	house_camera_user_hold = false
	_cancel_house_camera_return()
	status_message = "莉莉正走进未知房间……"
	_refresh_hud()
	_animate_enter_room(target)


func _animate_enter_room(target: Vector2i) -> void:
	var token := house_root.get_node_or_null("LiliToken") as Node3D
	var start_position := token.position if token != null else _house_world(current_room_pos)
	var target_position := _house_interaction_target_position("player:lili", target)
	var doorway_position := (_house_world(current_room_pos) + _house_world(target)) * 0.5
	doorway_position.y = lerpf(start_position.y, target_position.y, 0.5)
	var move_duration := UNITY_ACTOR_STEP_DURATION * animation_duration_scale
	if token != null and move_duration > 0.0:
		var presenter := token.get_node_or_null("Presenter")
		if presenter != null and presenter.has_method("play_state"):
			presenter.play_state("move")
		var move_tween := create_tween()
		active_motion_tween = move_tween
		move_tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		move_tween.tween_method(_set_house_token_path_motion.bind(token, start_position, doorway_position, target_position), 0.0, 1.0, move_duration)
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
		room_rules.set_instance_flag(target, "revealed", true)
		room = room_rules.placed[target]
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
	var direction := target_position - start_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		house_player_facing_yaw = atan2(direction.x, direction.z)
		token.rotation.y = house_player_facing_yaw


func _set_house_token_path_motion(weight: float, token: Node3D, start_position: Vector3, doorway_position: Vector3, target_position: Vector3) -> void:
	if not is_instance_valid(token):
		return
	var smooth_weight := weight * weight * (3.0 - 2.0 * weight)
	var inverse := 1.0 - smooth_weight
	var path_position := start_position * inverse * inverse + doorway_position * 2.0 * inverse * smooth_weight + target_position * smooth_weight * smooth_weight
	path_position.y += sin(smooth_weight * PI) * 0.18
	token.position = path_position
	var tangent := (doorway_position - start_position) * (2.0 * inverse) + (target_position - doorway_position) * (2.0 * smooth_weight)
	tangent.y = 0.0
	if tangent.length_squared() > 0.001:
		house_player_facing_yaw = atan2(tangent.x, tangent.z)
		token.rotation.y = house_player_facing_yaw


func _finish_enter_room(target: Vector2i) -> void:
	current_room_pos = target
	var room: Dictionary = room_rules.placed[target]
	var first_visit := not bool(room.get("visited", false))
	room_rules.set_instance_flag(target, "revealed", true)
	room_rules.set_instance_flag(target, "visited", true)
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
		start_combat(room, true)
	elif str(room.get("kind", "quiet")) == "event":
		start_event_trial(room)
	else:
		_complete_current_room()
		_start_quiet_reward()


func _complete_current_room() -> void:
	var room: Dictionary = current_room()
	if not bool(room.get("completed", false)):
		run_progress += 1
	room_rules.set_instance_flag(current_room_pos, "completed", true)
	room_rules.set_instance_flag(current_room_pos, "visited", true)


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


func start_combat(room: Dictionary, animate_entry: bool = false) -> void:
	combat = CombatRules.new()
	battle_room_title = str(room.get("name", "房间"))
	battle_player_facing_yaw = house_player_facing_yaw
	battle_enemy_facing_yaw = PI
	var enemy: Dictionary = room.get("enemy", {})
	var run_rules: Dictionary = content.get("run_rules", {}).duplicate(true)
	run_rules["player_hp"] = player_hp
	run_rules["base_speed"] = player_speed
	combat.setup(room.get("arena", {}), enemy, content.get("cards", {}), run_deck, run_seed + room_rules.instance_count() * 17, run_rules, active_relics)
	selected_card = -1
	hovered_battle_cell = INVALID_CELL
	phase = "combat"
	house_root.visible = false
	battle_root.visible = true
	battle_root.position = Vector3.ZERO
	battle_root.scale = Vector3.ONE
	build_battle_world()
	_set_battle_camera()
	var entry_message := str(room.get("arena", {}).get("spawnNote", "房门在身后合上。"))
	if animate_entry and animation_duration_scale > 0.0:
		animation_busy = true
		active_animation_kind = "combat_entry"
		status_message = "房间正在展开战斗舞台……"
		_prepare_combat_entry_pose()
		_animate_combat_entry(entry_message)
	else:
		status_message = entry_message
	_refresh_hud()


func _prepare_combat_entry_pose() -> void:
	battle_root.position = Vector3(0.0, 0.72, 0.0)
	battle_root.scale = Vector3(0.92, 0.04, 0.92)
	var player := battle_root.get_node_or_null("Player") as Node3D
	var enemy := battle_root.get_node_or_null("Enemy") as Node3D
	if player != null:
		player.visible = false
	if enemy != null:
		enemy.visible = false


func _animate_combat_entry(final_message: String) -> void:
	var stage_duration := BATTLE_STAGE_BUILD_DURATION * animation_duration_scale
	var stage_tween := create_tween()
	active_motion_tween = stage_tween
	stage_tween.set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	stage_tween.tween_property(battle_root, "position", Vector3.ZERO, stage_duration)
	stage_tween.tween_property(battle_root, "scale", Vector3.ONE, stage_duration)
	await stage_tween.finished
	if active_motion_tween != stage_tween:
		return
	battle_root.position = Vector3.ZERO
	battle_root.scale = Vector3.ONE
	var player := battle_root.get_node_or_null("Player") as Node3D
	var enemy := battle_root.get_node_or_null("Enemy") as Node3D
	if player == null or enemy == null:
		status_message = final_message
		_complete_dynamic_effect()
		_refresh_hud()
		return
	var player_target := player.position
	var enemy_target := enemy.position
	player.position = player_target + Vector3(-BATTLE_CELL * 0.70, 1.25, BATTLE_CELL * 0.55)
	enemy.position = enemy_target + Vector3(BATTLE_CELL * 0.70, 1.25, -BATTLE_CELL * 0.55)
	player.scale = Vector3.ONE * 0.68
	enemy.scale = Vector3.ONE * 0.68
	player.visible = true
	enemy.visible = true
	var actor_duration := BATTLE_ACTOR_ENTRY_DURATION * animation_duration_scale
	var actor_tween := create_tween()
	active_motion_tween = actor_tween
	actor_tween.set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	actor_tween.tween_property(player, "position", player_target, actor_duration)
	actor_tween.tween_property(player, "scale", Vector3.ONE, actor_duration)
	actor_tween.tween_property(enemy, "position", enemy_target, actor_duration)
	actor_tween.tween_property(enemy, "scale", Vector3.ONE, actor_duration)
	await actor_tween.finished
	if active_motion_tween != actor_tween:
		return
	if not is_instance_valid(player) or not is_instance_valid(enemy):
		build_battle_world()
		status_message = final_message
		_complete_dynamic_effect()
		_refresh_hud()
		return
	player.position = player_target
	enemy.position = enemy_target
	player.scale = Vector3.ONE
	enemy.scale = Vector3.ONE
	_play_actor_state("Player", "ready", "入场")
	_play_actor_state("Enemy", "ready", "现身")
	status_message = final_message
	_complete_dynamic_effect()
	_refresh_hud()


func select_or_play_card(index: int) -> void:
	if animation_busy or phase != "combat" or combat == null or index < 0 or index >= combat.hand.size():
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
				var damage_dealt: int = enemy_hp_before - combat.enemy_hp
				_play_actor_state("Enemy", "hurt", "-%d" % damage_dealt)
				_show_actor_damage_feedback("Enemy", damage_dealt)
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
	if animation_busy or phase != "combat" or combat == null or combat.outcome != "":
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
	var tween := create_tween()
	active_motion_tween = tween
	for event: Dictionary in turn_events:
		var kind := str(event.get("kind", ""))
		if kind == "move":
			var source: Vector2i = event.get("from", combat.enemy_pos)
			var target: Vector2i = event.get("to", combat.enemy_pos)
			tween.tween_callback(_play_actor_state.bind("Enemy", "move", "穿门" if bool(event.get("via_portal", false)) else ""))
			if bool(event.get("via_portal", false)):
				tween.tween_property(enemy_node, "scale", Vector3(0.08, 1.35, 0.08), ENEMY_STEP_DURATION * 0.42 * animation_duration_scale)
				tween.tween_callback(func() -> void: enemy_node.position = _battle_world(target))
				tween.tween_property(enemy_node, "scale", Vector3.ONE, ENEMY_STEP_DURATION * 0.58 * animation_duration_scale)
			else:
				tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				tween.tween_method(_set_enemy_step_motion.bind(enemy_node, _battle_world(source), _battle_world(target)), 0.0, 1.0, ENEMY_STEP_DURATION * animation_duration_scale)
			tween.tween_interval(0.035 * animation_duration_scale)
		elif kind == "attack":
			var attack_kind := str(event.get("attack_kind", "attack"))
			var attack_callouts := {"lunge": "突进!", "faceShock": "突脸!", "guardBreak": "破防!", "slam": "砸地!", "beam": "激光!"}
			tween.tween_callback(_play_actor_state.bind("Enemy", "attack", str(attack_callouts.get(attack_kind, "袭击!"))))
			if event.get("target", INVALID_CELL) == combat.player_pos and int(event.get("damage", 0)) > 0:
				tween.tween_callback(_play_actor_state.bind("Player", "hurt", "受击!"))
			tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(enemy_node, "scale", Vector3(1.22, 0.82, 1.22), ENEMY_ATTACK_DURATION * 0.45 * animation_duration_scale)
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(enemy_node, "scale", Vector3.ONE, ENEMY_ATTACK_DURATION * 0.55 * animation_duration_scale)
		elif kind == "face_shock":
			tween.tween_callback(_play_actor_state.bind("Enemy", "attack", "突脸!"))
			if int(event.get("damage", 0)) > 0:
				tween.tween_callback(_play_actor_state.bind("Player", "hurt", "惊吓!"))
			tween.tween_property(enemy_node, "scale", Vector3(1.18, 1.18, 1.18), ENEMY_ATTACK_DURATION * 0.45 * animation_duration_scale)
			tween.tween_property(enemy_node, "scale", Vector3.ONE, ENEMY_ATTACK_DURATION * 0.55 * animation_duration_scale)
		elif kind == "beam_charge":
			tween.tween_callback(_play_actor_state.bind("Enemy", "ready", "蓄力!"))
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(enemy_node, "scale", Vector3(0.86, 1.28, 0.86), 0.24 * animation_duration_scale)
			tween.tween_property(enemy_node, "scale", Vector3.ONE, 0.18 * animation_duration_scale)
		elif kind == "beam_fire":
			tween.tween_callback(_play_actor_state.bind("Enemy", "attack", "激光!"))
			if int(event.get("damage", 0)) > 0:
				tween.tween_callback(_play_actor_state.bind("Player", "hurt", "命中!"))
			tween.tween_property(enemy_node, "scale", Vector3(1.30, 0.76, 1.30), ENEMY_ATTACK_DURATION * 0.45 * animation_duration_scale)
			tween.tween_property(enemy_node, "scale", Vector3.ONE, ENEMY_ATTACK_DURATION * 0.55 * animation_duration_scale)
		else:
			tween.tween_interval(0.18 * animation_duration_scale)
	await tween.finished
	if active_motion_tween != tween:
		return
	_complete_dynamic_effect()
	_after_combat_action()


func _set_enemy_step_motion(weight: float, enemy_node: Node3D, start_position: Vector3, target_position: Vector3) -> void:
	_set_battle_actor_step_motion(weight, enemy_node, start_position, target_position)


func _set_battle_actor_step_motion(weight: float, actor_node: Node3D, start_position: Vector3, target_position: Vector3) -> void:
	if not is_instance_valid(actor_node):
		return
	var smooth_weight := weight * weight * (3.0 - 2.0 * weight)
	# The board owns all world translation; the FBX clip supplies limb motion only.
	actor_node.position = start_position.lerp(target_position, smooth_weight)
	var direction := target_position - start_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		var facing_yaw := atan2(direction.x, direction.z)
		actor_node.rotation.y = facing_yaw
		if actor_node.name == &"Player":
			battle_player_facing_yaw = facing_yaw
		elif actor_node.name == &"Enemy":
			battle_enemy_facing_yaw = facing_yaw


func _handle_battle_world_click(screen_pos: Vector2) -> void:
	if combat == null or combat.outcome != "":
		return
	var target := battle_cell_from_viewport(screen_pos)
	if target == INVALID_CELL:
		return
	handle_battle_cell(target)


func handle_battle_cell(target: Vector2i) -> void:
	if animation_busy or combat == null or combat.outcome != "" or target == INVALID_CELL:
		return
	if selected_card < 0 and combat.player_on_portal() and target == combat.player_portal_destination():
		use_player_portal()
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
				var damage_dealt: int = enemy_hp_before - combat.enemy_hp
				_play_actor_state("Enemy", "hurt", "-%d" % damage_dealt)
				_show_actor_damage_feedback("Enemy", damage_dealt)
			return
		else:
			selected_card = -1
			status_message = "%s不能放在这里，已自动取消选牌；现在可点击绿色格移动。" % card_name
	else:
		var source: Vector2i = combat.player_pos
		var movement_cost: int = combat.player_move_cost(target)
		if combat.move_player(target):
			if target == combat.enemy_pos:
				status_message = "你挤进敌人所在格，消耗 %d 行动力；仍可从另一侧离开。" % movement_cost
			else:
				status_message = "你站在传送门上：可花 %d 行动力穿门，也可继续行动。" % combat.move_cost if combat.player_on_portal() else "移动完成。选择手牌布置陷阱，或直接砸向有视野的敌人格。"
			_after_combat_action()
			_animate_player_battle_step(source, target)
			return
		else:
			status_message = "不能移动到该格：只能走相邻绿色格，且需要足够行动力。"
	_after_combat_action()


func _animate_player_battle_step(source: Vector2i, target: Vector2i) -> void:
	battle_camera_following = true
	_play_actor_state("Player", "move")
	var player_node := battle_root.get_node_or_null("Player") as Node3D
	var duration := UNITY_ACTOR_STEP_DURATION * animation_duration_scale
	if player_node == null or duration <= 0.0:
		return
	animation_busy = true
	active_animation_kind = "player_step"
	var source_height := float(combat.heights.get(source, 0)) * 0.64
	var target_height := float(combat.heights.get(target, 0)) * 0.64
	var start_position := _battle_world(source) + Vector3.UP * (source_height - target_height)
	var target_position := _battle_pawn_world(target, true)
	player_node.position = start_position
	var tween := create_tween()
	active_motion_tween = tween
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_battle_actor_step_motion.bind(player_node, start_position, target_position), 0.0, 1.0, duration)
	tween.finished.connect(func() -> void:
		if active_motion_tween != tween:
			return
		if is_instance_valid(player_node):
			player_node.position = target_position
		_complete_dynamic_effect()
		_refresh_hud()
	)


func use_player_portal() -> void:
	if animation_busy or phase != "combat" or combat == null:
		return
	if not combat.can_use_player_portal():
		status_message = "行动力不足，或传送门出口地形不可用。"
		_refresh_hud()
		return
	var source: Vector2i = combat.player_pos
	var target: Vector2i = combat.player_portal_destination()
	if not combat.use_player_portal():
		return
	status_message = "你花费 %d 行动力穿过传送门。" % combat.move_cost
	_after_combat_action()
	_animate_player_portal(source, target)


func _animate_player_portal(source: Vector2i, target: Vector2i) -> void:
	var player_node := battle_root.get_node_or_null("Player") as Node3D
	var duration := UNITY_ACTOR_STEP_DURATION * animation_duration_scale
	if player_node == null or duration <= 0.0:
		return
	animation_busy = true
	active_animation_kind = "player_portal"
	player_node.position = _battle_world(source)
	_play_actor_state("Player", "move", "穿门")
	var tween := create_tween()
	active_motion_tween = tween
	tween.tween_property(player_node, "scale", Vector3(0.08, 1.35, 0.08), duration * 0.42)
	tween.tween_callback(func() -> void: player_node.position = _battle_world(target))
	tween.tween_property(player_node, "scale", Vector3.ONE, duration * 0.58)
	tween.finished.connect(func() -> void:
		if active_motion_tween == tween:
			_complete_dynamic_effect()
			_refresh_hud()
	)


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
	if animation_busy or phase != "combat" or combat == null:
		return
	var next_hover := battle_cell_from_viewport(view_pos)
	if next_hover == hovered_battle_cell:
		return
	hovered_battle_cell = next_hover
	build_battle_world()


func clear_battle_hover() -> void:
	if animation_busy:
		return
	if hovered_battle_cell == INVALID_CELL:
		return
	hovered_battle_cell = INVALID_CELL
	if phase == "combat":
		build_battle_world()


func set_house_hover(view_pos: Vector2) -> void:
	if animation_busy or phase != "explore":
		return
	var hit: Variant = _screen_to_plane(view_pos, 0.0)
	var next_hover := INVALID_CELL
	if hit != null:
		var world: Vector3 = hit
		var target := Vector2i(roundi(world.x / HOUSE_CELL), roundi(world.z / HOUSE_CELL))
		if room_rules.placed.has(target) and target != current_room_pos and _rooms_connected(current_room_pos, target):
			next_hover = target
	if next_hover == hovered_house_cell:
		return
	hovered_house_cell = next_hover
	build_house_world()


func clear_house_hover() -> void:
	if animation_busy:
		return
	if hovered_house_cell == INVALID_CELL:
		return
	hovered_house_cell = INVALID_CELL
	if phase == "explore":
		build_house_world()

func reset_battle_camera() -> void:
	if combat == null or camera == null:
		return
	battle_camera_following = false
	battle_camera_user_hold = false
	battle_camera_return_delay = 0.0
	battle_camera_returning = false
	if battle_camera_return_tween != null and battle_camera_return_tween.is_valid():
		battle_camera_return_tween.kill()
		battle_camera_return_tween = null
	var max_height := 0.0
	for raw_height in combat.heights.values():
		max_height = maxf(max_height, float(raw_height))
	battle_camera_target = _battle_follow_target_position()
	battle_camera_target.y = max_height * 0.18
	battle_camera_yaw = atan2(CAMERA_DIRECTION.x, CAMERA_DIRECTION.z)
	battle_camera_pitch = atan2(CAMERA_DIRECTION.y, Vector2(CAMERA_DIRECTION.x, CAMERA_DIRECTION.z).length())
	battle_camera_zoom_ratio = 1.0
	_refit_battle_camera(false)
	# 镜头自始至终对准玩家与怪物中点的偏上区域（偏下构图，含偏上偏移的纵向分量）
	battle_camera_target = _battle_follow_target_position() + _battle_camera_frame_offset()
	_apply_battle_camera()


func _refit_battle_camera(preserve_zoom: bool) -> void:
	if combat == null or camera == null:
		return
	if preserve_zoom:
		battle_camera_zoom_ratio = clampf(battle_camera_zoom_ratio, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	else:
		battle_camera_zoom_ratio = 1.0
	var max_height := 0.0
	for raw_height in combat.heights.values():
		max_height = maxf(max_height, float(raw_height))
	var half_x := (float(combat.cols - 1) * 0.5 + 0.65) * BATTLE_CELL
	var half_z := (float(combat.rows - 1) * 0.5 + 0.65) * BATTLE_CELL
	var max_y := maxf(max_height * 0.64 + 2.25, BATTLE_SHELL_WALL_HEIGHT + 1.0)
	var horizontal_radius := Vector2(half_x, half_z).length()
	# 镜头始终偏上构图（对准点向屏幕上方平移约 size*FRAME_OFFSET），fit 需把该偏移量计入半径，
	# 保证全棋盘在偏上对准下仍然可见
	horizontal_radius += BATTLE_CAMERA_FRAME_OFFSET * (horizontal_radius * 2.0 + 10.0)
	battle_camera_fit_size = _rotation_invariant_fit_size(horizontal_radius, max_y, battle_camera_pitch, 0.8, 6.0)
	camera.size = battle_camera_fit_size * battle_camera_zoom_ratio
	_apply_battle_camera()


func pan_battle_camera(pixel_delta: Vector2) -> void:
	if phase != "combat" or combat == null:
		return
	battle_camera_following = false
	battle_camera_user_hold = true
	_cancel_battle_camera_return()
	var units_per_pixel := camera.size / maxf(1.0, world_view_rect.size.y)
	var right := Vector3(camera.global_transform.basis.x.x, 0.0, camera.global_transform.basis.x.z).normalized()
	var screen_up := Vector3(camera.global_transform.basis.y.x, 0.0, camera.global_transform.basis.y.z).normalized()
	battle_camera_target += (-right * pixel_delta.x + screen_up * pixel_delta.y) * units_per_pixel
	_clamp_battle_camera_target()
	_apply_battle_camera()


func orbit_battle_camera(pixel_delta: Vector2) -> void:
	if phase != "combat" or combat == null:
		return
	battle_camera_following = false
	battle_camera_user_hold = true
	_cancel_battle_camera_return()
	battle_camera_yaw = fposmod(battle_camera_yaw - pixel_delta.x * CAMERA_ORBIT_SENSITIVITY, TAU)
	_apply_battle_camera()


func zoom_battle_camera(view_pos: Vector2, zoom_factor: float) -> void:
	if phase != "combat" or combat == null:
		return
	battle_camera_following = false
	_cancel_battle_camera_return()
	var before: Variant = _screen_to_plane(view_pos, 0.0)
	camera.size = clampf(camera.size * zoom_factor, battle_camera_fit_size * CAMERA_ZOOM_MIN, battle_camera_fit_size * CAMERA_ZOOM_MAX)
	battle_camera_zoom_ratio = camera.size / maxf(0.001, battle_camera_fit_size)
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
	var limit_x := (float(combat.cols - 1) * 0.5 + 1.6) * BATTLE_CELL
	var limit_z := (float(combat.rows - 1) * 0.5 + 1.6) * BATTLE_CELL
	battle_camera_target.x = clampf(battle_camera_target.x, -limit_x, limit_x)
	battle_camera_target.z = clampf(battle_camera_target.z, -limit_z, limit_z)


func _apply_battle_camera() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var horizontal := cos(battle_camera_pitch) * battle_camera_distance
	var direction := Vector3(sin(battle_camera_yaw) * horizontal, sin(battle_camera_pitch) * battle_camera_distance, cos(battle_camera_yaw) * horizontal)
	camera.position = battle_camera_target + direction
	camera.look_at(battle_camera_target + Vector3(0, 0.2, 0), Vector3.UP)
	_apply_battle_room_cutaway()


func _rotation_invariant_fit_size(horizontal_radius: float, vertical_span: float, pitch: float, padding: float, minimum: float) -> float:
	var aspect := world_view_rect.size.x / maxf(1.0, world_view_rect.size.y)
	var projected_width := horizontal_radius * 2.0 + padding
	var projected_height := horizontal_radius * 2.0 * absf(sin(pitch)) + vertical_span * absf(cos(pitch)) + padding
	return maxf(minimum, maxf(projected_height, projected_width / maxf(0.5, aspect)) * 1.08)


func _after_combat_action() -> void:
	player_hp = combat.player_hp
	# 杀戮尖塔式回合：敌方动画播完后才给玩家发新牌
	if combat != null and combat.pending_player_turn and combat.outcome == "":
		combat.start_player_turn()
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
	if large_room_mix_test_mode or phase == "home" or phase.begins_with("lab_") and event_context.is_empty():
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
		"layout_profile": str(run_layout_profile.get("id", "")),
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
		"house_player_facing_yaw": house_player_facing_yaw,
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


func build_house_world() -> void:
	if build_preview_tween != null and build_preview_tween.is_valid():
		build_preview_tween.kill()
	build_preview_tween = null
	_clear_children(house_root)
	for raw_pos in room_rules.placed.keys():
		var pos: Vector2i = raw_pos
		_add_room_mesh(pos, room_rules.placed[pos])
	if kenney_build_lab_mode:
		_add_kenney_formal_composer()
	else:
		_add_room_bridges()
	for frontier in room_rules.frontiers():
		_add_frontier_mesh(frontier, phase == "build" and frontier == selected_frontier)
	if phase == "build" and not build_offers.is_empty():
		_add_build_preview()
	_add_house_player()
	if hovered_house_cell != INVALID_CELL and room_rules.placed.has(hovered_house_cell):
		_add_move_hover_mesh(hovered_house_cell)
	if phase != "combat":
		_set_house_camera()


func _add_kenney_formal_composer() -> void:
	var composer := PCG_HAND_LAYOUT_LAB.instantiate() as Node3D
	composer.name = "KenneyFormalComposer"
	composer.generation_seed = run_seed
	composer.animate_room_build = false
	composer.show_room_ids = true
	composer.kenney_only = true
	composer.use_kaykit_room_shell = true
	composer.unify_room_floor_finish = large_room_mix_test_mode
	composer.open_visited_connections = true
	composer.show_summary_title = false
	composer.explicit_connection_edges = _formal_connection_edge_keys()
	composer.explicit_open_edges = _formal_outer_open_edge_keys()
	composer.scale = Vector3.ONE * (HOUSE_CELL / 1.55)
	var layout := composer.get_node("Layout") as Node3D
	for existing: Node in layout.get_children():
		layout.remove_child(existing)
		existing.free()
	for record: Dictionary in _formal_instance_records_in_connection_order():
		var room: Dictionary = record["room"]
		var origin_raw: Array = room.get("origin", [0, 0])
		var origin := Vector2i(int(origin_raw[0]), int(origin_raw[1]))
		var piece := Node3D.new()
		piece.name = "Placed_%s" % str(record["id"]).replace("@", "_").replace(",", "_")
		piece.set_script(PCG_HAND_ROOM_SCRIPT)
		piece.set("room_id", str(record["id"]))
		piece.set("shape_id", str(room.get("footprint_kind", "single")))
		piece.set("elevated", bool(room.get("elevated", false)))
		piece.set_meta("room_name", str(room.get("name", "房间")))
		piece.set_meta("room_type", str(room.get("id", "")))
		piece.set_meta("revealed", bool(room.get("revealed", false)))
		piece.set_meta("visited", bool(room.get("visited", false)))
		piece.set_meta("completed", bool(room.get("completed", false)))
		piece.set_meta("is_current", str(record["id"]) == str(room_rules.placed[current_room_pos].get("instance_id", "")))
		piece.position = Vector3(float(origin.x) * 1.55, 0.0, float(origin.y) * 1.55)
		piece.rotation.y = float(int(room.get("rotation", 0))) * PI * 0.5
		layout.add_child(piece)
	house_root.add_child(composer)


func _formal_instance_records_in_connection_order() -> Array[Dictionary]:
	var by_id: Dictionary = {}
	for raw_pos: Variant in room_rules.placed.keys():
		var pos: Vector2i = raw_pos
		var room: Dictionary = room_rules.placed[pos]
		var instance_id := str(room.get("instance_id", "room@%d,%d" % [pos.x, pos.y]))
		if not by_id.has(instance_id):
			by_id[instance_id] = {"id": instance_id, "room": room, "cells": []}
		(by_id[instance_id]["cells"] as Array).append(pos)
	var result: Array[Dictionary] = []
	if by_id.is_empty():
		return result
	var start_id := str(room_rules.placed.get(Vector2i.ZERO, {}).get("instance_id", by_id.keys()[0]))
	var queued: Dictionary = {start_id: true}
	var queue: Array[String] = [start_id]
	while not queue.is_empty():
		var instance_id: String = queue.pop_front()
		if not by_id.has(instance_id):
			continue
		var record: Dictionary = by_id[instance_id]
		result.append(record)
		for cell: Vector2i in record["cells"]:
			for side in range(4):
				var neighbor: Vector2i = cell + RoomRules.DIRS[side]
				if not room_rules.placed.has(neighbor) or not room_rules.cell_has_door(cell, side) or not room_rules.cell_has_door(neighbor, (side + 2) % 4):
					continue
				var neighbor_id := str(room_rules.placed[neighbor].get("instance_id", ""))
				if neighbor_id == instance_id or queued.has(neighbor_id):
					continue
				queued[neighbor_id] = true
				queue.append(neighbor_id)
	var remaining_ids: Array = by_id.keys()
	remaining_ids.sort()
	for raw_id: Variant in remaining_ids:
		var instance_id := str(raw_id)
		if not queued.has(instance_id):
			result.append(by_id[instance_id])
	return result


func _formal_connection_edge_keys() -> Dictionary:
	var result: Dictionary = {}
	for raw_pos: Variant in room_rules.placed.keys():
		var pos: Vector2i = raw_pos
		for side in [1, 2]:
			var neighbor: Vector2i = pos + RoomRules.DIRS[side]
			if not room_rules.placed.has(neighbor) or room_rules.same_instance(pos, neighbor):
				continue
			if room_rules.cell_has_door(pos, side) and room_rules.cell_has_door(neighbor, (side + 2) % 4):
				result[_grid_edge_key(pos, neighbor)] = true
	return result


func _formal_outer_open_edge_keys() -> Dictionary:
	var result: Dictionary = {}
	for raw_pos: Variant in room_rules.placed.keys():
		var pos: Vector2i = raw_pos
		for side in range(4):
			var neighbor: Vector2i = pos + RoomRules.DIRS[side]
			if room_rules.placed.has(neighbor):
				continue
			if room_rules.cell_has_door(pos, side):
				result[_grid_edge_key(pos, neighbor)] = true
	return result

func _grid_edge_key(a: Vector2i, b: Vector2i) -> String:
	var first := a if a.y < b.y or (a.y == b.y and a.x < b.x) else b
	var second := b if first == a else a
	return "%d,%d|%d,%d" % [first.x, first.y, second.x, second.y]


func _add_room_mesh(pos: Vector2i, room: Dictionary) -> void:
	var node := Node3D.new()
	node.name = "Room_%d_%d" % [pos.x, pos.y]
	node.position = _house_world(pos)
	house_root.add_child(node)
	_populate_room_visual(node, pos, room)


func _populate_room_visual(node: Node3D, pos: Vector2i, room: Dictionary) -> void:
	_clear_children(node)
	if kenney_build_lab_mode:
		return
	var revealed := bool(room.get("revealed", false)) or bool(room.get("completed", false))
	var kind := str(room.get("kind", "quiet"))
	var accent := COL_TEAL
	if not revealed:
		accent = Color("46545b")
	elif kind == "combat":
		accent = COL_MAGENTA
	elif kind == "event":
		accent = Color("7964a5")
	if room_rules.same_instance(pos, current_room_pos):
		accent = COL_GOLD
	_add_box(node, "Base", Vector3.ZERO + Vector3(0, 0.14, 0), Vector3(3.05, 0.28, 3.05), _material(accent.darkened(0.35)))
	_add_box(node, "Floor", Vector3(0, 0.31, 0), Vector3(2.82, 0.12, 2.82), _material(COL_PAPER if revealed else Color("26363d")))
	var doors: Array = room.get("doors", [false, false, false, false])
	for side in range(4):
		if room_rules.same_instance(pos, pos + RoomRules.DIRS[side]):
			continue
		_add_room_edge(node, side, bool(doors[side]), accent)
	var decor_count := 0
	if room_rules.is_instance_anchor(pos):
		var decor_root := Node3D.new()
		decor_root.name = "RoomDecor"
		decor_root.rotation.y = -float(int(room.get("rotation", 0))) * PI * 0.5
		node.add_child(decor_root)
		decor_count = RoomArtRegistry.decorate(decor_root, room, revealed)
	var label_text := str(room.get("name", "房间")) if revealed else "?"
	var label_y := 2.10 if decor_count > 0 else 1.18
	if room_rules.is_instance_anchor(pos):
		_add_label(node, "Label", "%s · %d格" % [label_text, int(room.get("room_size", 1))], Vector3(0, label_y, 0), accent if revealed else COL_GOLD, 44)


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
		for side in [1, 2]:
			var neighbor: Vector2i = pos + RoomRules.DIRS[side]
			if not room_rules.placed.has(neighbor) or not room_rules.cell_has_door(pos, side):
				continue
			var bridge_size := Vector3(0.55, 0.12, 2.82) if side == 1 else Vector3(2.82, 0.12, 0.55)
			_add_box(house_root, "RoomJoin" if room_rules.same_instance(pos, neighbor) else "Bridge", (_house_world(pos) + _house_world(neighbor)) * 0.5 + Vector3(0, 0.24, 0), bridge_size, _material(COL_PAPER))


func _add_frontier_mesh(pos: Vector2i, selected: bool) -> void:
	var node := Node3D.new()
	node.name = "Frontier_%d_%d" % [pos.x, pos.y]
	node.position = _house_world(pos)
	house_root.add_child(node)
	var color := COL_GOLD if selected else Color("c88b2f")
	var transparent := Color(color, 0.72 if selected else 0.48)
	var socket_size := 0.88 if selected else 0.64
	node.rotation.y = PI * 0.25
	_add_box(node, "BuildSocket", Vector3(0, 0.18, 0), Vector3(socket_size, 0.22, socket_size), _material(transparent, true))
	_add_box(node, "SocketCore", Vector3(0, 0.30, 0), Vector3(socket_size * 0.48, 0.06, socket_size * 0.48), _material(color))
	var label := _add_label(node, "Plus", "+", Vector3(0, 0.88, 0), color, 44)
	label.rotation.y = -PI * 0.25


func _add_build_preview() -> void:
	var room: Dictionary = build_offers[selected_offer]
	var node := Node3D.new()
	node.name = "BuildPreview"
	var preview_origin := room_rules.placement_origin(selected_frontier, room, offer_rotation)
	node.position = _house_world(preview_origin) + Vector3(0, 0.20, 0)
	node.rotation.y = -float(offer_rotation) * PI * 0.5
	house_root.add_child(node)
	var preview_room := room.duplicate(true)
	preview_room["revealed"] = false
	preview_room["completed"] = false
	preview_room["doors"] = room_rules.normalize_doors(room.get("doors", []))
	if kenney_build_lab_mode:
		for offset: Vector2i in room_rules.footprint_cells(room):
			_add_kenney_preview_cell(node, offset)
	else:
		_populate_room_visual(node, selected_frontier, preview_room)
		for offset: Vector2i in room_rules.footprint_cells(room):
			if offset == Vector2i.ZERO:
				continue
			var footprint_cell := Node3D.new()
			footprint_cell.name = "Footprint_%d_%d" % [offset.x, offset.y]
			footprint_cell.position = Vector3(float(offset.x) * HOUSE_CELL, 0.0, float(offset.y) * HOUSE_CELL)
			node.add_child(footprint_cell)
			_add_box(footprint_cell, "Base", Vector3(0, 0.14, 0), Vector3(3.05, 0.28, 3.05), _material(Color("27343a")))
			_add_box(footprint_cell, "Floor", Vector3(0, 0.31, 0), Vector3(2.82, 0.12, 2.82), _material(Color("26363d")))
	var validity := _add_cylinder(node, "PreviewValidity", Vector3(0, 0.14, 0), 1.58, 0.08, _material(Color(COL_GREEN if can_place_selected_offer() else COL_RED, 0.72), true, 0.08))
	validity.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_label(node, "PreviewRotation", "%d°" % (offer_rotation * 90), Vector3(0, 1.68, 0), Color.WHITE, 30)
	_update_build_preview_validity(node)


func _add_kenney_preview_cell(parent: Node3D, offset: Vector2i) -> void:
	var cell_root := Node3D.new()
	cell_root.name = "KenneyPreview_%d_%d" % [offset.x, offset.y]
	cell_root.position = Vector3(float(offset.x) * HOUSE_CELL, 0.0, float(offset.y) * HOUSE_CELL)
	parent.add_child(cell_root)
	_add_box(cell_root, "GhostBase", Vector3(0, 0.10, 0), Vector3(HOUSE_CELL * 0.94, 0.16, HOUSE_CELL * 0.94), _material(Color(COL_GREEN if can_place_selected_offer() else COL_RED, 0.30), true))
	var packed := load(KAYKIT_DUNGEON_ROOT + "floor_wood_large.gltf.glb") as PackedScene
	if packed == null:
		return
	var floor_model := packed.instantiate() as Node3D
	if floor_model == null:
		return
	floor_model.name = "FloorModel"
	floor_model.position.y = 0.20
	floor_model.scale = Vector3.ONE * (HOUSE_CELL / 4.0)
	cell_root.add_child(floor_model)
	var ghost_material := _material(Color(COL_GREEN if can_place_selected_offer() else COL_RED, 0.34), true, 0.05)
	for raw_mesh: Node in floor_model.find_children("*", "MeshInstance3D", true, false):
		(raw_mesh as MeshInstance3D).material_override = ghost_material


func _update_build_preview_validity(preview: Node3D) -> void:
	var valid := can_place_selected_offer()
	var validity := preview.get_node_or_null("PreviewValidity") as MeshInstance3D
	if validity != null:
		validity.material_override = _material(Color(COL_GREEN if valid else COL_RED, 0.72), true, 0.08)
	for raw_ghost: Node in preview.find_children("GhostBase", "MeshInstance3D", true, false):
		(raw_ghost as MeshInstance3D).material_override = _material(Color(COL_GREEN if valid else COL_RED, 0.30), true)
	for preview_cell: Node in preview.find_children("KenneyPreview_*", "Node3D", true, false):
		var model := preview_cell.get_node_or_null("FloorModel")
		if model != null:
			for raw_mesh: Node in model.find_children("*", "MeshInstance3D", true, false):
				(raw_mesh as MeshInstance3D).material_override = _material(Color(COL_GREEN if valid else COL_RED, 0.34), true, 0.05)
	var label := preview.get_node_or_null("PreviewRotation") as Label3D
	if label != null:
		label.text = "%d° · %s" % [offer_rotation * 90, "可摆" if valid else "门不合"]
		label.modulate = COL_GREEN if valid else COL_RED


func _add_house_player() -> void:
	var node := Node3D.new()
	node.name = "LiliToken"
	var interaction_slot := claim_room_interaction_slot("player:lili", current_room_pos)
	if interaction_slot.is_empty():
		node.position = _house_world(current_room_pos)
		node.rotation.y = house_player_facing_yaw
	else:
		node.position = _interaction_slot_house_position(interaction_slot, "position")
		node.rotation.y = float(interaction_slot.get("facing_yaw", house_player_facing_yaw))
		house_player_facing_yaw = node.rotation.y
		node.set_meta("interaction_room_id", str(interaction_slot.get("room_id", "")))
		node.set_meta("interaction_cell", interaction_slot.get("cell", current_room_pos))
		node.set_meta("interaction_slot_index", int(interaction_slot.get("slot_index", -1)))
		node.set_meta("interaction_kind", str(interaction_slot.get("kind", "stand")))
		node.set_meta("interaction_pose", str(interaction_slot.get("pose", "stand")))
		node.set_meta("interaction_asset_id", str(interaction_slot.get("asset_id", "")))
		node.set_meta("interaction_anchor", _interaction_slot_house_position(interaction_slot, "anchor_position"))
	house_root.add_child(node)
	_add_cylinder(node, "TokenBase", Vector3(0, 0.09, 0), 0.48, 0.12, _material(COL_TEAL, false, 0.05))
	var presenter := CharacterPresenter.new()
	presenter.name = "Presenter"
	presenter.position = Vector3(0.0, 0.14, 0.0)
	node.add_child(presenter)
	presenter.configure("player", (presentation.get("actors", {}).get("player", {}) as Dictionary))
	if not interaction_slot.is_empty() and presenter.has_method("set_interaction_pose"):
		presenter.set_interaction_pose(str(interaction_slot.get("pose", "stand")), str(interaction_slot.get("kind", "stand")))


func room_interaction_slots(target: Vector2i) -> Array[Dictionary]:
	var composer := house_root.get_node_or_null("KenneyFormalComposer")
	if composer == null or not composer.has_method("interaction_slots_for_cell"):
		return []
	return composer.interaction_slots_for_cell(target)


func claim_room_interaction_slot(actor_id: String, target: Vector2i, preferred_kind: String = "") -> Dictionary:
	if not room_rules.placed.has(target):
		return {}
	var slots := room_interaction_slots(target)
	if slots.is_empty():
		return {}
	var room_id := str(room_rules.placed[target].get("instance_id", ""))
	var existing: Dictionary = house_actor_slot_assignments.get(actor_id, {})
	if str(existing.get("room_id", "")) == room_id and existing.has("cell") and existing["cell"] == target:
		var existing_index := int(existing.get("slot_index", -1))
		if existing_index >= 0 and existing_index < slots.size():
			return slots[existing_index].duplicate(true)
	var occupied: Dictionary = {}
	for raw_actor_id: Variant in house_actor_slot_assignments.keys():
		if str(raw_actor_id) == actor_id:
			continue
		var assignment: Dictionary = house_actor_slot_assignments[raw_actor_id]
		if str(assignment.get("room_id", "")) == room_id and assignment.has("cell") and assignment["cell"] == target:
			occupied[int(assignment.get("slot_index", -1))] = true
	var chosen_index := -1
	if not preferred_kind.is_empty():
		for slot_index in range(slots.size()):
			if not occupied.has(slot_index) and str(slots[slot_index].get("kind", "")) == preferred_kind:
				chosen_index = slot_index
				break
	if chosen_index < 0:
		for slot_index in range(slots.size()):
			if not occupied.has(slot_index):
				chosen_index = slot_index
				break
	if chosen_index < 0:
		return {}
	var chosen_slot: Dictionary = slots[chosen_index]
	house_actor_slot_assignments[actor_id] = {
		"room_id": room_id,
		"cell": target,
		"slot_index": chosen_index,
		"kind": str(chosen_slot.get("kind", "stand")),
		"pose": str(chosen_slot.get("pose", "stand")),
		"asset_id": str(chosen_slot.get("asset_id", "")),
	}
	return slots[chosen_index].duplicate(true)


func release_room_interaction_slot(actor_id: String) -> void:
	house_actor_slot_assignments.erase(actor_id)


func actor_interaction_state(actor_id: String) -> Dictionary:
	return (house_actor_slot_assignments.get(actor_id, {}) as Dictionary).duplicate(true)


func _house_interaction_target_position(actor_id: String, target: Vector2i) -> Vector3:
	var slot := claim_room_interaction_slot(actor_id, target)
	if slot.is_empty():
		return _house_world(target)
	return _interaction_slot_house_position(slot, "position")


func _interaction_slot_house_position(slot: Dictionary, field: String) -> Vector3:
	var local_position: Vector3 = slot.get(field, Vector3.ZERO)
	var composer := house_root.get_node_or_null("KenneyFormalComposer") as Node3D
	if composer == null:
		return local_position
	return composer.transform * local_position


func _add_move_hover_mesh(pos: Vector2i) -> void:
	var node := Node3D.new()
	node.name = "MoveHover_%d_%d" % [pos.x, pos.y]
	node.position = _house_world(pos)
	house_root.add_child(node)
	_add_box(node, "MoveHoverPad", Vector3(0, 0.15, 0), Vector3(HOUSE_CELL * 0.94, 0.10, HOUSE_CELL * 0.94), _material(Color(0.45, 0.88, 1.0, 0.38), true))


func _apply_current_room_cutaway() -> void:
	if not room_rules.placed.has(current_room_pos):
		return
	var composer := house_root.get_node_or_null("KenneyFormalComposer")
	if composer == null or camera == null or not composer.has_method("apply_camera_cutaway"):
		return
	var viewer_axis := camera.global_transform.basis.z
	var local_viewer_axis: Vector3 = composer.global_transform.basis.inverse() * viewer_axis
	composer.apply_camera_cutaway(current_room_pos, Vector2(local_viewer_axis.x, local_viewer_axis.z))


func pcg_cutaway_debug_text() -> String:
	var composer := house_root.get_node_or_null("KenneyFormalComposer")
	if composer == null or not composer.has_method("cutaway_debug_summary"):
		return "PCG 诊断等待生成"
	return str(composer.cutaway_debug_summary())


func pcg_room_state_debug_text() -> String:
	var composer := house_root.get_node_or_null("KenneyFormalComposer")
	if composer == null or not composer.has_method("room_state_debug_summary"):
		return "房态等待生成"
	return "%s · 扩建插槽%d" % [str(composer.room_state_debug_summary()), room_rules.frontiers().size()]


func large_room_mix_debug_text() -> String:
	var counts := _placed_room_size_counts()
	return "节奏 1格 %d/4 · 3格 %d/6 · 5格 %d/2" % [int(counts[1]), int(counts[3]), int(counts[5])]


func frontier_markers_are_compact() -> bool:
	var marker_count := 0
	for raw_marker: Node in house_root.find_children("Frontier_*", "Node3D", false, false):
		var marker := raw_marker as Node3D
		var socket := marker.get_node_or_null("BuildSocket") as MeshInstance3D
		if socket == null or not (socket.mesh is BoxMesh):
			return false
		if (socket.mesh as BoxMesh).size.x > HOUSE_CELL * 0.35:
			return false
		marker_count += 1
	return marker_count == room_rules.frontiers().size()

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
			if height == 0:
				_add_box(cell_node, "Frame", Vector3(0, platform_height * 0.5, 0), Vector3(BATTLE_CELL - 0.08, platform_height, BATTLE_CELL - 0.08), _material(rim_color, false, 0.04 if rim_color != COL_GRID_DARK else 0.0))
			else:
				_add_box(cell_node, "TerrainFoot", Vector3(0, 0.14, 0), Vector3(BATTLE_CELL - 0.08, 0.28, BATTLE_CELL - 0.08), _material(rim_color))
				_add_battle_height_asset(cell_node, pos, height, platform_height + 0.13)
			_add_box(cell_node, "Surface", Vector3(0, platform_height + 0.055, 0), Vector3(BATTLE_CELL - 0.34, 0.11, BATTLE_CELL - 0.34), _material(surface_color))
			var top_y := platform_height + 0.13
			var is_hurt_cell: bool = pos in (intent.get("hurt", []) as Array)
			var path_index: int = (intent.get("path", []) as Array).find(pos)
			if is_hurt_cell:
				_add_box(cell_node, "IntentAttackOverlay", Vector3(0, top_y + 0.035, 0), Vector3(BATTLE_CELL - 0.43, 0.065, BATTLE_CELL - 0.43), _material(Color(COL_RED, 0.78), true, 0.08))
				var attack_kind := str(intent.get("attack_kind", "attack"))
				var glyphs := {"lunge": "突", "faceShock": "惊", "guardBreak": "破", "slam": "砸", "beam": "激"}
				var attack_glyph := "蓄" if bool(intent.get("pending", false)) else str(glyphs.get(attack_kind, "攻"))
				if int(intent.get("hits", 1)) > 1:
					attack_glyph = "%s×%d" % [attack_glyph, int(intent.get("hits", 1))]
				_add_label(cell_node, "IntentAttackGlyph", attack_glyph, Vector3(0.0, top_y + 0.48, 0.0), Color.WHITE, 30)
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
				_add_cylinder(cell_node, "Trap", Vector3(0, top_y + 0.08, 0), 0.30, 0.13, _material(COL_GOLD, false, 0.05))
				var card_id := str(trap.get("card_id", ""))
				_add_trap_item_sprite(cell_node, card_id, top_y)
				_add_label(cell_node, "TrapGlyph", str(trap.get("glyph", "✦")), Vector3(0, top_y + 0.62, 0), COL_GOLD, 21)
	_add_battle_pawn(combat.player_pos, true, true)
	_add_battle_pawn(combat.enemy_pos, false, combat.enemy_revealed)
	if combat.has_decoy():
		_add_decoy_pawn(combat.decoy_pos)
	_add_battle_room_shell()
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


func _add_battle_height_asset(parent: Node3D, pos: Vector2i, height: int, logical_top_y: float) -> void:
	var options: Array = BATTLE_HEIGHT_ASSETS.get(height, [])
	if options.is_empty():
		return
	var asset_name := str(options[posmod(pos.x * 17 + pos.y * 31, options.size())])
	var packed := load(BATTLE_HEIGHT_ASSET_ROOT + asset_name) as PackedScene
	if packed == null:
		return
	var prop := packed.instantiate() as Node3D
	if prop == null:
		return
	prop.name = "TerrainAsset_H%d_%s" % [height, asset_name.get_basename()]
	prop.position = Vector3(0, 0.31, 0)
	prop.rotation.y = float(posmod(pos.x + pos.y, 4)) * PI * 0.5
	prop.scale = Vector3.ONE * (0.43 if height == 1 else 0.46)
	parent.add_child(prop)
	for child: Node in prop.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var top_marker := _add_box(parent, "WalkableAssetTop", Vector3(0, logical_top_y - 0.075, 0), Vector3(BATTLE_CELL - 0.46, 0.055, BATTLE_CELL - 0.46), _material(Color(COL_PAPER, 0.46), true, 0.03))
	top_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
	node.position = _battle_pawn_world(pos, is_player)
	node.rotation.y = battle_player_facing_yaw if is_player else battle_enemy_facing_yaw
	battle_root.add_child(node)
	var floor_y := 0.39 + float(combat.heights.get(pos, 0)) * 0.64
	_add_cylinder(node, "PawnBase", Vector3(0, floor_y + 0.08, 0), 0.52, 0.16, _material(COL_TEAL if is_player else COL_RED if revealed else Color("1f2930"), false, 0.04))
	var presenter := CharacterPresenter.new()
	presenter.name = "Presenter"
	presenter.position = Vector3(0, floor_y + 0.05, 0)
	node.add_child(presenter)
	var actor_key := "player" if is_player else "enemy"
	var presenter_id := actor_key if is_player else "%s:%s" % [actor_key, combat.enemy_archetype]
	presenter.configure(presenter_id, _battle_actor_presentation(actor_key))
	presenter.state_changed.connect(_on_presenter_state_changed)
	if not is_player:
		presenter.set_obscured(not revealed)
	if not is_player:
		_add_label(node, "PawnLabel", "怪" if revealed else "?", Vector3(0, floor_y + 2.05, 0), Color.WHITE if revealed else COL_GOLD, 31)
		if revealed and combat != null and str(combat.outcome) == "":
			var intent: Dictionary = combat.preview_intent()
			var intent_label := Label3D.new()
			intent_label.name = "EnemyIntent"
			intent_label.position = Vector3(0, floor_y + 2.62, 0)
			intent_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			intent_label.no_depth_test = true
			intent_label.font_size = 42
			intent_label.outline_size = 10
			intent_label.outline_modulate = Color("10151c")
			intent_label.modulate = _battle_intent_color(str(intent.get("type", "stall")))
			intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var intent_text := str(intent.get("label", ""))
			intent_label.text = intent_text if not intent_text.is_empty() else "观望"
			node.add_child(intent_label)


func _battle_intent_color(intent_type: String) -> Color:
	match intent_type:
		"attack": return Color("ff5a4e")
		"chase": return Color("ff9c4a")
		"search": return Color("6ab7e8")
		"patrol": return Color("5fd6c6")
		"ambush": return Color("e06bb4")
	return Color("c8d4d8")


func _battle_actor_presentation(actor_key: String) -> Dictionary:
	var actors: Dictionary = presentation.get("actors", {})
	var config: Dictionary = (actors.get(actor_key, {}) as Dictionary).duplicate(true)
	if actor_key != "enemy" or combat == null:
		return config
	var archetypes: Dictionary = presentation.get("enemy_archetypes", {})
	var variant: Dictionary = archetypes.get(combat.enemy_archetype, {})
	config.merge(variant, true)
	return config


func _battle_pawn_world(pos: Vector2i, is_player: bool) -> Vector3:
	var world := _battle_world(pos)
	if combat != null and combat.player_pos == combat.enemy_pos and pos == combat.player_pos:
		world += Vector3(-0.30, 0.0, 0.20) if is_player else Vector3(0.30, 0.0, -0.20)
	return world


func _add_decoy_pawn(pos: Vector2i) -> void:
	var node := Node3D.new()
	node.name = "PaperDecoy"
	node.position = _battle_world(pos)
	battle_root.add_child(node)
	var floor_y := 0.39 + float(combat.heights.get(pos, 0)) * 0.64
	_add_cylinder(node, "PaperBase", Vector3(0, floor_y + 0.06, 0), 0.42, 0.10, _material(Color("d5b97a")))
	_add_box(node, "PaperBody", Vector3(0, floor_y + 0.72, 0), Vector3(0.72, 1.22, 0.10), _material(Color("efe0b9")))
	var cross := _add_box(node, "PaperCross", Vector3(0, floor_y + 0.77, 0), Vector3(0.10, 1.05, 0.68), _material(Color("efe0b9")))
	cross.rotation.y = PI * 0.5
	_add_label(node, "PaperGlyph", "影", Vector3(0, floor_y + 1.48, 0), COL_MAGENTA, 34)


func _play_actor_state(actor_node_name: String, state: String, callout: String = "") -> void:
	var presenter := battle_root.get_node_or_null("%s/Presenter" % actor_node_name)
	if presenter != null and presenter.has_method("play_state"):
		presenter.play_state(state, callout)


func _show_actor_damage_feedback(actor_node_name: String, damage: int) -> void:
	var actor := battle_root.get_node_or_null(actor_node_name) as Node3D
	if actor == null or damage <= 0:
		return
	var popup := Label3D.new()
	popup.name = "DamageFeedback"
	popup.text = "✦  -%d  ✦" % damage
	popup.position = Vector3(0, 1.28, 0.12)
	popup.font_size = 58
	popup.pixel_size = 0.014
	popup.modulate = Color("ff4e61")
	popup.outline_modulate = Color("fff2d2")
	popup.outline_size = 12
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.no_depth_test = true
	popup.scale = Vector3(0.35, 0.35, 0.35)
	actor.add_child(popup)
	var base_actor_position := actor.position
	var feedback := actor.create_tween()
	feedback.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	feedback.tween_property(actor, "position", base_actor_position + Vector3(-0.18, 0.05, 0), 0.055)
	feedback.tween_property(actor, "position", base_actor_position + Vector3(0.16, 0.0, 0), 0.055)
	feedback.tween_property(actor, "position", base_actor_position, 0.09)
	feedback.parallel().tween_property(actor, "scale", Vector3(1.16, 0.86, 1.16), 0.10)
	feedback.tween_property(actor, "scale", Vector3.ONE, 0.13)
	var popup_tween := popup.create_tween()
	popup_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	popup_tween.tween_property(popup, "scale", Vector3.ONE, 0.11)
	popup_tween.parallel().tween_property(popup, "position:y", 1.72, 0.34)
	popup_tween.tween_property(popup, "modulate:a", 0.0, 0.20)
	popup_tween.tween_callback(popup.queue_free)


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


func _add_battle_room_shell() -> void:
	battle_shell_edge_records.clear()
	battle_shell_culled_count = 0
	battle_shell_visible_count = 0
	var shell := Node3D.new()
	shell.name = "BattleRoomShell"
	battle_root.add_child(shell)
	var half_x := float(combat.cols) * BATTLE_CELL * 0.5
	var half_z := float(combat.rows) * BATTLE_CELL * 0.5
	var entrance: Dictionary = _battle_room_entrance_edge()
	for side in range(4):
		var segment_count: int = int(combat.cols) if side in [0, 2] else int(combat.rows)
		for index in range(segment_count):
			var is_entrance := side == int(entrance["side"]) and index == int(entrance["index"])
			_add_battle_shell_edge(shell, side, index, half_x, half_z, is_entrance)
	_add_battle_boundary_outline(shell, half_x, half_z)
	var label := Label3D.new()
	label.name = "BattleRoomStateLabel"
	label.text = "%s · 当前房间" % battle_room_title
	label.position = Vector3(0, BATTLE_SHELL_WALL_HEIGHT + 0.75, -half_z - 0.10)
	label.modulate = COL_GOLD
	label.font_size = 44
	label.outline_size = 10
	label.pixel_size = 0.009
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	shell.add_child(label)
	_apply_battle_room_cutaway()


func _battle_room_entrance_edge() -> Dictionary:
	var player: Vector2i = combat.player_pos
	var distances := [player.y, combat.cols - 1 - player.x, combat.rows - 1 - player.y, player.x]
	var side := 0
	for candidate in range(1, 4):
		if int(distances[candidate]) < int(distances[side]):
			side = candidate
	var index := player.x if side in [0, 2] else player.y
	return {"side": side, "index": index}


func _add_battle_shell_edge(shell: Node3D, side: int, index: int, half_x: float, half_z: float, is_entrance: bool) -> void:
	var segment := Node3D.new()
	segment.name = "ShellEdge_%d_%d" % [side, index]
	segment.set_meta("side", side)
	segment.set_meta("is_entrance", is_entrance)
	var direction: Vector2i = RoomRules.DIRS[side]
	if side in [0, 2]:
		segment.position = Vector3((float(index) - float(combat.cols - 1) * 0.5) * BATTLE_CELL, 0.34, -half_z if side == 0 else half_z)
	else:
		segment.position = Vector3(half_x if side == 1 else -half_x, 0.34, (float(index) - float(combat.rows - 1) * 0.5) * BATTLE_CELL)
	segment.rotation.y = _battle_shell_direction_yaw(direction)
	shell.add_child(segment)
	var full_root := Node3D.new()
	full_root.name = "FullDoorway" if is_entrance else "FullWall"
	segment.add_child(full_root)
	var asset_path := KAYKIT_DUNGEON_ROOT + ("wall_doorway.glb" if is_entrance else "wall.gltf.glb")
	var packed := load(asset_path) as PackedScene
	if packed != null:
		var model := packed.instantiate() as Node3D
		if model != null:
			model.name = "ShellAsset"
			model.scale = Vector3((BATTLE_CELL - BATTLE_SHELL_JUNCTION_WIDTH) / 4.0, BATTLE_SHELL_WALL_HEIGHT / 4.0, BATTLE_SHELL_JUNCTION_WIDTH)
			full_root.add_child(model)
			for child: Node in model.find_children("*", "MeshInstance3D", true, false):
				(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var cutaway_root := Node3D.new()
	cutaway_root.name = "DoorThreshold" if is_entrance else "WallSill"
	cutaway_root.visible = false
	segment.add_child(cutaway_root)
	_add_battle_shell_sill(cutaway_root, is_entrance)
	var key := "%d:%d" % [side, index]
	battle_shell_edge_records[key] = {"side": side, "full": full_root, "cutaway": cutaway_root, "entrance": is_entrance}


func _add_battle_shell_sill(parent: Node3D, is_entrance: bool) -> void:
	var span := BATTLE_CELL - BATTLE_SHELL_JUNCTION_WIDTH
	if not is_entrance:
		_add_box(parent, "CutawayWallBase", Vector3(0, 0.07, 0), Vector3(span, 0.14, 0.16), _material(Color("54757a")))
		return
	var opening := minf(0.88, span * 0.46)
	var side_span := (span - opening) * 0.5
	var offset := opening * 0.5 + side_span * 0.5
	_add_box(parent, "DoorBaseLeft", Vector3(-offset, 0.07, 0), Vector3(side_span, 0.14, 0.16), _material(Color("54757a")))
	_add_box(parent, "DoorBaseRight", Vector3(offset, 0.07, 0), Vector3(side_span, 0.14, 0.16), _material(Color("54757a")))
	_add_box(parent, "EntranceThreshold", Vector3(0, 0.025, 0), Vector3(opening, 0.04, 0.24), _material(COL_GOLD, false, 0.05))


func _battle_shell_direction_yaw(direction: Vector2i) -> float:
	if direction == Vector2i.RIGHT:
		return -PI * 0.5
	if direction == Vector2i.LEFT:
		return PI * 0.5
	if direction == Vector2i.DOWN:
		return PI
	return 0.0


func _add_battle_boundary_outline(shell: Node3D, half_x: float, half_z: float) -> void:
	var y := 0.39
	_add_box(shell, "BattleBoundaryTop", Vector3(0, y, -half_z + 0.08), Vector3(half_x * 2.0 - 0.16, 0.045, 0.08), _material(COL_GOLD, false, 0.04))
	_add_box(shell, "BattleBoundaryBottom", Vector3(0, y, half_z - 0.08), Vector3(half_x * 2.0 - 0.16, 0.045, 0.08), _material(COL_GOLD, false, 0.04))
	_add_box(shell, "BattleBoundaryRight", Vector3(half_x - 0.08, y, 0), Vector3(0.08, 0.045, half_z * 2.0 - 0.16), _material(COL_GOLD, false, 0.04))
	_add_box(shell, "BattleBoundaryLeft", Vector3(-half_x + 0.08, y, 0), Vector3(0.08, 0.045, half_z * 2.0 - 0.16), _material(COL_GOLD, false, 0.04))


func _apply_battle_room_cutaway() -> void:
	if combat == null or battle_shell_edge_records.is_empty():
		return
	battle_shell_culled_count = 0
	battle_shell_visible_count = 0
	var viewer_direction := Vector2(sin(battle_camera_yaw), cos(battle_camera_yaw)).normalized()
	for raw_record: Variant in battle_shell_edge_records.values():
		var record: Dictionary = raw_record
		var side := int(record["side"])
		var direction: Vector2i = RoomRules.DIRS[side]
		var outward := Vector2(float(direction.x), float(direction.y))
		var full := record["full"] as Node3D
		var cutaway := record["cutaway"] as Node3D
		var was_culled := cutaway.visible and not full.visible
		var threshold := 0.28 if was_culled else 0.42
		var culled := outward.dot(viewer_direction) > threshold
		full.visible = not culled
		cutaway.visible = culled
		if culled:
			battle_shell_culled_count += 1
		else:
			battle_shell_visible_count += 1


func battle_room_shell_debug_state() -> Dictionary:
	var entrance_count := 0
	for raw_record: Variant in battle_shell_edge_records.values():
		if bool((raw_record as Dictionary).get("entrance", false)):
			entrance_count += 1
	return {
		"edges": battle_shell_edge_records.size(),
		"culled": battle_shell_culled_count,
		"visible": battle_shell_visible_count,
		"entrances": entrance_count,
		"logical_walls": combat.walls.size() if combat != null else 0,
	}


func battle_room_shell_is_consistent() -> bool:
	if combat == null or battle_shell_edge_records.size() != (combat.cols + combat.rows) * 2:
		return false
	var entrance_count := 0
	for raw_record: Variant in battle_shell_edge_records.values():
		var record: Dictionary = raw_record
		var full := record.get("full") as Node3D
		var cutaway := record.get("cutaway") as Node3D
		if full == null or cutaway == null or full.visible == cutaway.visible:
			return false
		if bool(record.get("entrance", false)):
			entrance_count += 1
	return entrance_count == 1 and battle_shell_culled_count > 0 and battle_shell_visible_count > 0


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
	sprite.position = Vector3(0, y + 0.31, 0)
	var max_pixels := maxi(texture.get_width(), texture.get_height())
	sprite.pixel_size = (BATTLE_CELL * 0.55) / float(maxi(1, max_pixels))
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
	var horizontal_radius := 0.0
	for point in points:
		horizontal_radius = maxf(horizontal_radius, Vector2(point.x - center.x, point.z - center.z).length())
	horizontal_radius += HOUSE_CELL * 1.15
	house_camera_fit_size = minf(28.0, _rotation_invariant_fit_size(horizontal_radius, HOUSE_CELL * 1.65, house_camera_pitch, 0.8, 12.0))
	if not house_camera_user_adjusted:
		house_camera_target = center
	camera.size = clampf(house_camera_fit_size * house_camera_zoom_ratio, house_camera_fit_size * CAMERA_ZOOM_MIN, house_camera_fit_size * CAMERA_ZOOM_MAX)
	_apply_house_camera()


func pan_house_camera(pixel_delta: Vector2) -> void:
	if phase not in ["explore", "build", "room_ready"]:
		return
	house_camera_user_hold = true
	_cancel_house_camera_return()
	var units_per_pixel := camera.size / maxf(1.0, world_view_rect.size.y)
	var right := Vector3(camera.global_transform.basis.x.x, 0.0, camera.global_transform.basis.x.z).normalized()
	var screen_up := Vector3(camera.global_transform.basis.y.x, 0.0, camera.global_transform.basis.y.z).normalized()
	house_camera_target += (-right * pixel_delta.x + screen_up * pixel_delta.y) * units_per_pixel
	house_camera_user_adjusted = true
	_clamp_house_camera_target()
	_apply_house_camera()


func orbit_house_camera(pixel_delta: Vector2) -> void:
	if phase not in ["explore", "build", "room_ready"]:
		return
	house_camera_user_hold = true
	_cancel_house_camera_return()
	house_camera_yaw = fposmod(house_camera_yaw - pixel_delta.x * CAMERA_ORBIT_SENSITIVITY, TAU)
	house_camera_user_adjusted = true
	_apply_house_camera()


func zoom_house_camera(view_pos: Vector2, zoom_factor: float) -> void:
	if phase not in ["explore", "build", "room_ready"]:
		return
	_cancel_house_camera_return()
	var before: Variant = _screen_to_plane(view_pos, 0.0)
	var next_size := clampf(camera.size * zoom_factor, house_camera_fit_size * CAMERA_ZOOM_MIN, house_camera_fit_size * CAMERA_ZOOM_MAX)
	camera.size = next_size
	house_camera_zoom_ratio = next_size / maxf(0.001, house_camera_fit_size)
	house_camera_user_adjusted = true
	_apply_house_camera()
	var after: Variant = _screen_to_plane(view_pos, 0.0)
	if before is Vector3 and after is Vector3:
		var anchor_shift: Vector3 = before - after
		house_camera_target += Vector3(anchor_shift.x, 0.0, anchor_shift.z)
		_clamp_house_camera_target()
		_apply_house_camera()


func reset_house_camera() -> void:
	house_camera_zoom_ratio = 1.0
	house_camera_user_adjusted = false
	house_camera_yaw = atan2(HOUSE_CAMERA_DIRECTION.x, HOUSE_CAMERA_DIRECTION.z)
	house_camera_pitch = atan2(HOUSE_CAMERA_DIRECTION.y, Vector2(HOUSE_CAMERA_DIRECTION.x, HOUSE_CAMERA_DIRECTION.z).length())
	house_camera_distance = HOUSE_CAMERA_DIRECTION.length()
	_set_house_camera()


func _start_camera_intro() -> void:
	if camera == null:
		return
	house_camera_following = false
	house_camera_user_hold = false
	house_camera_return_delay = 0.0
	house_camera_returning = false
	if house_camera_return_tween != null and house_camera_return_tween.is_valid():
		house_camera_return_tween.kill()
		house_camera_return_tween = null
	if house_camera_intro_tween != null and house_camera_intro_tween.is_valid():
		house_camera_intro_tween.kill()
	var duration := CAMERA_INTRO_DURATION * animation_duration_scale
	if duration <= 0.0:
		house_camera_intro_weight = 1.0
		_apply_house_camera()
		return
	house_camera_intro_weight = 0.0
	_apply_house_camera()
	house_camera_intro_tween = create_tween()
	house_camera_intro_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	house_camera_intro_tween.tween_method(func(weight: float) -> void:
		house_camera_intro_weight = weight
		_apply_house_camera()
	, 0.0, 1.0, duration)


func release_house_camera_gesture() -> void:
	house_camera_user_hold = false
	if house_camera_following and not house_camera_returning:
		house_camera_return_delay = HOUSE_CAMERA_RETURN_DELAY


func _cancel_house_camera_return() -> void:
	house_camera_return_delay = 0.0
	house_camera_returning = false
	if house_camera_return_tween != null and house_camera_return_tween.is_valid():
		house_camera_return_tween.kill()
		house_camera_return_tween = null


func _start_house_camera_return() -> void:
	if camera == null or phase not in ["explore", "build", "room_ready"]:
		return
	house_camera_returning = true
	var player_pos := _house_follow_target_position() + _house_camera_frame_offset()
	var duration := HOUSE_CAMERA_RETURN_DURATION * animation_duration_scale
	if duration <= 0.0:
		house_camera_target = player_pos
		house_camera_returning = false
		_clamp_house_camera_target()
		_apply_house_camera()
		return
	var start_target := house_camera_target
	house_camera_return_tween = create_tween()
	house_camera_return_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	house_camera_return_tween.tween_method(func(weight: float) -> void:
		house_camera_target = start_target.lerp(player_pos, weight)
		_clamp_house_camera_target()
		_apply_house_camera()
	, 0.0, 1.0, duration)
	house_camera_return_tween.finished.connect(func() -> void:
		house_camera_returning = false
		house_camera_return_delay = 0.0
		house_camera_return_tween = null
		_clamp_house_camera_target()
		_apply_house_camera()
	)


func _clamp_house_camera_target() -> void:
	var limit := maxf(HOUSE_CELL * 6.0, house_camera_fit_size * 1.5)
	house_camera_target.x = clampf(house_camera_target.x, -limit, limit)
	house_camera_target.z = clampf(house_camera_target.z, -limit, limit)


func _apply_house_camera() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var horizontal := cos(house_camera_pitch) * house_camera_distance
	var direction := Vector3(sin(house_camera_yaw) * horizontal, sin(house_camera_pitch) * house_camera_distance, cos(house_camera_yaw) * horizontal)
	camera.position = house_camera_target + direction
	camera.look_at(house_camera_target + Vector3(0, 0.2, 0), Vector3.UP)
	camera.size = clampf(house_camera_fit_size * house_camera_zoom_ratio, house_camera_fit_size * CAMERA_ZOOM_MIN, house_camera_fit_size * CAMERA_ZOOM_MAX) * lerpf(CAMERA_INTRO_FAR_SCALE, 1.0, house_camera_intro_weight)
	if kenney_build_lab_mode:
		_apply_current_room_cutaway()


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
	var candidates: Array[Dictionary] = []
	for room: Dictionary in remaining_rooms:
		if not room_rules.valid_rotations(target, room).is_empty():
			candidates.append(room)
	_shuffle_variants(candidates)
	if large_room_mix_test_mode:
		return _make_large_room_test_offers(candidates)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := _layout_profile_offer_score(a)
		var score_b := _layout_profile_offer_score(b)
		if score_a != score_b:
			return score_a > score_b
		return posmod((str(a.get("id", "")) + str(run_seed)).hash(), 10007) < posmod((str(b.get("id", "")) + str(run_seed)).hash(), 10007)
	)
	for room in candidates:
		if result.size() >= 3:
			break
		result.append(room)
	return result


func _make_large_room_test_offers(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var buckets := {1: [], 3: [], 5: []}
	for room: Dictionary in candidates:
		var size := int(room.get("room_size", 1))
		if buckets.has(size):
			(buckets[size] as Array).append(room)
	var counts := _placed_room_size_counts()
	var placed_count := room_rules.instance_count()
	var desired_size := int(LARGE_ROOM_TEST_SEQUENCE[mini(placed_count, LARGE_ROOM_TEST_SEQUENCE.size() - 1)])
	var last_size := _latest_placed_room_size()
	var size_order: Array[int] = [desired_size]
	var alternatives: Array[int] = [3, 5, 1]
	alternatives.sort_custom(func(a: int, b: int) -> bool:
		var remaining_a := int(LARGE_ROOM_TEST_TARGETS[a]) - int(counts[a])
		var remaining_b := int(LARGE_ROOM_TEST_TARGETS[b]) - int(counts[b])
		if remaining_a != remaining_b:
			return remaining_a > remaining_b
		return a > b
	)
	for size: int in alternatives:
		if size not in size_order:
			size_order.append(size)
	for size: int in size_order:
		if result.size() >= 3:
			break
		if int(counts[size]) >= int(LARGE_ROOM_TEST_TARGETS[size]):
			continue
		if size == 1 and last_size == 1:
			continue
		var bucket: Array = buckets[size]
		if not bucket.is_empty():
			result.append(bucket[0])
	for room: Dictionary in candidates:
		if result.size() >= 3:
			break
		var size := int(room.get("room_size", 1))
		var within_target := buckets.has(size) and int(counts[size]) < int(LARGE_ROOM_TEST_TARGETS[size])
		var respects_cadence := size != 1 or last_size != 1
		if within_target and respects_cadence and not _contains_room(result, str(room.get("id", ""))):
			result.append(room)
	if result.size() < 3:
		for room: Dictionary in candidates:
			if result.size() >= 3:
				break
			if not _contains_room(result, str(room.get("id", ""))):
				result.append(room)
	return result


func _placed_room_size_counts() -> Dictionary:
	var counts := {1: 0, 3: 0, 5: 0}
	var seen: Dictionary = {}
	for raw_pos: Variant in room_rules.placed.keys():
		var room: Dictionary = room_rules.placed[raw_pos]
		var instance_id := str(room.get("instance_id", ""))
		if seen.has(instance_id):
			continue
		seen[instance_id] = true
		var size := int(room.get("room_size", 1))
		if counts.has(size):
			counts[size] = int(counts[size]) + 1
	return counts


func _latest_placed_room_size() -> int:
	return int(current_room().get("room_size", 1))


func _apply_large_room_test_catalog() -> void:
	run_layout_profile = {"id": "large_room_test", "label": "大房间节奏实验", "weights": {}}
	for index in range(room_catalog.size()):
		room_catalog[index] = _large_room_test_room(room_catalog[index])
	for index in range(remaining_rooms.size()):
		remaining_rooms[index] = _large_room_test_room(remaining_rooms[index])


func _large_room_test_room(source: Dictionary) -> Dictionary:
	var room := source.duplicate(true)
	var room_id := str(room.get("id", ""))
	if not LARGE_ROOM_TEST_SHAPE_OVERRIDES.has(room_id):
		return room
	var shape_id := str(LARGE_ROOM_TEST_SHAPE_OVERRIDES[room_id])
	var footprint: Array = (RoomFootprintCatalog.SHAPES[shape_id] as Array).duplicate(true)
	room["footprint_kind"] = shape_id
	room["footprint"] = footprint
	room["room_size"] = footprint.size()
	return room


func _layout_profile_offer_score(room: Dictionary) -> int:
	var shape := str(room.get("footprint_kind", "single"))
	var category := "large"
	if shape == "single":
		category = "single"
	elif shape == "line3":
		category = "line3"
	elif shape == "l3":
		category = "l3"
	var weights: Dictionary = run_layout_profile.get("weights", {})
	var score := int(weights.get(category, 1)) * 100
	if str(run_layout_profile.get("id", "")) == "mixed":
		var desired_size: int = [1, 3, 5][posmod(run_progress - 1, 3)]
		score += 80 if int(room.get("room_size", 1)) == desired_size else 0
	return score


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
	if room_rules.same_instance(a, b):
		return true
	return room_rules.cell_has_door(a, side) and room_rules.cell_has_door(b, (side + 2) % 4)


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
var _smb_tail_padding := """
Combat Lab intentionally keeps the same fixed action-point setup as real rooms.
This trailing padding also guards SMB shares that do not truncate rewritten files.
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
"""
