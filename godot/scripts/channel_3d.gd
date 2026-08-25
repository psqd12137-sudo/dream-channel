extends Node3D

const RoomRules = preload("res://scripts/room_rules.gd")
const RoomFootprintCatalog = preload("res://scripts/room_footprint_catalog.gd")
const CombatRules = preload("res://scripts/combat_rules.gd")
const CombatTestCatalog = preload("res://scripts/combat_test_catalog.gd")
const CombatTestSession = preload("res://scripts/combat_test_session.gd")
const WebContentAdapter = preload("res://scripts/web_content_adapter.gd")
const CharacterPresenter = preload("res://scripts/character_presenter.gd")
const CameraFollowMath = preload("res://scripts/camera_follow_math.gd")
const RoomArtRegistry = preload("res://scripts/room_art_registry.gd")
const RoomPropCatalog = preload("res://scripts/room_prop_catalog.gd")
const BattleRoomArtContext = preload("res://scripts/battle_room_art_context.gd")
const CardboardShellBuilder = preload("res://scripts/cardboard_shell_builder.gd")
const RunSaveRepository = preload("res://scripts/run_save_repository.gd")
const PresentationSettings = preload("res://scripts/presentation_settings.gd")
const HouseWorldRenderer = preload("res://scripts/channel_house_world_renderer.gd")
const BattleWorldRenderer = preload("res://scripts/channel_battle_world_renderer.gd")
const LabController = preload("res://scripts/channel_lab_controller.gd")
const DIORAMA_ART_LAB = preload("res://scenes/diorama_art_lab.tscn")
const PCG_DIORAMA_STITCH_LAB = preload("res://scenes/pcg_diorama_stitch_lab.tscn")
const PCG_HAND_LAYOUT_LAB = preload("res://scenes/pcg_hand_layout_lab.tscn")
const PCG_HAND_ROOM_SCRIPT = preload("res://scripts/pcg_hand_room.gd")
const ASSET_EDITOR_SCENE_PATH := "res://scenes/asset_editor_3d.tscn"
const KAYKIT_DUNGEON_ROOT := "res://assets/third_party/kaykit_dungeon/models/"
const APP_FONT: Font = preload("res://assets/fonts/SourceHanSansCN-Regular.otf")

const EXE_SOURCE_ID := "CabinSlice_织梦频道.exe@EEC4C574CC22"
const SNAPSHOT_ROOT := "res://data/exe_snapshot/"
const PRESENTATION_MANIFEST := "res://data/presentation_manifest.json"
const RUN_SAVE_PATH := "user://channel_run_v1.json"
const BATTLE_HEIGHT_ASSET_ROOT := "res://assets/quaternius/ultimate_house_interior/"
const BATTLE_FLOOR_LIGHT := KAYKIT_DUNGEON_ROOT + "floor_wood_large.gltf.glb"
const BATTLE_FLOOR_DARK := KAYKIT_DUNGEON_ROOT + "floor_wood_large_dark.gltf.glb"
const BATTLE_HEIGHT_ASSETS := {
	1: [
		"res://assets/third_party/kaykit_furniture_bits/gltf/table_low.gltf",
		"res://assets/third_party/kaykit_furniture_bits/gltf/table_medium.gltf",
		"res://assets/quaternius/ultimate_house_interior/Couch_Medium1.fbx",
	],
	2: [
		KAYKIT_DUNGEON_ROOT + "stairs_wood.gltf.glb",
		"res://assets/third_party/kenney_mini_dungeon/models/wood-structure.glb",
		"res://assets/third_party/kenney_mini_dungeon/models/stairs.glb",
	],
}
const BATTLE_BLOCKER_ASSETS := [
	"res://assets/third_party/kenney_mini_dungeon/models/column.glb",
	"res://assets/third_party/kenney_mini_dungeon/models/chest.glb",
	"res://assets/third_party/kenney_mini_dungeon/models/barrel.glb",
	"res://assets/quaternius/ultimate_house_interior/Bookshelf.fbx",
]
const HOUSE_CELL := 3.4
const VISUAL_CELL_SCALE := 1.20
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
const CAMERA_ZOOM_SMOOTH_RATE := 12.0
const CAMERA_ORBIT_SENSITIVITY := 0.008
const CAMERA_INTRO_FAR_SCALE := 2.4
const CAMERA_INTRO_DURATION := 1.35
const HOUSE_CAMERA_FOLLOW_RATE := 3.4
const HOUSE_CAMERA_FRAME_OFFSET := 0.15
const HOUSE_CAMERA_RETURN_DELAY := 1.5
const HOUSE_CAMERA_RETURN_DURATION := 1.05
const HOUSE_CAMERA_CLOSEUP_SIZE := HOUSE_CELL * VISUAL_CELL_SCALE * 2.6
const HOUSE_CAMERA_SIZE_SMOOTH_RATE := 5.5
const BATTLE_CAMERA_FOLLOW_RATE := 4.5
const BATTLE_CAMERA_FRAME_OFFSET := 0.12
const BATTLE_CAMERA_RETURN_DELAY := 1.5
const BATTLE_CAMERA_RETURN_DURATION := 0.9
const INVALID_CELL := Vector2i(-999, -999)
const UNITY_ROOM_DROP_DURATION := 0.25
const UNITY_ROOM_DROP_HEIGHT_CELLS := 0.65
const UNITY_ROOM_START_SCALE := 0.94
const UNITY_ACTOR_STEP_DURATION := 0.25
const UNITY_ACTOR_TURN_DURATION := 0.16
const UNITY_ACTOR_SETTLE_DURATION := 0.12
const UNITY_CARD_HALF_FLIP_DURATION := 0.10
const ENEMY_STEP_DURATION := 0.48
const ENEMY_TURN_DURATION := 0.22
const ENEMY_ATTACK_DURATION := 0.62
const ENEMY_EVENT_PAUSE_DURATION := 0.16
const ENEMY_PROJECTILE_DURATION := 0.42
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
var test_catalog = CombatTestCatalog.new()
var test_session = CombatTestSession.new()
var rng := RandomNumberGenerator.new()
var run_save_repository = RunSaveRepository.new(RUN_SAVE_PATH, EXE_SOURCE_ID)
var presentation_settings = null
var house_world_renderer = null
var battle_world_renderer = null
var lab_controller = null

# Compatibility surface for tests and external UI callers. The actual state
# lives in ChannelPresentationSettings, but the old game-level properties stay
# available while callers migrate to the settings module.
var display_resolution_index:
	get: return presentation_settings.resolution_index if presentation_settings != null else 2
	set(value):
		if presentation_settings != null:
			presentation_settings.resolution_index = int(value)
var display_fullscreen:
	get: return presentation_settings.fullscreen if presentation_settings != null else false
	set(value):
		if presentation_settings != null:
			presentation_settings.fullscreen = bool(value)
var tilt_shift_enabled:
	get: return presentation_settings.tilt_shift_enabled if presentation_settings != null else true
	set(value):
		if presentation_settings != null:
			presentation_settings.tilt_shift_enabled = bool(value)

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
var house_camera_closeup := false
var house_camera_size_current := 0.0
var house_camera_size_target := 0.0
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
var battle_room_context: Dictionary = {}
var enemy_nodes: Dictionary = {}
var battle_board_root: Node3D = null
var battle_actor_root: Node3D = null
var battle_entry_side := -1
var battle_entry_cell := INVALID_CELL
var battle_backstage_cells: Dictionary = {}
var battle_height_prop_assignments: Dictionary = {}
var battle_blocker_prop_assignments: Dictionary = {}
var battle_height_visual_indices: Dictionary = {}
var previous_room_pos := Vector2i.ZERO
var battle_shell_edge_records: Dictionary = {}
var battle_shell_culled_count := 0
var battle_shell_visible_count := 0
var hovered_battle_cell := INVALID_CELL
var hovered_house_cell := INVALID_CELL
var animation_busy := false
var active_animation_kind := ""
var active_motion_tween: Tween = null
var battle_projectile_nodes: Array[Node3D] = []
var battle_active_projectile: Node3D = null
var battle_projectile_start := Vector3.ZERO
var battle_projectile_target := Vector3.ZERO
var build_preview_tween: Tween = null
var lab_root: Node3D = null
var home_tests_open := false
var test_combat_active := false
var test_mode_selected_id := ""
var test_saved_state: Dictionary = {}
var test_auto_accumulator := 0.0
var test_last_events: Array[Dictionary] = []
var test_focused_enemy_id := ""
var battle_focused_enemy_id := ""
var test_enemy_phase_pending := false
var battle_turn_actor_id := "player"
var battle_turn_events: Array[Dictionary] = []
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
func _ready() -> void:
	presentation_settings = PresentationSettings.new(self, world_container, hud, home_video)
	presentation_settings.load_settings()
	_configure_environment()
	presentation_settings.configure_home_video()
	presentation = _load_json_dictionary(PRESENTATION_MANIFEST)
	if not test_catalog.load_from_path():
		push_error("Combat test catalog failed: %s" % str(test_catalog.errors))
	lab_root = Node3D.new()
	lab_root.name = "LabRoot"
	world_root.add_child(lab_root)
	hud.game = self
	house_world_renderer = HouseWorldRenderer.new(self)
	battle_world_renderer = BattleWorldRenderer.new(self)
	lab_controller = LabController.new(self)
	hud.sync_layout()
	reset_run(run_seed)
	go_home()


func display_resolution_label() -> String:
	return presentation_settings.resolution_label()


func display_mode_label() -> String:
	return presentation_settings.mode_label()


func tilt_shift_label() -> String:
	return presentation_settings.tilt_shift_label()


func cycle_display_resolution() -> void:
	presentation_settings.cycle_resolution()


func toggle_display_mode() -> void:
	presentation_settings.toggle_mode()


func toggle_tilt_shift() -> void:
	presentation_settings.toggle_tilt_shift()


func _apply_display_settings(save_settings: bool) -> void:
	if presentation_settings != null:
		await presentation_settings._apply_display_settings(save_settings)


func quit_game() -> void:
	get_tree().quit()


func _set_home_video(active: bool) -> void:
	if presentation_settings != null:
		presentation_settings.set_home_video(active)


func _process(delta: float) -> void:
	if phase == "combat" and test_combat_active:
		_update_test_observer(delta)
	elif phase == "lab_sideview":
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


## 相机系统分区：
## - 探索地图（house）：`house_camera_*` 状态 + `_update_camera_follow` 的 house 分支，
##   入场运镜（_start_camera_intro）、延迟跟随（enter_room 激活）、松手延迟回位、玩家偏下构图。
## - 战斗（battle）：`battle_camera_*` 状态 + `_update_camera_follow` 的 battle 分支，
##   走格跟随玩家-怪物中点、松手延迟回位、偏上对准。
## - 共享数学在 `camera_follow_math.gd`（平滑因子、屏幕上方偏移）。
func _update_camera_follow(delta: float) -> void:
	if house_camera_return_delay > 0.0:
		house_camera_return_delay = maxf(0.0, house_camera_return_delay - delta)
		if house_camera_return_delay <= 0.0 and not house_camera_user_hold:
			_start_house_camera_return()
	if phase in ["explore", "build", "room_ready"] and camera != null:
		var target_size := _house_camera_size_target()
		var size_factor := CameraFollowMath.smooth_factor(HOUSE_CAMERA_SIZE_SMOOTH_RATE, delta)
		var next_size := lerpf(house_camera_size_current, target_size, size_factor)
		if absf(next_size - house_camera_size_current) > 0.001:
			house_camera_size_current = next_size
			_apply_house_camera()
		if house_camera_following and not house_camera_user_hold and not house_camera_returning:
			var follow_target := _house_follow_target_position() + _house_camera_frame_offset()
			var factor := CameraFollowMath.smooth_factor(HOUSE_CAMERA_FOLLOW_RATE, delta)
			var next_target := house_camera_target.lerp(follow_target, factor)
			if not next_target.is_equal_approx(house_camera_target):
				house_camera_target = next_target
				_clamp_house_camera_target()
				_apply_house_camera()
	elif phase == "combat" and combat != null and camera != null:
		var battle_camera_changed := false
		if battle_camera_return_delay > 0.0:
			battle_camera_return_delay = maxf(0.0, battle_camera_return_delay - delta)
			if battle_camera_return_delay <= 0.0 and not battle_camera_user_hold:
				_start_battle_camera_return()
		var target_size := battle_camera_fit_size * battle_camera_zoom_ratio
		var size_factor := CameraFollowMath.smooth_factor(CAMERA_ZOOM_SMOOTH_RATE, delta)
		var next_size := lerpf(camera.size, target_size, size_factor)
		if absf(next_size - camera.size) > 0.001:
			camera.size = next_size
			battle_camera_changed = true
		if battle_camera_following and not battle_camera_user_hold and not battle_camera_returning:
			var follow_target := _battle_follow_target_position() + _battle_camera_frame_offset()
			var factor := CameraFollowMath.smooth_factor(HOUSE_CAMERA_FOLLOW_RATE, delta)
			var next_target := battle_camera_target.lerp(follow_target, factor)
			if not next_target.is_equal_approx(battle_camera_target):
				battle_camera_target = next_target
				_clamp_battle_camera_target()
				battle_camera_changed = true
		if battle_camera_changed:
			_apply_battle_camera()


func _house_follow_target_position() -> Vector3:
	if not house_camera_closeup:
		return _house_camera_overview_target()
	var token := house_root.get_node_or_null("LiliToken") as Node3D
	if token != null:
		var token_world := house_root.to_global(token.position)
		return Vector3(token_world.x, 0.0, token_world.z)
	return _house_visual_world(current_room_pos)


func _house_camera_overview_target() -> Vector3:
	var points := _house_camera_layout_points()
	var center := Vector3.ZERO
	for point in points:
		center += point
	if not points.is_empty():
		center /= float(points.size())
	return center


func _house_camera_layout_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for raw_pos: Variant in room_rules.placed.keys():
		points.append(_house_visual_world(raw_pos as Vector2i))
	# Ordinary frontier sockets are navigation affordances, not composition
	# content. Only the currently selected multi-cell build preview contributes
	# to framing, so a one-room opening no longer floats in a future-map void.
	if phase == "build" and selected_offer >= 0 and selected_offer < build_offers.size():
		var room: Dictionary = build_offers[selected_offer]
		var resolved: Dictionary = room_rules.resolve_placement(selected_frontier, room, offer_rotation)
		for raw_cell: Variant in resolved.get("cells", []):
			var preview_cell := raw_cell as Vector2i
			if preview_cell not in room_rules.placed:
				points.append(_house_visual_world(preview_cell))
	return points


func _house_camera_size_target() -> float:
	var base_size := house_camera_fit_size
	if house_camera_closeup:
		base_size = minf(base_size, HOUSE_CAMERA_CLOSEUP_SIZE)
	return clampf(base_size * house_camera_zoom_ratio, base_size * CAMERA_ZOOM_MIN, base_size * CAMERA_ZOOM_MAX)


func _house_camera_frame_offset() -> Vector3:
	return CameraFollowMath.screen_up_offset(camera, HOUSE_CAMERA_FRAME_OFFSET)


func _battle_camera_frame_offset() -> Vector3:
	return CameraFollowMath.screen_up_offset(camera, BATTLE_CAMERA_FRAME_OFFSET)


func _battle_follow_target_position() -> Vector3:
	if combat == null:
		return Vector3.ZERO
	var points: Array[Vector3] = [_battle_pawn_world(combat.player_pos, true)]
	for enemy_id in combat.living_enemy_ids():
		var state = combat.enemy_by_id(enemy_id)
		if state != null:
			points.append(_battle_pawn_world(state.pos, false, enemy_id))
	if points.is_empty():
		return Vector3.ZERO
	var center := Vector3.ZERO
	for point in points:
		center += point
	return center / float(points.size())


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
	previous_room_pos = current_room_pos
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
	house_camera_closeup = false
	house_camera_size_current = 0.0
	house_camera_size_target = 0.0
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
	if test_combat_active:
		_restore_test_state()
	test_combat_active = false
	test_session.clear()
	test_saved_state.clear()
	test_mode_selected_id = ""
	test_auto_accumulator = 0.0
	test_last_events.clear()
	test_focused_enemy_id = ""
	battle_focused_enemy_id = ""
	test_enemy_phase_pending = false
	_cancel_dynamic_effect()
	character_animation_demo_mode = false
	camera.environment = null
	house_camera_following = false
	house_camera_closeup = false
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
	return run_save_repository.exists()


func continue_saved_run() -> bool:
	_set_home_video(false)
	var save := run_save_repository.read()
	if save.is_empty():
		return false
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
	previous_room_pos = current_room_pos
	pending_room_pos = _array_to_pos(save.get("pending_room", [0, 0]))
	house_player_facing_yaw = float(save.get("house_player_facing_yaw", 0.0))
	phase = str(save.get("phase", "explore"))
	if phase not in ["omen", "explore", "room_ready", "reward"]:
		phase = "room_ready" if not bool(current_room().get("completed", false)) else "explore"
	house_camera_closeup = phase == "reward" and reward_origin in ["combat", "event"]
	house_camera_following = house_camera_closeup
	world_container.visible = true
	house_root.visible = true
	battle_root.visible = false
	status_message = "已接上上集：房间、生命、预兆和本局牌库都已恢复。"
	build_house_world()
	_set_house_camera()
	_refresh_hud()
	return true


func toggle_home_tests() -> void:
	lab_controller.toggle_home_tests()


func open_combat_test_mode() -> bool:
	return lab_controller.open_combat_test_mode()


func select_combat_test_scenario(scenario_id: String) -> void:
	lab_controller.select_combat_test_scenario(scenario_id)


func start_test_combat(mode: String = "manual") -> bool:
	return lab_controller.start_test_combat(mode)


func restart_test_combat() -> bool:
	return lab_controller.restart_test_combat()


func return_to_combat_test_menu() -> void:
	lab_controller.return_to_combat_test_menu()


func _restore_test_state() -> void:
	lab_controller._restore_test_state()


func _update_test_observer(_delta: float) -> void:
	lab_controller._update_test_observer(_delta)


func _advance_test_player_script() -> void:
	lab_controller._advance_test_player_script()


func advance_test_observer() -> void:
	lab_controller.advance_test_observer()


func toggle_test_observer() -> void:
	lab_controller.toggle_test_observer()


func focus_test_enemy(enemy_id: String) -> void:
	lab_controller.focus_test_enemy(enemy_id)


func open_asset_editor() -> bool:
	return lab_controller.open_asset_editor()


func start_combat_lab(room_id: String = "hall") -> void:
	lab_controller.start_combat_lab(room_id)


func start_kenney_build_lab() -> void:
	lab_controller.start_kenney_build_lab()


func start_diorama_art_lab() -> void:
	lab_controller.start_diorama_art_lab()


func start_character_animation_lab() -> void:
	lab_controller.start_character_animation_lab()


func demo_character_idle() -> void:
	lab_controller.demo_character_idle()


func demo_character_grid_step() -> void:
	lab_controller.demo_character_grid_step()


func demo_character_attack() -> void:
	lab_controller.demo_character_attack()


func demo_character_hurt() -> void:
	lab_controller.demo_character_hurt()


func start_pcg_diorama_lab() -> void:
	lab_controller.start_pcg_diorama_lab()


func reroll_pcg_diorama() -> void:
	lab_controller.reroll_pcg_diorama()


func start_pcg_hand_layout_lab() -> void:
	lab_controller.start_pcg_hand_layout_lab()


func _set_pcg_diorama_camera(generator: Node3D) -> void:
	lab_controller._set_pcg_diorama_camera(generator)


func _find_catalog_room(room_id: String) -> Dictionary:
	return lab_controller._find_catalog_room(room_id)


func start_sideview_lab() -> void:
	lab_controller.start_sideview_lab()


func set_sideview_input(axis: float, jump_pressed: bool) -> void:
	lab_controller.set_sideview_input(axis, jump_pressed)


func _update_sideview(delta: float) -> void:
	lab_controller._update_sideview(delta)


func _sideview_floor_at(x_value: float, previous_y: float) -> float:
	return lab_controller._sideview_floor_at(x_value, previous_y)


func start_puzzle_lab() -> void:
	lab_controller.start_puzzle_lab()


func puzzle_slide(index: int) -> void:
	lab_controller.puzzle_slide(index)


func puzzle_refresh() -> void:
	lab_controller.puzzle_refresh()


func puzzle_slide_from_offset(offset: int) -> void:
	lab_controller.puzzle_slide_from_offset(offset)


func _shuffle_puzzle(reset_refreshes: bool = true) -> void:
	lab_controller._shuffle_puzzle(reset_refreshes)


func start_search_lab() -> void:
	lab_controller.start_search_lab()


func search_pick_from_view(view_pos: Vector2) -> bool:
	return lab_controller.search_pick_from_view(view_pos)


func start_chase_lab() -> void:
	lab_controller.start_chase_lab()


func _reset_chase() -> void:
	lab_controller._reset_chase()


func begin_chase() -> void:
	lab_controller.begin_chase()


func chase_type_character(character: String) -> void:
	lab_controller.chase_type_character(character)


func forfeit_chase() -> void:
	lab_controller.forfeit_chase()


func _update_chase(delta: float) -> void:
	lab_controller._update_chase(delta)


func _update_chase_countdown(delta: float) -> void:
	lab_controller._update_chase_countdown(delta)


func _next_chase_sentence() -> void:
	lab_controller._next_chase_sentence()


func _finish_chase(success: bool, message: String = "") -> void:
	lab_controller._finish_chase(success, message)


func _update_chase_finish_delay(delta: float) -> void:
	lab_controller._update_chase_finish_delay(delta)


func _prepare_lab(next_phase: String) -> void:
	lab_controller._prepare_lab(next_phase)


func _set_lab_camera(target: Vector3, size_value: float) -> void:
	lab_controller._set_lab_camera(target, size_value)


func _set_search_camera_defaults() -> void:
	lab_controller._set_search_camera_defaults()


func _set_diorama_camera_defaults() -> void:
	lab_controller._set_diorama_camera_defaults()


func _make_visual_polish_environment() -> Environment:
	return lab_controller._make_visual_polish_environment()


func orbit_search_camera(relative: Vector2) -> void:
	lab_controller.orbit_search_camera(relative)


func zoom_search_camera(factor: float) -> void:
	lab_controller.zoom_search_camera(factor)


func _apply_search_camera() -> void:
	lab_controller._apply_search_camera()
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
	var world := _house_logical_world_from_visual(hit as Vector3)
	var target := Vector2i(roundi(world.x / HOUSE_CELL), roundi(world.z / HOUSE_CELL))
	if target in room_rules.frontiers():
		begin_build(target)
	elif room_rules.placed.has(target) and target != current_room_pos and _rooms_connected(current_room_pos, target):
		enter_room(target)


func enter_room(target: Vector2i) -> void:
	if animation_busy or not room_rules.placed.has(target) or not _rooms_connected(current_room_pos, target):
		return
	previous_room_pos = current_room_pos
	animation_busy = true
	active_animation_kind = "room_entry"
	house_camera_closeup = false
	house_camera_following = false
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
	house_camera_closeup = false
	house_camera_following = false
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
	var origin := reward_origin
	phase = "explore"
	reward_options.clear()
	reward_origin = ""
	house_camera_closeup = origin in ["combat", "event"]
	house_camera_following = house_camera_closeup
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
	house_camera_closeup = true
	house_camera_following = true
	if success:
		if context == "chase":
			player_speed += 1
		_start_quiet_reward()
		reward_origin = "event"
		_save_run()
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
	var enemy_specs: Variant = room.get("enemies", [])
	if not enemy_specs is Array or (enemy_specs as Array).is_empty():
		enemy_specs = room.get("enemy", {})
	var run_rules: Dictionary = content.get("run_rules", {}).duplicate(true)
	if test_combat_active and test_session.active:
		run_rules.merge(test_session.scenario.get("run_rules", {}), true)
	run_rules["player_hp"] = player_hp
	run_rules["base_speed"] = player_speed
	run_rules["base_speed"] = player_speed
	combat.setup(room.get("arena", {}), enemy_specs, content.get("cards", {}), run_deck, run_seed + room_rules.instance_count() * 17, run_rules, active_relics)
	battle_entry_cell = combat.player_pos
	battle_entry_side = _resolve_battle_entry_side(room)
	battle_room_context = BattleRoomArtContext.build(room, combat.cols, combat.rows, BATTLE_CELL, run_seed + str(room.get("instance_id", room.get("id", "room"))).hash())
	_apply_battle_footprint_to_combat()
	_align_battle_terrain_to_room_context()
	_prepare_battle_prop_assignments()
	selected_card = -1
	hovered_battle_cell = INVALID_CELL
	battle_focused_enemy_id = ""
	phase = "combat"
	world_container.visible = true
	house_root.visible = false
	battle_root.visible = true
	battle_turn_actor_id = "player"
	battle_turn_events.clear()
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
	var player := battle_actor_root.get_node_or_null("Player") as Node3D
	if player != null:
		player.visible = false
	for enemy_id in enemy_nodes.keys():
		var enemy := enemy_nodes[enemy_id] as Node3D
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
	var player := battle_actor_root.get_node_or_null("Player") as Node3D
	var enemies_in_scene: Array[Node3D] = []
	for enemy_id in enemy_nodes.keys():
		var enemy := enemy_nodes[enemy_id] as Node3D
		if enemy != null:
			enemies_in_scene.append(enemy)
	if player == null or enemies_in_scene.is_empty():
		status_message = final_message
		_complete_dynamic_effect()
		_refresh_hud()
		return
	var player_target := player.position
	player.position = player_target + Vector3(-BATTLE_CELL * 0.70, 1.25, BATTLE_CELL * 0.55)
	player.scale = Vector3.ONE * 0.68
	player.visible = true
	for enemy in enemies_in_scene:
		enemy.position = enemy.position + Vector3(BATTLE_CELL * 0.70, 1.25, -BATTLE_CELL * 0.55)
		enemy.scale = Vector3.ONE * 0.68
		enemy.visible = true
	var actor_duration := BATTLE_ACTOR_ENTRY_DURATION * animation_duration_scale
	var actor_tween := create_tween()
	active_motion_tween = actor_tween
	actor_tween.set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	actor_tween.tween_property(player, "position", player_target, actor_duration)
	actor_tween.tween_property(player, "scale", Vector3.ONE, actor_duration)
	for enemy in enemies_in_scene:
		var enemy_target := _battle_world(_enemy_state_for_node(enemy).pos) if _enemy_state_for_node(enemy) != null else enemy.position
		actor_tween.tween_property(enemy, "position", enemy_target, actor_duration)
		actor_tween.tween_property(enemy, "scale", Vector3.ONE, actor_duration)
	await actor_tween.finished
	if active_motion_tween != actor_tween:
		return
	if not is_instance_valid(player):
		build_battle_world()
		status_message = final_message
		_complete_dynamic_effect()
		_refresh_hud()
		return
	player.position = player_target
	player.scale = Vector3.ONE
	for enemy in enemies_in_scene:
		if is_instance_valid(enemy):
			enemy.scale = Vector3.ONE
	_play_actor_state("Player", "ready", "入场")
	for enemy_id in enemy_nodes.keys():
		_play_enemy_state(str(enemy_id), "ready", "现身")
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
		update_battle_overlays()
		_play_actor_state("Player", "ready", "准备·%s" % str(card.get("name", combat.hand[index])))
	else:
		var enemy_hp_before: int = combat.enemy_hp
		if str(combat.card_target_type(card)) == "single_enemy" and combat.living_enemy_ids().size() > 1:
			# 多敌人时单体牌必须先点选目标敌人，不能默认打第一个。
			if selected_card == index:
				cancel_selected_card("已取消%s；绿色角标恢复为移动目标。" % str(card.get("name", combat.hand[index])))
				return
			selected_card = index
			status_message = "已选%s：点击目标敌人格生效。再次点牌、右键或 Esc 可取消。" % str(card.get("name", combat.hand[index]))
			update_battle_overlays()
			_play_actor_state("Player", "ready", "瞄准·%s" % str(card.get("name", combat.hand[index])))
			_refresh_hud()
			return
		var played: bool = combat.play_card(index, combat.enemy_pos)
		selected_card = -1
		if played:
			status_message = "已打出%s。" % str(card.get("name", "卡牌"))
			_after_combat_action()
			_play_actor_state("Player", "ready" if str(card.get("type", "")) == "ready" else "attack", str(card.get("name", "出手")))
			var damage_feedback_shown := false
			for raw_event in combat.last_card_events:
				var damage_event: Dictionary = raw_event
				if str(damage_event.get("kind", "")) != "enemy_damaged" or int(damage_event.get("damage", 0)) <= 0:
					continue
				var damage_enemy_id := str(damage_event.get("target_enemy_id", ""))
				if damage_enemy_id.is_empty():
					continue
				_play_enemy_state(damage_enemy_id, "hurt", "-%d" % int(damage_event["damage"]))
				_show_enemy_damage_feedback(damage_enemy_id, int(damage_event["damage"]))
				damage_feedback_shown = true
			if not damage_feedback_shown and combat.enemy_hp < enemy_hp_before:
				var damage_dealt: int = enemy_hp_before - combat.enemy_hp
				if not combat.enemy_order.is_empty():
					_play_enemy_state(combat.enemy_order[0], "hurt", "-%d" % damage_dealt)
					_show_enemy_damage_feedback(combat.enemy_order[0], damage_dealt)
		else:
			status_message = "%s当前条件不满足，卡牌没有消耗。" % str(card.get("name", "这张牌"))
	_refresh_hud()


func cancel_selected_card(message: String = "已取消选牌；绿色角标表示可以移动的格子。") -> void:
	if phase != "combat" or selected_card < 0:
		return
	selected_card = -1
	status_message = message
	update_battle_overlays()
	_refresh_hud()


func end_combat_turn() -> void:
	if animation_busy or phase != "combat" or combat == null or combat.outcome != "":
		return
	selected_card = -1
	hovered_battle_cell = INVALID_CELL
	var turn_events: Array[Dictionary] = combat.enemy_turn()
	battle_turn_events = turn_events.duplicate(true)
	battle_turn_actor_id = "enemy_phase"
	for event: Dictionary in turn_events:
		var actor_id := str(event.get("actor_id", ""))
		if not actor_id.is_empty():
			battle_turn_actor_id = actor_id
			break
	if test_combat_active:
		test_last_events = turn_events.duplicate(true)
		test_enemy_phase_pending = true
	animation_busy = true
	active_animation_kind = "enemy_turn"
	status_message = _enemy_turn_summary(turn_events)
	# 逻辑状态可以先结算，但敌人节点必须保持在演员层等待移动动画。
	# 这里只刷新格子、意图和危险标记，不重建任何演员节点。
	refresh_battle_board()
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
	if animation_duration_scale <= 0.0:
		_complete_dynamic_effect()
		_after_combat_action(true)
		return
	if turn_events.is_empty():
		var wait_tween := create_tween()
		active_motion_tween = wait_tween
		wait_tween.tween_interval(0.34 * animation_duration_scale)
		await wait_tween.finished
		if active_motion_tween != wait_tween:
			return
		_complete_dynamic_effect()
		_after_combat_action(false)
		return
	_position_enemy_turn_starts(turn_events)
	var tween := create_tween()
	active_motion_tween = tween
	for event: Dictionary in turn_events:
		var kind := str(event.get("kind", ""))
		var actor_id := str(event.get("actor_id", ""))
		var enemy_node := _enemy_node_for_id(actor_id)
		if kind == "move":
			if enemy_node == null:
				continue
			var source: Vector2i = event.get("from", combat.enemy_pos)
			var target: Vector2i = event.get("to", combat.enemy_pos)
			var facing_yaw := _battle_move_facing_yaw(source, target)
			battle_enemy_facing_yaw = facing_yaw
			tween.tween_callback(_play_enemy_state.bind(actor_id, "move", "穿门" if bool(event.get("via_portal", false)) else ""))
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(enemy_node, "rotation:y", facing_yaw, ENEMY_TURN_DURATION * animation_duration_scale)
			if bool(event.get("via_portal", false)):
				tween.tween_property(enemy_node, "scale", Vector3(0.08, 1.35, 0.08), ENEMY_STEP_DURATION * 0.42 * animation_duration_scale)
				tween.tween_callback(func() -> void: enemy_node.position = _battle_pawn_world(target, false, actor_id))
				tween.tween_property(enemy_node, "scale", Vector3.ONE, ENEMY_STEP_DURATION * 0.58 * animation_duration_scale)
			else:
				tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				tween.tween_method(_set_enemy_step_motion.bind(enemy_node, _battle_pawn_world(source, false, actor_id), _battle_pawn_world(target, false, actor_id)), 0.0, 1.0, ENEMY_STEP_DURATION * animation_duration_scale)
			tween.tween_interval(ENEMY_EVENT_PAUSE_DURATION * animation_duration_scale)
		elif kind == "attack":
			if enemy_node == null:
				continue
			var attack_kind := str(event.get("attack_kind", "attack"))
			var attack_callouts := {"lunge": "突进!", "faceShock": "突脸!", "guardBreak": "破防!", "slam": "砸地!", "beam": "激光!"}
			var is_ranged_attack := attack_kind == "ranged"
			if is_ranged_attack:
				_queue_enemy_attack_facing(tween, enemy_node, event)
			tween.tween_callback(_play_enemy_state.bind(actor_id, "attack", str(attack_callouts.get(attack_kind, "袭击!"))))
			if is_ranged_attack:
				# 远程攻击先抛出石块，石块落地后再播放玩家受击反馈。
				tween.tween_callback(_launch_enemy_projectile.bind(enemy_node, event))
				tween.tween_method(_set_enemy_projectile_arc, 0.0, 1.0, ENEMY_PROJECTILE_DURATION * animation_duration_scale)
				tween.tween_callback(_finish_enemy_projectile)
			if event.get("target", INVALID_CELL) == combat.player_pos and int(event.get("damage", 0)) > 0:
				tween.tween_callback(_play_actor_state.bind("Player", "hurt", "受击!"))
			tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(enemy_node, "scale", Vector3(1.22, 0.82, 1.22), ENEMY_ATTACK_DURATION * 0.45 * animation_duration_scale)
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(enemy_node, "scale", Vector3.ONE, ENEMY_ATTACK_DURATION * 0.55 * animation_duration_scale)
			tween.tween_interval(ENEMY_EVENT_PAUSE_DURATION * animation_duration_scale)
		elif kind == "face_shock":
			if enemy_node == null:
				continue
			tween.tween_callback(_play_enemy_state.bind(actor_id, "attack", "突脸!"))
			if int(event.get("damage", 0)) > 0:
				tween.tween_callback(_play_actor_state.bind("Player", "hurt", "惊吓!"))
			tween.tween_property(enemy_node, "scale", Vector3(1.18, 1.18, 1.18), ENEMY_ATTACK_DURATION * 0.45 * animation_duration_scale)
			tween.tween_property(enemy_node, "scale", Vector3.ONE, ENEMY_ATTACK_DURATION * 0.55 * animation_duration_scale)
			tween.tween_interval(ENEMY_EVENT_PAUSE_DURATION * animation_duration_scale)
		elif kind == "beam_charge":
			if enemy_node == null:
				continue
			_queue_enemy_attack_facing(tween, enemy_node, event)
			tween.tween_callback(_play_enemy_state.bind(actor_id, "ready", "蓄力!"))
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(enemy_node, "scale", Vector3(0.86, 1.28, 0.86), 0.24 * animation_duration_scale)
			tween.tween_property(enemy_node, "scale", Vector3.ONE, 0.18 * animation_duration_scale)
			tween.tween_interval(ENEMY_EVENT_PAUSE_DURATION * animation_duration_scale)
		elif kind == "beam_fire":
			if enemy_node == null:
				continue
			_queue_enemy_attack_facing(tween, enemy_node, event)
			tween.tween_callback(_play_enemy_state.bind(actor_id, "attack", "激光!"))
			if int(event.get("damage", 0)) > 0:
				tween.tween_callback(_play_actor_state.bind("Player", "hurt", "命中!"))
			tween.tween_property(enemy_node, "scale", Vector3(1.30, 0.76, 1.30), ENEMY_ATTACK_DURATION * 0.45 * animation_duration_scale)
			tween.tween_property(enemy_node, "scale", Vector3.ONE, ENEMY_ATTACK_DURATION * 0.55 * animation_duration_scale)
			tween.tween_interval(ENEMY_EVENT_PAUSE_DURATION * animation_duration_scale)
		else:
			tween.tween_interval(ENEMY_EVENT_PAUSE_DURATION * animation_duration_scale)
	await tween.finished
	if active_motion_tween != tween:
		return
	_complete_dynamic_effect()
	_after_combat_action(false)


func _position_enemy_turn_starts(turn_events: Array[Dictionary]) -> void:
	var positioned_actor_ids: Dictionary = {}
	for event: Dictionary in turn_events:
		if str(event.get("kind", "")) != "move":
			continue
		var actor_id := str(event.get("actor_id", ""))
		if actor_id.is_empty() or positioned_actor_ids.has(actor_id):
			continue
		positioned_actor_ids[actor_id] = true
		var move_node := _enemy_node_for_id(actor_id)
		if move_node != null:
			# 同一敌人一回合可能走多格；首帧只能采用第一段移动的起点。
			move_node.position = _battle_pawn_world(event.get("from", combat.enemy_pos), false, actor_id)


func _set_enemy_step_motion(weight: float, enemy_node: Node3D, start_position: Vector3, target_position: Vector3) -> void:
	_set_battle_actor_step_motion(weight, enemy_node, start_position, target_position)


func _battle_enemy_projectile_position(weight: float, start_position: Vector3, target_position: Vector3) -> Vector3:
	var smooth_weight := clampf(weight, 0.0, 1.0)
	var position := start_position.lerp(target_position, smooth_weight)
	position.y += sin(PI * smooth_weight) * maxf(0.72, start_position.distance_to(target_position) * 0.18)
	return position


func _launch_enemy_projectile(enemy_node: Node3D, event: Dictionary) -> void:
	_finish_enemy_projectile()
	if battle_actor_root == null or enemy_node == null:
		return
	var target_cell: Vector2i = event.get("target", combat.player_pos)
	if target_cell == INVALID_CELL:
		return
	var player_node := battle_actor_root.get_node_or_null("Player") as Node3D
	battle_projectile_start = enemy_node.position + Vector3(0.0, 0.84, 0.0)
	battle_projectile_target = _battle_pawn_world(target_cell, true) + Vector3(0.0, 0.36, 0.0)
	if player_node != null:
		battle_projectile_target = player_node.position + Vector3(0.0, 0.36, 0.0)
	var projectile := MeshInstance3D.new()
	projectile.name = "EnemyProjectile_Rock"
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.20
	mesh.radial_segments = 8
	mesh.rings = 4
	projectile.mesh = mesh
	projectile.position = battle_projectile_start
	projectile.rotation = Vector3(-0.22, 0.35, 0.18)
	projectile.material_override = _material(Color("66707a"), false, 0.05)
	battle_actor_root.add_child(projectile)
	battle_projectile_nodes.append(projectile)
	battle_active_projectile = projectile


func _set_enemy_projectile_arc(weight: float) -> void:
	if battle_active_projectile == null or not is_instance_valid(battle_active_projectile):
		return
	battle_active_projectile.position = _battle_enemy_projectile_position(weight, battle_projectile_start, battle_projectile_target)
	var smooth_weight := clampf(weight, 0.0, 1.0)
	battle_active_projectile.rotation = Vector3(-0.22 + smooth_weight * 3.2, 0.35 + smooth_weight * 5.8, 0.18 + smooth_weight * 2.4)


func _finish_enemy_projectile() -> void:
	if battle_active_projectile != null and is_instance_valid(battle_active_projectile):
		battle_active_projectile.queue_free()
	battle_active_projectile = null


func _clear_battle_projectiles() -> void:
	_finish_enemy_projectile()
	for projectile in battle_projectile_nodes:
		if projectile != null and is_instance_valid(projectile):
			projectile.queue_free()
	battle_projectile_nodes.clear()


func _set_battle_actor_step_motion(weight: float, actor_node: Node3D, start_position: Vector3, target_position: Vector3) -> void:
	if not is_instance_valid(actor_node):
		return
	var smooth_weight := weight * weight * (3.0 - 2.0 * weight)
	# The board owns all world translation; the FBX clip supplies limb motion only.
	actor_node.position = start_position.lerp(target_position, smooth_weight)


func _battle_move_facing_yaw(source: Vector2i, target: Vector2i) -> float:
	return atan2(float(target.x - source.x), float(target.y - source.y))


func _battle_enemy_attack_facing_yaw(enemy_node: Node3D, event: Dictionary) -> float:
	var enemy_state = _enemy_state_for_node(enemy_node)
	var attack_origin: Vector2i = enemy_state.pos if enemy_state != null else combat.enemy_pos
	var attack_target: Vector2i = event.get("target", combat.player_pos)
	if attack_origin == attack_target:
		return enemy_node.rotation.y
	return _battle_move_facing_yaw(attack_origin, attack_target)


func _queue_enemy_attack_facing(tween: Tween, enemy_node: Node3D, event: Dictionary) -> void:
	var attack_facing_yaw := _battle_enemy_attack_facing_yaw(enemy_node, event)
	battle_enemy_facing_yaw = attack_facing_yaw
	# 远程攻击先用短转身对准玩家，再进入攻击姿态，避免敌人朝侧面开火。
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(enemy_node, "rotation:y", attack_facing_yaw, ENEMY_TURN_DURATION * animation_duration_scale)


func _handle_battle_world_click(screen_pos: Vector2) -> void:
	if combat == null or combat.outcome != "":
		return
	var target := battle_cell_from_viewport(screen_pos)
	if target == INVALID_CELL:
		return
	handle_battle_cell(target)


func move_player_direction(direction: Vector2i) -> bool:
	if animation_busy or phase != "combat" or combat == null or combat.outcome != "" or selected_card >= 0:
		return false
	if direction.x != 0 and direction.y != 0:
		return false
	var target: Vector2i = combat.player_pos + direction
	return move_player_to(target)


func handle_battle_cell(target: Vector2i) -> void:
	if animation_busy or combat == null or combat.outcome != "" or target == INVALID_CELL:
		return
	if selected_card < 0:
		var clicked_enemy: Variant = combat.enemy_at(target)
		if clicked_enemy != null:
			select_battle_enemy(str(clicked_enemy.get("id")))
			return
	if selected_card < 0 and combat.player_on_portal() and target == combat.player_portal_destination():
		use_player_portal()
		return
	if selected_card >= 0:
		var card_name := "所选卡牌"
		if selected_card < combat.hand.size():
			card_name = str(combat.cards.get(combat.hand[selected_card], {}).get("name", combat.hand[selected_card]))
		var enemy_hp_before: int = combat.enemy_hp
		var clicked_enemy: Variant = combat.enemy_at(target)
		var clicked_enemy_id: String = ""
		if clicked_enemy != null:
			clicked_enemy_id = str(clicked_enemy.get("id"))
		if combat.play_card(selected_card, target, clicked_enemy_id):
			selected_card = -1
			status_message = "%s已生效。继续移动、出牌，或结束回合让敌人行动。" % card_name
			_after_combat_action()
			_play_actor_state("Player", "attack", card_name)
			for raw_event in combat.last_card_events:
				var damage_event: Dictionary = raw_event
				if int(damage_event.get("damage", 0)) > 0 and str(damage_event.get("kind", "")) == "enemy_damaged":
					var damage_enemy_id := str(damage_event.get("target_enemy_id", ""))
					if not damage_enemy_id.is_empty():
						_play_enemy_state(damage_enemy_id, "hurt", "-%d" % int(damage_event["damage"]))
						_show_enemy_damage_feedback(damage_enemy_id, int(damage_event["damage"]))
			if combat.enemy_hp < enemy_hp_before and combat.last_card_events.is_empty():
				var damage_dealt: int = enemy_hp_before - combat.enemy_hp
				if not combat.enemy_order.is_empty():
					_play_enemy_state(combat.enemy_order[0], "hurt", "-%d" % damage_dealt)
					_show_enemy_damage_feedback(combat.enemy_order[0], damage_dealt)
			return
		else:
			selected_card = -1
			status_message = "%s不能放在这里，已自动取消选牌；现在可点击绿色格移动。" % card_name
	else:
		if move_player_to(target):
			return
		status_message = "这个格子无法到达，或当前行动力不足。"
		_refresh_hud()


func select_battle_enemy(enemy_id: String) -> void:
	if combat == null:
		return
	var state = combat.enemy_by_id(enemy_id)
	if state == null or not state.revealed:
		return
	battle_focused_enemy_id = enemy_id
	if test_combat_active:
		test_focused_enemy_id = enemy_id
	battle_world_renderer.refresh_battle_state(false, false)
	_refresh_hud()


func move_player_to(target: Vector2i) -> bool:
	if animation_busy or phase != "combat" or combat == null or combat.outcome != "" or selected_card >= 0:
		return false
	var path: Array = combat.player_path_to(target)
	if path.size() < 2:
		return false
	var path_cost: int = combat.player_path_cost(path)
	if path_cost > combat.energy:
		status_message = "到达那里需要 %d AP，但本回合只剩 %d AP。" % [path_cost, combat.energy]
		_refresh_hud()
		return false
	status_message = "莉莉沿路径移动 %d 格。" % (path.size() - 1)
	battle_camera_following = true
	if animation_duration_scale <= 0.0:
		for index in range(1, path.size()):
			if not combat.move_player(path[index]):
				return false
		_after_combat_action(true)
		return true
	animation_busy = true
	active_animation_kind = "player_path"
	_animate_player_path(path, 1)
	return true


func _animate_player_path(path: Array[Vector2i], index: int) -> void:
	if index >= path.size():
		_complete_dynamic_effect()
		_after_combat_action()
		return
	var source: Vector2i = path[index - 1]
	var target: Vector2i = path[index]
	if not combat.move_player(target):
		_complete_dynamic_effect()
		_refresh_hud()
		return
	# 移动过程中只移动演员节点；棋盘、家具和房间外壳保持复用。
	# 路径结束后由 _after_combat_action() 统一刷新一次敌人意图和状态。
	var player_node := battle_actor_root.get_node_or_null("Player") as Node3D
	var duration := UNITY_ACTOR_STEP_DURATION * animation_duration_scale
	if player_node == null or duration <= 0.0:
		_animate_player_path(path, index + 1)
		return
	_play_actor_state("Player", "move")
	var source_height := float(combat.heights.get(source, 0)) * 0.64
	var target_height := float(combat.heights.get(target, 0)) * 0.64
	var start_position := _battle_world(source) + Vector3.UP * (source_height - target_height)
	var target_position := _battle_pawn_world(target, true)
	player_node.position = start_position
	var tween := create_tween()
	active_motion_tween = tween
	var facing_yaw := _battle_move_facing_yaw(source, target)
	battle_player_facing_yaw = facing_yaw
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player_node, "rotation:y", facing_yaw, UNITY_ACTOR_TURN_DURATION * animation_duration_scale)
	tween.tween_method(_set_battle_actor_step_motion.bind(player_node, start_position, target_position), 0.0, 1.0, duration)
	tween.finished.connect(func() -> void:
		if active_motion_tween != tween:
			return
		if is_instance_valid(player_node):
			player_node.position = target_position
		_animate_player_path(path, index + 1)
	)


func _animate_player_battle_step(source: Vector2i, target: Vector2i) -> void:
	battle_camera_following = true
	_play_actor_state("Player", "move")
	var player_node := battle_actor_root.get_node_or_null("Player") as Node3D
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
	var facing_yaw := _battle_move_facing_yaw(source, target)
	battle_player_facing_yaw = facing_yaw
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player_node, "rotation:y", facing_yaw, UNITY_ACTOR_TURN_DURATION * animation_duration_scale)
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
	_after_combat_action(animation_duration_scale <= 0.0)
	_animate_player_portal(source, target)


func _animate_player_portal(source: Vector2i, target: Vector2i) -> void:
	var player_node := battle_actor_root.get_node_or_null("Player") as Node3D
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
	update_battle_hover()


func clear_battle_hover() -> void:
	if animation_busy:
		return
	if hovered_battle_cell == INVALID_CELL:
		return
	hovered_battle_cell = INVALID_CELL
	if phase == "combat":
		update_battle_hover()


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
	# Reserve only the actual framing offset. The previous doubled-radius plus
	# ten-unit allowance left a themed arena occupying barely half the viewport.
	horizontal_radius += BATTLE_CAMERA_FRAME_OFFSET * (horizontal_radius + 4.0)
	# The invariant fit already encloses every rotated cell. Keep only a compact
	# presentation margin so the miniature, rather than empty backdrop, is the
	# visual subject of combat.
	battle_camera_fit_size = _rotation_invariant_fit_size(horizontal_radius, max_y, battle_camera_pitch, 0.8, 6.0) * 0.90
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
	var next_ratio := clampf(battle_camera_zoom_ratio * zoom_factor, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	battle_camera_zoom_ratio = next_ratio
	# 先用目标尺寸计算鼠标锚点，但不立即改变实际尺寸；实际缩放交给每帧平滑追赶。
	var current_size := camera.size
	camera.size = battle_camera_fit_size * next_ratio
	var after: Variant = _screen_to_plane(view_pos, 0.0)
	camera.size = current_size
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


func _after_combat_action(sync_actor_positions: bool = false) -> void:
	player_hp = combat.player_hp
	if test_combat_active and test_session.active and test_enemy_phase_pending:
		test_session.record_enemy_phase(test_last_events, combat)
		test_last_events.clear()
		test_enemy_phase_pending = false
	# 杀戮尖塔式回合：敌方动画播完后才给玩家发新牌
	if combat != null and combat.pending_player_turn and combat.outcome == "":
		combat.start_player_turn()
		battle_turn_actor_id = "player"
		battle_turn_events.clear()
	# 移动、出牌和敌方事件的静态棋盘都已存在；这里只更新危险标记、陷阱
	# 与演员编队，避免玩家落到新格子的收尾帧同步重建整套房间资产。
	battle_world_renderer.refresh_battle_state(true, sync_actor_positions)
	if combat.outcome != "":
		status_message = "战斗胜利。" if combat.outcome == "victory" else "本集信号中断。"
	_refresh_hud()


func return_from_combat() -> void:
	if animation_busy or phase != "combat" or combat == null or combat.outcome == "":
		return
	if combat.outcome == "victory":
		house_camera_closeup = true
		house_camera_following = true
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
	run_save_repository.write(payload)


func _clear_run_save() -> void:
	run_save_repository.clear()


func _array_to_pos(raw_value: Variant) -> Vector2i:
	if raw_value is Array and raw_value.size() >= 2:
		return Vector2i(int(raw_value[0]), int(raw_value[1]))
	return Vector2i.ZERO


func build_house_world() -> void:
	house_world_renderer.build_house_world()


func _add_kenney_formal_composer() -> void:
	house_world_renderer._add_kenney_formal_composer()


func _formal_instance_records_in_connection_order() -> Array[Dictionary]:
	return house_world_renderer._formal_instance_records_in_connection_order()


func _formal_connection_edge_keys() -> Dictionary:
	return house_world_renderer._formal_connection_edge_keys()


func _formal_outer_open_edge_keys() -> Dictionary:
	return house_world_renderer._formal_outer_open_edge_keys()


func _grid_edge_key(a: Vector2i, b: Vector2i) -> String:
	return house_world_renderer._grid_edge_key(a, b)


func _add_room_mesh(pos: Vector2i, room: Dictionary) -> void:
	house_world_renderer._add_room_mesh(pos, room)


func _populate_room_visual(node: Node3D, pos: Vector2i, room: Dictionary) -> void:
	house_world_renderer._populate_room_visual(node, pos, room)


func _add_room_edge(parent: Node3D, side: int, has_door: bool, color: Color) -> void:
	house_world_renderer._add_room_edge(parent, side, has_door, color)


func _add_room_bridges() -> void:
	house_world_renderer._add_room_bridges()


func _add_frontier_mesh(pos: Vector2i, selected: bool) -> void:
	house_world_renderer._add_frontier_mesh(pos, selected)


func _add_build_preview() -> void:
	house_world_renderer._add_build_preview()


func _add_kenney_preview_cell(parent: Node3D, offset: Vector2i) -> void:
	house_world_renderer._add_kenney_preview_cell(parent, offset)


func _update_build_preview_validity(preview: Node3D) -> void:
	house_world_renderer._update_build_preview_validity(preview)


func _add_house_player() -> void:
	house_world_renderer._add_house_player()


func room_interaction_slots(target: Vector2i) -> Array[Dictionary]:
	return house_world_renderer.room_interaction_slots(target)


func claim_room_interaction_slot(actor_id: String, target: Vector2i, preferred_kind: String = "") -> Dictionary:
	return house_world_renderer.claim_room_interaction_slot(actor_id, target, preferred_kind)


func release_room_interaction_slot(actor_id: String) -> void:
	house_world_renderer.release_room_interaction_slot(actor_id)


func actor_interaction_state(actor_id: String) -> Dictionary:
	return house_world_renderer.actor_interaction_state(actor_id)


func _house_interaction_target_position(actor_id: String, target: Vector2i) -> Vector3:
	return house_world_renderer._house_interaction_target_position(actor_id, target)


func _interaction_slot_house_position(slot: Dictionary, field: String) -> Vector3:
	return house_world_renderer._interaction_slot_house_position(slot, field)


func _add_move_hover_mesh(pos: Vector2i) -> void:
	house_world_renderer._add_move_hover_mesh(pos)


func _apply_current_room_cutaway() -> void:
	house_world_renderer._apply_current_room_cutaway()


func pcg_cutaway_debug_text() -> String:
	return house_world_renderer.pcg_cutaway_debug_text()


func pcg_room_state_debug_text() -> String:
	return house_world_renderer.pcg_room_state_debug_text()


func large_room_mix_debug_text() -> String:
	return house_world_renderer.large_room_mix_debug_text()


func frontier_markers_are_compact() -> bool:
	return house_world_renderer.frontier_markers_are_compact()

	if combat == null or battle_shell_edge_records.size() != _battle_footprint_boundary_edges().size():
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
	battle_board_root.add_child(sprite)


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
	var points := _house_camera_layout_points()
	var center := Vector3.ZERO
	for point in points:
		center += point
	if not points.is_empty():
		center /= float(points.size())
	var horizontal_radius := 0.0
	for point in points:
		horizontal_radius = maxf(horizontal_radius, Vector2(point.x - center.x, point.z - center.z).length())
	horizontal_radius += HOUSE_CELL * VISUAL_CELL_SCALE * 0.85
	house_camera_fit_size = minf(28.0 * VISUAL_CELL_SCALE, _rotation_invariant_fit_size(horizontal_radius, HOUSE_CELL * VISUAL_CELL_SCALE * 1.65, house_camera_pitch, 0.8 * VISUAL_CELL_SCALE, 7.6 * VISUAL_CELL_SCALE))
	house_camera_size_target = _house_camera_size_target()
	if house_camera_size_current <= 0.0:
		house_camera_size_current = house_camera_size_target
	# 跟随/回位/用户操作期间保持镜头对准点（玩家偏上构图），只有空闲态才重置为布局中心
	if not house_camera_user_adjusted and not house_camera_following and not house_camera_returning and not house_camera_user_hold:
		house_camera_target = center
	_apply_house_camera()


func toggle_house_camera_closeup() -> bool:
	if phase not in ["explore", "build", "room_ready"] or camera == null:
		return false
	house_camera_closeup = not house_camera_closeup
	house_camera_following = true
	house_camera_user_hold = false
	house_camera_user_adjusted = false
	_cancel_house_camera_return()
	house_camera_size_target = _house_camera_size_target()
	_apply_house_camera()
	return house_camera_closeup


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
	var base_size := HOUSE_CAMERA_CLOSEUP_SIZE if house_camera_closeup else house_camera_fit_size
	var current_target := _house_camera_size_target()
	var next_size := clampf(current_target * zoom_factor, base_size * CAMERA_ZOOM_MIN, base_size * CAMERA_ZOOM_MAX)
	house_camera_size_target = next_size
	house_camera_zoom_ratio = next_size / maxf(0.001, base_size)
	house_camera_user_adjusted = true
	# 只临时使用目标尺寸计算鼠标锚点，实际镜头尺寸由每帧平滑逻辑推进。
	var current_actual_size := camera.size
	camera.size = next_size * lerpf(CAMERA_INTRO_FAR_SCALE, 1.0, house_camera_intro_weight)
	var after: Variant = _screen_to_plane(view_pos, 0.0)
	camera.size = current_actual_size
	if before is Vector3 and after is Vector3:
		var anchor_shift: Vector3 = before - after
		house_camera_target += Vector3(anchor_shift.x, 0.0, anchor_shift.z)
		_clamp_house_camera_target()
		_apply_house_camera()


func reset_house_camera() -> void:
	house_camera_following = false
	house_camera_closeup = false
	house_camera_user_hold = false
	house_camera_return_delay = 0.0
	house_camera_returning = false
	if house_camera_return_tween != null and house_camera_return_tween.is_valid():
		house_camera_return_tween.kill()
		house_camera_return_tween = null
	house_camera_zoom_ratio = 1.0
	house_camera_user_adjusted = false
	house_camera_size_current = 0.0
	house_camera_size_target = 0.0
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
	var limit := maxf(HOUSE_CELL * VISUAL_CELL_SCALE * 6.0, house_camera_fit_size * 1.5)
	house_camera_target.x = clampf(house_camera_target.x, -limit, limit)
	house_camera_target.z = clampf(house_camera_target.z, -limit, limit)


func _apply_house_camera() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var horizontal := cos(house_camera_pitch) * house_camera_distance
	var direction := Vector3(sin(house_camera_yaw) * horizontal, sin(house_camera_pitch) * house_camera_distance, cos(house_camera_yaw) * horizontal)
	camera.position = house_camera_target + direction
	camera.look_at(house_camera_target + Vector3(0, 0.2, 0), Vector3.UP)
	if house_camera_size_current <= 0.0:
		house_camera_size_current = _house_camera_size_target()
	camera.size = house_camera_size_current * lerpf(CAMERA_INTRO_FAR_SCALE, 1.0, house_camera_intro_weight)
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


func _house_visual_world(pos: Vector2i) -> Vector3:
	return _house_world(pos) * VISUAL_CELL_SCALE


func _house_logical_world_from_visual(world: Vector3) -> Vector3:
	return world / VISUAL_CELL_SCALE


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


func _resolve_battle_entry_side(room: Dictionary) -> int:
	# 战斗房间的门位必须来自真实入场方向或房间定义，不能根据角色当前
	# 位置猜最近的一面墙。测试场没有大地图入口时，再使用出生格所在边。
	var arena: Dictionary = room.get("arena", {}) as Dictionary
	var explicit_side := _room_side_from_value(arena.get("entry_side", room.get("entry_side", -1)))
	if explicit_side >= 0:
		return explicit_side
	var linked_side := _room_side_from_delta(previous_room_pos - current_room_pos)
	if linked_side >= 0 and room_rules.placed.has(current_room_pos) and room_rules.cell_has_door(current_room_pos, linked_side):
		return linked_side
	var spawn_sides := _battle_spawn_boundary_sides()
	var doors: Array = room.get("doors", []) as Array
	for side: int in spawn_sides:
		if side < doors.size() and bool(doors[side]):
			return side
	if not spawn_sides.is_empty():
		return spawn_sides[0]
	for side in range(mini(4, doors.size())):
		if bool(doors[side]):
			return side
	return -1


func _room_side_from_value(value: Variant) -> int:
	if value is int or value is float:
		var side := int(value)
		return side if side >= 0 and side < 4 else -1
	var label := str(value).to_lower()
	match label:
		"up", "north", "n":
			return 0
		"right", "east", "e":
			return 1
		"down", "south", "s":
			return 2
		"left", "west", "w":
			return 3
	return -1


func _room_side_from_delta(delta: Vector2i) -> int:
	if delta == Vector2i.UP:
		return 0
	if delta == Vector2i.RIGHT:
		return 1
	if delta == Vector2i.DOWN:
		return 2
	if delta == Vector2i.LEFT:
		return 3
	return -1


func _battle_spawn_boundary_sides() -> Array[int]:
	var result: Array[int] = []
	if combat == null:
		return result
	var spawn: Vector2i = combat.player_pos
	if spawn.y == 0:
		result.append(0)
	if spawn.x == combat.cols - 1:
		result.append(1)
	if spawn.y == combat.rows - 1:
		result.append(2)
	if spawn.x == 0:
		result.append(3)
	return result


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
	_clear_battle_projectiles()
	active_motion_tween = null
	animation_busy = false
	active_animation_kind = ""


func _complete_dynamic_effect() -> void:
	_clear_battle_projectiles()
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
	label.font = APP_FONT
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
func _ensure_battle_layers() -> void:
	battle_world_renderer._ensure_battle_layers()

func build_battle_world() -> void:
	battle_world_renderer.build_battle_world()

func refresh_battle_board() -> void:
	battle_world_renderer.refresh_battle_board()

func refresh_battle_state(sync_actors := true, sync_actor_positions := false) -> void:
	battle_world_renderer.refresh_battle_state(sync_actors, sync_actor_positions)

func update_battle_overlays() -> void:
	battle_world_renderer.update_battle_overlays()

func update_battle_hover() -> void:
	battle_world_renderer.update_battle_hover()

func _build_battle_board() -> void:
	battle_world_renderer._build_battle_board()

func _sync_battle_actors() -> void:
	battle_world_renderer._sync_battle_actors()

func _is_valid_battle_target(pos: Vector2i) -> bool:
	return battle_world_renderer._is_valid_battle_target(pos)

func _add_corner_marks(parent: Node3D, prefix: String, color: Color, y: float) -> void:
	battle_world_renderer._add_corner_marks(parent, prefix, color, y)

func _add_battle_floor_model(parent: Node3D, pos: Vector2i, footprint_active: bool) -> void:
	battle_world_renderer._add_battle_floor_model(parent, pos, footprint_active)

func _add_battle_timber_tiles(parent: Node3D, pos: Vector2i, floor_path: String, floor_y: float, root_name: String, meta_key: String = "") -> Node3D:
	return battle_world_renderer._add_battle_timber_tiles(parent, pos, floor_path, floor_y, root_name, meta_key)

func _apply_battle_footprint_to_combat() -> void:
	battle_world_renderer._apply_battle_footprint_to_combat()

func _nearest_active_battle_cell(origin: Vector2i, forbidden: Vector2i = INVALID_CELL, reserved: Dictionary = {}) -> Vector2i:
	return battle_world_renderer._nearest_active_battle_cell(origin, forbidden, reserved)

func _prepare_battle_prop_assignments() -> void:
	battle_world_renderer._prepare_battle_prop_assignments()

func _battle_cell_normalized(pos: Vector2i) -> Vector2:
	return battle_world_renderer._battle_cell_normalized(pos)

func _align_battle_terrain_to_room_context() -> void:
	battle_world_renderer._align_battle_terrain_to_room_context()

func _nearest_battle_layout_cell(preferred: Vector2i, used_cells: Dictionary) -> Vector2i:
	return battle_world_renderer._nearest_battle_layout_cell(preferred, used_cells)

func _battle_cell_in_room_footprint(pos: Vector2i) -> bool:
	return battle_world_renderer._battle_cell_in_room_footprint(pos)

func _add_battle_height_asset(parent: Node3D, pos: Vector2i, height: int, logical_top_y: float) -> void:
	battle_world_renderer._add_battle_height_asset(parent, pos, height, logical_top_y)

func _add_battle_raised_deck(parent: Node3D, pos: Vector2i, logical_top_y: float) -> void:
	battle_world_renderer._add_battle_raised_deck(parent, pos, logical_top_y)

func _add_battle_walkable_top_marker(parent: Node3D, logical_top_y: float) -> void:
	battle_world_renderer._add_battle_walkable_top_marker(parent, logical_top_y)

func _add_battle_blocker_asset(parent: Node3D, pos: Vector2i, platform_height: float) -> void:
	battle_world_renderer._add_battle_blocker_asset(parent, pos, platform_height)

func _battle_context_prop_for_cell(pos: Vector2i, height: int) -> Dictionary:
	return battle_world_renderer._battle_context_prop_for_cell(pos, height)

func _battle_height_asset_options(height: int) -> Array:
	return battle_world_renderer._battle_height_asset_options(height)

func _node_visual_aabb_in_parent(parent: Node3D, model: Node3D) -> AABB:
	return battle_world_renderer._node_visual_aabb_in_parent(parent, model)

func _apply_battle_miniature_finish(model: Node3D, asset_id: String) -> void:
	battle_world_renderer._apply_battle_miniature_finish(model, asset_id)

func _add_portal_marker(parent: Node3D, pos: Vector2i, y: float) -> void:
	battle_world_renderer._add_portal_marker(parent, pos, y)

func _portal_endpoint_label(pos: Vector2i) -> String:
	return battle_world_renderer._portal_endpoint_label(pos)

func _add_battle_pawn(pos: Vector2i, is_player: bool, revealed: bool, enemy_id: String = "") -> void:
	battle_world_renderer._add_battle_pawn(pos, is_player, revealed, enemy_id)

func _battle_intent_color(intent_type: String) -> Color:
	return battle_world_renderer._battle_intent_color(intent_type)

func _battle_intent_glyph(intent_type: String) -> String:
	return battle_world_renderer._battle_intent_glyph(intent_type)

func _battle_actor_presentation(actor_key: String, enemy_id: String = "") -> Dictionary:
	return battle_world_renderer._battle_actor_presentation(actor_key, enemy_id)

func _battle_pawn_world(pos: Vector2i, is_player: bool, enemy_id: String = "") -> Vector3:
	return battle_world_renderer._battle_pawn_world(pos, is_player, enemy_id)

func _enemy_node_name(enemy_id: String) -> String:
	return battle_world_renderer._enemy_node_name(enemy_id)

func _enemy_node_for_id(enemy_id: String) -> Node3D:
	return battle_world_renderer._enemy_node_for_id(enemy_id)

func _enemy_state_for_node(node: Node3D):
	return battle_world_renderer._enemy_state_for_node(node)

func _play_enemy_state(enemy_id: String, state: String, callout: String = "") -> void:
	battle_world_renderer._play_enemy_state(enemy_id, state, callout)

func _show_enemy_damage_feedback(enemy_id: String, damage: int) -> void:
	battle_world_renderer._show_enemy_damage_feedback(enemy_id, damage)

func _add_decoy_pawn(pos: Vector2i) -> void:
	battle_world_renderer._add_decoy_pawn(pos)

func _play_actor_state(actor_node_name: String, state: String, callout: String = "") -> void:
	battle_world_renderer._play_actor_state(actor_node_name, state, callout)

func _show_actor_damage_feedback(actor_node_name: String, damage: int) -> void:
	battle_world_renderer._show_actor_damage_feedback(actor_node_name, damage)

func _on_presenter_state_changed(_state: String) -> void:
	battle_world_renderer._on_presenter_state_changed(_state)

func _add_battle_stage_decor() -> void:
	battle_world_renderer._add_battle_stage_decor()

func _battle_shell_edge_center(edge: Dictionary) -> Vector3:
	return battle_world_renderer._battle_shell_edge_center(edge)

func _add_battle_room_shell() -> void:
	battle_world_renderer._add_battle_room_shell()

func _battle_footprint_boundary_edges() -> Array[Dictionary]:
	return battle_world_renderer._battle_footprint_boundary_edges()

func _battle_room_entrance_edge(boundary_edges: Array[Dictionary]) -> Dictionary:
	return battle_world_renderer._battle_room_entrance_edge(boundary_edges)

func _add_battle_shell_edge(shell: Node3D, edge: Dictionary, edge_index: int, is_entrance: bool) -> void:
	battle_world_renderer._add_battle_shell_edge(shell, edge, edge_index, is_entrance)

func _battle_shell_kind_for_segment(index: int) -> String:
	return battle_world_renderer._battle_shell_kind_for_segment(index)

func _add_battle_shell_junctions(shell: Node3D, boundary_edges: Array[Dictionary]) -> void:
	battle_world_renderer._add_battle_shell_junctions(shell, boundary_edges)

func _add_battle_shell_sill(parent: Node3D, is_entrance: bool) -> void:
	battle_world_renderer._add_battle_shell_sill(parent, is_entrance)

func _battle_shell_direction_yaw(direction: Vector2i) -> float:
	return battle_world_renderer._battle_shell_direction_yaw(direction)

func _add_battle_boundary_outline(shell: Node3D, boundary_edges: Array[Dictionary]) -> void:
	battle_world_renderer._add_battle_boundary_outline(shell, boundary_edges)

func _apply_battle_room_cutaway() -> void:
	battle_world_renderer._apply_battle_room_cutaway()

func battle_room_shell_debug_state() -> Dictionary:
	return battle_world_renderer.battle_room_shell_debug_state()

func battle_room_shell_is_consistent() -> bool:
	return battle_world_renderer.battle_room_shell_is_consistent()
