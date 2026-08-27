extends SceneTree

const CombatRules = preload("res://scripts/combat_rules.gd")

var failures: Array[String] = []


func _init() -> void:
	_test_webber_places_web()
	_test_webber_turns_web_into_player_control()
	_test_webber_attacks_when_adjacent()
	if failures.is_empty():
		print("CHANNEL_WEBBER_ENEMY: PASS web-control-melee-expiry")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_WEBBER_ENEMY: %s" % failure)
		quit(1)


func _test_webber_places_web() -> void:
	var combat = _combat(Vector2i(5, 2))
	var intent: Dictionary = combat.preview_intent()
	var web_cells: Array[Vector2i] = []
	web_cells.assign(intent.get("web_cells", []))
	_check(str(intent.get("type", "")) == "web", "缚网者远离玩家且有行动力时应显示铺网意图")
	_check(str(intent.get("label", "")) == "铺网", "铺网意图应显示铺网文案")
	_check(str(intent.get("intent_value", "")) == "网", "铺网头顶意图牌应保留网文字")
	_check(web_cells.size() == 1 and web_cells[0] == Vector2i(4, 2), "铺网意图应锁定玩家相邻的空地块")
	var events: Array[Dictionary] = combat.enemy_turn()
	_check(events.any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "web_place"), "敌方回合应发布铺网事件")
	_check(combat.traps.has(Vector2i(4, 2)), "铺网事件应在目标地块生成缚网")
	var web: Dictionary = combat.traps.get(Vector2i(4, 2), {})
	_check(int(web.get("player_slow", 0)) == 1 and int(web.get("slow", 0)) == 0, "缚网只能增加玩家移动费用，不能减速敌人")
	_check(int(web.get("expires_round", 0)) - combat.round_number == 1, "铺网回合结束后网的上方倒计时应显示1")
	var follow_intent: Dictionary = combat.preview_intent()
	var follow_path: Array[Vector2i] = []
	follow_path.assign(follow_intent.get("path", []))
	_check(str(follow_intent.get("type", "")) == "attack", "铺网后下一回合应转入接近并攻击意图")
	_check(follow_path == [Vector2i(4, 2)], "铺网后攻击预览应显示接近玩家的路径")


func _test_webber_turns_web_into_player_control() -> void:
	var combat = _combat(Vector2i(5, 2))
	combat.enemy_turn()
	var web_cell := Vector2i(4, 2)
	_check(combat.player_move_cost(web_cell) == 2, "玩家进入缚网格的移动费用应为2")
	var tile_statuses: Array[Dictionary] = combat.statuses_for_tile(web_cell)
	_check(tile_statuses.any(func(status: Dictionary) -> bool: return str(status.get("label", "")) == "缚网"), "缚网地块状态应显示缚网")
	_check(tile_statuses.any(func(status: Dictionary) -> bool: return str(status.get("detail", "")).contains("移动额外消耗1行动力")), "缚网 hover 详情应说明玩家移动费用")
	_check(combat.move_player(web_cell), "玩家应能走入未被敌人占据的缚网格")
	var player_web_status: Dictionary = {}
	for status: Dictionary in combat.statuses_for_player():
		if str(status.get("id", "")) == "web_slow":
			player_web_status = status
	_check(not player_web_status.is_empty(), "玩家站在缚网上时应显示缚网状态")
	_check(str(player_web_status.get("icon", "")) == "salt", "玩家踩网状态应复用盐圈晕眩图标")
	combat.enemy_turn()
	_check(not combat.traps.has(web_cell), "缚网持续2个敌方回合后应消失")


func _test_webber_attacks_when_adjacent() -> void:
	var combat = _combat(Vector2i(4, 2))
	var intent: Dictionary = combat.preview_intent()
	_check(str(intent.get("type", "")) == "attack", "缚网者贴身时应优先显示近战攻击")
	_check(str(intent.get("attack_kind", "")) == "melee", "缚网者贴身后的攻击类型应为近战")
	var events: Array[Dictionary] = combat.enemy_turn()
	_check(events.any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "attack"), "缚网者贴身时应执行近战攻击")


func _combat(enemy_pos: Vector2i):
	var combat = CombatRules.new()
	combat.setup({
		"cols": 7,
		"rows": 5,
		"player": [3, 2],
		"player_facing": [0, 1],
		"walls": [],
		"heights": {},
		"portals": [],
	}, [{
		"id": "webber",
		"name": "缚网者",
		"spawn": [enemy_pos.x, enemy_pos.y],
		"hp": 5,
		"damage": 1,
		"toughness": 1,
		"action_points": 3,
		"attack_cost": 2,
		"attack_range": 1,
		"archetype": "webber",
		"archetype_label": "缚网者",
		"traits": ["webber"],
	}], {}, [], 20260826, {"player_hp": 20, "base_energy": 5}, [])
	return combat


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
