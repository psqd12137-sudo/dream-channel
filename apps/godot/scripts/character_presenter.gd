extends Node3D

signal state_changed(state: String)

var actor_id := ""
var current_state := "idle"
var action_count := 0
var config: Dictionary = {}
var sprite: AnimatedSprite3D = null
var action_label: Label3D = null
var action_tween: Tween = null
var base_position := Vector3.ZERO


func configure(next_actor_id: String, next_config: Dictionary) -> void:
	actor_id = next_actor_id
	config = next_config.duplicate(true)
	base_position = position
	sprite = AnimatedSprite3D.new()
	sprite.name = "AnimatedCharacter"
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.no_depth_test = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.pixel_size = float(config.get("pixel_size", 0.002))
	sprite.position = Vector3(0, float(config.get("visual_y", 0.85)), 0)
	sprite.sprite_frames = _build_frames(config)
	add_child(sprite)
	action_label = Label3D.new()
	action_label.name = "ActionCallout"
	action_label.position = Vector3(0, float(config.get("visual_y", 0.85)) + 1.05, 0)
	action_label.font_size = 32
	action_label.pixel_size = 0.012
	action_label.modulate = Color.TRANSPARENT
	action_label.outline_modulate = Color("111820")
	action_label.outline_size = 10
	action_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	action_label.no_depth_test = true
	add_child(action_label)
	sprite.play("idle")


func play_state(state: String, callout: String = "") -> void:
	if sprite == null:
		return
	if action_tween != null and action_tween.is_valid():
		action_tween.kill()
	current_state = state
	action_count += 1
	state_changed.emit(state)
	position = base_position
	rotation = Vector3.ZERO
	scale = Vector3.ONE
	sprite.modulate = Color.WHITE
	if sprite.sprite_frames.has_animation(state) and sprite.sprite_frames.get_frame_count(state) > 0:
		sprite.play(state)
	else:
		sprite.play("idle")
	action_label.text = callout if not callout.is_empty() else _default_callout(state)
	action_label.modulate = _state_color(state)
	if state in ["ready", "attack", "hurt"]:
		_spawn_burst(_state_color(state))
	action_tween = create_tween()
	match state:
		"move":
			action_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			action_tween.tween_property(self, "position:y", base_position.y + 0.32, 0.10)
			action_tween.tween_property(self, "position:y", base_position.y, 0.12)
			action_tween.tween_property(self, "rotation:z", deg_to_rad(-6.0), 0.07)
			action_tween.tween_property(self, "rotation:z", 0.0, 0.08)
		"ready":
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
			sprite.modulate = Color("ff766e")
			action_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			action_tween.tween_property(self, "position:x", base_position.x - 0.24, 0.07)
			action_tween.tween_property(self, "position:x", base_position.x + 0.18, 0.07)
			action_tween.tween_property(self, "position:x", base_position.x, 0.14)
			action_tween.parallel().tween_property(self, "scale", Vector3(1.20, 0.72, 1.0), 0.12)
			action_tween.tween_property(self, "scale", Vector3.ONE, 0.15)
		_:
			action_tween.tween_interval(0.18)
	action_tween.tween_property(action_label, "modulate:a", 0.0, 0.24)
	action_tween.tween_callback(_return_to_idle)


func _return_to_idle() -> void:
	current_state = "idle"
	state_changed.emit("idle")
	position = base_position
	rotation = Vector3.ZERO
	scale = Vector3.ONE
	if sprite != null:
		sprite.modulate = Color.WHITE
		sprite.play("idle")


func _spawn_burst(color: Color) -> void:
	var burst := Label3D.new()
	burst.name = "ActionBurst"
	burst.text = "✦  ✦  ✦"
	burst.position = Vector3(0, float(config.get("visual_y", 0.85)) + 0.60, 0.03)
	burst.font_size = 54
	burst.pixel_size = 0.015
	burst.modulate = color
	burst.outline_modulate = Color("101820")
	burst.outline_size = 8
	burst.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	burst.no_depth_test = true
	burst.scale = Vector3(0.35, 0.35, 0.35)
	add_child(burst)
	var tween := burst.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "scale", Vector3(1.25, 1.25, 1.25), 0.16)
	tween.parallel().tween_property(burst, "position:y", burst.position.y + 0.42, 0.30)
	tween.tween_property(burst, "modulate:a", 0.0, 0.16)
	tween.tween_callback(burst.queue_free)


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


func _default_callout(state: String) -> String:
	match state:
		"move": return "走!"
		"ready": return "预备!"
		"attack": return "出手!"
		"hurt": return "受击!"
	return ""


func _state_color(state: String) -> Color:
	match state:
		"move": return Color("7ee6d2")
		"ready": return Color("ffd05e")
		"attack": return Color("ff8a67")
		"hurt": return Color("ff5f68")
	return Color.WHITE
