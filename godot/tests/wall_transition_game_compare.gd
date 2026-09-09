extends SceneTree

## Formal-game A/B test. It loads channel_3d.tscn and drives the real house camera.
## Pass --interactive to keep the scene open after the fixed-path capture.
const OUT := "res://../output/wall-transition-game"
const MODES := [0, 1, 2]
var output_dir := OUT
var game: Node3D
var composer: Node3D
var mode_label: Label
var interactive := false
var failures: Array[String] = []

func _init() -> void:
	interactive = "--interactive" in OS.get_cmdline_user_args()
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--"):
			output_dir = argument
			break
	call_deferred("run")

func run() -> void:
	create_timer(150.0).timeout.connect(func(): quit(1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	game = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	game.run_save_repository = load("res://scripts/run_save_repository.gd").new(output_dir + "/isolated.json", game.EXE_SOURCE_ID)
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_new_run(false, 2026081901)
	game.choose_omen(0)
	var hall: Dictionary = game._find_catalog_room("hall")
	var placed := false
	for cell: Vector2i in game.room_rules.frontiers():
		var rotations: Array = game.room_rules.valid_rotations(cell, hall)
		if rotations.is_empty():
			continue
		if game.room_rules.place(cell, hall, int(rotations[0])):
			var instance_id := str(game.room_rules.placed[cell].get("instance_id", ""))
			for raw_pos: Variant in game.room_rules.placed.keys():
				var pos: Vector2i = raw_pos
				if str(game.room_rules.placed[pos].get("instance_id", "")) == instance_id:
					game.room_rules.set_instance_flag(pos, "visited", true)
					game.room_rules.set_instance_flag(pos, "revealed", true)
					game.room_rules.set_instance_flag(pos, "completed", false)
			game.current_room_pos = cell
			placed = true
			break
	if not placed:
		quit(1)
		return
	game.phase = "explore"
	game.build_house_world()
	await process_frame
	composer = game.house_root.get_node_or_null("KenneyFormalComposer") as Node3D
	_check(composer != null, "formal comparison composer exists")
	if composer == null:
		quit(1)
		return
	game.reset_house_camera()
	game.set_process(false)
	_add_compare_overlay()
	for mode: int in MODES:
		composer.set_cutaway_transition_mode(mode)
		var mode_name: String = ["原版：直接隐藏", "A：缩入底座", "B：波浪渐隐"][mode]
		mode_label.text = mode_name + "   |   正式房间 / 固定 120° 旋转 / 正常速度"
		game.reset_house_camera()
		await process_frame
		var mode_dir := "%s/mode_%d" % [output_dir, mode]
		var mkdir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(mode_dir))
		if mkdir_error != OK:
			push_error("Could not create formal compare directory: " + ProjectSettings.globalize_path(mode_dir))
			quit(1)
			return
		var capture_yaws: Array[float] = [-PI / 3.0, -PI / 18.0, PI / 6.0, PI / 3.0]
		var frame := 0
		for yaw: float in capture_yaws:
			game.house_camera_yaw = yaw
			game._apply_house_camera()
			for hold in range(6):
				await process_frame
				var frame_path := ProjectSettings.globalize_path(mode_dir + "/frame_%03d.png" % frame)
				var save_error := root.get_texture().get_image().save_png(frame_path)
				if save_error != OK:
					push_error("Could not save formal compare frame: " + frame_path)
					quit(1)
					return
				frame += 1
		for settle in range(24):
			game._apply_house_camera()
			await process_frame
			await process_frame
		var settle_path := ProjectSettings.globalize_path(mode_dir + "/settled.png")
		var settle_error := root.get_texture().get_image().save_png(settle_path)
		if settle_error != OK:
			push_error("Could not save formal compare settle frame: " + settle_path)
			quit(1)
			return
		_check(int(composer.cutaway_transition_state().get("active", 0)) == 0, mode_name + " settles after rotation")
	game.run_save_repository.clear()
	if failures.is_empty():
		print("WALL_TRANSITION_GAME_COMPARE: PASS formal scene modes=instant,retract,wave fixed_path=120deg")
	else:
		for failure in failures:
			push_error("WALL_TRANSITION_GAME_COMPARE: " + failure)
	if interactive:
		mode_label.text += "   |   1/2/3 切换模式，A/D 旋转"
		await create_timer(12.0).timeout
	else:
		game.queue_free()
		await process_frame
		quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("WALL_TRANSITION_GAME_COMPARE: " + message)

func _add_compare_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	root.add_child(layer)
	mode_label = Label.new()
	mode_label.position = Vector2(120, 18)
	mode_label.add_theme_font_size_override("font_size", 22)
	mode_label.add_theme_color_override("font_color", Color("fff0c9"))
	layer.add_child(mode_label)

func _process(_delta: float) -> bool:
	if game == null or composer == null:
		return false
	var keys := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if absf(keys.x) > 0.01:
		game.house_camera_yaw += keys.x * 0.035
	if Input.is_key_pressed(KEY_1):
		composer.set_cutaway_transition_mode(0)
	if Input.is_key_pressed(KEY_2):
		composer.set_cutaway_transition_mode(1)
	if Input.is_key_pressed(KEY_3):
		composer.set_cutaway_transition_mode(2)
	game._apply_house_camera()
	return false
