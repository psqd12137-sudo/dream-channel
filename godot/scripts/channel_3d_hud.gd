extends Control

const PLAYER_PROFILE = preload("res://assets/web_show/characters/lili/bust.png")
const ENEMY_PROFILE = preload("res://assets/web_show/characters/enemy/bust.png")
const OMEN_ICON = preload("res://assets/latest_web/OmenIcon.png")
const COMBAT_UI_LAYOUT = preload("res://scenes/combat_ui_layout.tscn")
const CARD_BACK_BLUE = preload("res://assets/ui/channel_concept/card_blue.png")
const CARD_BACK_RED = preload("res://assets/ui/channel_concept/card_red.png")
const CARD_BACK_YELLOW = preload("res://assets/ui/channel_concept/card_yellow.png")
const CARD_FRAME_YELLOW = preload("res://assets/ui/cards/Front_Yellow.png")
const CARD_FRAME_BLUE = preload("res://assets/ui/cards/Front_Blue.png")
const CARD_FRAME_RED = preload("res://assets/ui/cards/Front_Red.png")
const EVENT_PANEL_TEXTURE = preload("res://assets/ui/channel_concept/UI_HUD_Panel_EventProgram_Normal.png")
const ACTION_PANEL_TEXTURE = preload("res://assets/ui/channel_concept/UI_HUD_Panel_ActionPanel_Normal.png")
const BTN_START_TEXTURE = preload("res://assets/ui/unity_buttons/SP_StartGame.png")
const BTN_END_TEXTURE = preload("res://assets/ui/unity_buttons/SP_EndGame.png")
const BTN_MENU_TEXTURE = preload("res://assets/ui/unity_buttons/SP_Menu.png")

const INK := Color("171c25")
const DARK := Color("101820")
const DARK_2 := Color("1e2834")
const PAPER := Color("f8e9c7")
const PAPER_2 := Color("e7cfa4")
const TEXT := Color("fff5df")
const MUTED := Color("aac4bf")
const TEAL := Color("22aa9b")
const GOLD := Color("f3a51f")
const MAGENTA := Color("d63b72")
const GREEN := Color("66b76d")
const RED := Color("d9574f")
const BLUE := Color("4c92bd")

const DESIGN_SIZE := Vector2(1280, 800)
const HOUSE_VIEW_RECT := Rect2(20, 88, 968, 586)
const BUILD_VIEW_RECT := Rect2(20, 88, 968, 376)
const COMBAT_VIEW_RECT := Rect2(20, 88, 1244, 540)

const RESET_RECT := Rect2(1142, 17, 110, 38)
const CAMERA_RESET_RECT := Rect2(1040, 19, 94, 34)
const OMEN_A_RECT := Rect2(300, 570, 260, 46)
const OMEN_B_RECT := Rect2(720, 570, 260, 46)
const BUILD_CARD_RECTS := [Rect2(44, 526, 210, 150), Rect2(270, 526, 210, 150), Rect2(496, 526, 210, 150)]
const BUILD_ROTATE_RECT := Rect2(734, 526, 230, 42)
const BUILD_PLACE_RECT := Rect2(734, 580, 230, 48)
const BUILD_CANCEL_RECT := Rect2(734, 640, 230, 38)
const ROOM_ACTION_RECT := Rect2(1020, 682, 220, 50)
const ENTER_PENDING_RECT := Rect2(1020, 620, 220, 46)
const END_TURN_RECT := Rect2(1015, 736, 230, 48)
const RETURN_RECT := Rect2(1015, 736, 230, 48)
const CARD_CANCEL_RECT := Rect2(1015, 700, 230, 28)
const PORTAL_USE_RECT := Rect2(960, 262, 120, 44)
const PORTAL_STAY_RECT := Rect2(1100, 262, 120, 44)
const HOME_START_RECT := Rect2(80, 350, 320, 56)
const HOME_TUTORIAL_RECT := Rect2(80, 418, 154, 44)
const HOME_CONTINUE_RECT := Rect2(246, 418, 154, 44)
const HOME_SEED_INPUT_RECT := Rect2(92, 516, 296, 38)
const HOME_SEED_START_RECT := Rect2(92, 564, 142, 38)
const HOME_SEED_COPY_RECT := Rect2(246, 564, 142, 38)
const HOME_TESTS_RECT := Rect2(1060, 20, 172, 34)
const HOME_TEST_COMBAT_RECT := Rect2(780, 120, 205, 42)
const HOME_TEST_SIDE_RECT := Rect2(997, 120, 205, 42)
const HOME_TEST_PUZZLE_RECT := Rect2(780, 174, 205, 42)
const HOME_TEST_SEARCH_RECT := Rect2(997, 174, 205, 42)
const HOME_TEST_CHASE_RECT := Rect2(780, 228, 205, 42)
const HOME_TEST_DIORAMA_RECT := Rect2(997, 228, 205, 42)
const HOME_TEST_CHARACTER_ANIMATION_RECT := Rect2(780, 282, 422, 42)
const HOME_RESOLUTION_RECT := Rect2(780, 670, 190, 38)
const HOME_WINDOW_MODE_RECT := Rect2(982, 670, 105, 38)
const HOME_QUIT_RECT := Rect2(1099, 670, 105, 38)
const CHARACTER_IDLE_RECT := Rect2(32, 222, 130, 38)
const CHARACTER_STEP_RECT := Rect2(166, 222, 130, 38)
const CHARACTER_ATTACK_RECT := Rect2(32, 270, 130, 38)
const CHARACTER_HURT_RECT := Rect2(166, 270, 130, 38)
const LAB_EXIT_RECT := Rect2(1100, 28, 150, 40)
const LAB_REROLL_RECT := Rect2(520, 86, 180, 32)
const LAB_HAND_RECT := Rect2(720, 86, 200, 32)
const LAB_SWITCH_RECT := Rect2(940, 86, 220, 32)
const PUZZLE_REFRESH_RECT := Rect2(850, 650, 190, 44)
const CHASE_START_RECT := Rect2(480, 590, 190, 48)
const CHASE_FORFEIT_RECT := Rect2(690, 590, 190, 48)
const REWARD_CARD_RECTS := [Rect2(205, 230, 260, 330), Rect2(510, 230, 260, 330), Rect2(815, 230, 260, 330)]
const REWARD_SKIP_RECT := Rect2(520, 590, 240, 44)

var game = null
var combat_card_rects: Array[Rect2] = []
var ui_scale := 1.0
var ui_offset := Vector2.ZERO
var world_view_rect_screen := HOUSE_VIEW_RECT
var middle_dragging := false
var last_layout_size := Vector2.ZERO
var last_layout_phase := ""
var side_left := false
var side_right := false
var combat_ui_layout: Control
var seed_input: LineEdit
var hovered_combat_card := -1
var combat_card_hover_amount := 0.0
var dragged_combat_card := -1
var dragged_card_position := Vector2.ZERO
var card_flight_offsets: Dictionary = {}
var card_flight_tweens: Dictionary = {}
var card_exit_alphas: Dictionary = {}
var card_icon_cache: Dictionary = {}
var exiting_cards: Array[Dictionary] = []
var last_hand_key := ""
var deck_flight_origin := Vector2(78, 710)
var discard_flight_origin := Vector2(930, 710)
var board_left_pressed := false
var board_left_dragged := false
var board_left_distance := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	combat_ui_layout = COMBAT_UI_LAYOUT.instantiate()
	combat_ui_layout.visible = false
	add_child(combat_ui_layout)
	seed_input = LineEdit.new()
	seed_input.name = "SeedInput"
	seed_input.placeholder_text = "输入种子码"
	seed_input.max_length = 10
	seed_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_input.add_theme_color_override("font_color", TEXT)
	seed_input.add_theme_color_override("font_placeholder_color", Color("b9a9c3"))
	var seed_style := StyleBoxFlat.new()
	seed_style.bg_color = Color("17101fd9")
	seed_style.border_color = Color("8f6aa2")
	seed_style.set_border_width_all(2)
	seed_style.corner_radius_top_left = 3
	seed_style.corner_radius_top_right = 3
	seed_style.corner_radius_bottom_left = 3
	seed_style.corner_radius_bottom_right = 3
	seed_input.add_theme_stylebox_override("normal", seed_style)
	var seed_focus := seed_style.duplicate() as StyleBoxFlat
	seed_focus.border_color = MAGENTA
	seed_input.add_theme_stylebox_override("focus", seed_focus)
	seed_input.text_submitted.connect(_submit_seed_input)
	add_child(seed_input)
	set_process_input(true)
	sync_layout()


func _combat_layout_rect(node_name: String, fallback: Rect2) -> Rect2:
	if combat_ui_layout == null:
		return fallback
	var marker := combat_ui_layout.get_node_or_null(node_name) as Control
	return Rect2(marker.position, marker.size) if marker != null else fallback


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		sync_layout()


func _process(delta: float) -> void:
	if game != null and last_layout_phase != game.phase:
		sync_layout()
	if seed_input != null:
		seed_input.visible = game != null and game.phase == "home"
	# 离开战斗时清理残留的飞行动画状态
	if game != null and game.phase != "combat" and (not card_flight_offsets.is_empty() or not exiting_cards.is_empty() or not card_flight_tweens.is_empty()):
		for raw_tween: Variant in card_flight_tweens.values():
			var tween: Tween = raw_tween
			if tween != null and tween.is_valid():
				tween.kill()
		card_flight_offsets.clear()
		card_flight_tweens.clear()
		card_exit_alphas.clear()
		exiting_cards.clear()
		last_hand_key = ""
		queue_redraw()
	var target := 1.0 if hovered_combat_card >= 0 and dragged_combat_card < 0 else 0.0
	var previous := combat_card_hover_amount
	combat_card_hover_amount = move_toward(combat_card_hover_amount, target, delta * 8.5)
	if not is_equal_approx(previous, combat_card_hover_amount):
		queue_redraw()
	# 发牌/收牌动效推进（flight offsets 归零后自动清除）
	if not card_flight_offsets.is_empty() or not exiting_cards.is_empty():
		queue_redraw()


func _update_card_flights(old_key: String, new_key: String) -> void:
	# 计算新旧手牌的差异：新增的卡从牌堆飞入，消失的卡飞向弃牌堆
	var old_ids: Array[String] = []
	for raw_id: String in (old_key.split(",") if not old_key.is_empty() else []):
		if not raw_id.is_empty():
			old_ids.append(raw_id)
	var new_ids: Array[String] = []
	for raw_id: String in (new_key.split(",") if not new_key.is_empty() else []):
		if not raw_id.is_empty():
			new_ids.append(raw_id)
	var new_set: Dictionary = {}
	for id: String in new_ids:
		if not id.is_empty():
			new_set[id] = true
	var old_set: Dictionary = {}
	for id: String in old_ids:
		if not id.is_empty():
			old_set[id] = true
	# 新卡：从牌堆位置逐张飞入（stagger 0.09s）
	var deal_index := 0
	for id: String in new_ids:
		if id.is_empty() or old_set.has(id):
			continue
		if card_flight_offsets.has(id):
			card_flight_offsets.erase(id)
		var start_offset := deck_flight_origin - _hand_card_anchor_position(id, new_ids)
		card_flight_offsets[id] = start_offset
		_tween_card_flight(id, Vector2.ZERO, 0.26, 0.09 * float(deal_index))
		deal_index += 1
	# 消失的卡：进入离场列表，逐张飞向弃牌堆并淡出
	var discard_index := 0
	for id: String in old_ids:
		if id.is_empty() or new_set.has(id):
			continue
		var card_data: Dictionary = combat_cards().get(id, {})
		var anchor := _hand_card_anchor_position(id, old_ids)
		exiting_cards.append({"id": id, "from": anchor, "position": anchor, "alpha": 1.0, "kind": str(card_data.get("type", "skill"))})
		_tween_exit_flight(id, 0.09 * float(discard_index))
		discard_index += 1


func _hand_card_anchor_position(card_id: String, hand_ids: Array) -> Vector2:
	# 估算卡在错落手牌中的目标位置（供飞行动画起点计算）
	var idx := hand_ids.find(card_id)
	if idx < 0:
		return Vector2(250, 700)
	var hand_rect := _combat_layout_rect("HandArea", Rect2(170, 470, 940, 290))
	var count := maxi(1, hand_ids.size())
	var card_width := 120.0
	var card_height := minf(card_width * 1.66, hand_rect.size.y - 8.0)
	var spacing := card_width * 0.62
	var total_width := card_width + spacing * maxf(0.0, float(count - 1))
	var start_x := hand_rect.position.x + (hand_rect.size.x - total_width) * 0.5
	var x := start_x + float(idx) * spacing
	var stagger := (float(posmod(idx, 3)) - 1.0) * 5.0
	var base_y := hand_rect.end.y - card_height - 6.0 + stagger
	return Vector2(x + card_width * 0.5, base_y + card_height * 0.5)


func _tween_card_flight(card_id: String, target_offset: Vector2, duration: float = 0.26, delay: float = 0.0) -> void:
	if card_flight_tweens.has(card_id):
		var existing: Tween = card_flight_tweens[card_id]
		if existing != null and existing.is_valid():
			existing.kill()
	var start_offset: Vector2 = card_flight_offsets.get(card_id, target_offset)
	var flight := create_tween()
	card_flight_tweens[card_id] = flight
	if delay > 0.0:
		flight.tween_interval(delay)
	flight.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flight.tween_method(_apply_card_flight.bind(card_id), start_offset, target_offset, duration)
	flight.tween_callback(_finish_card_flight.bind(card_id))


func _tween_exit_flight(card_id: String, delay: float = 0.0) -> void:
	# 离场卡：从手牌位置飞向弃牌堆，同时淡出；逐张 stagger
	var exit_tween := create_tween()
	if delay > 0.0:
		exit_tween.tween_interval(delay)
	exit_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit_tween.tween_method(_apply_exit_card_flight.bind(card_id), 0.0, 1.0, 0.22)
	exit_tween.tween_callback(_finish_exit_card.bind(card_id))


func _apply_card_flight(offset: Vector2, card_id: String) -> void:
	card_flight_offsets[card_id] = offset
	queue_redraw()


func _apply_exit_card_flight(weight: float, card_id: String) -> void:
	for entry: Dictionary in exiting_cards:
		if str(entry.get("id", "")) == card_id:
			var start: Vector2 = entry.get("from", Vector2.ZERO)
			entry["position"] = start.lerp(discard_flight_origin, weight)
			entry["alpha"] = 1.0 - weight
			queue_redraw()
			return


func _finish_exit_card(card_id: String) -> void:
	for i in range(exiting_cards.size() - 1, -1, -1):
		if str((exiting_cards[i] as Dictionary).get("id", "")) == card_id:
			exiting_cards.remove_at(i)
			break
	queue_redraw()


func _finish_card_flight(card_id: String) -> void:
	card_flight_offsets.erase(card_id)
	card_flight_tweens.erase(card_id)
	card_exit_alphas.erase(card_id)
	queue_redraw()


func combat_cards() -> Dictionary:
	if game != null and game.combat != null:
		return game.combat.cards
	return {}


func sync_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x < 1.0 or viewport_size.y < 1.0:
		viewport_size = size
	last_layout_phase = game.phase if game != null else ""
	var layout := calculate_layout(viewport_size, last_layout_phase)
	ui_scale = float(layout["scale"])
	ui_offset = layout["offset"]
	world_view_rect_screen = layout["board_rect"]
	last_layout_size = viewport_size
	if game != null:
		game.set_world_view_rect(world_view_rect_screen)
	_sync_seed_input_layout()
	queue_redraw()


func _sync_seed_input_layout() -> void:
	if seed_input == null:
		return
	var rect := _scale_rect(HOME_SEED_INPUT_RECT, ui_scale, ui_offset)
	seed_input.position = rect.position
	seed_input.size = rect.size
	seed_input.add_theme_font_size_override("font_size", maxi(11, roundi(14.0 * ui_scale)))
	seed_input.visible = game != null and game.phase == "home"


func _submit_seed_input(_submitted_text: String = "") -> void:
	if game == null or not game.start_run_from_seed_text(seed_input.text):
		seed_input.text = ""
		seed_input.placeholder_text = "请输入 1-9999999999"
		return
	seed_input.text = ""
	seed_input.release_focus()
	_sync_seed_input_layout()


func calculate_layout(viewport_size: Vector2, phase_name: String) -> Dictionary:
	var scale_value := minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	scale_value = maxf(0.1, scale_value)
	var offset_value := (viewport_size - DESIGN_SIZE * scale_value) * 0.5
	var board_design := _design_world_rect(phase_name)
	var coach_design := Rect2(20, 690, 968, 68) if phase_name == "combat" else Rect2(20, 686, 968, 74)
	return {
		"scale": scale_value,
		"offset": offset_value,
		"board_rect": _scale_rect(board_design, scale_value, offset_value),
		"top_rect": _scale_rect(Rect2(0, 0, 1280, 72), scale_value, offset_value),
		"side_rect": _scale_rect(Rect2(1004, 88, 260, 680), scale_value, offset_value),
		"coach_rect": _scale_rect(coach_design, scale_value, offset_value),
	}


func get_world_view_rect() -> Rect2:
	return world_view_rect_screen


func _design_world_rect(phase_name: String) -> Rect2:
	if phase_name == "combat":
		return COMBAT_VIEW_RECT
	if phase_name in ["lab_sideview", "lab_search", "lab_diorama", "lab_pcg_diorama", "lab_hand_diorama"]:
		return Rect2(60, 120, 1160, 520)
	if phase_name == "lab_puzzle" or phase_name == "home":
		return Rect2(0, 84, 1280, 716)
	if phase_name == "build":
		return BUILD_VIEW_RECT
	return HOUSE_VIEW_RECT


func _scale_rect(rect: Rect2, scale_value: float, offset_value: Vector2) -> Rect2:
	return Rect2(offset_value + rect.position * scale_value, rect.size * scale_value)


func _to_design(point: Vector2) -> Vector2:
	return (point - ui_offset) / maxf(0.001, ui_scale)


func _ensure_input_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x > 0.0 and viewport_size.y > 0.0 and not last_layout_size.is_equal_approx(viewport_size):
		sync_layout()


func _draw() -> void:
	if game == null:
		return
	if not last_layout_size.is_equal_approx(size):
		sync_layout()
	draw_set_transform(ui_offset, 0.0, Vector2(ui_scale, ui_scale))
	if game.phase == "home":
		_draw_home()
		return
	if game.phase == "reward":
		_draw_top_bar()
		_draw_reward_modal()
		return
	var board_design := _design_world_rect(game.phase)
	if game.phase != "lab_puzzle":
		draw_rect(board_design.grow(4.0), Color("091116"), false, 8.0)
		if game.phase == "combat":
			draw_rect(board_design.grow(-2.0), Color("0a1218cc"), true)
		else:
			draw_rect(board_design, TEAL if game.phase != "combat" else GOLD, false, 2.0)
	_draw_top_bar()
	if game.phase == "combat":
		_draw_combat_hud()
	elif game.phase.begins_with("lab_"):
		_draw_lab_hud()
	else:
		_draw_house_hud()
	if game.phase == "omen":
		_draw_omen_modal()


func _draw_top_bar() -> void:
	draw_rect(Rect2(0, 0, DESIGN_SIZE.x, 72), Color("101820f4"), true)
	draw_rect(Rect2(0, 69, DESIGN_SIZE.x, 3), TEAL, true)
	_label("织梦频道", Vector2(24, 29), 21, TEXT)
	_label("第 %02d 集 · 种子 %010d" % [game.run_progress, game.run_seed], Vector2(24, 52), 11, Color("70cdbf"))
	if game.phase == "combat":
		_draw_chip(Rect2(800, 18, 112, 32), "集数 %d/%d" % [game.run_progress, int(game.content.get("run_length", 12))], GOLD, INK, 11)
		_draw_chip(Rect2(920, 18, 112, 32), _phase_label(), MAGENTA, TEXT, 11)
	else:
		_draw_chip(Rect2(560, 18, 112, 32), "速度 %d" % int(game.player_speed), TEAL, TEXT, 11)
		_draw_chip(Rect2(680, 18, 112, 32), "生命 %d/%d" % [game.player_hp, game.player_max_hp], RED, TEXT, 11)
		_draw_chip(Rect2(800, 18, 112, 32), "集数 %d/%d" % [game.run_progress, int(game.content.get("run_length", 12))], GOLD, INK, 11)
		_draw_chip(Rect2(920, 18, 112, 32), _phase_label(), Color("344751"), TEXT, 11)
	if game.phase == "combat" or game.phase in ["explore", "build", "room_ready"]:
		_draw_button(CAMERA_RESET_RECT, "镜头复位" if game.phase == "combat" else "地图复位", TEAL, TEXT)
	if not game.phase.begins_with("lab_"):
		_draw_button(RESET_RECT, "回到标题", Color("394852"), TEXT)


func _draw_home() -> void:
	draw_rect(Rect2(0, 0, DESIGN_SIZE.x, DESIGN_SIZE.y), Color(0.04, 0.015, 0.055, 0.48), true)
	draw_rect(Rect2(0, 0, DESIGN_SIZE.x, 68), Color("0d0512e8"), true)
	draw_rect(Rect2(0, 66, DESIGN_SIZE.x, 3), Color("6c3a7e"), true)
	_label("CHANNEL DREAM · CH-198X", Vector2(34, 41), 13, Color("b997c8"))
	_label("今晚播出 · 纸盒片场正在失控", Vector2(84, 132), 13, Color("d7a7e7"))
	_label("织梦频道", Vector2(78, 204), 62, Color("fff7ff"))
	_label("一档会记住你的荒诞儿童玩具秀", Vector2(84, 246), 20, Color("f3c96b"))
	_draw_wrapped("拧开旧电视，走进会咬人的纸盒布景。把道具摆进场地，用走位把怪家伙引进一场场节目事故。", Vector2(84, 286), 470, 15, Color("dfd1e7"))
	_draw_texture_button(HOME_START_RECT, "打开电视机", BTN_START_TEXTURE, Color.WHITE, 15)
	_draw_texture_button(HOME_TUTORIAL_RECT, "新手教学", BTN_END_TEXTURE, Color.WHITE, 14)
	if game.has_saved_run():
		_draw_texture_button(HOME_CONTINUE_RECT, "接着看上集", BTN_END_TEXTURE, Color.WHITE, 13)
	draw_rect(Rect2(72, 482, 336, 132), Color("100b17d9"), true)
	draw_rect(Rect2(72, 482, 336, 132), Color("725184"), false, 2.0)
	_label("自定义播出", Vector2(92, 505), 11, Color("cbb6d4"))
	_draw_button(HOME_SEED_START_RECT, "按种子开局", Color("355e5d"), TEXT)
	_draw_button(HOME_SEED_COPY_RECT, "复制种子", Color("394852"), TEXT)
	_draw_button(HOME_TESTS_RECT, "关闭后台" if game.home_tests_open else "后台测试", Color("34263d"), TEXT)
	if game.home_tests_open:
		draw_rect(Rect2(764, 96, 454, 242), Color("100b17ed"), true)
		draw_rect(Rect2(764, 96, 454, 242), Color("8f6aa2"), false, 2.0)
		_label("节目后台 · 仅供开发检查", Vector2(780, 112), 10, Color("cbb6d4"))
		_draw_button(HOME_TEST_COMBAT_RECT, "战斗意图实验", MAGENTA, TEXT)
		_draw_button(HOME_TEST_SIDE_RECT, "WASD 横版手感", TEAL, TEXT)
		_draw_button(HOME_TEST_PUZZLE_RECT, "八数码拼图", GOLD, INK)
		_draw_button(HOME_TEST_SEARCH_RECT, "3D 微缩搜物", Color("7863a5"), TEXT)
		_draw_button(HOME_TEST_CHASE_RECT, "警察抓小偷", RED, TEXT)
		_draw_button(HOME_TEST_DIORAMA_RECT, "桌模扩建 PCG", Color("5967a8"), TEXT)
		_draw_button(HOME_TEST_CHARACTER_ANIMATION_RECT, "角色动画检查", Color("3e8b78"), TEXT)
	draw_rect(Rect2(764, 626, 454, 96), Color("100b17d9"), true)
	draw_rect(Rect2(764, 626, 454, 96), Color("725184"), false, 2.0)
	_label("显示设置", Vector2(780, 650), 11, Color("cbb6d4"))
	_draw_button(HOME_RESOLUTION_RECT, game.display_resolution_label(), Color("355e5d"), TEXT)
	_draw_button(HOME_WINDOW_MODE_RECT, game.display_mode_label(), Color("394852"), TEXT)
	_draw_button(HOME_QUIT_RECT, "退出", RED, TEXT)
	_label("纸盒布景 · 黏土演员 · 每次开播都是不同的一集", Vector2(84, 734), 13, Color("c9afd5"))


func _draw_lab_hud() -> void:
	_draw_button(LAB_EXIT_RECT, "回到标题", Color("394852"), TEXT)
	if game.phase == "lab_sideview":
		_label("横版手感 · WASD / 方向键 · 空格跳跃", Vector2(78, 108), 18, TEXT)
		_draw_chip(Rect2(870, 82, 180, 32), "信号 %d/3" % game.lab_collected, GOLD, INK, 12)
		_draw_coach(Rect2(60, 660, 1160, 96), "手感实验", game.status_message)
	elif game.phase == "lab_search":
		_label("3D 微缩搜物 · 中键环视 · 滚轮缩放", Vector2(78, 108), 18, TEXT)
		_draw_chip(Rect2(870, 82, 180, 32), "找到 %d/3" % game.search_found, GOLD, INK, 12)
		_draw_coach(Rect2(60, 660, 1160, 96), "搜物实验", game.status_message)
	elif game.phase == "lab_diorama":
		_label("美术增强对比 · 中键环视 · 滚轮缩放", Vector2(78, 108), 18, TEXT)
		_draw_button(LAB_SWITCH_RECT, "查看 PCG 连片", Color("5967a8"), TEXT)
		_draw_coach(Rect2(60, 660, 1160, 96), "灯光与空间层次", game.status_message)
	elif game.phase == "lab_pcg_diorama":
		_label("PCG 连片箱庭 · 中键环视 · 滚轮缩放", Vector2(78, 108), 18, TEXT)
		_draw_button(LAB_REROLL_RECT, "换一个 Seed", GOLD, INK)
		_draw_button(LAB_HAND_RECT, "查看手摆模拟", Color("3e8b78"), TEXT)
		_draw_button(LAB_SWITCH_RECT, "查看 A/B/C 单格", Color("5967a8"), TEXT)
		_draw_coach(Rect2(60, 660, 1160, 96), "拼接规则", game.status_message)
	elif game.phase == "lab_hand_diorama":
		_label("正式地图手摆模拟 · 中键环视 · 滚轮缩放", Vector2(78, 108), 18, TEXT)
		_draw_button(LAB_REROLL_RECT, "返回 PCG", GOLD, INK)
		_draw_button(LAB_SWITCH_RECT, "查看 A/B/C 单格", Color("5967a8"), TEXT)
		_draw_coach(Rect2(60, 660, 1160, 96), "手摆工作流", game.status_message)
	elif game.phase == "lab_puzzle":
		_draw_puzzle()
	elif game.phase == "lab_chase":
		_draw_chase()


func _draw_puzzle() -> void:
	draw_rect(Rect2(235, 120, 810, 620), Color("f8e9c7"), true)
	draw_rect(Rect2(235, 120, 810, 620), INK, false, 3.0)
	_label("雪花拼图", Vector2(285, 174), 30, INK)
	_label("把 1–8 滑回顺序，空格在右下。", Vector2(285, 210), 14, Color("665746"))
	var origin := Vector2(385, 245)
	var tile_size := 118.0
	for i in range(game.puzzle_board.size()):
		var value: int = game.puzzle_board[i]
		var rect := Rect2(origin + Vector2(i % 3, i / 3) * (tile_size + 8.0), Vector2(tile_size, tile_size))
		draw_rect(rect, Color("355e5d") if value > 0 else Color("d7c7a7"), true)
		draw_rect(rect, INK, false, 2.0)
		if value > 0:
			_draw_centered(str(value), rect, 34, TEXT)
	_label("剩余步数 %d · 刷新 %d/3" % [game.puzzle_moves_left, game.puzzle_refreshes_left], Vector2(385, 650), 15, INK)
	_label(game.puzzle_status, Vector2(385, 688), 14, MAGENTA if game.puzzle_moves_left <= 0 else TEAL)
	_draw_button(PUZZLE_REFRESH_RECT, "刷新局面", GOLD if game.puzzle_refreshes_left > 0 else Color("6a6258"), INK)


func _draw_chase() -> void:
	draw_rect(Rect2(160, 130, 960, 540), PAPER, true)
	draw_rect(Rect2(160, 130, 960, 540), INK, false, 3.0)
	_label("警察抓小偷 · 打字追逐", Vector2(210, 185), 28, INK)
	_label("你是小偷：打完整句往门口跑。警察匀速追；打错只闪一下、不清空进度。", Vector2(210, 220), 14, Color("665746"))
	var track := Rect2(220, 285, 840, 64)
	draw_rect(track, Color("d7c7a7"), true)
	draw_rect(track, INK, false, 2.0)
	var police_x := track.position.x + track.size.x * clampf(game.chase_police_progress / game.CHASE_TRACK_LENGTH, 0.0, 1.0)
	var player_x := track.position.x + track.size.x * clampf(game.chase_player_progress / game.CHASE_TRACK_LENGTH, 0.0, 1.0)
	draw_circle(Vector2(police_x, track.get_center().y), 19, RED)
	draw_circle(Vector2(player_x, track.get_center().y), 19, TEAL)
	_label("警", Vector2(police_x - 10, track.get_center().y + 7), 17, TEXT)
	_label("你", Vector2(player_x - 10, track.get_center().y + 7), 17, TEXT)
	_label("门", Vector2(track.end.x - 28, track.position.y - 12), 18, INK)
	var typed: String = str(game.chase_sentence).left(int(game.chase_typed))
	var remaining: String = str(game.chase_sentence).substr(int(game.chase_typed))
	_label(typed, Vector2(245, 430), 21, TEAL)
	var typed_width := ThemeDB.fallback_font.get_string_size(typed, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
	if not remaining.is_empty():
		var next_character := remaining.left(1)
		var next_color: Color = RED if game.chase_miss_flash_remaining > 0.0 else MAGENTA
		_label(next_character, Vector2(245 + typed_width, 430), 21, next_color)
		var next_width := ThemeDB.fallback_font.get_string_size(next_character, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
		_label(remaining.substr(1), Vector2(245 + typed_width + next_width, 430), 21, INK)
	var gap: float = maxf(0.0, game.chase_player_progress - game.chase_police_progress)
	_label("间距 %.1f · 终点 %d · 本句剩 %d 字" % [gap, int(game.CHASE_TRACK_LENGTH), max(0, game.chase_sentence.length() - game.chase_typed)], Vector2(245, 472), 13, Color("665746"))
	if game.chase_phase == "countdown":
		_label(game.chase_countdown_text, Vector2(610, 535), 38, MAGENTA)
	elif not game.chase_result.is_empty():
		_label("逃脱成功" if game.chase_result == "success" else "被追上了", Vector2(555, 535), 28, GREEN if game.chase_result == "success" else RED)
	if game.chase_phase == "ready":
		_draw_button(CHASE_START_RECT, "开始追逐", GOLD, INK)
	_draw_button(CHASE_FORFEIT_RECT, "举手投降", Color("4f5960"), TEXT)
	_draw_coach(Rect2(160, 680, 960, 72), "追逐导播", game.status_message)


func _draw_reward_modal() -> void:
	draw_rect(Rect2(0, 72, DESIGN_SIZE.x, DESIGN_SIZE.y - 72), Color("071116fb"), true)
	_label("本集道具台", Vector2(536, 138), 30, TEXT)
	_label("节目组只准带走一件；它会继续跟着演员参与本集。", Vector2(430, 174), 14, MUTED)
	for i in range(mini(REWARD_CARD_RECTS.size(), game.reward_options.size())):
		var reward: Dictionary = game.reward_options[i]
		var rect: Rect2 = REWARD_CARD_RECTS[i]
		var kind := str(reward.get("kind", "stat"))
		var accent: Color = TEAL if kind == "card" else MAGENTA if kind == "relic" else GOLD
		draw_rect(Rect2(rect.position + Vector2(0, 6), rect.size), Color("03070a"), true)
		draw_rect(rect, PAPER, true)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 12)), accent, true)
		draw_rect(rect, INK, false, 2.0)
		_draw_chip(Rect2(rect.position + Vector2(18, 26), Vector2(86, 24)), _reward_kind_label(kind), accent, TEXT if kind != "stat" else INK, 10)
		var art_rect := Rect2(rect.position + Vector2(54, 58), Vector2(152, 104))
		var reward_icon: Texture2D = _reward_icon(reward)
		if reward_icon != null:
			_draw_texture_contained(reward_icon, art_rect, Color.WHITE)
		else:
			draw_circle(art_rect.get_center(), 42.0, Color(accent, 0.18))
			_draw_centered("+", art_rect, 46, accent)
		_label(_shorten(game.reward_title(reward), 13), rect.position + Vector2(22, 194), 20, INK)
		_draw_wrapped(_shorten(game.reward_description(reward), 66), rect.position + Vector2(22, 226), rect.size.x - 44, 12, Color("584d43"))
		_draw_button(Rect2(rect.position + Vector2(35, 274), Vector2(190, 40)), "带走", accent, TEXT if kind != "stat" else INK)
	_draw_button(REWARD_SKIP_RECT, "什么也不拿", Color("4f5960"), TEXT)


func _draw_house_hud() -> void:
	var room: Dictionary = game.current_room()
	var revealed := bool(room.get("revealed", false)) or bool(room.get("completed", false))
	if game.show_house_diagnostics:
		_draw_chip(Rect2(32, 102, 245, 30), "大房间节奏实验", Color("3e8b78"), TEXT, 11)
		_draw_chip(Rect2(290, 102, 680, 30), game.pcg_cutaway_debug_text(), Color("394852"), TEXT, 10)
		_draw_chip(Rect2(32, 138, 245, 28), game.large_room_mix_debug_text(), Color("654b79"), TEXT, 9)
		_draw_chip(Rect2(290, 138, 500, 28), game.pcg_room_state_debug_text(), Color("46545b"), TEXT, 10)
		_draw_chip(Rect2(802, 138, 168, 28), "小型 + = 扩建口", Color("c88b2f"), INK, 10)
	var side := Rect2(1004, 88, 260, 680)
	draw_rect(side, Color("f8e9c7f5"), true)
	draw_rect(side, INK, false, 3.0)
	draw_rect(Rect2(1004, 88, 8, 680), TEAL, true)
	_label("正在播出", Vector2(1024, 120), 11, Color("806448"))
	_label(str(room.get("name", "玄关")) if revealed else "未知布景", Vector2(1024, 154), 23, INK)
	_draw_chip(Rect2(1024, 170, 116, 30), _room_kind_label(room) if revealed else "信号未解码", _room_kind_color(room) if revealed else Color("4f5960"), TEXT, 11)
	draw_rect(Rect2(1024, 218, 216, 1), Color("bda981"), true)
	_label("本集进度", Vector2(1024, 248), 11, Color("806448"))
	_draw_bar(Rect2(1024, 261, 216, 13), game.run_progress, int(game.content.get("run_length", 12)), GOLD, Color("bba781"))
	_label("%d / %d 个布景" % [game.run_progress, int(game.content.get("run_length", 12))], Vector2(1024, 296), 13, INK)

	_label("随身预兆", Vector2(1024, 338), 11, Color("806448"))
	var omen: Dictionary = game.current_omen()
	if omen.is_empty():
		_label("尚未选择", Vector2(1024, 364), 14, Color("8b6b56"))
	else:
		draw_texture_rect(OMEN_ICON, Rect2(1022, 350, 36, 36), false)
		_label(_shorten(str(omen.get("name", "预兆")), 12), Vector2(1066, 373), 14, Color("834b21"))
		_draw_wrapped(_shorten(str(omen.get("desc", "")), 48), Vector2(1024, 404), 216, 11, Color("594f45"))

	draw_rect(Rect2(1024, 448, 216, 1), Color("bda981"), true)
	_label("导播记录", Vector2(1024, 478), 11, Color("806448"))
	var log_start := maxi(0, game.event_log.size() - 3)
	var y := 503.0
	for i in range(log_start, game.event_log.size()):
		_draw_wrapped("• " + _shorten(str(game.event_log[i]), 30), Vector2(1024, y), 216, 10, Color("554e48"))
		y += 42.0

	if game.phase == "room_ready":
		var action_text := "打开惊吓时间" if str(room.get("kind", "")) == "combat" else "接受考验" if str(room.get("kind", "")) == "event" else "搜查房间"
		_draw_button(ROOM_ACTION_RECT, action_text, MAGENTA if str(room.get("kind", "")) == "combat" else GOLD, INK if str(room.get("kind", "")) != "combat" else TEXT)
	elif game.phase == "explore" and game.pending_room_pos != game.current_room_pos and game._rooms_connected(game.current_room_pos, game.pending_room_pos):
		_draw_button(ENTER_PENDING_RECT, "走进新房间", MAGENTA, TEXT)

	if game.phase == "build":
		_draw_build_dock()
	else:
		_draw_coach(Rect2(20, 686, 968, 74), "导播耳语", game.status_message)


func _draw_build_dock() -> void:
	draw_rect(Rect2(20, 478, 968, 290), Color("111b23f5"), true)
	draw_rect(Rect2(20, 478, 968, 290), Color("6bbeb1"), false, 3.0)
	draw_rect(Rect2(20, 478, 968, 8), TEAL, true)
	_label("下一块布景", Vector2(44, 511), 17, TEXT)
	_label("选票根、对门位、摆上节目台；内容要等演员走进去才揭晓。", Vector2(194, 511), 11, MUTED)
	for i in range(mini(3, game.build_offers.size())):
		var room: Dictionary = game.build_offers[i]
		var rect: Rect2 = BUILD_CARD_RECTS[i]
		var selected: bool = i == int(game.selected_offer)
		draw_rect(Rect2(rect.position + Vector2(0, 4), rect.size), Color("050a0e"), true)
		draw_rect(rect, PAPER, true)
		draw_rect(Rect2(rect.position, Vector2(34, rect.size.y)), GOLD, true)
		draw_rect(rect, TEAL if selected else Color("9f7a55"), false, 4.0 if selected else 2.0)
		if selected and game.can_place_selected_offer():
			_draw_chip(Rect2(rect.position + Vector2(44, 8), Vector2(88, 24)), "可以摆下", GREEN, TEXT, 9)
		_label("?", rect.position + Vector2(10, 74), 26, MAGENTA)
		_label(_shorten(str(room.get("name", "房间")), 9), rect.position + Vector2(44, 66), 17, INK)
		_label("%d格 · %s" % [int(room.get("room_size", 1)), _footprint_label(str(room.get("footprint_kind", "single")))], rect.position + Vector2(44, 94), 10, Color("776553"))
		_label("%s门" % _door_shape(room.get("doors", [])), rect.position + Vector2(44, 116), 10, Color("776553"))
		if selected:
			_label("朝向 %d° · 门：%s" % [game.offer_rotation * 90, _door_text(game.room_rules.rotated_doors(room.get("doors", []), game.offer_rotation))], rect.position + Vector2(44, 138), 9, Color("5e5146"))
	_draw_button(BUILD_ROTATE_RECT, "房间转向 90°", TEAL, TEXT)
	_draw_button(BUILD_PLACE_RECT, "摆上节目台", GREEN if game.can_place_selected_offer() else Color("6a5554"), TEXT)
	_draw_button(BUILD_CANCEL_RECT, "取消扩建", Color("303947"), TEXT)


func _draw_omen_modal() -> void:
	draw_rect(Rect2(0, 72, DESIGN_SIZE.x, DESIGN_SIZE.y - 72), Color("071116f7"), true)
	_label("开播前的两张提词卡", Vector2(438, 148), 30, TEXT)
	_label("频道会兑现其中一条；另一条会被剪掉。", Vector2(492, 184), 14, MUTED)
	for i in range(mini(2, game.omen_options.size())):
		var relic_id: String = game.omen_options[i]
		var relic: Dictionary = game.content.get("relics", {}).get(relic_id, {})
		var x := 270.0 + i * 420.0
		var rect := Rect2(x, 260, 320, 275)
		var accent := TEAL if i == 0 else MAGENTA
		draw_rect(Rect2(rect.position + Vector2(0, 6), rect.size), Color("03070a"), true)
		draw_rect(rect, Color("fff4d8"), true)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 12)), accent, true)
		draw_rect(rect, accent, false, 2.0)
		draw_circle(Vector2(x + 52, 310), 28.0, Color(accent, 0.18))
		draw_texture_rect(OMEN_ICON, Rect2(x + 26, 284, 52, 52), false, Color(1, 1, 1, 0.92))
		_label("A" if i == 0 else "B", Vector2(x + 278, 302), 18, accent)
		_label(_shorten(str(relic.get("name", relic_id)), 12), Vector2(x + 96, 318), 21, INK)
		_draw_chip(Rect2(x + 96, 336, 96, 26), "全程生效", accent, TEXT, 10)
		_draw_wrapped(_shorten(str(relic.get("desc", "")), 80), Vector2(x + 26, 404), 268, 13, Color("584d43"))
	_draw_button(OMEN_A_RECT, "采用 A 提词卡", TEAL, TEXT)
	_draw_button(OMEN_B_RECT, "采用 B 提词卡", MAGENTA, TEXT)


func _draw_combat_hud() -> void:
	var combat = game.combat
	var action_rect := _combat_layout_rect("ActionArea", Rect2(1000, 570, 256, 116))
	var hand_rect := _combat_layout_rect("HandArea", Rect2(170, 470, 940, 290))
	var deck_rect := _combat_layout_rect("DeckArea", Rect2(24, 640, 104, 150))
	var discard_rect := _combat_layout_rect("DiscardArea", Rect2(1152, 640, 104, 150))
	_draw_actor_strip(Rect2(24, 92, 300, 108), PLAYER_PROFILE, "莉莉", GREEN, combat.player_hp, game.player_max_hp, "护盾", combat.player_block, 4, "预备 %s" % ("—" if combat.ready_effect.is_empty() else "已挂载"), _actor_presentation_state("Player"))
	_draw_actor_strip(Rect2(948, 92, 300, 108), ENEMY_PROFILE, combat.enemy_name if combat.enemy_revealed else "怪家伙", MAGENTA, combat.enemy_hp if combat.enemy_revealed else -1, combat.enemy_max_hp, "韧性", combat.enemy_toughness if combat.enemy_revealed else 0, combat.enemy_max_toughness, "T%d · %s" % [combat.enemy_tier, combat.enemy_archetype_label], _actor_presentation_state("Enemy"))

	draw_rect(action_rect, Color("101820f4"), true)
	draw_rect(action_rect, GOLD, false, 3.0)
	_draw_action_ticket(Rect2(action_rect.position + Vector2(10, 8), Vector2(action_rect.size.x - 20, action_rect.size.y - 16)))
	_draw_card_frame_contained(CARD_BACK_BLUE, deck_rect, Color(1, 1, 1, 0.92))
	_draw_card_frame_contained(CARD_BACK_RED, discard_rect, Color(1, 1, 1, 0.92))
	_draw_chip(Rect2(deck_rect.position + Vector2(5, deck_rect.size.y - 25), Vector2(deck_rect.size.x - 10, 22)), "抽牌 %d" % combat.deck.size(), TEAL, TEXT, 10)
	_draw_chip(Rect2(discard_rect.position + Vector2(5, discard_rect.size.y - 25), Vector2(discard_rect.size.x - 10, 22)), "弃牌 %d" % combat.discard.size(), RED, TEXT, 10)
	combat_card_rects.clear()
	var hand_key := ",".join(combat.hand)
	if hand_key != last_hand_key:
		_update_card_flights(last_hand_key, hand_key)
		last_hand_key = hand_key
	var card_width := 120.0
	var card_height := minf(card_width * 1.66, hand_rect.size.y - 8.0)
	var spacing := card_width * 0.62
	var total_width := card_width + spacing * maxf(0.0, float(combat.hand.size() - 1))
	var start_x := hand_rect.position.x + (hand_rect.size.x - total_width) * 0.5
	var base_y := hand_rect.end.y - card_height - 6.0
	var card_draw_entries: Array[Dictionary] = []
	for i in range(combat.hand.size()):
		var x := start_x + float(i) * spacing
		var rect := Rect2(x, base_y, card_width, card_height)
		var card_id := str(combat.hand[i])
		if card_flight_offsets.has(card_id):
			rect.position += card_flight_offsets[card_id]
		if i == game.selected_card:
			rect.position.y -= 8.0
		var stagger := (float(posmod(i, 3)) - 1.0) * 5.0
		rect.position.y += stagger
		if i == hovered_combat_card and dragged_combat_card < 0:
			var hover_scale := lerpf(1.0, 1.16, combat_card_hover_amount)
			var hover_size := rect.size * hover_scale
			var hover_y := lerpf(rect.position.y, hand_rect.position.y - 44.0, combat_card_hover_amount)
			rect = Rect2(Vector2(rect.get_center().x - hover_size.x * 0.5, hover_y), hover_size)
		combat_card_rects.append(rect)
		var card: Dictionary = combat.cards.get(combat.hand[i], {})
		card_draw_entries.append({"index": i, "rect": rect, "id": card_id, "card": card, "cost": combat.card_cost(card), "selected": i == game.selected_card, "tilt": 0.0})
	for entry: Dictionary in card_draw_entries:
		if int(entry["index"]) == hovered_combat_card and dragged_combat_card < 0:
			continue
		_draw_combat_card(entry["rect"], str(entry["id"]), entry["card"], int(entry["cost"]), bool(entry["selected"]), float(entry["tilt"]))
	if hovered_combat_card >= 0 and hovered_combat_card < card_draw_entries.size() and dragged_combat_card < 0:
		var hovered_entry: Dictionary = card_draw_entries[hovered_combat_card]
		_draw_combat_card(hovered_entry["rect"], str(hovered_entry["id"]), hovered_entry["card"], int(hovered_entry["cost"]), bool(hovered_entry["selected"]), 0.0)
	# 离场卡（正在飞向弃牌堆）绘制在手牌之上
	for entry: Dictionary in exiting_cards:
		var exit_id := str(entry.get("id", ""))
		var exit_pos: Vector2 = entry.get("position", discard_flight_origin)
		var exit_alpha := float(entry.get("alpha", 0.0))
		if exit_alpha <= 0.01:
			continue
		var exit_card: Dictionary = combat.cards.get(exit_id, {})
		var exit_rect := Rect2(exit_pos - Vector2(card_width, card_height) * 0.5, Vector2(card_width, card_height))
		_draw_combat_card(exit_rect, exit_id, exit_card, combat.card_cost(exit_card), false, 0.0, exit_alpha)
	if dragged_combat_card >= 0 and dragged_combat_card < combat.hand.size():
		_draw_card_target_arrow(combat_card_rects[dragged_combat_card].get_center(), dragged_card_position)
	if combat.outcome == "":
		if game.character_animation_demo_mode:
			draw_rect(Rect2(24, 214, 300, 130), Color("142d2bee"), true)
			draw_rect(Rect2(24, 214, 300, 130), TEAL, false, 2.0)
			_label("角色动画演示", Vector2(36, 236), 12, TEXT)
			_draw_button(CHARACTER_IDLE_RECT, "待机", Color("355e5d"), TEXT)
			_draw_button(CHARACTER_STEP_RECT, "走一格", TEAL, TEXT)
			_draw_button(CHARACTER_ATTACK_RECT, "攻击", MAGENTA, TEXT)
			_draw_button(CHARACTER_HURT_RECT, "受击", RED, TEXT)
		if combat.player_on_portal():
			draw_rect(Rect2(948, 216, 300, 130), Color("2c2441ee"), true)
			draw_rect(Rect2(948, 216, 300, 130), Color("9a70da"), false, 3.0)
			_label("已站上传送门", Vector2(962, 244), 14, Color("e6d7ff"))
			_draw_button(PORTAL_USE_RECT, "穿门（%d）" % combat.move_cost, Color("7863a5") if combat.can_use_player_portal() else Color("5b515f"), TEXT)
		elif game.selected_card >= 0:
			_draw_button(CARD_CANCEL_RECT, "取消选牌", Color("4f5960"), TEXT)
		_draw_button(END_TURN_RECT, "回合结束", GOLD, INK)
	else:
		_draw_button(RETURN_RECT, "返回节目布景" if combat.outcome == "victory" else "重开本集", GREEN if combat.outcome == "victory" else RED, TEXT)


func _draw_card_target_arrow(start: Vector2, target: Vector2) -> void:
	var distance := start.distance_to(target)
	if distance < 8.0:
		return
	var control := (start + target) * 0.5 + Vector2(0, -minf(92.0, distance * 0.24))
	var points := PackedVector2Array()
	for step in range(17):
		var t := float(step) / 16.0
		var inv := 1.0 - t
		points.append(start * inv * inv + control * 2.0 * inv * t + target * t * t)
	draw_polyline(points, Color("15191fbb"), 9.0, true)
	draw_polyline(points, Color("f3a51f"), 4.0, true)
	var direction := (points[-1] - points[-2]).normalized()
	var side := Vector2(-direction.y, direction.x)
	var arrow := PackedVector2Array([target, target - direction * 22.0 + side * 11.0, target - direction * 22.0 - side * 11.0])
	draw_colored_polygon(arrow, Color("f3a51f"))
	draw_circle(target, 12.0, Color("f3a51f44"))
	draw_circle(target, 12.0, Color("fff0cf"), false, 2.0)


func _draw_actor_strip(rect: Rect2, portrait: Texture2D, title: String, accent: Color, hp: int, max_hp: int, secondary_label: String, secondary_value: int, secondary_max: int, footer: String, action_state: String = "idle") -> void:
	draw_rect(Rect2(rect.position + Vector2(0, 4), rect.size), Color("03070a"), true)
	draw_rect(rect, Color("f6e7c4ee"), true)
	if action_state != "idle":
		var action_color := _presentation_state_color(action_state)
		draw_rect(rect.grow(-3.0), Color(action_color, 0.20), true)
	draw_rect(Rect2(rect.position, Vector2(8, rect.size.y)), accent, true)
	draw_rect(rect, accent, false, 2.0)
	draw_texture_rect(portrait, Rect2(rect.position + Vector2(14, 12), Vector2(62, 88)), false)
	_label(_shorten(title, 14), rect.position + Vector2(88, 25), 16, INK)
	_draw_health_bar(Rect2(rect.position + Vector2(88, 34), Vector2(rect.size.x - 102, 20)), hp, max_hp)
	_label(secondary_label, rect.position + Vector2(88, 72), 10, Color("43535b"))
	_draw_stat_pips(Vector2(rect.position.x + 132, rect.position.y + 66), secondary_value, secondary_max, Color("3f91ad") if secondary_label == "护盾" else MAGENTA)
	_label(_shorten(footer, 24), rect.position + Vector2(88, 96), 10, Color("4a634a"))
	if action_state != "idle":
		_draw_chip(Rect2(rect.end.x - 68, rect.position.y + 8, 58, 24), _presentation_state_label(action_state), _presentation_state_color(action_state), TEXT, 10)


func _draw_health_bar(rect: Rect2, value: int, maximum: int) -> void:
	draw_rect(rect, Color("352c2d"), true)
	if value >= 0 and maximum > 0:
		var ratio := clampf(float(value) / float(maximum), 0.0, 1.0)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), Color("d9574f"), true)
		_draw_centered("♥  %d / %d" % [value, maximum], rect, 11, TEXT)
	else:
		_draw_centered("♥  ? / ?", rect, 11, MUTED)
	draw_rect(rect, Color("823b35"), false, 1.5)


func _draw_stat_pips(origin: Vector2, value: int, maximum: int, color: Color) -> void:
	var shown_max := clampi(maximum, 1, 8)
	for index in range(shown_max):
		var center := origin + Vector2(float(index) * 17.0, 0)
		draw_circle(center, 5.5, color if index < value else Color("958c7c"))
		draw_circle(center, 5.5, Color("27313a"), false, 1.0)


func _actor_presentation_state(actor_name: String) -> String:
	var presenter: Node = game.battle_root.get_node_or_null("%s/Presenter" % actor_name)
	return str(presenter.current_state) if presenter != null else "idle"


func _presentation_state_label(state: String) -> String:
	match state:
		"move": return "移动"
		"ready": return "预备"
		"attack": return "出手"
		"hurt": return "受击"
	return "待机"


func _presentation_state_color(state: String) -> Color:
	match state:
		"move": return TEAL
		"ready": return GOLD
		"attack": return Color("ff7d55")
		"hurt": return Color("ff4f63")
	return PAPER


func _draw_intent_strip(rect: Rect2, intent: Dictionary) -> void:
	var intent_type := str(intent.get("type", "stall"))
	var intent_color := _intent_color(intent_type)
	draw_rect(Rect2(rect.position + Vector2(0, 4), rect.size), Color("03070a"), true)
	draw_texture_rect(EVENT_PANEL_TEXTURE, rect, false, Color(1, 1, 1, 0.66))
	draw_rect(rect.grow(-6.0), Color("222a35c8"), true)
	draw_rect(Rect2(rect.position, Vector2(7, rect.size.y)), intent_color, true)
	draw_circle(rect.position + Vector2(44, 54), 31, Color(intent_color, 0.32))
	draw_circle(rect.position + Vector2(44, 54), 31, intent_color, false, 3.0)
	_draw_centered(_intent_glyph(intent_type), Rect2(rect.position + Vector2(14, 24), Vector2(60, 60)), 27, TEXT)
	_draw_chip(Rect2(rect.position + Vector2(82, 12), Vector2(78, 22)), _intent_mode_label(intent_type), intent_color, TEXT, 9)
	_label(_shorten(str(intent.get("label", "—")), 21), rect.position + Vector2(82, 57), 18, TEXT)
	var hint := str(intent.get("detail", "蓝格=它走，红格=本回合必伤。"))
	_label(_shorten(hint, 38), rect.position + Vector2(82, 78), 9, MUTED)
	_label("敌方 AP", rect.position + Vector2(82, 100), 9, GOLD)
	_draw_stat_pips(rect.position + Vector2(138, 96), game.combat.enemy_action_points, 6, GOLD)


func _intent_color(intent_type: String) -> Color:
	match intent_type:
		"attack": return RED
		"chase": return Color("ff8c42")
		"search": return BLUE
		"patrol": return TEAL
		"ambush": return MAGENTA
	return Color("77838c")


func _intent_glyph(intent_type: String) -> String:
	match intent_type:
		"attack": return "!"
		"chase": return "»"
		"search": return "?"
		"patrol": return "↻"
		"ambush": return "◉"
	return "·"


func _intent_mode_label(intent_type: String) -> String:
	match intent_type:
		"attack": return "攻击"
		"chase": return "追击"
		"search": return "搜索"
		"patrol": return "巡逻"
		"ambush": return "埋伏"
	return "观望"


func _draw_action_ticket(rect: Rect2) -> void:
	draw_texture_rect(ACTION_PANEL_TEXTURE, rect, false, Color(1, 1, 1, 0.78))
	draw_rect(rect.grow(-6.0), Color("f8e9c7d8"), true)
	draw_rect(rect, GOLD, false, 2.0)
	draw_rect(Rect2(rect.position, Vector2(62, rect.size.y)), GOLD, true)
	draw_dashed_line(rect.position + Vector2(70, 8), rect.position + Vector2(70, rect.size.y - 8), Color("9a7045"), 1.5, 6.0)
	_label("速度", rect.position + Vector2(12, 26), 10, Color("684719"))
	_label("S%d" % game.combat.base_speed, rect.position + Vector2(15, 64), 26, INK)
	_label("行动力", rect.position + Vector2(86, 28), 10, Color("7a6044"))
	_label("%d AP" % game.combat.energy, rect.position + Vector2(84, 61), 24, INK)
	_draw_stat_pips(rect.position + Vector2(91, 86), game.combat.energy, game.combat.turn_energy_max, TEAL)
	_label("本回合", rect.position + Vector2(177, 89), 9, Color("7a6044"))


func _draw_combat_card(rect: Rect2, card_id: String, card: Dictionary, cost: int, selected: bool, tilt_deg: float = 0.0, alpha_override: float = -1.0) -> void:
	var kind := str(card.get("type", "skill"))
	var accent := GOLD if kind == "place" else MAGENTA if kind == "ready" else RED if kind == "medicine" else TEAL
	var frame: Texture2D = CARD_FRAME_YELLOW if kind == "place" else CARD_FRAME_RED if kind in ["medicine", "ready"] else CARD_FRAME_BLUE
	var card_scale := rect.size.x / 110.0
	var scaled := func(value: float) -> float: return value * card_scale
	var fade := Color(1, 1, 1, alpha_override if alpha_override >= 0.0 else float(card_exit_alphas.get(card_id, 1.0)))
	var unaffordable: bool = game != null and game.combat != null and cost > int(game.combat.energy)
	if not is_zero_approx(tilt_deg):
		var pivot := rect.get_center()
		draw_set_transform(pivot, deg_to_rad(tilt_deg), Vector2.ONE)
		rect = Rect2(rect.position - pivot, rect.size)
	draw_rect(Rect2(rect.position + Vector2(0, scaled.call(4.0)), rect.size), Color(0.012, 0.027, 0.039, 0.92) * fade, true)
	if frame != null:
		_draw_card_frame_contained(frame, rect, fade)
	else:
		draw_rect(rect, Color(accent.darkened(0.32), 1.0) * fade, true)
	draw_rect(rect, Color(GOLD if selected else accent.darkened(0.30), fade.a), false, scaled.call(4.0 if selected else 1.5))
	var cost_center := rect.position + Vector2(scaled.call(22.0), scaled.call(23.0))
	draw_circle(cost_center, scaled.call(15.0), Color(accent, fade.a))
	draw_circle(cost_center, scaled.call(15.0), Color(INK, fade.a), false, scaled.call(1.5))
	_draw_centered(str(cost), Rect2(cost_center - Vector2.ONE * scaled.call(15.0), Vector2.ONE * scaled.call(30.0)), maxi(9, roundi(scaled.call(14.0))), Color(INK if accent.get_luminance() > 0.55 else TEXT, fade.a))
	_label(_shorten(str(card.get("name", card_id)), 7), rect.position + Vector2(scaled.call(42.0), scaled.call(24.0)), maxi(9, roundi(scaled.call(12.0))), Color(INK, fade.a))
	_label(_card_kind_label(kind), rect.position + Vector2(scaled.call(42.0), scaled.call(42.0)), maxi(7, roundi(scaled.call(8.0))), Color(accent.darkened(0.28), fade.a))
	var art_rect := Rect2(rect.position + Vector2(scaled.call(12.0), scaled.call(52.0)), Vector2(rect.size.x - scaled.call(24.0), scaled.call(78.0)))
	var icon := _card_icon(card_id)
	if icon != null:
		_draw_texture_contained(icon, art_rect, Color(1, 1, 1, 0.98) * fade)
	draw_rect(art_rect, Color(accent.darkened(0.25), fade.a), false, scaled.call(1.3))
	_draw_wrapped_lines(_shorten(str(card.get("text", "")), 36), Vector2(rect.position.x + scaled.call(12.0), art_rect.end.y + scaled.call(12.0)), rect.size.x - scaled.call(24.0), maxi(7, roundi(scaled.call(9.0))), Color("514940", fade.a), 3)
	if unaffordable:
		draw_rect(rect.grow(-scaled.call(4.0)), Color("10182078"), true)
		_draw_chip(Rect2(rect.position + Vector2(scaled.call(18.0), rect.size.y - scaled.call(28.0)), Vector2(rect.size.x - scaled.call(36.0), scaled.call(20.0))), "行动力不足", Color("4d3940"), TEXT, maxi(7, roundi(scaled.call(8.0))))
	if not is_zero_approx(tilt_deg):
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _card_icon(card_id: String) -> Texture2D:
	# 图标纹理缓存：避免动画期间每帧 load()（卡顿主因）
	if card_icon_cache.has(card_id):
		return card_icon_cache[card_id] as Texture2D
	var icon: Texture2D = null
	if game != null:
		var item_path := str((game.presentation.get("items", {}) as Dictionary).get(card_id, ""))
		if not item_path.is_empty():
			icon = load(item_path) as Texture2D
	card_icon_cache[card_id] = icon
	return icon


func _draw_texture_contained(texture: Texture2D, rect: Rect2, modulate: Color = Color.WHITE) -> void:
	if texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var source_size := texture.get_size()
	var fit_scale := minf(rect.size.x / source_size.x, rect.size.y / source_size.y)
	var fitted_size := source_size * fit_scale
	var fitted_rect := Rect2(rect.get_center() - fitted_size * 0.5, fitted_size)
	draw_texture_rect(texture, fitted_rect, false, modulate)


func _draw_card_frame_contained(texture: Texture2D, rect: Rect2, modulate: Color = Color.WHITE) -> void:
	# 按目标 rect 比例从背景原图中裁切一块再拉伸（cover 模式）：
	# 避免把 1208x2048（窄高）的卡面直接拉成 124x154（宽扁）导致变形。
	if texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var source_size := texture.get_size()
	var target_ratio := rect.size.x / rect.size.y
	var source_ratio := source_size.x / source_size.y
	var region := Rect2(Vector2.ZERO, source_size)
	if source_ratio > target_ratio:
		# 原图更宽：裁两侧
		var region_width := source_size.y * target_ratio
		region.position.x = (source_size.x - region_width) * 0.5
		region.size.x = region_width
	else:
		# 原图更窄高：裁上下
		var region_height := source_size.x / target_ratio
		region.position.y = (source_size.y - region_height) * 0.5
		region.size.y = region_height
	draw_texture_rect_region(texture, rect, region, modulate)


func _input(event: InputEvent) -> void:
	if game == null:
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if key_event.pressed and not key_event.echo and game.phase == "lab_chase" and game.chase_phase == "race" and key_event.unicode > 0:
		game.chase_type_character(char(key_event.unicode))
		get_viewport().set_input_as_handled()
		return
	if key_event.pressed and not key_event.echo and game.phase.begins_with("lab_") and key_event.keycode == KEY_ESCAPE:
		if not game.event_context.is_empty():
			game.finish_event_trial(false)
		else:
			game.go_home()
		get_viewport().set_input_as_handled()
		return
	if key_event.pressed and not key_event.echo and game.phase == "lab_puzzle":
		var empty: int = game.puzzle_board.find(0)
		var row: int = empty / 3
		var col: int = empty % 3
		if key_event.keycode in [KEY_A, KEY_LEFT] and col < 2:
			game.puzzle_slide_from_offset(1)
		elif key_event.keycode in [KEY_D, KEY_RIGHT] and col > 0:
			game.puzzle_slide_from_offset(-1)
		elif key_event.keycode in [KEY_W, KEY_UP] and row < 2:
			game.puzzle_slide_from_offset(3)
		elif key_event.keycode in [KEY_S, KEY_DOWN] and row > 0:
			game.puzzle_slide_from_offset(-3)
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if game.phase == "lab_sideview":
		if key_event.keycode in [KEY_A, KEY_LEFT]:
			side_left = key_event.pressed
		if key_event.keycode in [KEY_D, KEY_RIGHT]:
			side_right = key_event.pressed
		var jump := key_event.pressed and key_event.keycode in [KEY_W, KEY_UP, KEY_SPACE]
		game.set_sideview_input(float(int(side_right) - int(side_left)), jump)
		get_viewport().set_input_as_handled()
		return
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE and game.phase == "combat" and game.selected_card >= 0:
		game.cancel_selected_card()
		get_viewport().set_input_as_handled()


func _combat_overlay_has_point(point: Vector2) -> bool:
	if game == null or game.phase != "combat" or game.combat == null:
		return false
	if game.character_animation_demo_mode:
		for rect: Rect2 in [CHARACTER_IDLE_RECT, CHARACTER_STEP_RECT, CHARACTER_ATTACK_RECT, CHARACTER_HURT_RECT]:
			if rect.has_point(point):
				return true
	if game.combat.outcome != "":
		return RETURN_RECT.has_point(point)
	if END_TURN_RECT.has_point(point):
		return true
	if game.combat.player_on_portal() and PORTAL_USE_RECT.has_point(point):
		return true
	return game.selected_card >= 0 and CARD_CANCEL_RECT.has_point(point)


func _house_overlay_has_point(point: Vector2) -> bool:
	if RESET_RECT.has_point(point) or CAMERA_RESET_RECT.has_point(point):
		return true
	if game.phase == "build":
		if BUILD_ROTATE_RECT.has_point(point) or BUILD_PLACE_RECT.has_point(point) or BUILD_CANCEL_RECT.has_point(point):
			return true
		for rect: Rect2 in BUILD_CARD_RECTS:
			if rect.has_point(point):
				return true
	if game.phase == "room_ready":
		return ROOM_ACTION_RECT.has_point(point)
	if game.phase == "explore":
		return ENTER_PENDING_RECT.has_point(point)
	return false


func _gui_input(event: InputEvent) -> void:
	if game == null:
		return
	_ensure_input_layout()
	if event is InputEventMouseMotion:
		var design_point := _to_design(event.position)
		if dragged_combat_card >= 0 and game.phase == "combat":
			dragged_card_position = design_point
			if world_view_rect_screen.has_point(event.position):
				game.set_battle_hover(event.position - world_view_rect_screen.position)
			else:
				game.clear_battle_hover()
			queue_redraw()
			accept_event()
		elif board_left_pressed and game.phase in ["combat", "explore", "build", "room_ready"]:
			board_left_distance += event.relative.length()
			if board_left_distance >= 5.0:
				board_left_dragged = true
				if game.phase == "combat":
					game.orbit_battle_camera(event.relative)
					game.clear_battle_hover()
				else:
					game.orbit_house_camera(event.relative)
					game.clear_house_hover()
			accept_event()
		elif middle_dragging and game.phase == "combat":
			game.pan_battle_camera(event.relative)
			game.clear_battle_hover()
			accept_event()
		elif middle_dragging and game.phase in ["explore", "build", "room_ready"]:
			game.pan_house_camera(event.relative)
			accept_event()
		elif middle_dragging and game.phase in ["lab_search", "lab_diorama", "lab_pcg_diorama", "lab_hand_diorama"]:
			game.orbit_search_camera(event.relative)
			accept_event()
		elif game.phase == "combat":
			var previous_hover := hovered_combat_card
			hovered_combat_card = -1
			for i in range(combat_card_rects.size() - 1, -1, -1):
				if combat_card_rects[i].has_point(design_point):
					hovered_combat_card = i
					break
			if hovered_combat_card >= 0:
				game.clear_battle_hover()
			elif world_view_rect_screen.has_point(event.position):
				game.set_battle_hover(event.position - world_view_rect_screen.position)
			else:
				game.clear_battle_hover()
			if previous_hover != hovered_combat_card:
				queue_redraw()
		else:
			game.clear_battle_hover()
			if game.phase == "explore" and world_view_rect_screen.has_point(event.position):
				game.set_house_hover(event.position - world_view_rect_screen.position)
			else:
				game.clear_house_hover()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event
	var point: Vector2 = _to_design(mouse_event.position)
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed and game.phase == "combat" and game.selected_card >= 0:
		game.cancel_selected_card()
		accept_event()
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and game.phase == "combat":
		if not mouse_event.pressed and dragged_combat_card >= 0:
			var dropped_on_board := world_view_rect_screen.has_point(mouse_event.position) and not _combat_overlay_has_point(point)
			dragged_combat_card = -1
			hovered_combat_card = -1
			if dropped_on_board:
				game.handle_screen_click(mouse_event.position - world_view_rect_screen.position)
			elif game.selected_card >= 0:
				game.cancel_selected_card("卡牌没有放到战场格，已返回手牌。")
			game.clear_battle_hover()
			queue_redraw()
			accept_event()
			return
		if not mouse_event.pressed and board_left_pressed:
			var should_click := not board_left_dragged and world_view_rect_screen.has_point(mouse_event.position)
			var was_dragged := board_left_dragged
			board_left_pressed = false
			board_left_dragged = false
			board_left_distance = 0.0
			if was_dragged:
				game.release_battle_camera_gesture()
			if should_click:
				game.handle_screen_click(mouse_event.position - world_view_rect_screen.position)
			accept_event()
			return
		if mouse_event.pressed:
			for i in range(combat_card_rects.size() - 1, -1, -1):
				if not combat_card_rects[i].has_point(point):
					continue
				var card: Dictionary = game.combat.cards.get(game.combat.hand[i], {})
				game.select_or_play_card(i)
				if str(card.get("type", "")) == "place" and game.selected_card == i:
					dragged_combat_card = i
					dragged_card_position = point
				queue_redraw()
				accept_event()
				return
			if world_view_rect_screen.has_point(mouse_event.position) and not _combat_overlay_has_point(point):
				board_left_pressed = true
				board_left_dragged = false
				board_left_distance = 0.0
				accept_event()
				return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and game.phase in ["explore", "build", "room_ready"]:
		if not mouse_event.pressed and board_left_pressed:
			var should_click := not board_left_dragged and world_view_rect_screen.has_point(mouse_event.position)
			var was_dragged := board_left_dragged
			board_left_pressed = false
			board_left_dragged = false
			board_left_distance = 0.0
			if was_dragged:
				game.release_house_camera_gesture()
			if should_click:
				game.handle_screen_click(mouse_event.position - world_view_rect_screen.position)
			accept_event()
			return
		if mouse_event.pressed and world_view_rect_screen.has_point(mouse_event.position) and not _house_overlay_has_point(point):
			board_left_pressed = true
			board_left_dragged = false
			board_left_distance = 0.0
			accept_event()
			return
	if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
		if mouse_event.pressed and game.phase in ["combat", "explore", "build", "room_ready", "lab_search", "lab_diorama", "lab_pcg_diorama", "lab_hand_diorama"] and world_view_rect_screen.has_point(mouse_event.position):
			middle_dragging = true
			if game.phase == "combat":
				game.clear_battle_hover()
			accept_event()
		elif not mouse_event.pressed:
			middle_dragging = false
			if game.phase in ["explore", "build", "room_ready"]:
				game.release_house_camera_gesture()
			elif game.phase == "combat":
				game.release_battle_camera_gesture()
			accept_event()
		return
	if mouse_event.pressed and game.phase == "combat" and world_view_rect_screen.has_point(mouse_event.position):
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			game.zoom_battle_camera(mouse_event.position - world_view_rect_screen.position, 0.9)
			accept_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			game.zoom_battle_camera(mouse_event.position - world_view_rect_screen.position, 1.1)
			accept_event()
			return
	if mouse_event.pressed and game.phase in ["explore", "build", "room_ready"] and world_view_rect_screen.has_point(mouse_event.position):
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			game.zoom_house_camera(mouse_event.position - world_view_rect_screen.position, 0.9)
			accept_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			game.zoom_house_camera(mouse_event.position - world_view_rect_screen.position, 1.1)
			accept_event()
			return
	if mouse_event.pressed and game.phase in ["lab_search", "lab_diorama", "lab_pcg_diorama", "lab_hand_diorama"] and world_view_rect_screen.has_point(mouse_event.position):
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			game.zoom_search_camera(0.9)
			accept_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			game.zoom_search_camera(1.1)
			accept_event()
			return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if game.phase == "home":
		if HOME_START_RECT.has_point(point):
			game.start_new_run(false)
		elif HOME_TUTORIAL_RECT.has_point(point):
			game.start_new_run(true)
		elif game.has_saved_run() and HOME_CONTINUE_RECT.has_point(point):
			game.continue_saved_run()
		elif HOME_SEED_START_RECT.has_point(point):
			_submit_seed_input()
		elif HOME_SEED_COPY_RECT.has_point(point):
			game.copy_current_seed()
		elif HOME_TESTS_RECT.has_point(point):
			game.toggle_home_tests()
		elif game.home_tests_open and HOME_TEST_COMBAT_RECT.has_point(point):
			game.start_combat_lab("hall")
		elif game.home_tests_open and HOME_TEST_SIDE_RECT.has_point(point):
			game.start_sideview_lab()
		elif game.home_tests_open and HOME_TEST_PUZZLE_RECT.has_point(point):
			game.start_puzzle_lab()
		elif game.home_tests_open and HOME_TEST_SEARCH_RECT.has_point(point):
			game.start_search_lab()
		elif game.home_tests_open and HOME_TEST_CHASE_RECT.has_point(point):
			game.start_chase_lab()
		elif game.home_tests_open and HOME_TEST_DIORAMA_RECT.has_point(point):
			game.start_kenney_build_lab()
		elif game.home_tests_open and HOME_TEST_CHARACTER_ANIMATION_RECT.has_point(point):
			game.start_character_animation_lab()
		elif HOME_RESOLUTION_RECT.has_point(point):
			game.cycle_display_resolution()
		elif HOME_WINDOW_MODE_RECT.has_point(point):
			game.toggle_display_mode()
		elif HOME_QUIT_RECT.has_point(point):
			game.quit_game()
		return
	if game.phase.begins_with("lab_"):
		if LAB_EXIT_RECT.has_point(point):
			if not game.event_context.is_empty():
				game.finish_event_trial(false)
			else:
				game.go_home()
			return
		if game.phase == "lab_diorama" and LAB_SWITCH_RECT.has_point(point):
			game.start_pcg_diorama_lab()
			return
		if game.phase == "lab_pcg_diorama":
			if LAB_REROLL_RECT.has_point(point):
				game.reroll_pcg_diorama()
			elif LAB_HAND_RECT.has_point(point):
				game.start_pcg_hand_layout_lab()
			elif LAB_SWITCH_RECT.has_point(point):
				game.start_diorama_art_lab()
			return
		if game.phase == "lab_hand_diorama":
			if LAB_REROLL_RECT.has_point(point):
				game.start_pcg_diorama_lab()
			elif LAB_SWITCH_RECT.has_point(point):
				game.start_diorama_art_lab()
			return
		if game.phase == "lab_puzzle":
			var origin := Vector2(385, 245)
			var tile_size := 118.0
			for i in range(game.puzzle_board.size()):
				var rect := Rect2(origin + Vector2(i % 3, i / 3) * (tile_size + 8.0), Vector2(tile_size, tile_size))
				if rect.has_point(point):
					game.puzzle_slide(i)
					return
			if PUZZLE_REFRESH_RECT.has_point(point):
				game.puzzle_refresh()
			return
		if game.phase == "lab_search" and world_view_rect_screen.has_point(mouse_event.position):
			game.search_pick_from_view(mouse_event.position - world_view_rect_screen.position)
			return
		if game.phase == "lab_chase":
			if CHASE_START_RECT.has_point(point):
				game.begin_chase()
			elif CHASE_FORFEIT_RECT.has_point(point):
				game.forfeit_chase()
			return
	if game.phase == "reward":
		for i in range(mini(REWARD_CARD_RECTS.size(), game.reward_options.size())):
			if REWARD_CARD_RECTS[i].has_point(point):
				game.choose_reward(i)
				return
		if REWARD_SKIP_RECT.has_point(point):
			game.skip_reward()
		return
	if RESET_RECT.has_point(point):
		game.go_home()
		return
	if game.phase == "combat" and CAMERA_RESET_RECT.has_point(point):
		game.reset_battle_camera()
		return
	if game.phase in ["explore", "build", "room_ready"] and CAMERA_RESET_RECT.has_point(point):
		game.reset_house_camera()
		return
	if game.phase == "omen":
		if OMEN_A_RECT.has_point(point):
			game.choose_omen(0)
		elif OMEN_B_RECT.has_point(point):
			game.choose_omen(1)
		return
	if game.phase == "build":
		for i in range(mini(BUILD_CARD_RECTS.size(), game.build_offers.size())):
			if BUILD_CARD_RECTS[i].has_point(point):
				game.select_offer(i)
				return
		if BUILD_ROTATE_RECT.has_point(point):
			game.rotate_offer()
		elif BUILD_PLACE_RECT.has_point(point):
			game.place_selected_offer()
		elif BUILD_CANCEL_RECT.has_point(point):
			game.cancel_build()
		return
	if game.phase == "room_ready" and ROOM_ACTION_RECT.has_point(point):
		game.resolve_current_room()
		return
	if game.phase == "explore" and ENTER_PENDING_RECT.has_point(point) and game._rooms_connected(game.current_room_pos, game.pending_room_pos):
		game.enter_room(game.pending_room_pos)
		return
	if game.phase == "combat":
		if game.character_animation_demo_mode:
			if CHARACTER_IDLE_RECT.has_point(point):
				game.demo_character_idle()
				return
			if CHARACTER_STEP_RECT.has_point(point):
				game.demo_character_grid_step()
				return
			if CHARACTER_ATTACK_RECT.has_point(point):
				game.demo_character_attack()
				return
			if CHARACTER_HURT_RECT.has_point(point):
				game.demo_character_hurt()
				return
		if game.combat.player_on_portal() and PORTAL_USE_RECT.has_point(point):
			game.use_player_portal()
			return
		if game.selected_card >= 0 and CARD_CANCEL_RECT.has_point(point):
			game.cancel_selected_card()
			return
		if game.combat.outcome != "" and RETURN_RECT.has_point(point):
			game.return_from_combat()
			return
		if game.combat.outcome == "" and END_TURN_RECT.has_point(point):
			game.end_combat_turn()
			return
		for i in range(combat_card_rects.size()):
			if combat_card_rects[i].has_point(point):
				game.select_or_play_card(i)
				return
	if world_view_rect_screen.has_point(mouse_event.position):
		game.handle_screen_click(mouse_event.position - world_view_rect_screen.position)


func _draw_ticket_panel(rect: Rect2, fill: Color, accent: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(0, 6), rect.size), Color("080b0f99"), true)
	draw_rect(rect, fill, true)
	draw_rect(rect, INK, false, 3.0)
	draw_line(rect.position + Vector2(14, 10), rect.position + Vector2(rect.size.x - 14, 10), accent, 4.0)


func _draw_coach(rect: Rect2, kicker: String, body: String) -> void:
	draw_rect(rect, Color("101820eb"), true)
	draw_rect(Rect2(rect.position, Vector2(7, rect.size.y)), GOLD, true)
	_label(kicker, rect.position + Vector2(20, 23), 10, GOLD)
	_label(_shorten(body, 92), rect.position + Vector2(20, 49), 13, TEXT)


func _draw_button(rect: Rect2, caption: String, fill: Color, text_color: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(0, 4), rect.size), INK, true)
	draw_rect(rect, fill, true)
	draw_rect(rect, INK, false, 2.0)
	_draw_centered(caption, rect, 14, text_color)


func _draw_texture_button(rect: Rect2, caption: String, texture: Texture2D, text_color: Color, font_size: int = 14, modulate: Color = Color.WHITE) -> void:
	if texture != null:
		draw_texture_rect(texture, rect, false, modulate)
	_draw_centered(caption, rect, font_size, text_color)


func _draw_chip(rect: Rect2, caption: String, fill: Color, text_color: Color, font_size: int) -> void:
	var radius := rect.size.y * 0.5
	draw_rect(Rect2(rect.position + Vector2(radius, 0), Vector2(maxf(0.0, rect.size.x - radius * 2.0), rect.size.y)), fill, true)
	draw_circle(rect.position + Vector2(radius, radius), radius, fill)
	draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, fill)
	_draw_centered(caption, rect, font_size, text_color)


func _draw_bar(rect: Rect2, value: int, maximum: int, fill: Color, empty: Color) -> void:
	draw_rect(rect, empty, true)
	var ratio := clampf(float(value) / maxf(1.0, float(maximum)), 0.0, 1.0)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), fill, true)
	draw_rect(rect, INK, false, 1.0)


func _label(value: String, pos: Vector2, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_centered(value: String, rect: Rect2, font_size: int, color: Color) -> void:
	var bounds := ThemeDB.fallback_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := rect.position + Vector2((rect.size.x - bounds.x) * 0.5, (rect.size.y + bounds.y) * 0.5 - 2.0)
	_label(value, pos, font_size, color)


func _draw_wrapped(value: String, pos: Vector2, width: float, font_size: int, color: Color) -> void:
	draw_multiline_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, -1, color)


func _draw_wrapped_lines(value: String, pos: Vector2, width: float, font_size: int, color: Color, max_lines: int) -> void:
	draw_multiline_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, max_lines, color)


func _phase_label() -> String:
	if game.animation_busy:
		return "动态演出"
	if game.phase == "home":
		return "节目首页"
	if game.phase.begins_with("lab_"):
		return "节目测试"
	if game.phase == "omen":
		return "行前预兆"
	if game.phase == "build":
		return "三选一扩建"
	if game.phase == "room_ready":
		return "房间揭示"
	if game.phase == "reward":
		return "节目奖励"
	if game.phase == "combat":
		return "惊吓时间"
	return "布景探索"


func _room_kind_label(room: Dictionary) -> String:
	var kind := str(room.get("kind", "quiet"))
	return "惊吓时间" if kind == "combat" else "考验" if kind == "event" else "安静角落"


func _room_kind_color(room: Dictionary) -> Color:
	var kind := str(room.get("kind", "quiet"))
	return MAGENTA if kind == "combat" else Color("7863a5") if kind == "event" else TEAL


func _door_shape(raw: Array) -> String:
	var doors: Array = []
	for i in range(mini(4, raw.size())):
		if bool(raw[i]):
			doors.append(i)
	if doors.size() == 4:
		return "十字"
	if doors.size() == 3:
		return "三岔"
	if doors.size() == 2:
		return "直通" if absi(int(doors[0]) - int(doors[1])) == 2 else "拐角"
	return "尽端" if doors.size() == 1 else "封闭"


func _door_text(doors: Array) -> String:
	var labels := ["北", "东", "南", "西"]
	var result: Array[String] = []
	for i in range(mini(4, doors.size())):
		if bool(doors[i]):
			result.append(labels[i])
	return "-" if result.is_empty() else "/".join(result)


func _footprint_label(kind: String) -> String:
	match kind:
		"single": return "单格"
		"line3": return "直廊"
		"l3": return "折角房"
		"plus5": return "十字厅"
		"t5": return "三岔厅"
		"p5": return "错层房"
		"stair5": return "阶梯房"
		"u5": return "回廊房"
	return "组合房"


func _reward_kind_label(kind: String) -> String:
	match kind:
		"card": return "新道具"
		"relic": return "常驻预兆"
		"stat": return "演员成长"
	return "节目奖励"


func _reward_icon(reward: Dictionary) -> Texture2D:
	match str(reward.get("kind", "stat")):
		"card":
			return _card_icon(str(reward.get("id", "")))
		"relic":
			return OMEN_ICON
	return null


func _card_kind_label(kind: String) -> String:
	return "放置" if kind == "place" else "预备" if kind == "ready" else "药物" if kind == "medicine" else "技巧"


func _shorten(value: String, max_chars: int) -> String:
	if max_chars <= 1 or value.length() <= max_chars:
		return value
	return value.left(max_chars - 1) + "…"
var _smb_tail_padding := """
ready" else "药物" if kind == "medicine" else "技巧"


func _shorten(value: String, max_chars: int) -> String:
	if max_chars <= 1 or value.length() <= max_chars:
		return value
	return value.left(max_chars - 1) + "…"

This padding block intentionally stays longer than an obsolete SMB file tail.
It prevents stale bytes on the shared volume from being parsed as GDScript.
"""
# SMB_SAFE_PADDING_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz
var _smb_tail_padding_2 := """
ly stays longer than an obsolete SMB file tail.
It prevents stale bytes on the shared volume from being parsed as GDScript.
"""
# SMB_SAFE_PADDING_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz

# SMB_FINAL_PADDING_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz
