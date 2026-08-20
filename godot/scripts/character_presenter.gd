extends Node3D

signal state_changed(state: String)

var actor_id := ""
var current_state := "idle"
var action_count := 0
var config: Dictionary = {}
var sprite: AnimatedSprite3D = null
var model_root: Node3D = null
var model_animation_player: AnimationPlayer = null
var action_tween: Tween = null
var base_position := Vector3.ZERO
var preview_generation := 0


func configure(next_actor_id: String, next_config: Dictionary) -> void:
	actor_id = next_actor_id
	config = next_config.duplicate(true)
	base_position = position
	_configure_model()
	sprite = AnimatedSprite3D.new()
	sprite.name = "AnimatedCharacter"
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.no_depth_test = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.pixel_size = float(config.get("pixel_size", 0.002))
	sprite.position = Vector3(0, float(config.get("visual_y", 0.85)), 0)
	sprite.sprite_frames = _build_frames(config)
	sprite.visible = model_root == null
	add_child(sprite)
	sprite.play("idle")
	_play_model_animation("idle")


func play_state(state: String, callout: String = "") -> void:
	preview_generation += 1
	if sprite == null and model_root == null:
		return
	if action_tween != null and action_tween.is_valid():
		action_tween.kill()
	current_state = state
	action_count += 1
	state_changed.emit(state)
	position = base_position
	rotation = Vector3.ZERO
	scale = Vector3.ONE
	if sprite != null:
		sprite.modulate = Color.WHITE
	_play_model_animation(state)
	if sprite.sprite_frames.has_animation(state) and sprite.sprite_frames.get_frame_count(state) > 0:
		sprite.play(state)
	else:
		sprite.play("idle")
	action_tween = create_tween()
	match state:
		"move":
			# Grid movement owns translation. The skeletal clip only supplies the gait.
			action_tween.tween_interval(0.30)
		"ready":
			if sprite != null:
				sprite.modulate = Color("ffe4a0")
			action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			action_tween.tween_property(self, "scale", Vector3(0.82, 1.18, 1.0), 0.13)
			action_tween.tween_property(self, "scale", Vector3(1.08, 0.94, 1.0), 0.12)
			action_tween.tween_property(self, "scale", Vector3.ONE, 0.10)
		"attack":
			action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			action_tween.tween_property(self, "position:x", base_position.x - 0.28, 0.08)
			action_tween.tween_property(self, "position:x", base_position.x + 0.58, 0.12)
			action_tween.parallel().tween_property(self, "scale", Vector3(1.22, 0.82, 1.0), 0.12)
			action_tween.tween_property(self, "position:x", base_position.x, 0.15)
			action_tween.parallel().tween_property(self, "scale", Vector3.ONE, 0.15)
		"hurt":
			if sprite != null:
				sprite.modulate = Color("ff766e")
			action_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			action_tween.tween_property(self, "position:x", base_position.x - 0.24, 0.07)
			action_tween.tween_property(self, "position:x", base_position.x + 0.18, 0.07)
			action_tween.tween_property(self, "position:x", base_position.x, 0.14)
			action_tween.parallel().tween_property(self, "scale", Vector3(1.20, 0.72, 1.0), 0.12)
			action_tween.tween_property(self, "scale", Vector3.ONE, 0.15)
		_:
			action_tween.tween_interval(0.18)
	action_tween.tween_interval(0.24)
	action_tween.tween_callback(_return_to_idle)


func preview_model_animation(state: String, playback_speed: float = 1.0) -> float:
	if model_animation_player == null:
		return 0.0
	if action_tween != null and action_tween.is_valid():
		action_tween.kill()
	preview_generation += 1
	var generation := preview_generation
	current_state = state
	state_changed.emit(state)
	position = base_position
	rotation = Vector3.ZERO
	scale = Vector3.ONE
	if sprite != null:
		sprite.modulate = Color.WHITE
	var animation_map: Dictionary = config.get("animation_map", {})
	var resolved := _resolve_model_animation(str(animation_map.get(state, "")))
	if resolved.is_empty():
		return 0.0
	var animation := model_animation_player.get_animation(resolved)
	if animation == null:
		return 0.0
	var speed := maxf(playback_speed, 0.05)
	animation.loop_mode = Animation.LOOP_LINEAR if state == "idle" else Animation.LOOP_NONE
	model_animation_player.play(resolved, 0.08, speed)
	if state != "idle":
		var duration := animation.length / speed
		get_tree().create_timer(duration).timeout.connect(func() -> void:
			if generation == preview_generation and is_inside_tree():
				_return_to_idle()
		)
		return duration
	return INF


func set_interaction_pose(pose: String, kind: String) -> void:
	if sprite == null and model_root == null:
		return
	if action_tween != null and action_tween.is_valid():
		action_tween.kill()
	current_state = "interact_%s" % kind
	state_changed.emit(current_state)
	position = base_position
	rotation = Vector3.ZERO
	scale = Vector3.ONE
	match pose:
		"sit":
			position.y = base_position.y - 0.12
			scale = Vector3(1.0, 0.82, 1.0)
		"rest":
			position.y = base_position.y - 0.18
			rotation.z = deg_to_rad(68.0)
			scale = Vector3.ONE * 0.88
		"work":
			rotation.x = deg_to_rad(-8.0)
			scale = Vector3(1.0, 0.96, 1.0)
	_play_model_animation(pose)


func _return_to_idle() -> void:
	preview_generation += 1
	current_state = "idle"
	state_changed.emit("idle")
	position = base_position
	rotation = Vector3.ZERO
	scale = Vector3.ONE
	if sprite != null:
		sprite.modulate = Color.WHITE
		sprite.play("idle")
	_play_model_animation("idle")


func set_obscured(obscured: bool) -> void:
	if model_root != null:
		model_root.visible = not obscured
	if sprite != null:
		sprite.visible = obscured or model_root == null
		sprite.modulate = Color("30383d") if obscured else Color.WHITE


func has_3d_model() -> bool:
	return model_root != null and model_animation_player != null


func current_model_animation() -> String:
	return model_animation_player.current_animation if model_animation_player != null else ""


func model_animation_names() -> Array[String]:
	var names: Array[String] = []
	if model_animation_player == null:
		return names
	for raw_name: StringName in model_animation_player.get_animation_list():
		names.append(str(raw_name))
	return names


func _configure_model() -> void:
	var model_path := str(config.get("model_path", ""))
	if model_path.is_empty():
		return
	var packed := load(model_path) as PackedScene
	if packed == null:
		push_warning("Character model could not be loaded: %s" % model_path)
		return
	model_root = packed.instantiate() as Node3D
	if model_root == null:
		return
	model_root.name = "CharacterModel"
	model_root.position = Vector3(0.0, float(config.get("model_y", 0.0)), 0.0)
	model_root.rotation.y = deg_to_rad(float(config.get("model_yaw", 180.0)))
	model_root.scale = Vector3.ONE * float(config.get("model_scale", 0.72))
	add_child(model_root)
	for child: Node in model_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var players := model_root.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		model_animation_player = players[0] as AnimationPlayer


func _play_model_animation(state: String) -> void:
	if model_animation_player == null:
		return
	var animation_map: Dictionary = config.get("animation_map", {})
	var requested := str(animation_map.get(state, animation_map.get("idle", "Idle")))
	var resolved := _resolve_model_animation(requested)
	if resolved.is_empty() and state != "idle":
		resolved = _resolve_model_animation(str(animation_map.get("idle", "Idle")))
	if resolved.is_empty():
		return
	var animation := model_animation_player.get_animation(resolved)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR if state in ["idle", "move"] else Animation.LOOP_NONE
	model_animation_player.play(resolved, 0.08)


func _resolve_model_animation(requested: String) -> String:
	for raw_name: StringName in model_animation_player.get_animation_list():
		var name := str(raw_name)
		if name == requested or name.to_lower() == requested.to_lower() or name.get_file().to_lower() == requested.to_lower() or name.to_lower().ends_with("|" + requested.to_lower()):
			return name
	return ""


func _build_frames(actor_config: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var animations: Dictionary = actor_config.get("animations", {})
	for raw_state in animations:
		var state := str(raw_state)
		var animation: Dictionary = animations[raw_state]
		_add_animation(frames, state, animation.get("frames", []), float(animation.get("fps", 8.0)), bool(animation.get("loop", state in ["idle", "move"])))
	if not frames.has_animation("idle") or frames.get_frame_count("idle") == 0:
		_add_animation(frames, "idle", actor_config.get("idle_frames", []), float(actor_config.get("idle_fps", 8.0)), true)
	return frames


func _add_animation(frames: SpriteFrames, state: String, paths: Array, fps: float, loop: bool) -> void:
	if not frames.has_animation(state):
		frames.add_animation(state)
	frames.set_animation_speed(state, maxf(fps, 0.1))
	frames.set_animation_loop(state, loop)
	for raw_path in paths:
		var texture := load(str(raw_path)) as Texture2D
		if texture != null:
			frames.add_frame(state, texture)


func _state_color(state: String) -> Color:
	match state:
		"move": return Color("7ee6d2")
		"ready": return Color("ffd05e")
		"attack": return Color("ff8a67")
		"hurt": return Color("ff5f68")
	return Color.WHITE
