extends SceneTree

const CombatRules = preload("res://scripts/combat_rules.gd")

var failures: Array[String] = []


func _init() -> void:
	_test_backstab_never_attacks_from_front()
	_test_backstab_attacks_from_back()
	_test_backstab_retreats_when_route_is_unavailable()
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
	_check(not attacked, "背后攻击位不可达时不能退化为正面攻击")
	_check(combat.manhattan(combat.enemy_pos, combat.player_pos) > 1, "背刺者无法绕后时必须拉开与玩家的距离")
	_check(combat.player_hp == 12, "拉开距离时不能对玩家造成伤害")


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
