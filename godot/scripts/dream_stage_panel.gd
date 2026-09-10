class_name DreamStagePanel
extends Control

const DreamDrawRules = preload("res://scripts/dream_draw_rules.gd")

signal submitted(nomination_id: String)
signal reveal_finished()
signal program_requested(program_entry: Dictionary)

const INK := Color("17151c")
const PAPER := Color("fff3df")
const MUTED := Color("c8e8eb")
const TEAL := Color("12b4aa")
const GOLD := Color("ffe233")
const MAGENTA := Color("ee3e91")
const BLUE := Color("269dca")
const RED := Color("ef493f")

var stage := 1
var records: Array[Dictionary] = []
var probability_map: Dictionary = {}
var result: Dictionary = {}
var submitted_once := false
var revealing := false
var reveal_finished_once := false
var reveal_only := false
var _buttons: Array[Button] = []
var _abstain_button: Button
var _program_button: Button
var _message := ""
var _program_entry: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func show_candidates(next_stage: int, next_records: Array[Dictionary], probabilities_for_display: Dictionary) -> void:
	stage = next_stage
	records.clear()
	for record: Dictionary in next_records:
		records.append(record.duplicate(true))
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("instance_id", "")) < str(b.get("instance_id", ""))
	)
	probability_map = probabilities_for_display.duplicate(true)
	result.clear()
	_program_entry.clear()
	submitted_once = false
	revealing = false
	reveal_finished_once = false
	reveal_only = false
	_message = "选择一间房，把它交给这一阶段的节目；也可以本次弃权。"
	_rebuild_buttons()
	visible = true
	queue_redraw()


func update_probabilities(next_probabilities: Dictionary) -> void:
	probability_map = next_probabilities.duplicate(true)
	for index in range(mini(records.size(), _buttons.size())):
		_buttons[index].text = _candidate_text(records[index])
	queue_redraw()


func show_reveal_only(next_stage: int, next_records: Array[Dictionary], saved_result: Dictionary, seconds: float) -> void:
	show_candidates(next_stage, next_records, saved_result.get("probabilities", {}))
	reveal_only = true
	submitted_once = true
	reveal(saved_result, seconds)


func reject_submission(message: String) -> void:
	if revealing:
		return
	submitted_once = false
	_message = message
	_set_buttons_disabled(false)
	queue_redraw()


func reveal(next_result: Dictionary, seconds: float) -> void:
	if revealing or reveal_finished_once:
		return
	result = next_result.duplicate(true)
	revealing = true
	_message = "节目正在抽片……"
	_set_buttons_disabled(true)
	queue_redraw()
	var duration := maxf(0.0, seconds)
	if duration <= 0.0:
		_finish_reveal()
		return
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.finished.connect(_finish_reveal)


func skip_reveal() -> void:
	if revealing:
		_finish_reveal()


func _finish_reveal() -> void:
	if reveal_finished_once:
		return
	revealing = false
	reveal_finished_once = true
	_message = _recap_text()
	_program_entry = _read_program_entry()
	if _program_button != null and stage >= 3:
		_program_button.visible = true
	queue_redraw()
	reveal_finished.emit()


func _request_program() -> void:
	if stage < 3 or _program_entry.is_empty():
		return
	if _program_button != null:
		_program_button.disabled = true
	program_requested.emit(_program_entry.duplicate(true))


func _submit(instance_id: String) -> void:
	if submitted_once or revealing or reveal_only:
		return
	submitted_once = true
	_message = "已交给节目，正在锁定这一阶段的抽片。"
	_set_buttons_disabled(true)
	queue_redraw()
	submitted.emit(instance_id)


func _rebuild_buttons() -> void:
	for button: Button in _buttons:
		button.queue_free()
	_buttons.clear()
	if _abstain_button != null:
		_abstain_button.queue_free()
		_abstain_button = null
	if _program_button != null:
		_program_button.queue_free()
		_program_button = null
	for index in range(records.size()):
		var record: Dictionary = records[index]
		var button := Button.new()
		button.name = "Nominate_%s" % str(record.get("instance_id", index))
		button.text = _candidate_text(record)
		button.position = Vector2(220.0, 205.0 + index * 92.0)
		button.size = Vector2(840.0, 72.0)
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", INK)
		button.add_theme_color_override("font_hover_color", INK)
		button.add_theme_color_override("font_pressed_color", INK)
		button.add_theme_stylebox_override("normal", _button_style(PAPER, TEAL))
		button.add_theme_stylebox_override("hover", _button_style(Color("fff9e8"), GOLD))
		button.add_theme_stylebox_override("pressed", _button_style(Color("ffe7bc"), MAGENTA))
		var id := str(record.get("instance_id", ""))
		button.pressed.connect(func() -> void: _submit(id))
		add_child(button)
		_buttons.append(button)
	_abstain_button = Button.new()
	_abstain_button.name = "Abstain"
	_abstain_button.text = "本次弃权"
	_abstain_button.position = Vector2(520.0, 610.0)
	_abstain_button.size = Vector2(240.0, 48.0)
	_abstain_button.add_theme_font_size_override("font_size", 17)
	_abstain_button.add_theme_color_override("font_color", Color.WHITE)
	_abstain_button.add_theme_stylebox_override("normal", _button_style(Color("4f5960"), Color("d5e0df")))
	_abstain_button.add_theme_stylebox_override("hover", _button_style(Color("65747a"), PAPER))
	_abstain_button.pressed.connect(func() -> void: _submit(""))
	add_child(_abstain_button)
	if stage >= 3:
		_program_button = Button.new()
		_program_button.name = "OpenProgramList"
		_program_button.text = "打开节目单"
		_program_button.position = Vector2(790.0, 610.0)
		_program_button.size = Vector2(240.0, 48.0)
		_program_button.visible = false
		_program_button.add_theme_font_size_override("font_size", 17)
		_program_button.add_theme_color_override("font_color", INK)
		_program_button.add_theme_stylebox_override("normal", _button_style(GOLD, MAGENTA))
		_program_button.add_theme_stylebox_override("hover", _button_style(Color("fff3a5"), MAGENTA))
		_program_button.pressed.connect(_request_program)
		add_child(_program_button)


func _set_buttons_disabled(disabled: bool) -> void:
	for button: Button in _buttons:
		button.disabled = disabled
	if _abstain_button != null:
		_abstain_button.disabled = disabled


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


func _candidate_text(record: Dictionary) -> String:
	var id := str(record.get("instance_id", ""))
	var chance := float(probability_map.get(id, 0.0)) * 100.0
	var hp := maxi(0, int(record.get("hp_lost", 0)))
	var score := DreamDrawRules.token_score(record)
	var image_note := "房间图：已提供" if str(record.get("thumbnail_path", "")).strip_edges() != "" else "房间图：暂无缩略图，使用文字回顾"
	return "交给节目：%s    受伤经历 %d    信物分 %d    当前概率 %.1f%%    %s" % [str(record.get("name", record.get("room_id", id))), hp, score, chance, image_note]


func _recap_text() -> String:
	if bool(result.get("abstained", false)):
		return "本阶段你选择了弃权；节目仍从已走过的房间中抽片。"
	var selected_id := str(result.get("selected_id", ""))
	var selected: Dictionary = {}
	for record: Dictionary in records:
		if str(record.get("instance_id", "")) == selected_id:
			selected = record
			break
	if selected.is_empty():
		return "节目已完成抽片。"
	var base := "节目选中了%s：你在这里损失了%d点生命。" % [str(selected.get("name", selected_id)), int(selected.get("hp_lost", 0))]
	if stage >= 3:
		return base + " 节目单入口：三份素材已汇总，进入终幕节目单。"
	return base + " 阶段素材提示：它会成为终幕的一项来源。"


func _read_program_entry() -> Dictionary:
	var saved: Variant = result.get("program_entry", {})
	if saved is Dictionary and not (saved as Dictionary).is_empty():
		return (saved as Dictionary).duplicate(true)
	var source_ids: Array[String] = []
	for record: Dictionary in records:
		var id := str(record.get("instance_id", ""))
		if id == str(result.get("selected_id", "")) or id.is_empty():
			continue
		source_ids.append(id)
	return {"type": "dream_finale_program", "version": 1, "status": "awaiting_dream_finale_profile", "source_ids": source_ids}


func show_program_placeholder(program_entry: Dictionary) -> void:
	if stage < 3 or _program_button == null:
		var empty_records: Array[Dictionary] = []
		show_candidates(3, empty_records, {})
		reveal_only = true
		reveal_finished_once = true
		result = {"stage": 3, "program_entry": program_entry.duplicate(true)}
	_program_entry = program_entry.duplicate(true)
	if _program_button != null:
		_program_button.visible = true
	var source_ids: Array = _program_entry.get("source_ids", [])
	_message = "节目单已打开：%d 份素材已锁定；终幕规则将在节目配置阶段接入。" % source_ids.size()
	visible = true
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("091116f7"), true)
	draw_rect(Rect2(110.0, 88.0, 1060.0, 620.0), Color("171d26fa"), true)
	draw_rect(Rect2(110.0, 88.0, 1060.0, 620.0), MAGENTA, false, 3.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(220.0, 140.0), "第 %d 阶段 · 把房间交给节目" % stage, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, GOLD)
	draw_string(font, Vector2(220.0, 169.0), "候选只来自你走过的房间；概率受受伤经历影响，信物分只用于说明价值。", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
	draw_string(font, Vector2(220.0, 189.0), _message, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffe8c8"))
	if revealing:
		draw_string(font, Vector2(475.0, 570.0), "轮盘正在转动……", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, MAGENTA)
	elif reveal_finished_once:
		draw_string(font, Vector2(220.0, 575.0), _message, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEAL)
