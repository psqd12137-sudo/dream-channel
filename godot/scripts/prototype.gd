extends Control

const APP_FONT: Font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")

const RoomRules = preload("res://scripts/room_rules.gd")
const CombatRules = preload("res://scripts/combat_rules.gd")
const WebContentAdapter = preload("res://scripts/web_content_adapter.gd")
const PLAYER_PORTRAIT = preload("res://assets/web_ui/SP_Lili_Profile.png")
const ENEMY_PORTRAIT = preload("res://assets/web_ui/SP_Yellow_idle_1.png")
const CARD_ICON_TRAP = preload("res://assets/web_ui/SP_Card_IconT_Trap.png")
const CARD_ICON_THING = preload("res://assets/web_ui/SP_Card_IconT_Thing.png")
const CARD_ICON_OMEN = preload("res://assets/web_ui/SP_Card_IconT_Omen.png")
const CARD_ICON_DEFENCE = preload("res://assets/web_ui/SP_Card_IconT_Defence.png")
const OMEN_ICON = preload("res://assets/web_ui/OmenIcon.png")

const BG := Color("102d32")
const INK := Color("20242d")
const PANEL := Color("0b3c43")
const PANEL_2 := Color("156a68")
const PAPER := Color("fff3d2")
const PAPER_2 := Color("f2d8a7")
const TEXT := Color("fff5dd")
const MUTED := Color("a8c8c1")
const ACCENT := Color("f4a623")
const MAGENTA := Color("d63b72")
const GREEN := Color("65b86c")
const RED := Color("d9564c")
const BLUE := Color("4a91bb")
const TEAL := Color("20ad9e")

const HOUSE_ORIGIN := Vector2(435, 405)
const HOUSE_CELL := 72.0
const ARENA_BOUNDS := Rect2(46, 300, 760, 350)

var content: Dictionary = {}
var room_rules = RoomRules.new()
var combat = null
var run_seed := 1337
var active_relics: Array = []
var mode := "house"
var room_catalog: Array = []
var candidate_index := 0
var candidate_rotation := 0
var selected_frontier := Vector2i.ZERO
var last_placed := Vector2i.ZERO
var selected_card := -1
var current_combat_room: Dictionary = {}
var status_message := "选择一个黄色 Frontier，然后旋转并摆放房间。"
var capture_file := "house-scene.png"

var frontier_rects: Dictionary = {}
var card_rects: Array[Rect2] = []
var cell_rects: Dictionary = {}

const RESET_RECT := Rect2(1080, 22, 165, 38)
const PREV_RECT := Rect2(920, 594, 145, 40)
const NEXT_RECT := Rect2(1078, 594, 145, 40)
const ROTATE_RECT := Rect2(920, 646, 145, 42)
const PLACE_RECT := Rect2(1078, 646, 145, 42)
const ENTER_RECT := Rect2(920, 702, 303, 44)
const END_RECT := Rect2(858, 704, 376, 44)
const RETURN_RECT := Rect2(858, 704, 376, 44)


func _ready() -> void:
	content = WebContentAdapter.new().build_content(run_seed)
	if content == null or content.is_empty():
		var raw := FileAccess.get_file_as_string("res://data/prototype_content.json")
		content = JSON.parse_string(raw)
	if content == null or content.is_empty():
		push_error("Unable to load Web snapshot or prototype fallback")
		return
	for room in content.get("rooms", []):
		room_catalog.append(room)
	active_relics = content.get("active_relics", []).duplicate()
	_reset_house()
	set_process_input(true)
	queue_redraw()
	var user_args := OS.get_cmdline_user_args()
	if "--capture-combat" in user_args:
		_start_combat(_first_combat_room())
		capture_file = "combat-scene.png"
		_capture_after_draw.call_deferred()
	elif "--capture" in user_args:
		_capture_after_draw.call_deferred()


func _capture_after_draw() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("res://artifacts/%s" % capture_file)
	if error != OK:
		push_error("Unable to save capture: %s" % error_string(error))
	get_tree().quit()


func _reset_house() -> void:
	mode = "house"
	combat = null
	current_combat_room.clear()
	selected_card = -1
	room_rules.reset(content["start_room"])
	candidate_index = 0
	candidate_rotation = 0
	last_placed = Vector2i.ZERO
	var options: Array[Vector2i] = room_rules.frontiers()
	selected_frontier = options[0] if not options.is_empty() else Vector2i.ZERO
	_select_first_legal_offer()
	status_message = "Web 快照已载入：%d 房间 / %d 卡牌；严格门匹配已启用。" % [int(content.get("source_room_count", room_catalog.size())), content.get("cards", {}).size()]
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	_draw_header()
	if mode == "house":
		_draw_house()
	else:
		_draw_combat()


func _draw_header() -> void:
	draw_rect(Rect2(0, 0, size.x, 82), Color("17242b"))
	draw_rect(Rect2(0, 78, size.x, 4), TEAL)
	_label("织梦频道 · CHANNEL DREAM", Vector2(28, 34), 24, TEXT)
	_label("Godot 玩法桥接台  /  Web Run Scheme v3  /  seed %d" % run_seed, Vector2(28, 61), 14, MUTED)
	_draw_chip(Rect2(790, 22, 128, 34), "独立测试场景", TEAL, TEXT, 13)
	_draw_chip(Rect2(930, 22, 132, 34), "Web 快照 %d" % int(content.get("source_room_count", 0)), MAGENTA, TEXT, 13)
	_draw_button(RESET_RECT, "重开本集", Color("36434b"))


func _draw_house() -> void:
	var explored := maxi(0, room_rules.instance_count() - 1)
	var run_length := int(content.get("run_length", 12))
	_draw_stage_panel(Rect2(24, 102, 860, 650))
	_label("山屋频道 · 探索中", Vector2(46, 137), 22, TEXT)
	_label("选扩建位 → 看节目票根 → 旋转 → 摆下房间", Vector2(46, 160), 13, MUTED)
	_draw_ticket_panel(Rect2(305, 112, 300, 48), PAPER, ACCENT)
	_label("今天的行程  %d / %d" % [explored, run_length], Vector2(340, 143), 19, INK)
	_draw_chip(Rect2(656, 120, 94, 30), "安静屋", GREEN, TEXT, 12)
	_draw_chip(Rect2(758, 120, 94, 30), "惊吓房", MAGENTA, TEXT, 12)

	var map_rect := Rect2(42, 174, 824, 468)
	draw_rect(map_rect, Color("082f35"), true)
	draw_rect(map_rect, TEAL, false, 6.0)
	draw_rect(map_rect.grow(-8), Color("dff6e9"), false, 2.0)
	_label("CRT HOUSE MAP", Vector2(62, 203), 12, Color("7bd1c5"))
	_draw_legend_dot(Vector2(670, 197), ACCENT, "可扩建")
	_draw_legend_dot(Vector2(758, 197), RED, "有惊吓")
	frontier_rects.clear()
	for raw_pos in room_rules.placed.keys():
		var pos: Vector2i = raw_pos
		_draw_room(pos, room_rules.placed[pos])
	for frontier in room_rules.frontiers():
		var rect := _house_rect(frontier).grow(-12)
		frontier_rects[frontier] = rect
		var color := ACCENT if frontier == selected_frontier else Color("9b7650")
		draw_rect(rect, Color(color, 0.2), true)
		draw_rect(rect, color, false, 3.0 if frontier == selected_frontier else 2.0)
		_label("+", rect.position + Vector2(rect.size.x * 0.5 - 7, rect.size.y * 0.5 + 8), 28, color)

	var room: Dictionary = room_catalog[candidate_index]
	var valid := room_rules.can_place(selected_frontier, room, candidate_rotation)
	var kind := str(room.get("kind", "quiet"))
	var kind_color := _kind_color(kind)
	_draw_ticket_panel(Rect2(902, 102, 354, 476), PAPER, kind_color)
	draw_rect(Rect2(902, 102, 58, 476), kind_color, true)
	draw_dashed_line(Vector2(968, 118), Vector2(968, 562), Color("8f745a"), 2.0, 7.0)
	_label("房间票根", Vector2(986, 135), 13, Color("85664c"))
	_label(_shorten(str(room.get("name", room.get("id", "room"))), 16), Vector2(986, 171), 23, INK)
	_draw_chip(Rect2(986, 188, 92, 30), _kind_label(kind), kind_color, TEXT, 12)
	_draw_chip(Rect2(1086, 188, 136, 30), "ROT %d°" % (candidate_rotation * 90), Color("2f3a45"), TEXT, 12)
	_label("门型 / DOORS", Vector2(986, 250), 11, Color("886e58"))
	_label(_door_text(room_rules.rotated_doors(room.get("doors", []), candidate_rotation)), Vector2(986, 278), 19, INK)
	var validity := "合法 / LEGAL" if valid else "不合法 / INVALID"
	_draw_chip(Rect2(986, 294, 236, 34), validity, GREEN if valid else RED, TEXT, 13)
	_label("本集简介", Vector2(986, 359), 12, Color("886e58"))
	_draw_wrapped(_shorten(str(room.get("description", "")), 52), Vector2(986, 383), 228, 13, INK)
	if kind == "combat":
		var enemy: Dictionary = room.get("enemy", {})
		var enemy_line := "%s · T%d" % [str(enemy.get("name", "雪花剪影")), int(enemy.get("tier", 1))]
		_label("今晚嘉宾", Vector2(986, 442), 12, Color("886e58"))
		_label(_shorten(enemy_line, 18), Vector2(986, 466), 16, RED)
		_label("%s  HP%d  韧%d  AP%d" % [str(enemy.get("archetype_label", "怪家伙")), int(enemy.get("hp", 6)), int(enemy.get("toughness", 3)), int(enemy.get("action_points", 3))], Vector2(986, 490), 12, INK)
	else:
		_label("节目状态", Vector2(986, 442), 12, Color("886e58"))
		_label("这里暂时没有惊吓", Vector2(986, 468), 14, GREEN)
	var omen_text := "无"
	if not active_relics.is_empty():
		var relic: Dictionary = content.get("relics", {}).get(active_relics[0], {})
		omen_text = str(relic.get("name", active_relics[0]))
	draw_texture_rect(OMEN_ICON, Rect2(978, 515, 34, 34), false)
	_label("开局预兆 · %s" % _shorten(omen_text, 13), Vector2(1018, 538), 12, Color("735127"))

	_draw_button(PREV_RECT, "← 上一张", Color("344851"))
	_draw_button(NEXT_RECT, "下一张 →", Color("344851"))
	_draw_button(ROTATE_RECT, "↻ 旋转 90°", TEAL)
	_draw_button(PLACE_RECT, "摆下房间", GREEN if valid else Color("76585a"))
	if last_placed != Vector2i.ZERO and room_rules.placed.has(last_placed):
		var placed_room: Dictionary = room_rules.placed[last_placed]
		if str(placed_room.get("kind", "")) == "combat" and not bool(placed_room.get("completed", false)):
			_draw_button(ENTER_RECT, "▶ 走进惊吓房 · ENTER COMBAT", MAGENTA)

	_draw_coach(Rect2(42, 654, 824, 88), "导播耳语", "严格门匹配已启用", status_message)


func _draw_room(pos: Vector2i, room: Dictionary) -> void:
	var rect := _house_rect(pos).grow(-5)
	var kind := str(room.get("kind", "quiet"))
	var fill := Color("69354d") if kind == "combat" else Color("315e54") if kind == "quiet" else Color("5c4d76")
	draw_rect(rect, fill, true)
	draw_rect(rect, PAPER_2, false, 2.0)
	_label(_shorten(str(room.get("name", room.get("id", "room"))), 7), rect.position + Vector2(7, 24), 12, TEXT)
	_label(_kind_label(kind), rect.position + Vector2(7, 45), 10, Color("d9e9df"))
	var doors: Array = room.get("doors", [false, false, false, false])
	var center := rect.get_center()
	if bool(doors[0]): draw_line(Vector2(center.x, rect.position.y), Vector2(center.x, rect.position.y + 9), GREEN, 5)
	if bool(doors[1]): draw_line(Vector2(rect.end.x, center.y), Vector2(rect.end.x - 9, center.y), GREEN, 5)
	if bool(doors[2]): draw_line(Vector2(center.x, rect.end.y), Vector2(center.x, rect.end.y - 9), GREEN, 5)
	if bool(doors[3]): draw_line(Vector2(rect.position.x, center.y), Vector2(rect.position.x + 9, center.y), GREEN, 5)


func _draw_combat() -> void:
	_draw_stage_panel(Rect2(24, 102, 800, 650))
	_draw_stage_panel(Rect2(838, 102, 418, 650))
	var room_name := str(current_combat_room.get("name", "场地战"))
	_label("惊吓时间 · %s" % room_name, Vector2(44, 135), 22, TEXT)
	_label("放置道具改变场地，跑动让怪把行动力花在追你身上", Vector2(44, 158), 13, MUTED)
	_draw_chip(Rect2(686, 118, 116, 32), "ROUND %d" % combat.round_number, ACCENT, INK, 13)
	var intent: Dictionary = combat.preview_intent()
	_draw_actor_strip(Rect2(44, 174, 226, 104), PLAYER_PORTRAIT, "小主角", GREEN, "HP %d" % combat.player_hp, "盾 %d" % combat.player_block, "预备 %s" % ("—" if combat.ready_effect.is_empty() else "已挂载"))
	_draw_intent_panel(Rect2(282, 174, 278, 104), intent)
	_draw_actor_strip(Rect2(572, 174, 230, 104), ENEMY_PORTRAIT, _shorten(combat.enemy_name, 8), MAGENTA, "HP %d/%d" % [combat.enemy_hp, combat.enemy_max_hp], "韧 %d/%d" % [combat.enemy_toughness, combat.enemy_max_toughness], "T%d · %s" % [combat.enemy_tier, combat.enemy_archetype_label])
	_draw_bar(Rect2(632, 257, 152, 7), combat.enemy_toughness, combat.enemy_max_toughness, MAGENTA, Color("4f3a42"))

	_draw_legend_dot(Vector2(48, 292), GREEN, "你")
	_draw_legend_dot(Vector2(101, 292), RED, "怪")
	_draw_legend_dot(Vector2(154, 292), Color(RED, 0.7), "必伤")
	_draw_legend_dot(Vector2(225, 292), Color(BLUE, 0.8), "它走")
	_draw_legend_dot(Vector2(296, 292), ACCENT, "道具")
	cell_rects.clear()
	for y in range(combat.rows):
		for x in range(combat.cols):
			var pos := Vector2i(x, y)
			var rect := _arena_rect(pos)
			cell_rects[pos] = rect
			var fill := Color("f5ecd5")
			if combat.walls.has(pos):
				fill = Color("6b6a6d")
			elif pos in intent["hurt"]:
				fill = Color("efb0a5")
			elif pos in intent["path"]:
				fill = Color("b9d9e7")
			draw_rect(rect.grow(-2), fill, true)
			draw_rect(rect.grow(-2), Color("9a7555"), false, 2.0)
			if combat.heights.has(pos):
				_draw_chip(Rect2(rect.position + Vector2(5, 5), Vector2(34, 22)), "H%d" % int(combat.heights[pos]), TEAL, TEXT, 10)
			if combat.portals.has(pos):
				_label("门", rect.get_center() + Vector2(-10, 7), 17, BLUE)
			if combat.traps.has(pos):
				var trap: Dictionary = combat.traps[pos]
				_label(str(trap.get("glyph", "物")), rect.get_center() + Vector2(-9, 8), 19, Color("9c5c08"))
	if combat.has_decoy():
		_draw_unit(combat.decoy_pos, "影", BLUE)
	if combat.outcome == "" or combat.outcome == "victory":
		_draw_unit(combat.player_pos, "P", GREEN)
	if combat.outcome == "" or combat.enemy_hp > 0:
		_draw_unit(combat.enemy_pos, "E", RED)

	_draw_action_ticket(Rect2(856, 118, 382, 112))
	_label("道具卡", Vector2(860, 257), 17, TEXT)
	_label("点击卡牌 · 放置牌再点场地格", Vector2(942, 257), 12, MUTED)
	card_rects.clear()
	var card_gap := 8.0
	var card_height := minf(88.0, (390.0 - maxf(0.0, float(combat.hand.size() - 1)) * card_gap) / maxf(1.0, float(combat.hand.size())))
	for i in range(combat.hand.size()):
		var rect := Rect2(858, 272 + i * (card_height + card_gap), 376, card_height)
		card_rects.append(rect)
		var card: Dictionary = combat.cards[combat.hand[i]]
		_draw_web_card(rect, str(combat.hand[i]), card, combat.card_cost(card), i == selected_card)

	_draw_chip(Rect2(858, 668, 132, 28), "牌库 %d" % combat.deck.size(), Color("344851"), TEXT, 11)
	_draw_chip(Rect2(998, 668, 132, 28), "弃牌 %d" % combat.discard.size(), Color("344851"), TEXT, 11)
	_draw_button(END_RECT, "结束回合 · END TURN", ACCENT)
	if combat.outcome != "":
		var result_text := "胜利 / VICTORY" if combat.outcome == "victory" else "失败 / DEFEAT"
		_draw_chip(Rect2(596, 118, 196, 36), result_text, GREEN if combat.outcome == "victory" else RED, TEXT, 14)
		_draw_button(RETURN_RECT, "返回房屋地图", TEAL)
	var log_start := maxi(0, combat.event_log.size() - 2)
	var log_lines: Array[String] = []
	for i in range(log_start, combat.event_log.size()):
		log_lines.append(str(combat.event_log[i]))
	var coach_body := "点击相邻格移动；放置牌要再选目标格。"
	if selected_card >= 0 and selected_card < combat.hand.size():
		var selected: Dictionary = combat.cards[combat.hand[selected_card]]
		coach_body = "已选 %s：现在点一个合法场地格。" % str(selected.get("name", combat.hand[selected_card]))
	elif not log_lines.is_empty():
		coach_body = "  ·  ".join(log_lines)
	_draw_coach(Rect2(44, 664, 758, 76), "战斗导播", _shorten(combat.enemy_archetype_desc, 36), coach_body)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var point: Vector2 = event.position
	if RESET_RECT.has_point(point):
		_reset_house()
		return
	if mode == "house":
		_handle_house_click(point)
	else:
		_handle_combat_click(point)


func _handle_house_click(point: Vector2) -> void:
	for raw_frontier in frontier_rects.keys():
		if (frontier_rects[raw_frontier] as Rect2).has_point(point):
			selected_frontier = raw_frontier
			_select_first_legal_offer()
			status_message = "已选择 Frontier %s" % selected_frontier
			queue_redraw()
			return
	if PREV_RECT.has_point(point):
		candidate_index = posmod(candidate_index - 1, room_catalog.size())
		candidate_rotation = 0
	elif NEXT_RECT.has_point(point):
		candidate_index = (candidate_index + 1) % room_catalog.size()
		candidate_rotation = 0
	elif ROTATE_RECT.has_point(point):
		candidate_rotation = (candidate_rotation + 1) % 4
	elif PLACE_RECT.has_point(point):
		var room: Dictionary = room_catalog[candidate_index]
		if room_rules.place(selected_frontier, room, candidate_rotation):
			last_placed = selected_frontier
			status_message = "已摆放 %s。" % str(room.get("name", room.get("id")))
			candidate_index = (candidate_index + 1) % room_catalog.size()
			candidate_rotation = 0
			var options: Array[Vector2i] = room_rules.frontiers()
			if not options.is_empty():
				selected_frontier = options[0]
				_select_first_legal_offer()
		else:
			status_message = "摆放失败：相邻边门型不完全匹配。"
	elif ENTER_RECT.has_point(point):
		_start_combat_for_last_room()
	queue_redraw()


func _start_combat_for_last_room() -> void:
	if not room_rules.placed.has(last_placed):
		return
	var room: Dictionary = room_rules.placed[last_placed]
	if str(room.get("kind", "")) != "combat" or not room.has("arena"):
		return
	_start_combat(room)


func _start_combat(room: Dictionary) -> void:
	if room.is_empty() or not room.has("arena"):
		return
	current_combat_room = room.duplicate(true)
	combat = CombatRules.new()
	var enemy: Dictionary = room.get("enemy", content.get("enemy", {}))
	combat.setup(room["arena"], enemy, content["cards"], content["starter_deck"], run_seed + room_rules.instance_count(), content.get("run_rules", {}), active_relics)
	selected_card = -1
	mode = "combat"
	queue_redraw()


func _handle_combat_click(point: Vector2) -> void:
	if END_RECT.has_point(point) and combat.outcome == "":
		selected_card = -1
		combat.enemy_turn()
		queue_redraw()
		return
	if RETURN_RECT.has_point(point) and combat.outcome != "":
		if room_rules.placed.has(last_placed):
			room_rules.placed[last_placed]["completed"] = combat.outcome == "victory"
		mode = "house"
		current_combat_room.clear()
		status_message = "战斗结果：%s；已返回房屋地图。" % combat.outcome
		queue_redraw()
		return
	for i in range(card_rects.size()):
		if not card_rects[i].has_point(point):
			continue
		var card: Dictionary = combat.cards[combat.hand[i]]
		if str(card.get("type", "")) != "place":
			combat.play_card(i, combat.enemy_pos)
			selected_card = -1
		else:
			selected_card = i
		queue_redraw()
		return
	for raw_pos in cell_rects.keys():
		if not (cell_rects[raw_pos] as Rect2).has_point(point):
			continue
		var pos: Vector2i = raw_pos
		if selected_card >= 0:
			if combat.play_card(selected_card, pos):
				selected_card = -1
		else:
			combat.move_player(pos)
		queue_redraw()
		return


func _house_rect(pos: Vector2i) -> Rect2:
	var center := HOUSE_ORIGIN + Vector2(pos.x, pos.y) * HOUSE_CELL
	return Rect2(center - Vector2.ONE * HOUSE_CELL * 0.5, Vector2.ONE * HOUSE_CELL)


func _arena_rect(pos: Vector2i) -> Rect2:
	var cell := minf(ARENA_BOUNDS.size.x / maxf(1.0, float(combat.cols)), ARENA_BOUNDS.size.y / maxf(1.0, float(combat.rows)))
	var grid_size := Vector2(float(combat.cols), float(combat.rows)) * cell
	var origin := ARENA_BOUNDS.position + (ARENA_BOUNDS.size - grid_size) * 0.5
	return Rect2(origin + Vector2(pos.x, pos.y) * cell, Vector2.ONE * cell)


func _first_combat_room() -> Dictionary:
	for room in room_catalog:
		if str(room.get("kind", "")) == "combat":
			return room
	return {}


func _select_first_legal_offer() -> void:
	if room_catalog.is_empty():
		return
	for offset in range(room_catalog.size()):
		var index := (candidate_index + offset) % room_catalog.size()
		for rotation in range(4):
			if room_rules.can_place(selected_frontier, room_catalog[index], rotation):
				candidate_index = index
				candidate_rotation = rotation
				return


func _draw_unit(pos: Vector2i, label_text: String, color: Color) -> void:
	var center := _arena_rect(pos).get_center()
	draw_circle(center + Vector2(0, 4), 25, Color("251d1a"))
	draw_circle(center, 24, color)
	draw_circle(center, 24, PAPER, false, 3.0)
	_draw_centered(label_text, Rect2(center - Vector2(24, 18), Vector2(48, 40)), 21, INK)


func _draw_stage_panel(rect: Rect2) -> void:
	draw_rect(rect, Color("082b31"), true)
	draw_rect(rect, TEAL, false, 4.0)
	draw_rect(rect.grow(-7), Color("325f60"), false, 2.0)


func _draw_ticket_panel(rect: Rect2, fill: Color, accent: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(0, 5), rect.size), Color("0b171b88"), true)
	draw_rect(rect, fill, true)
	draw_rect(rect, INK, false, 2.0)
	draw_line(rect.position + Vector2(10, 6), rect.position + Vector2(rect.size.x - 10, 6), accent, 3.0)


func _draw_chip(rect: Rect2, caption: String, fill: Color, text_color: Color, font_size: int) -> void:
	var radius := rect.size.y * 0.5
	draw_rect(Rect2(rect.position + Vector2(radius, 0), Vector2(maxf(0.0, rect.size.x - radius * 2.0), rect.size.y)), fill, true)
	draw_circle(rect.position + Vector2(radius, radius), radius, fill)
	draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, fill)
	_draw_centered(caption, rect, font_size, text_color)


func _draw_legend_dot(pos: Vector2, color: Color, caption: String) -> void:
	draw_circle(pos, 5.0, color)
	_label(caption, pos + Vector2(10, 5), 11, MUTED)


func _draw_coach(rect: Rect2, kicker: String, title: String, body: String) -> void:
	draw_rect(rect, Color("17242b"), true)
	draw_rect(Rect2(rect.position, Vector2(6, rect.size.y)), ACCENT, true)
	_label(kicker, rect.position + Vector2(18, 22), 10, ACCENT)
	_label(_shorten(title, 38), rect.position + Vector2(18, 43), 14, TEXT)
	_label(_shorten(body, 84), rect.position + Vector2(18, 65), 12, MUTED)


func _draw_actor_strip(rect: Rect2, portrait: Texture2D, actor_name: String, accent: Color, stat_a: String, stat_b: String, stat_c: String) -> void:
	draw_rect(Rect2(rect.position + Vector2(0, 4), rect.size), Color("06161a"), true)
	draw_rect(rect, Color("f8e9c6"), true)
	draw_rect(Rect2(rect.position, Vector2(8, rect.size.y)), accent, true)
	draw_rect(rect, accent, false, 2.0)
	draw_texture_rect(portrait, Rect2(rect.position + Vector2(12, 10), Vector2(52, 84)), false)
	_label(actor_name, rect.position + Vector2(72, 26), 15, INK)
	_label(stat_a, rect.position + Vector2(72, 50), 13, Color("80352f"))
	_label(stat_b, rect.position + Vector2(72, 70), 12, Color("28677b"))
	_label(_shorten(stat_c, 18), rect.position + Vector2(72, 90), 11, Color("496248"))


func _draw_intent_panel(rect: Rect2, intent: Dictionary) -> void:
	draw_rect(Rect2(rect.position + Vector2(0, 4), rect.size), Color("06161a"), true)
	draw_rect(rect, Color("222934"), true)
	draw_rect(Rect2(rect.position, Vector2(7, rect.size.y)), RED, true)
	draw_circle(rect.position + Vector2(30, 31), 18, RED)
	_draw_centered("!", Rect2(rect.position + Vector2(12, 12), Vector2(36, 36)), 20, TEXT)
	_label("敌人意图", rect.position + Vector2(58, 23), 10, Color("e7acaa"))
	_label(_shorten(str(intent.get("label", "—")), 19), rect.position + Vector2(58, 45), 15, TEXT)
	_label(_intent_description(intent), rect.position + Vector2(18, 72), 11, MUTED)
	_label("怪行动力 %d · 追击/攻击共用" % combat.enemy_action_points, rect.position + Vector2(18, 93), 11, Color("f2b75f"))


func _draw_action_ticket(rect: Rect2) -> void:
	_draw_ticket_panel(rect, PAPER, ACCENT)
	draw_rect(Rect2(rect.position, Vector2(86, rect.size.y)), ACCENT, true)
	draw_dashed_line(rect.position + Vector2(94, 10), rect.position + Vector2(94, rect.size.y - 10), Color("98714a"), 2.0, 7.0)
	_label("速度", rect.position + Vector2(18, 28), 12, Color("6d451c"))
	_label("S%d" % combat.base_speed, rect.position + Vector2(19, 68), 28, INK)
	_label("行动力", rect.position + Vector2(110, 27), 11, Color("866744"))
	_label("%d AP" % combat.energy, rect.position + Vector2(108, 63), 26, INK)
	_label("本回合骰面", rect.position + Vector2(210, 27), 10, Color("866744"))
	var rolls: Array = combat.energy_rolls
	if rolls.is_empty():
		rolls = [combat.energy_roll]
	for i in range(mini(4, rolls.size())):
		var die := Rect2(rect.position + Vector2(210 + i * 36, 42), Vector2(30, 30))
		draw_rect(die, Color("fffaf0"), true)
		draw_rect(die, Color("9b714a"), false, 2.0)
		_draw_centered(str(rolls[i]), die, 15, INK)
	_label("速度骰合计 %d" % combat.energy_roll, rect.position + Vector2(210, 92), 10, Color("866744"))


func _draw_web_card(rect: Rect2, card_id: String, card: Dictionary, cost: int, selected: bool) -> void:
	var kind := str(card.get("type", "skill"))
	var accent := _card_color(kind)
	draw_rect(Rect2(rect.position + Vector2(0, 3), rect.size), Color("06161a"), true)
	draw_rect(rect, PAPER, true)
	draw_rect(Rect2(rect.position, Vector2(48, rect.size.y)), accent, true)
	draw_dashed_line(rect.position + Vector2(54, 7), rect.position + Vector2(54, rect.size.y - 7), Color("9d7652"), 1.5, 5.0)
	draw_rect(rect, ACCENT if selected else Color("a97951"), false, 4.0 if selected else 2.0)
	var icon: Texture2D = _card_icon(kind)
	var icon_size := minf(40.0, rect.size.y - 16.0)
	draw_texture_rect(icon, Rect2(rect.position + Vector2(5, (rect.size.y - icon_size) * 0.5), Vector2(icon_size, icon_size)), false)
	_label(_card_kind_label(kind), rect.position + Vector2(65, 17), 9, Color("8a674a"))
	_label(_shorten(str(card.get("name", card_id)), 16), rect.position + Vector2(65, 38), 15, INK)
	if rect.size.y >= 78.0:
		_label(_shorten(str(card.get("text", "")), 30), rect.position + Vector2(65, 60), 10, Color("6e6155"))
		_label(_card_tags(card), rect.position + Vector2(65, rect.size.y - 8), 9, accent.darkened(0.28))
	var cost_center := rect.position + Vector2(rect.size.x - 25, 24)
	draw_circle(cost_center, 18, accent)
	draw_circle(cost_center, 18, INK, false, 2.0)
	_draw_centered(str(cost), Rect2(cost_center - Vector2(18, 18), Vector2(36, 36)), 16, TEXT if accent.get_luminance() < 0.55 else INK)


func _draw_bar(rect: Rect2, value: int, maximum: int, fill: Color, empty: Color) -> void:
	draw_rect(rect, empty, true)
	var ratio := clampf(float(value) / maxf(1.0, float(maximum)), 0.0, 1.0)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), fill, true)
	draw_rect(rect, INK, false, 1.0)


func _draw_button(rect: Rect2, caption: String, color: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(0, 4), rect.size), INK, true)
	draw_rect(rect, color, true)
	draw_rect(rect, INK, false, 2.0)
	_draw_centered(caption, rect, 14, INK if color.get_luminance() > 0.55 else TEXT)


func _label(value: String, pos: Vector2, font_size: int, color: Color) -> void:
	draw_string(APP_FONT, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_centered(value: String, rect: Rect2, font_size: int, color: Color) -> void:
	var bounds := APP_FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := rect.position + Vector2((rect.size.x - bounds.x) * 0.5, (rect.size.y + bounds.y) * 0.5 - 2.0)
	_label(value, pos, font_size, color)


func _draw_wrapped(value: String, pos: Vector2, width: float, font_size: int, color: Color) -> void:
	draw_multiline_string(APP_FONT, pos, value, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, -1, color)


func _kind_color(kind: String) -> Color:
	if kind == "combat":
		return MAGENTA
	if kind == "event":
		return Color("7764a7")
	return TEAL


func _kind_label(kind: String) -> String:
	if kind == "combat":
		return "惊吓房"
	if kind == "event":
		return "小插曲"
	return "安静屋"


func _card_color(kind: String) -> Color:
	if kind == "place":
		return ACCENT
	if kind == "ready":
		return MAGENTA
	if kind == "medicine":
		return RED
	return TEAL


func _card_kind_label(kind: String) -> String:
	if kind == "place":
		return "机关 · PLACE"
	if kind == "ready":
		return "预备 · READY"
	if kind == "medicine":
		return "药物 · MEDICINE"
	return "技巧 · SKILL"


func _card_icon(kind: String) -> Texture2D:
	if kind == "place":
		return CARD_ICON_TRAP
	if kind == "ready":
		return CARD_ICON_OMEN
	if kind == "medicine":
		return CARD_ICON_DEFENCE
	return CARD_ICON_THING


func _card_tags(card: Dictionary) -> String:
	var tags: Array[String] = []
	if bool(card.get("retain", false)):
		tags.append("保留")
	if bool(card.get("exhaust", false)):
		tags.append("消耗")
	if tags.is_empty():
		tags.append("使用后进弃牌堆")
	return " · ".join(tags)


func _intent_description(intent: Dictionary) -> String:
	var label_text := str(intent.get("label", ""))
	if "Blinded" in label_text or "致盲" in label_text:
		return "它看不清你，本回合不会追击。"
	if not (intent.get("hurt", []) as Array).is_empty():
		return "红格会受伤；先离开或让道具接住它。"
	if not (intent.get("path", []) as Array).is_empty():
		return "蓝格是追击路线，它正在靠近你。"
	return "它暂时找不到合适的追击路线。"


func _shorten(value: String, max_chars: int) -> String:
	if max_chars <= 1 or value.length() <= max_chars:
		return value
	return value.left(max_chars - 1) + "…"


func _door_text(doors: Array) -> String:
	var labels := ["N", "E", "S", "W"]
	var result: Array[String] = []
	for i in range(mini(4, doors.size())):
		if bool(doors[i]):
			result.append(labels[i])
	return "-" if result.is_empty() else "/".join(result)
