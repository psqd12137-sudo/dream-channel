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
	for first_large in [false, true]:
		for second_combat in [false, true]:
			for third_combat in [false, true]:
				var combo: Dictionary = Profile.compose([
					{"instance_id": "combo-a-%s" % str(first_large), "room_id": "room-a", "room_size": 3 if first_large else 1},
					{"instance_id": "combo-b-%s" % str(second_combat), "room_id": "room-b", "kind": "combat" if second_combat else "quiet"},
					{"instance_id": "combo-c-%s" % str(third_combat), "room_id": "room-c", "kind": "combat" if third_combat else "quiet"},
				])
				var combo_rules = _make_rules(Rules, rooms, defs, combo)
				var combo_boss = combo_rules.enemy_by_id(combo_rules.enemy_order[0])
				combo_boss.pos = Vector2i(4, 0)
				combo_rules.player_pos = Vector2i.ZERO
				combo_rules.round_number = 1
				combo_rules.host_fight.prepare(combo_rules)
				var combo_path: Array = combo_rules.host_fight.plan.get("path", [])
				_check(combo_path.size() == (3 if first_large else 2), "八组合首回合均应用短/长冲撞上限")
				var combo_route_events: Array[Dictionary] = combo_rules.host_fight.execute(combo_rules, combo_boss)
				_check(combo_route_events.any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "attack") == first_large, "八组合首回合实际兑现长短冲撞受击差异")
				combo_rules.outcome = ""
				combo_boss.pos = Vector2i(7, 0)
				combo_rules.player_pos = Vector2i(2, 0)
				combo_rules.round_number = 3
				combo_rules.host_fight.prepare(combo_rules)
				var expected_kind := "sweep" if third_combat else "pursuit"
				_check(str(combo_rules.host_fight.plan.get("kind", "")) == expected_kind, "八组合第三回合均兑现第三素材招式")
				var combo_climax_events: Array[Dictionary] = combo_rules.host_fight.execute(combo_rules, combo_boss)
				_check(combo_climax_events.any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "attack") == third_combat, "八组合第三回合实际兑现扫场/聚光受击差异")
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
	short_rules.round_number = 1
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
	long_rules.round_number = 1
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

	# Exercise the two materially different programmes on the same physical map,
	# starter deck, seed, and player state. The assertions observe actual enemy
	# movement, attack events, and player HP rather than only the telegraph shape.
	var long_live_profile: Dictionary = Profile.compose([
		{"instance_id": "live-long-route", "room_id": "room-a", "name": "长冲撞房", "room_size": 3},
		{"instance_id": "live-relay", "room_id": "room-b", "name": "接力锚房", "kind": "combat"},
		{"instance_id": "live-double", "room_id": "room-c", "name": "双扫房", "kind": "combat"},
	])
	var short_live_profile: Dictionary = Profile.compose([
		{"instance_id": "live-short-route", "room_id": "room-a", "name": "短冲撞房", "room_size": 1},
		{"instance_id": "live-breather", "room_id": "room-b", "name": "喘息锚房", "kind": "quiet"},
		{"instance_id": "live-spotlight", "room_id": "room-c", "name": "聚光房", "kind": "quiet"},
	])
	var long_live = _make_rules(Rules, rooms, defs, long_live_profile)
	var short_live = _make_rules(Rules, rooms, defs, short_live_profile)
	var long_live_boss = long_live.enemy_by_id(long_live.enemy_order[0])
	var short_live_boss = short_live.enemy_by_id(short_live.enemy_order[0])
	long_live_boss.pos = Vector2i(4, 0)
	short_live_boss.pos = Vector2i(4, 0)
	long_live.player_pos = Vector2i.ZERO
	short_live.player_pos = Vector2i.ZERO
	long_live.round_number = 1
	short_live.round_number = 1
	long_live.host_fight.prepare(long_live)
	short_live.host_fight.prepare(short_live)
	var long_live_route_events: Array[Dictionary] = long_live.host_fight.execute(long_live, long_live_boss)
	var short_live_route_events: Array[Dictionary] = short_live.host_fight.execute(short_live, short_live_boss)
	_check(long_live_route_events.any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "attack") and long_live.player_hp < short_live.player_hp, "同图同起始状态下 long_charge 实际移动并造成受击")
	_check(not short_live_route_events.any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "attack") and short_live.player_hp == 6, "同图同起始状态下 short_charge 停在上限外且不受击")

	var long_live_climax = _make_rules(Rules, rooms, defs, long_live_profile)
	var short_live_climax = _make_rules(Rules, rooms, defs, short_live_profile)
	var long_live_climax_boss = long_live_climax.enemy_by_id(long_live_climax.enemy_order[0])
	var short_live_climax_boss = short_live_climax.enemy_by_id(short_live_climax.enemy_order[0])
	long_live_climax_boss.pos = Vector2i(7, 0)
	short_live_climax_boss.pos = Vector2i(7, 0)
	long_live_climax.player_pos = Vector2i(2, 0)
	short_live_climax.player_pos = Vector2i(2, 0)
	long_live_climax.round_number = 3
	short_live_climax.round_number = 3
	long_live_climax.host_fight.prepare(long_live_climax)
	short_live_climax.host_fight.prepare(short_live_climax)
	var long_live_climax_events: Array[Dictionary] = long_live_climax.host_fight.execute(long_live_climax, long_live_climax_boss)
	var short_live_climax_events: Array[Dictionary] = short_live_climax.host_fight.execute(short_live_climax, short_live_climax_boss)
	_check(long_live_climax.physical_cells == short_live_climax.physical_cells and long_live_climax.initial.get("deck", []) == short_live_climax.initial.get("deck", []), "两种终幕组合使用同一地图与起始牌组")
	_check(long_live_climax_events.any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "attack") and long_live_climax.player_hp < 6, "double_sweep 实际消费第三房间范围并造成受击")
	_check(not short_live_climax_events.any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "attack") and short_live_climax.player_hp == 6, "spotlight 实际追击因行动力不足未造成受击")
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
