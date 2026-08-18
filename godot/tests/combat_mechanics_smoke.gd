extends SceneTree

const WebContentAdapter = preload("res://scripts/web_content_adapter.gd")
const CombatRules = preload("res://scripts/combat_rules.gd")

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
	trap_combat.enemy_turn()
	_check(trap_combat.enemy_hp == 8, "enemy should take 2 trap damage")
	_check(trap_combat.enemy_toughness == 1, "basic damage trap should drain 2 toughness")

	var ready_combat = CombatRules.new()
	ready_combat.setup(arena, _enemy(4), cards, ["brace", "guard", "focus", "tonic"], 2, rules, [])
	var brace_index: int = ready_combat.hand.find("brace")
	_check(brace_index >= 0 and ready_combat.play_card(brace_index, ready_combat.enemy_pos), "brace should arm instantly")
	ready_combat.enemy_turn()
	_check(ready_combat.event_log.any(func(line: String) -> bool: return line.begins_with("ReadyTriggered")), "ready should trigger when enemy enters the cross zone")

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
