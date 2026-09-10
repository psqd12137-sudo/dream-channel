extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var Rules = load("res://scripts/overworld_boss_rules.gd")
	var Profile = load("res://scripts/dream_finale_profile.gd")
	for first_large in [false, true]:
		for second_combat in [false, true]:
			for third_combat in [false, true]:
				var composed: Dictionary = Profile.compose([
					{"instance_id": "r1-%s" % str(first_large), "room_id": "r1", "room_size": 3 if first_large else 1},
					{"instance_id": "r2-%s" % str(second_combat), "room_id": "r2", "kind": "combat" if second_combat else "quiet"},
					{"instance_id": "r3-%s" % str(third_combat), "room_id": "r3", "kind": "combat" if third_combat else "quiet"},
				])
				_check(str(composed.get("route_rule", "")) == ("long_charge" if first_large else "short_charge"), "规则回归覆盖八组合的冲撞分支")
				_check(str(composed.get("anchor_rule", "")) == ("relay" if second_combat else "breather"), "规则回归覆盖八组合的熄锚分支")
				_check(str(composed.get("climax_rule", "")) == ("double_sweep" if third_combat else "spotlight"), "规则回归覆盖八组合的终幕分支")
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
	_check(short_rules.initial.get("rules", {}).get("dream_finale_profile", {}).get("route_rule", "") == "short_charge", "combat 初始规则必须持久化 dream_finale_profile")
	var short_boss = short_rules.enemy_by_id(short_rules.enemy_order[0])
	short_boss.pos = Vector2i(7, 0)
	short_rules.player_pos = Vector2i.ZERO
	short_rules.round_number = 3
	short_rules.host_fight.prepare(short_rules)
	_check(short_rules.host_fight.plan.get("path", []).size() == 2, "short_charge 冲撞路径上限为2格")
	var short_path: Array = short_rules.host_fight.plan.get("path", []).duplicate()
	var short_events: Array[Dictionary] = short_rules.host_fight.execute(short_rules, short_boss)
	_check(short_events.size() > 0 and short_boss.pos == short_path[-1], "short_charge 执行消费预告路径并停在上限内")

	var long_profile: Dictionary = profile_base.duplicate(true)
	long_profile["route_rule"] = "long_charge"
	long_profile["climax_rule"] = "none"
	var long_rules = _make_rules(Rules, rooms, defs, long_profile)
	var long_boss = long_rules.enemy_by_id(long_rules.enemy_order[0])
	long_boss.pos = Vector2i(7, 0)
	long_rules.player_pos = Vector2i.ZERO
	long_rules.round_number = 3
	long_rules.host_fight.prepare(long_rules)
	_check(long_rules.host_fight.plan.get("path", []).size() == 4, "long_charge 冲撞路径上限为4格")
	_check(long_rules.host_fight.plan.get("path", []).all(func(cell: Vector2i) -> bool: return long_rules.is_walkable(cell)), "冲撞路径不能穿越墙体或非连接格")
	var long_path: Array = long_rules.host_fight.plan.get("path", []).duplicate()
	var long_events: Array[Dictionary] = long_rules.host_fight.execute(long_rules, long_boss)
	_check(long_events.size() > 0 and long_boss.pos == long_path[-1], "long_charge 执行消费预告路径并停在上限内")

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
	var sweep_preview: Dictionary = sweep_rules.host_fight.preview(sweep_rules, sweep_boss)
	_check(sweep_preview.get("impact_cells", []) == sweep_cells, "扫场预告范围必须与实际执行范围一致")
	sweep_rules.player_pos = Vector2i(2, 0)
	var sweep_events: Array[Dictionary] = sweep_rules.host_fight.execute(sweep_rules, sweep_boss)
	_check(sweep_events.any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "attack"), "double_sweep 执行会消费已预告的扫场范围")

	var spotlight_profile: Dictionary = profile_base.duplicate(true)
	spotlight_profile["climax_cells"] = [[4, 0]]
	var spotlight_rules = _make_rules(Rules, rooms, defs, spotlight_profile)
	spotlight_rules.enemy_by_id(spotlight_rules.enemy_order[0]).pos = Vector2i(7, 0)
	spotlight_rules.player_pos = Vector2i.ZERO
	spotlight_rules.round_number = 3
	spotlight_rules.host_fight.prepare(spotlight_rules)
	_check(spotlight_rules.host_fight.plan.get("kind", "") == "pursuit", "spotlight 保持单次追击攻击")
	_check(spotlight_rules.host_fight.camera_cells == [Vector2i(2, 0)], "spotlight 每第三回合优先第三份房间取景")
	var spotlight_events: Array[Dictionary] = spotlight_rules.host_fight.execute(spotlight_rules, spotlight_rules.enemy_by_id(spotlight_rules.enemy_order[0]))
	_check(spotlight_events.size() > 0, "spotlight 执行仍保持单次追击回合")
	var missing_profile: Dictionary = profile_base.duplicate(true)
	missing_profile["climax_room_id"] = "missing-room"
	var missing_rules = _make_rules(Rules, rooms, defs, missing_profile)
	_check(not missing_rules.error.is_empty(), "第三份素材没有可达实体格时必须报错")

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
