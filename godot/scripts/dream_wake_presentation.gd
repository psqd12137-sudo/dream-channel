extends Node

## The short, deterministic coda between the final result and the ending card.
## It owns presentation timing and input capture; the game owns the saved result.
signal finished()

class DreamWakeOverlay:
	extends Control

	var presentation: Node = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_process_input(true)

	func _gui_input(event: InputEvent) -> void:
		if presentation == null:
			return
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			presentation.skip()
			accept_event()

	func _draw() -> void:
		if presentation == null or not presentation.is_playing():
			return
		var recap: Dictionary = presentation.current_recap
		var outcome := str(recap.get("outcome", "defeat"))
		var intro := outcome == "program_intro"
		var success := outcome == "victory"
		var accent := Color("ffe233") if intro else Color("8ccd42") if success else Color("ef493f")
		var paper := Color("fff3df")
		var muted := Color("c8e8eb")
		var gold := Color("ffe233")
		var dark := Color("091116e8")
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), dark, true)
		draw_rect(Rect2(0, 0, size.x, 6), Color("ee3e91"), true)
		draw_rect(Rect2(0, size.y - 6, size.x, 6), Color("269dca"), true)
		# A simple cone reads as a studio spotlight without introducing a second
		# interactive scene or changing the user's room assets.
		var spotlight := PackedVector2Array([
			Vector2(size.x * 0.5 - 92.0, 98.0),
			Vector2(size.x * 0.5 + 92.0, 98.0),
			Vector2(size.x * 0.5 + 300.0, size.y),
			Vector2(size.x * 0.5 - 300.0, size.y),
		])
		draw_colored_polygon(spotlight, Color(1.0, 0.86, 0.42, 0.07))
		draw_string(font, Vector2(512, 90), "织梦频道 · 终幕颁奖", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, gold)
		var subtitle := "节目单入场" if intro else "梦演到结尾" if success else "梦提前中断"
		draw_string(font, Vector2(538, 124), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, accent)
		draw_string(font, Vector2(472, 155), "三张素材，合成这一场最后的破坏秀", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, muted)

		var cards: Array = recap.get("cards", [])
		var card_width := 254.0
		var gap := 18.0
		var start_x := (size.x - card_width * 3.0 - gap * 2.0) * 0.5
		for index in range(3):
			var card: Dictionary = cards[index] if index < cards.size() and cards[index] is Dictionary else {}
			var rect := Rect2(start_x + float(index) * (card_width + gap), 210, card_width, 294)
			var raised: bool = presentation.active_card_index == index
			var fill := Color("202c35f5") if not raised else Color("34434cf8")
			draw_rect(rect, fill, true)
			draw_rect(rect, gold if raised else Color("52706b"), false, 3.0 if raised else 1.5)
			draw_string(font, rect.position + Vector2(20, 38), "素材 %d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gold)
			draw_string(font, rect.position + Vector2(20, 80), str(card.get("name", "未命名布景")), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, paper)
			draw_string(font, rect.position + Vector2(20, 122), "受伤经历 %d 点" % int(card.get("hp_lost", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, muted)
			draw_string(font, rect.position + Vector2(20, 164), "已写入终幕剧本", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("9ddbd6"))
			draw_line(rect.position + Vector2(20, 190), rect.position + Vector2(card_width - 20, 190), Color("52706b"), 1.0)
			draw_string(font, rect.position + Vector2(20, 232), "房间 · 角色 · 记忆", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffd4bd"))

		draw_string(font, Vector2(470, 566), "没有排名，没有对手，只有这一场梦的回放", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, paper)
		draw_string(font, Vector2(512, 610), "点击、空格或回车跳过演出", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, muted)
		draw_string(font, Vector2(514, 650), "节目已锁定 · 结局不会改变", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, accent)


var current_recap: Dictionary = {}
var current_outcome := ""
var input_locked := false
var player_was_stilled := false
var active_card_index := -1
var skip_seconds := 0.0

var _playing := false
var _finished_emitted := false
var _generation := 0
var _elapsed := 0.0
var _duration := 0.0
var _player_node: Node3D = null
var _player_process_mode := Node.PROCESS_MODE_INHERIT
var _overlay: DreamWakeOverlay = null
var _canvas_layer: CanvasLayer = null


func _ready() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "DreamWakePresentationLayer"
	_canvas_layer.layer = 40
	add_child(_canvas_layer)
	_overlay = DreamWakeOverlay.new()
	_overlay.name = "DreamWakeOverlay"
	_overlay.presentation = self
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas_layer.add_child(_overlay)
	_overlay.visible = false
	set_process_input(true)


func play(player_node: Node3D, recap: Dictionary, seconds: float) -> void:
	_cancel_timer()
	_generation += 1
	_finished_emitted = false
	_playing = true
	input_locked = true
	_elapsed = 0.0
	_duration = maxf(0.0, seconds)
	player_was_stilled = false
	_player_node = player_node
	current_recap = _normalize_recap(recap)
	current_outcome = str(current_recap.get("outcome", "defeat"))
	active_card_index = 0
	_still_player()
	_overlay.visible = true
	_overlay.queue_redraw()
	var duration := _duration
	if skip_seconds > 0.0:
		duration = minf(duration, skip_seconds)
	_duration = duration
	if duration <= 0.0:
		call_deferred("_complete", _generation)
	else:
		var timer := get_tree().create_timer(duration)
		timer.timeout.connect(_complete.bind(_generation), CONNECT_ONE_SHOT)


func skip() -> void:
	if not _playing:
		return
	_complete(_generation)


func cancel() -> void:
	_generation += 1
	_cancel_timer()
	_playing = false
	input_locked = false
	active_card_index = -1
	if _overlay != null:
		_overlay.visible = false


func is_playing() -> bool:
	return _playing


func _process(delta: float) -> void:
	if not _playing or _duration <= 0.0:
		return
	_elapsed = minf(_duration, _elapsed + delta)
	var next_card_index: int = mini(2, int(floor(_elapsed / (_duration / 3.0))))
	if next_card_index != active_card_index:
		active_card_index = next_card_index
		if _overlay != null:
			_overlay.queue_redraw()


func card_count() -> int:
	return (current_recap.get("cards", []) as Array).size()


func has_ranking_or_opponent_copy() -> bool:
	var copy := JSON.stringify(current_recap).to_lower()
	return copy.contains("排名") or copy.contains("对手") or copy.contains("contestant") or copy.contains("opponent")


func _complete(generation_value: int) -> void:
	if generation_value != _generation or not _playing or _finished_emitted:
		return
	_finished_emitted = true
	_playing = false
	input_locked = false
	active_card_index = -1
	_cancel_timer()
	if _overlay != null:
		_overlay.visible = false
		_overlay.queue_redraw()
	finished.emit()


func _normalize_recap(recap: Dictionary) -> Dictionary:
	var normalized := recap.duplicate(true)
	var outcome := str(normalized.get("outcome", ""))
	var success := bool(normalized.get("success", false))
	if outcome not in ["victory", "defeat", "program_intro"]:
		outcome = "victory" if success else "defeat"
		success = outcome == "victory"
	elif outcome == "program_intro":
		success = false
	else:
		# Outcome is the persisted source of truth. This prevents a stale title or
		# success flag from displaying the opposite ending after recovery.
		success = outcome == "victory"
	normalized["outcome"] = outcome
	normalized["success"] = success
	var cards: Array = []
	var raw_cards: Variant = normalized.get("cards", [])
	if raw_cards is Array:
		for raw_card: Variant in raw_cards:
			if raw_card is Dictionary:
				cards.append((raw_card as Dictionary).duplicate(true))
	while cards.size() < 3:
		cards.append({"name": "未命名素材", "hp_lost": 0})
	normalized["cards"] = cards.slice(0, 3)
	return normalized


func _still_player() -> void:
	if not is_instance_valid(_player_node):
		return
	player_was_stilled = true
	_player_process_mode = _player_node.process_mode
	_player_node.process_mode = Node.PROCESS_MODE_DISABLED
	if _player_node.has_method("play_state"):
		_player_node.call("play_state", "idle")
	if _player_node.has_method("set_velocity"):
		_player_node.call("set_velocity", Vector3.ZERO)
	_player_node.set_meta("dream_wake_stilled", true)
	# Runtime actors are already placed at the room floor. Clamp only a stray
	# positive offset so a recovered finale cannot leave the toy hovering.
	_player_node.position.y = minf(_player_node.position.y, 0.30)


func _cancel_timer() -> void:
	# SceneTreeTimers are one-shot and generation guarded, so there is no object
	# to dispose here. Keeping this hook makes cancel/play safe and explicit.
	pass


func _input(event: InputEvent) -> void:
	if not _playing or not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
		skip()
		get_viewport().set_input_as_handled()
