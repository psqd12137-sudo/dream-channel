extends SceneTree

const CombatRules = preload("res://scripts/combat_rules.gd")

var failures: Array[String] = []


func _init() -> void:
	_test_backstab_never_attacks_from_front()
	_test_backstab_attacks_from_back()
	_test_backstab_retreats_when_route_is_unavailable()
	_test_backstab_reengages_after_retreat()
	_test_mixed_assault_backstab_sequence()
	if failures.is_empty():
		print("CHANNEL_BACKSTAB_ENEMY: PASS facing-backstab-retreat")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_BACKSTAB_ENEMY: %s" % failure)
		quit(1)


func _test_backstab_never_attacks_from_front() -> void:
	var combat = _combat(Vector2i(3, 1), 5, 8)
	var state = combat.enemy_by_id(combat.enemy_order[0])
	var front_plan: Dictionary = combat._enemy_attack_plan(state, state.pos, 5, true)
	var tactical_plan: Dictionary = combat.preview_tactical_plan(state.id)
	_check(front_plan.is_empty(), "背刺者在玩家正面相邻格不能生成攻击计划")
	_check(tactical_plan.get("goal", Vector2i.ZERO) == Vector2i(1, 1), "背刺者的战术目标必须是玩家背后格")


func _test_backstab_attacks_from_back() -> void:
	var combat = _combat(Vector2i(1, 1), 2, 8)
	var intent: Dictionary = combat.preview_intent()
	var events: Array[Dictionary] = combat.enemy_turn()
	var backstab_hit := false
	for event: Dictionary in events:
		if str(event.get("kind", "")) == "attack" and str(event.get("attack_kind", "")) == "backstab":
			backstab_hit = true
	_check(str(intent.get("attack_kind", "")) == "backstab", "背后相邻时意图必须显示背刺")
	_check(str(intent.get("intent_value", "")) == "8", "背刺意图必须直接显示攻击力")
	_check(backstab_hit, "背后相邻时必须执行背刺事件")
	_check(combat.player_hp == 4, "背刺者应造成 8 点高额伤害")


func _test_backstab_retreats_when_route_is_unavailable() -> void:
	var combat = _combat(Vector2i(3, 1), 4, 8)
	var intent: Dictionary = combat.preview_intent()
	var events: Array[Dictionary] = combat.enemy_turn()
	var attacked := false
	for event: Dictionary in events:
		if str(event.get("kind", "")) == "attack":
			attacked = true
	_check(str(intent.get("type", "")) == "retreat", "本回合无法绕到背后时意图必须显示拉开距离")
	_check(str(intent.get("intent_value", "")).begins_with("-"), "背刺者远离玩家时必须显示负数步数")
	var move_count: int = 0
	for event: Dictionary in events:
		if str(event.get("kind", "")) == "move":
			move_count += 1
	_check(int(intent.get("movement_steps", 0)) == move_count, "背刺者预览步数必须与实际移动一致")
	_check(not attacked, "背后攻击位不可达时不能退化为正面攻击")
	_check(combat.manhattan(combat.enemy_pos, combat.player_pos) > 1, "背刺者无法绕后时必须拉开与玩家的距离")
	_check(combat.player_hp == 12, "拉开距离时不能对玩家造成伤害")


func _test_backstab_reengages_after_retreat() -> void:
	var combat = _combat(Vector2i(3, 1), 4, 8)
	var retreat_intent: Dictionary = combat.preview_intent()
	combat.enemy_turn()
	var approach_intent: Dictionary = combat.preview_intent()
	_check(str(retreat_intent.get("type", "")) == "retreat", "背刺者第一次无法绕后时应先撤离")
	_check(str(approach_intent.get("type", "")) != "retreat", "撤离后下一回合必须重新接近背后")
	_check(str(approach_intent.get("intent_value", "")).begins_with("+"), "重新接近背后时意图必须显示正向步数")


func _test_mixed_assault_backstab_sequence() -> void:
	var combat: RefCounted = CombatRules.new()
	combat.setup({
		"cols": 9, "rows": 5, "player": [1, 2], "player_facing": [0, 1],
		"walls": [], "heights": {}, "portals": [],
	}, [
		{"id": "close_hunter", "name": "近战猎手", "spawn": [4, 2], "action_points": 2, "attack_range": 1, "traits": []},
		{"id": "far_sentry", "name": "远射哨兵", "spawn": [7, 2], "action_points": 2, "attack_range": 2, "traits": ["ranged"]},
		{"id": "black_assassin", "name": "黑影背刺者", "spawn": [3, 1], "behavior_role": "flanker", "action_points": 4, "attack_cost": 2, "attack_range": 1, "hp": 1, "toughness": 0, "damage": 8, "traits": ["backstab"]},
	], {}, [], 20260825, {"player_hp": 50, "base_energy": 5}, [])
	var intent: Dictionary = combat.preview_intent("black_assassin")
	var intent_path: Array[Vector2i] = []
	intent_path.assign(intent.get("path", []))
	_check(intent_path == [Vector2i(2, 1), Vector2i(1, 1)], "混战场景的黑色敌人预览必须显示完整绕后路径")
	_check(str(intent.get("attack_kind", "")) == "backstab" and str(intent.get("intent_value", "")) == "8", "混战场景预览必须显示背刺攻击力")
	var events: Array[Dictionary] = combat.enemy_turn()
	var black_moves: Array[Vector2i] = []
	var black_attacked := false
	for event: Dictionary in events:
		if str(event.get("actor_id", "")) != "black_assassin":
			continue
		if str(event.get("kind", "")) == "move":
			black_moves.append(event.get("to", Vector2i(-1, -1)) as Vector2i)
		if str(event.get("kind", "")) == "attack" and str(event.get("attack_kind", "")) == "backstab":
			black_attacked = true
	_check(black_moves == [Vector2i(2, 1), Vector2i(1, 1)], "混战场景的黑色敌人必须沿背后路线移动")
	_check(black_attacked, "混战场景的黑色敌人绕到背后后必须攻击")


func _combat(enemy_pos: Vector2i, action_points: int, damage: int):
	var combat = CombatRules.new()
	var arena := {
		"cols": 5,
		"rows": 3,
		"player": [2, 1],
		"player_facing": [1, 0],
		"enemy": [enemy_pos.x, enemy_pos.y],
		"walls": [],
		"heights": {},
		"portals": [],
	}
	var enemy := {
		"id": "backstabber",
		"name": "黑影背刺者",
		"hp": 1,
		"damage": damage,
		"toughness": 0,
		"action_points": action_points,
		"attack_cost": 2,
		"attack_range": 1,
		"archetype": "assassin",
		"traits": ["backstab"],
	}
	combat.setup(arena, enemy, {}, [], 20260825, {"player_hp": 12, "base_energy": 5}, [])
	return combat


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
