extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var Rules = load("res://scripts/overworld_boss_rules.gd")
	var rooms = _rooms(8)
	# The rule harness does not need the full content adapter; an empty card
	# catalogue keeps this regression independent of presentation assets.
	var defs: Dictionary = {}
	var profile_base := {
		"valid": true,
		"name": "测试终幕",
		"source_ids": ["a", "b", "c"],
		"route_rule": "short_charge",
		"anchor_rule": "breather",
		"climax_rule": "spotlight",
		"climax_room_id": "room-c",
	}
	var route_profile: Dictionary = profile_base.duplicate(true)
	route_profile["climax_rule"] = "none"
	var short_rules = _make_rules(Rules, rooms, defs, route_profile)
	var short_boss = short_rules.enemy_by_id(short_rules.enemy_order[0])
	short_boss.pos = Vector2i(7, 0)
	short_rules.player_pos = Vector2i.ZERO
	short_rules.round_number = 3
	short_rules.host_fight.prepare(short_rules)
	_check(short_rules.host_fight.plan.get("path", []).size() <= 2, "short_charge 冲撞路径上限为2格")

	var long_profile: Dictionary = profile_base.duplicate(true)
	long_profile["route_rule"] = "long_charge"
	long_profile["climax_rule"] = "none"
	var long_rules = _make_rules(Rules, rooms, defs, long_profile)
	var long_boss = long_rules.enemy_by_id(long_rules.enemy_order[0])
	long_boss.pos = Vector2i(7, 0)
	long_rules.player_pos = Vector2i.ZERO
	long_rules.round_number = 3
	long_rules.host_fight.prepare(long_rules)
	_check(long_rules.host_fight.plan.get("path", []).size() <= 4, "long_charge 冲撞路径上限为4格")
	_check(long_rules.host_fight.plan.get("path", []).all(func(cell: Vector2i) -> bool: return long_rules.is_walkable(cell)), "冲撞路径不能穿越墙体或非连接格")

	var relay_profile: Dictionary = profile_base.duplicate(true)
	relay_profile["anchor_rule"] = "relay"
	var relay_rules = _make_rules(Rules, rooms, defs, relay_profile)
	var relay_cell: Vector2i = relay_rules.anchors.keys()[0]
	relay_rules.player_pos = relay_cell
	relay_rules.energy = 5
	relay_rules.anchors[relay_cell] = 1
	_check(relay_rules.dismantle(), "relay 测试应能关闭锚点")
	_check(relay_rules.energy == 4, "relay 关闭锚点后净额外获得1 AP")
	relay_rules.outcome = ""
	relay_rules.anchors[relay_cell] = 1
	_check(relay_rules.dismantle(), "同一锚点重新装载后仍可验证幂等奖励")
	_check(relay_rules.energy == 2, "同一锚点重复关闭不应重复获得 relay AP")

	var breather_rules = _make_rules(Rules, rooms, defs, profile_base)
	var breather_cell: Vector2i = breather_rules.anchors.keys()[0]
	breather_rules.player_pos = breather_cell
	breather_rules.player_hp = 5
	breather_rules.anchors[breather_cell] = 1
	_check(breather_rules.dismantle(), "breather 测试应能关闭锚点")
	_check(breather_rules.player_hp == 6, "breather 关闭锚点后恢复1生命且不超过上限")
	breather_rules.outcome = ""
	breather_rules.anchors[breather_cell] = 1
	_check(breather_rules.dismantle(), "breather 重复关闭应仍可验证幂等")
	_check(breather_rules.player_hp == 6, "breather 重复关闭不应突破生命上限或重复奖励")

	var sweep_profile: Dictionary = profile_base.duplicate(true)
	sweep_profile["climax_rule"] = "double_sweep"
	var sweep_rules = _make_rules(Rules, rooms, defs, sweep_profile)
	var sweep_boss = sweep_rules.enemy_by_id(sweep_rules.enemy_order[0])
	sweep_boss.pos = Vector2i(7, 0)
	sweep_rules.player_pos = Vector2i(0, 0)
	sweep_rules.round_number = 3
	sweep_rules.host_fight.prepare(sweep_rules)
	var sweep_cells: Array = sweep_rules.host_fight.plan.get("cells", [])
	_check(sweep_rules.host_fight.plan.get("kind", "") == "sweep", "double_sweep 每第三回合进入扫场")
	_check(sweep_cells.size() >= 2 and sweep_cells.has(Vector2i(2, 0)), "double_sweep 优先第三份房间可达格并覆盖直接相邻格")
	_check(sweep_cells.all(func(cell: Vector2i) -> bool: return cell == Vector2i(2, 0) or cell in sweep_rules.graph.get(Vector2i(2, 0), [])), "double_sweep 不跨越无连接格")

	var spotlight_profile: Dictionary = profile_base.duplicate(true)
	spotlight_profile["climax_cells"] = [[4, 0]]
	var spotlight_rules = _make_rules(Rules, rooms, defs, spotlight_profile)
	spotlight_rules.enemy_by_id(spotlight_rules.enemy_order[0]).pos = Vector2i(7, 0)
	spotlight_rules.player_pos = Vector2i.ZERO
	spotlight_rules.round_number = 3
	spotlight_rules.host_fight.prepare(spotlight_rules)
	_check(spotlight_rules.host_fight.plan.get("kind", "") == "pursuit", "spotlight 保持单次追击攻击")
	_check(spotlight_rules.host_fight.camera_cells == [Vector2i(2, 0)], "spotlight 每第三回合优先第三份房间取景")

	if failures.is_empty():
		print("DREAM_FINALE_RULES: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error("DREAM_FINALE_RULES: " + failure)
		quit(1)


func _rooms(count: int):
	var rooms = load("res://scripts/room_rules.gd").new()
	for index in range(count):
		var id := "room-%s" % ("abc"[mini(index, 2)] if index < 3 else str(index))
		rooms.placed[Vector2i(index, 0)] = {
			"id": id,
			"instance_id": id,
			"name": id,
			"origin": [index, 0],
			"doors": [true, true, true, true],
			"floor": 0,
			"revealed": true,
			"completed": true,
			"completion_order": index,
		}
	return rooms


func _make_rules(Rules, rooms, defs: Dictionary, profile: Dictionary):
	var rules = Rules.new()
	rules.initialize(rooms, Vector2i.ZERO, {"name": "测试Boss", "hp": 20}, defs, ["guard"], 9, {"player_hp": 6, "player_max_hp": 6, "base_speed": 3, "base_energy": 5}, [], profile)
	return rules


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
