extends SceneTree

const WebContentAdapter = preload("res://scripts/web_content_adapter.gd")
const CombatRules = preload("res://scripts/combat_rules.gd")
const CombatStatus = preload("res://scripts/combat_status.gd")

var failures: Array[String] = []


func _init() -> void:
	var content: Dictionary = WebContentAdapter.new().build_content(21)
	var cards: Dictionary = content["cards"]
	var arena := {
		"cols": 5,
		"rows": 1,
		"player": [0, 0],
		"enemy": [4, 0],
		"walls": [],
		"heights": {},
		"portals": [],
	}
	var rules := {"player_hp": 6, "base_speed": 3, "base_energy": 5, "hand_size": 4, "move_cost": 1}

	var trap_combat = CombatRules.new()
	trap_combat.setup(arena, _enemy(3), cards, ["jab", "guard", "focus", "tonic"], 1, rules, [])
	_check(trap_combat.energy == 5 and trap_combat.energy_rolls.is_empty(), "player turns must use a fixed 5 AP budget without 0/1/2 dice")
	var jab_index: int = trap_combat.hand.find("jab")
	_check(jab_index >= 0 and trap_combat.play_card(jab_index, Vector2i(1, 0)), "jab should place on an adjacent cell")
	var trap_events: Array = trap_combat.enemy_turn()
	_check(trap_combat.enemy_hp == 8, "enemy should take 2 trap damage")
	_check(trap_combat.enemy_toughness == 1, "basic damage trap should drain 2 toughness")
	var trap_damage_event_found := false
	for raw_event in trap_events:
		var event: Dictionary = raw_event
		if str(event.get("kind", "")) == "enemy_damaged" and int(event.get("damage", 0)) == 2:
			trap_damage_event_found = true
			_check(str(event.get("label", "")).contains("地刺"), "spike trigger event must identify the spike trap")
			_check((event.get("trap", {}) as Dictionary).get("glyph", "") == "刺", "spike damage event must carry the triggered trap visual snapshot")
	_check(trap_damage_event_found, "enemy stepping on a damage trap must publish a damage event for presentation")

	var status_combat = CombatRules.new()
	status_combat.setup(arena, _enemy(2), cards, ["guard", "focus", "tonic", "jab"], 12, rules, [])
	var status_enemy = status_combat.enemy_by_id(status_combat.enemy_order[0])
	status_enemy.status_effects["bleed"] = {"stacks": 2, "turns": 3}
	var bleed_status: Dictionary = {}
	for status: Dictionary in status_combat.enemy_statuses(status_enemy):
		if str(status.get("id", "")) == "bleed":
			bleed_status = status
	_check(str(bleed_status.get("category", "")) == "debuff", "generic enemy statuses must expose a canonical category")
	_check(int(bleed_status.get("stacks", 0)) == 2 and int(bleed_status.get("duration", 0)) == 3, "generic enemy statuses must normalize stacks and duration")
	_check(str(bleed_status.get("text", "")).contains("流血×2") and str(bleed_status.get("text", "")).contains("3回合"), "normalized status text must include label, stacks and duration")
	status_combat.gain_player_shield(2, "test")
	status_combat.set_player_status("focus", "buff", "专注", 1, 1, "next_action", "test", "下一张放置牌")
	var player_statuses: Array[Dictionary] = status_combat.player_statuses_view()
	_check(player_statuses.any(func(status: Dictionary) -> bool: return str(status.get("id", "")) == "shield"), "player shield must be exposed as a resource status")
	_check(player_statuses.any(func(status: Dictionary) -> bool: return str(status.get("id", "")) == "focus" and str(status.get("category", "")) == "buff"), "player temporary effects must use the shared status contract")
	_check(status_combat.statuses_for_player().size() == player_statuses.size(), "canonical player status entry point should match compatibility view")
	status_combat.set_player_status("momentum", "buff", "动量", 1, 1, CombatStatus.DURATION_TURNS, "test")
	CombatStatus.tick_turns(status_combat.player_statuses)
	_check(status_combat.player_statuses_view().all(func(status: Dictionary) -> bool: return str(status.get("id", "")) != "momentum"), "turn-limited statuses should expire through the shared ledger")
	var enemy_toughness_before: int = status_enemy.toughness
	var enemy_hp_before: int = status_enemy.hp
	var hit_result: Dictionary = status_combat._apply_player_hit(status_enemy, "melee", 3)
	_check(int(hit_result.get("shield_blocked", 0)) == 2 and int(hit_result.get("damage", 0)) == 1, "shield must absorb player damage independently")
	_check(status_combat.player_shield == 0 and status_combat.player_hp == 5, "shield must be consumed before player HP")
	_check(status_enemy.toughness == enemy_toughness_before, "player shield and enemy toughness must never share a damage rule")
	status_combat._apply_enemy_damage(status_enemy, 0, 2, "status-test")
	_check(status_enemy.hp == enemy_hp_before and status_enemy.toughness == enemy_toughness_before - 2, "toughness damage must be able to resolve without HP damage")

	var ready_combat = CombatRules.new()
	ready_combat.setup(arena, _enemy(4), cards, ["brace", "guard", "focus", "tonic"], 2, rules, [])
	var brace_index: int = ready_combat.hand.find("brace")
	_check(brace_index >= 0 and ready_combat.play_card(brace_index, ready_combat.enemy_pos), "brace should arm instantly")
	ready_combat.enemy_turn()
	_check(ready_combat.event_log.any(func(line: String) -> bool: return line.begins_with("ReadyTriggered")), "ready should trigger when enemy enters the cross zone")

	var fling_combat = CombatRules.new()
	fling_combat.setup(arena, _enemy(4), cards, ["fling", "guard", "focus", "tonic"], 6, rules, [])
	var fling_index: int = fling_combat.hand.find("fling")
	_check(fling_index >= 0 and fling_combat.play_card(fling_index, fling_combat.enemy_pos), "fling should arm instantly")
	var fling_events: Array[Dictionary] = fling_combat.enemy_turn()
	_check(fling_combat.event_log.any(func(line: String) -> bool: return line.begins_with("ReadyTriggered")), "fling should trigger when enemy enters the cross zone")
	_check(fling_combat.enemy_pos == Vector2i(2, 0), "fling should leave the enemy one cell away instead of walking back into adjacency")
	_check(fling_events.any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "enemy_shove" and str(event.get("label", "")) == "甩开"), "fling should publish a dedicated visible shove event")

	var decoy_combat = CombatRules.new()
	decoy_combat.setup(arena, _enemy(5), cards, ["decoy", "guard", "focus", "tonic"], 3, rules, [])
	var decoy_index: int = decoy_combat.hand.find("decoy")
	_check(decoy_index >= 0 and decoy_combat.play_card(decoy_index, Vector2i(1, 0)), "decoy should place on an adjacent cell")
	_check(not decoy_combat.can_move_player(Vector2i(1, 0)), "paper decoy must visibly occupy its cell like the Web implementation")
	decoy_combat.enemy_turn()
	_check(not decoy_combat.has_decoy(), "enemy should prioritize and destroy the decoy")
	_check(decoy_combat.player_hp == 6, "decoy attack should not damage the player")
	_check(decoy_combat.enemy_pos == Vector2i(1, 0), "enemy must spend attack AP on the decoy and continue with any remaining AP")

	var combo_arena := arena.duplicate(true)
	combo_arena["cols"] = 6
	combo_arena["enemy"] = [5, 0]
	var combo_combat = CombatRules.new()
	combo_combat.setup(combo_arena, _enemy(2), cards, ["decoy", "guard", "focus", "tonic"], 4, rules, [])
	combo_combat.decoy_pos = Vector2i(1, 0)
	combo_combat.traps[Vector2i(3, 0)] = {"card_id": "jab", "damage": 2, "tough": 2}
	combo_combat.enemy_turn()
	_check(combo_combat.enemy_hp == 7, "chasing a paper decoy through a damage trap must add the Web paper-shadow combo +1")
	_check(combo_combat.event_log.has("ComboTriggered name=纸影连击"), "paper-shadow trap combo must be named in the combat log")

	if failures.is_empty():
		print("CHANNEL_COMBAT_MECHANICS_SMOKE: PASS fixed-ap trap ready decoy")
		quit(0)
	else:
		for failure in failures:
			push_error("CHANNEL_COMBAT_MECHANICS_SMOKE: %s" % failure)
		quit(1)


func _enemy(action_points: int) -> Dictionary:
	return {
		"name": "测试剪影",
		"hp": 10,
		"damage": 1,
		"toughness": 3,
		"action_points": action_points,
		"attack_cost": 2,
		"archetype": "execute",
		"archetype_label": "处决匣",
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
