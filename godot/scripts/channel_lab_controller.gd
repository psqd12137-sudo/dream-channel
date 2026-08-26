class_name ChannelLabController
extends RefCounted

## Optional combat test and interactive lab controller.
## The host owns the run; this module owns only lab/test flows.

const DIORAMA_ART_LAB = preload("res://scenes/diorama_art_lab.tscn")
const PCG_DIORAMA_STITCH_LAB = preload("res://scenes/pcg_diorama_stitch_lab.tscn")
const PCG_HAND_LAYOUT_LAB = preload("res://scenes/pcg_hand_layout_lab.tscn")
const ASSET_EDITOR_SCENE_PATH := "res://scenes/asset_editor_3d.tscn"
const COL_INK := Color("161b24")
const COL_PAPER := Color("f7e8c5")
const COL_TEAL := Color("23aa9b")
const COL_TEAL_DARK := Color("164f53")
const COL_GOLD := Color("f2a51e")
const COL_RED := Color("d9574f")
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

var host = null

var content:
	get: return host.content
	set(value): host.content = value
var test_catalog:
	get: return host.test_catalog
	set(value): host.test_catalog = value
var test_session:
	get: return host.test_session
	set(value): host.test_session = value
var run_seed:
	get: return host.run_seed
	set(value): host.run_seed = value
var player_hp:
	get: return host.player_hp
	set(value): host.player_hp = value
var player_max_hp:
	get: return host.player_max_hp
	set(value): host.player_max_hp = value
var player_speed:
	get: return host.player_speed
	set(value): host.player_speed = value
var run_deck: Array[String]:
	get: return host.run_deck
	set(value): host.run_deck = value
var test_saved_state:
	get: return host.test_saved_state
	set(value): host.test_saved_state = value
var test_focused_enemy_id:
	get: return host.test_focused_enemy_id
	set(value): host.test_focused_enemy_id = value
var test_combat_active:
	get: return host.test_combat_active
	set(value): host.test_combat_active = value
var combat_presentation_lab:
	get: return host.combat_presentation_lab
	set(value): host.combat_presentation_lab = value
var phase:
	get: return host.phase
	set(value): host.phase = value
var status_message:
	get: return host.status_message
	set(value): host.status_message = value
var animation_busy:
	get: return host.animation_busy
	set(value): host.animation_busy = value
var test_mode_selected_id:
	get: return host.test_mode_selected_id
	set(value): host.test_mode_selected_id = value
var battle_actor_root:
	get: return host.battle_actor_root
	set(value): host.battle_actor_root = value
var lab_move_axis:
	get: return host.lab_move_axis
	set(value): host.lab_move_axis = value
var active_motion_tween:
	get: return host.active_motion_tween
	set(value): host.active_motion_tween = value
var active_animation_kind:
	get: return host.active_animation_kind
	set(value): host.active_animation_kind = value
var enemy_nodes:
	get: return host.enemy_nodes
	set(value): host.enemy_nodes = value
var combat:
	get: return host.combat
	set(value): host.combat = value
var test_last_events: Array[Dictionary]:
	get: return host.test_last_events
	set(value): host.test_last_events = value
var test_enemy_phase_pending:
	get: return host.test_enemy_phase_pending
	set(value): host.test_enemy_phase_pending = value
var home_tests_open:
	get: return host.home_tests_open
	set(value): host.home_tests_open = value
var world_container:
	get: return host.world_container
	set(value): host.world_container = value
var house_root:
	get: return host.house_root
	set(value): host.house_root = value
var battle_root:
	get: return host.battle_root
	set(value): host.battle_root = value
var hud:
	get: return host.hud
	set(value): host.hud = value
var camera:
	get: return host.camera
	set(value): host.camera = value
var lab_root:
	get: return host.lab_root
	set(value): host.lab_root = value
var room_catalog: Array[Dictionary]:
	get: return host.room_catalog
	set(value): host.room_catalog = value
var kenney_build_lab_mode:
	get: return host.kenney_build_lab_mode
	set(value): host.kenney_build_lab_mode = value
var show_house_diagnostics:
	get: return host.show_house_diagnostics
	set(value): host.show_house_diagnostics = value
var large_room_mix_test_mode:
	get: return host.large_room_mix_test_mode
	set(value): host.large_room_mix_test_mode = value
var omen_options: Array[String]:
	get: return host.omen_options
	set(value): host.omen_options = value
var character_animation_demo_mode:
	get: return host.character_animation_demo_mode
	set(value): host.character_animation_demo_mode = value
var pcg_diorama_seed:
	get: return host.pcg_diorama_seed
	set(value): host.pcg_diorama_seed = value
var lab_camera_target:
	get: return host.lab_camera_target
	set(value): host.lab_camera_target = value
var lab_camera_yaw:
	get: return host.lab_camera_yaw
	set(value): host.lab_camera_yaw = value
var lab_camera_pitch:
	get: return host.lab_camera_pitch
	set(value): host.lab_camera_pitch = value
var lab_camera_distance:
	get: return host.lab_camera_distance
	set(value): host.lab_camera_distance = value
var lab_platforms: Array[Dictionary]:
	get: return host.lab_platforms
	set(value): host.lab_platforms = value
var lab_player:
	get: return host.lab_player
	set(value): host.lab_player = value
var lab_collectibles: Array[Dictionary]:
	get: return host.lab_collectibles
	set(value): host.lab_collectibles = value
var lab_velocity:
	get: return host.lab_velocity
	set(value): host.lab_velocity = value
var lab_jump_held:
	get: return host.lab_jump_held
	set(value): host.lab_jump_held = value
var lab_jump_was_down:
	get: return host.lab_jump_was_down
	set(value): host.lab_jump_was_down = value
var lab_collected:
	get: return host.lab_collected
	set(value): host.lab_collected = value
var puzzle_board: Array[int]:
	get: return host.puzzle_board
	set(value): host.puzzle_board = value
var puzzle_moves_left:
	get: return host.puzzle_moves_left
	set(value): host.puzzle_moves_left = value
var puzzle_refreshes_left:
	get: return host.puzzle_refreshes_left
	set(value): host.puzzle_refreshes_left = value
var puzzle_status:
	get: return host.puzzle_status
	set(value): host.puzzle_status = value
var event_context:
	get: return host.event_context
	set(value): host.event_context = value
var search_targets: Array[Dictionary]:
	get: return host.search_targets
	set(value): host.search_targets = value
var search_found:
	get: return host.search_found
	set(value): host.search_found = value
var chase_sentence:
	get: return host.chase_sentence
	set(value): host.chase_sentence = value
var chase_typed:
	get: return host.chase_typed
	set(value): host.chase_typed = value
var chase_police_progress:
	get: return host.chase_police_progress
	set(value): host.chase_police_progress = value
var chase_player_progress:
	get: return host.chase_player_progress
	set(value): host.chase_player_progress = value
var chase_started:
	get: return host.chase_started
	set(value): host.chase_started = value
var chase_phase:
	get: return host.chase_phase
	set(value): host.chase_phase = value
var chase_countdown:
	get: return host.chase_countdown
	set(value): host.chase_countdown = value
var chase_countdown_index:
	get: return host.chase_countdown_index
	set(value): host.chase_countdown_index = value
var chase_countdown_step_remaining:
	get: return host.chase_countdown_step_remaining
	set(value): host.chase_countdown_step_remaining = value
var chase_countdown_text:
	get: return host.chase_countdown_text
	set(value): host.chase_countdown_text = value
var chase_miss_flash_remaining:
	get: return host.chase_miss_flash_remaining
	set(value): host.chase_miss_flash_remaining = value
var chase_used_sentences: Array[String]:
	get: return host.chase_used_sentences
	set(value): host.chase_used_sentences = value
var chase_finish_delay_remaining:
	get: return host.chase_finish_delay_remaining
	set(value): host.chase_finish_delay_remaining = value
var chase_event_result_pending:
	get: return host.chase_event_result_pending
	set(value): host.chase_event_result_pending = value
var chase_result:
	get: return host.chase_result
	set(value): host.chase_result = value
var rng:
	get: return host.rng
	set(value): host.rng = value

func _init(next_host) -> void:
	host = next_host


func _set_home_video(active: bool) -> void:
	host._set_home_video(active)


func _refresh_hud() -> void:
	host._refresh_hud()


func _cancel_dynamic_effect() -> void:
	host._cancel_dynamic_effect()


func start_combat(room: Dictionary, animate_entry: bool = false) -> void:
	host.start_combat(room, animate_entry)


func build_battle_world() -> void:
	host.build_battle_world()


func build_house_world() -> void:
	host.build_house_world()


func end_combat_turn() -> void:
	host.end_combat_turn()


func handle_battle_cell(target: Vector2i) -> void:
	host.handle_battle_cell(target)


func reset_run(seed_value: int = 0) -> void:
	host.reset_run(seed_value)


func _apply_large_room_test_catalog() -> void:
	host._apply_large_room_test_catalog()


func _set_house_camera() -> void:
	host._set_house_camera()


func _clear_children(parent: Node) -> void:
	host._clear_children(parent)


func _add_box(parent: Node3D, node_name: String, local_position: Vector3, box_size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	return host._add_box(parent, node_name, local_position, box_size, material)


func _add_cylinder(parent: Node3D, node_name: String, local_position: Vector3, radius: float, height: float, material: StandardMaterial3D) -> MeshInstance3D:
	return host._add_cylinder(parent, node_name, local_position, radius, height, material)


func _add_label(parent: Node3D, node_name: String, text_value: String, local_position: Vector3, color: Color, font_size: int) -> Label3D:
	return host._add_label(parent, node_name, text_value, local_position, color, font_size)


func _material(color: Color, transparent: bool = false, emission_strength: float = 0.0) -> StandardMaterial3D:
	return host._material(color, transparent, emission_strength)


func finish_event_trial(success: bool) -> void:
	host.finish_event_trial(success)


func get_tree() -> SceneTree:
	return host.get_tree()


func toggle_home_tests() -> void:
	if phase != "home":
		return
	home_tests_open = not home_tests_open
	_refresh_hud()


func open_combat_test_mode() -> bool:
	if phase != "home":
		return false
	if test_catalog.scenarios.is_empty() and not test_catalog.load_from_path():
		status_message = "战斗测试目录加载失败：%s" % "; ".join(test_catalog.errors)
		_refresh_hud()
		return false
	_set_home_video(false)
	home_tests_open = false
	test_combat_active = false
	test_session.clear()
	test_mode_selected_id = test_catalog.first_id()
	test_focused_enemy_id = ""
	world_container.visible = false
	house_root.visible = false
	battle_root.visible = false
	phase = "test_combat_menu"
	status_message = "选择一个固定场景，观察房间战斗和敌人 AI。"
	_refresh_hud()
	return true


func select_combat_test_scenario(scenario_id: String) -> void:
	if phase != "test_combat_menu":
		return
	if not test_catalog.get_scenario(scenario_id).is_empty():
		test_mode_selected_id = scenario_id
		status_message = "已选择测试场景：%s。" % str(test_catalog.get_scenario(scenario_id).get("name", scenario_id))
		_refresh_hud()


func start_test_combat(mode: String = "manual") -> bool:
	var scenario: Dictionary = test_catalog.get_scenario(test_mode_selected_id)
	if scenario.is_empty():
		return false
	test_saved_state = {
		"run_seed": run_seed,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"player_speed": player_speed,
		"run_deck": run_deck.duplicate(),
	}
	var run_rules: Dictionary = scenario.get("run_rules", {})
	player_hp = int(run_rules.get("player_hp", 30))
	player_max_hp = player_hp
	player_speed = int(run_rules.get("base_speed", 3))
	run_seed = int(scenario.get("seed", run_seed))
	run_deck.assign(scenario.get("deck", ["jab", "guard", "brace", "fling"]))
	test_session.begin(scenario, mode)
	var test_enemies: Array = (scenario.get("room", {}) as Dictionary).get("enemies", [])
	test_focused_enemy_id = str(test_enemies[0].get("id", "")) if not test_enemies.is_empty() else ""
	test_combat_active = true
	host.apply_test_visual_filter(scenario.get("visual", {}))
	start_combat((scenario.get("room", {}) as Dictionary).duplicate(true))
	status_message = "测试场景：%s。" % str(scenario.get("description", scenario.get("name", "")))
	_refresh_hud()
	return true


func restart_test_combat() -> bool:
	if not test_combat_active and phase != "combat":
		return false
	var mode: String = test_session.mode if test_session.active else "manual"
	if phase == "combat":
		return_to_combat_test_menu()
	return start_test_combat(mode)


func return_to_combat_test_menu() -> void:
	if not test_combat_active:
		return
	host.clear_test_visual_filter()
	_cancel_dynamic_effect()
	if active_motion_tween != null and active_motion_tween.is_valid():
		active_motion_tween.kill()
	active_motion_tween = null
	animation_busy = false
	active_animation_kind = ""
	enemy_nodes.clear()
	combat = null
	_restore_test_state()
	test_combat_active = false
	test_last_events.clear()
	test_focused_enemy_id = ""
	test_enemy_phase_pending = false
	test_session.paused = true
	world_container.visible = false
	house_root.visible = false
	battle_root.visible = false
	phase = "test_combat_menu"
	status_message = "测试战斗已结束；可以重开同一场景或选择其他预设。"
	_refresh_hud()


func _restore_test_state() -> void:
	if test_saved_state.is_empty():

		return
	run_seed = int(test_saved_state.get("run_seed", run_seed))
	player_hp = int(test_saved_state.get("player_hp", player_hp))
	player_max_hp = int(test_saved_state.get("player_max_hp", player_max_hp))
	player_speed = int(test_saved_state.get("player_speed", player_speed))
	run_deck.assign(test_saved_state.get("run_deck", []))


func _update_test_observer(_delta: float) -> void:
	if not test_session.active or test_session.mode != "observer_auto" or not test_session.can_advance():
		return
	if animation_busy or combat == null or combat.outcome != "":
		return
	if combat.pending_player_turn:
		return
	_advance_test_player_script()
	end_combat_turn()


func _advance_test_player_script() -> void:
	if combat == null or combat.energy <= 0:
		return
	var observer: Dictionary = test_session.scenario.get("observer", {})
	var script_id := str(observer.get("player_script", "stationary"))
	if script_id == "stationary":
		return
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var ordered: Array[Vector2i] = []
	var offset: int = test_session.round_count % directions.size()
	for index in range(directions.size()):
		ordered.append(directions[(index + offset) % directions.size()])
	for direction in ordered:
		var target: Vector2i = combat.player_pos + direction
		if not combat.can_move_player(target):
			continue
		if script_id == "safe_random_walk" and combat.enemy_at(target, false) != null:
			continue
		combat.move_player(target)
		return


func advance_test_observer() -> void:
	if not test_combat_active or not test_session.active or test_session.mode != "observer_step":
		return
	if animation_busy or combat == null or combat.outcome != "" or combat.pending_player_turn:
		return
	test_session.paused = false
	_advance_test_player_script()
	end_combat_turn()
	test_session.paused = true


func toggle_test_observer() -> void:
	if not test_combat_active or not test_session.active or test_session.mode != "observer_auto":
		return
	test_session.paused = not test_session.paused
	status_message = "AI 连续观察已%s。" % ("暂停" if test_session.paused else "继续")
	_refresh_hud()


func focus_test_enemy(enemy_id: String) -> void:
	if not test_combat_active or combat == null or combat.enemy_by_id(enemy_id) == null:
		return
	test_focused_enemy_id = enemy_id
	_refresh_hud()


func open_asset_editor() -> bool:
	if phase != "home":
		return false
	var packed := load(ASSET_EDITOR_SCENE_PATH) as PackedScene
	if packed == null:
		status_message = "资产地编场景没有找到。"
		_refresh_hud()
		return false
	_set_home_video(false)
	get_tree().change_scene_to_packed(packed)
	return true


func start_combat_lab(room_id: String = "hall") -> void:
	var room := _find_catalog_room(room_id)
	if room.is_empty():
		return
	combat_presentation_lab = true
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
	var presenter: Node = battle_actor_root.get_node_or_null("Player/Presenter")
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
	var presenter: Node = battle_actor_root.get_node_or_null("Player/Presenter")
	var duration := 0.0
	if presenter != null and presenter.has_method("preview_model_animation"):
		duration = presenter.preview_model_animation("attack", 1.5)
	status_message = "攻击：完整预览 FBX preset_biped_slash（%.1f 秒），结束后自动回到待机。" % duration
	_refresh_hud()


func demo_character_hurt() -> void:
	if not character_animation_demo_mode or phase != "combat":
		return
	var presenter: Node = battle_actor_root.get_node_or_null("Player/Presenter")
	var duration := 0.0
	if presenter != null and presenter.has_method("preview_model_animation"):
		duration = presenter.preview_model_animation("hurt", 1.25)
	status_message = "受击：完整预览 FBX preset_biped_afraid（%.1f 秒），不改变生命值。" % duration
	_refresh_hud()


func start_pcg_diorama_lab() -> void:
	_prepare_lab("lab_pcg_diorama")
	var generator: Node3D = PCG_DIORAMA_STITCH_LAB.instantiate() as Node3D
	generator.name = "PcgDioramaStitch"
	generator.generation_seed = pcg_diorama_seed
	lab_root.add_child(generator)
	_set_pcg_diorama_camera(generator)
	status_message = "先看 R00·1格 整块接入 R01·5格，再继续拼 3/1/5 格；编号保留房间归属，门洞标记跨房连接，整房依次落位。"
	_refresh_hud()


func reroll_pcg_diorama() -> void:
	if phase != "lab_pcg_diorama":
		return
	var generator: Node = lab_root.get_node_or_null("PcgDioramaStitch")
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
	var previous_y: float = lab_player.position.y
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
			var pickup: Node = lab_root.get_node_or_null("Signal_%d" % i)
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
	var empty: int = puzzle_board.find(0)
	if absi(index / 3 - empty / 3) + absi(index % 3 - empty % 3) != 1:
		puzzle_status = "只能推动空格旁边的数字。"
		_refresh_hud()
		return
	var value: int = puzzle_board[index]
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
	var empty: int = puzzle_board.find(0)
	var source: int = empty + offset
	if source >= 0 and source < puzzle_board.size():
		puzzle_slide(source)


func _shuffle_puzzle(reset_refreshes: bool = true) -> void:
	puzzle_board.assign([1, 2, 3, 4, 5, 6, 7, 8, 0])
	var previous_empty := -1
	for i in range(24):
		var empty: int = puzzle_board.find(0)
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
	var ray_origin: Vector3 = camera.project_ray_origin(view_pos)
	var ray_direction: Vector3 = camera.project_ray_normal(view_pos).normalized()
	var best_index := -1
	var best_distance := 0.82
	for i in range(search_targets.size()):
		if bool(search_targets[i]["found"]):
			continue
		var pos: Vector3 = search_targets[i]["pos"]
		var along_ray := maxf(0.0, (pos - ray_origin).dot(ray_direction))
		var closest_point: Vector3 = ray_origin + ray_direction * along_ray
		var distance: float = closest_point.distance_to(pos)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	if best_index < 0:
		return false
	search_targets[best_index]["found"] = true
	search_found += 1
	var node: Node = lab_root.get_node_or_null("SearchItem_%d" % best_index)
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
	var expected: String = chase_sentence.substr(chase_typed, 1)
	var matches: bool = character == " " if expected == " " else character.to_lower() == expected.to_lower()
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
