extends SceneTree

const CombatRules = preload("res://scripts/combat_rules.gd")

var failures: Array[String] = []


func _init() -> void:
	_test_placement_smash()
	_test_single_enemy_target_requires_id_when_ambiguous()
	_test_selected_card_index_is_removed()
	if failures.is_empty():
		print("CHANNEL_MULTI_ENEMY_TARGETING: PASS placement-smash explicit-single-target")
		quit(0)
		return
	for failure in failures:
		push_error("CHANNEL_MULTI_ENEMY_TARGETING: %s" % failure)
	print("CHANNEL_MULTI_ENEMY_TARGETING: FAIL count=%d" % failures.size())
	quit(1)


func _test_placement_smash() -> void:
	var rules := CombatRules.new()
	rules.setup(
		{"cols": 5, "rows": 1, "player": [1, 0], "enemy": [2, 0], "walls": [], "heights": {}},
		{"id": "target", "spawn": [2, 0], "name": "Target", "hp": 6, "toughness": 3},
		{"jab": {"id": "jab", "type": "place", "cost": 1, "place": {"onStep": {"damage": 2}}}},
		["jab"],
		17,
		{"player_hp": 6, "base_speed": 3, "base_energy": 3},
		[]
	)
	var before: int = rules.enemy_hp
	rules.energy = 3
	_check(rules.can_target_place_card(0, rules.enemy_pos), "placement smash target must be legal")
	_check(rules.play_card(0, rules.enemy_pos), "placement smash must be accepted")
	_check(rules.enemy_hp < before, "placement smash must damage the enemy")
	_check(not rules.last_card_events.is_empty(), "placement smash must emit a target event")
	if not rules.last_card_events.is_empty():
		_check(str(rules.last_card_events[0].get("target_enemy_id", "")) == "target", "placement smash event must name target")


func _test_single_enemy_target_requires_id_when_ambiguous() -> void:
	var rules := CombatRules.new()
	rules.setup(
		{"cols": 6, "rows": 1, "player": [0, 0], "walls": [], "heights": {"0,0": 1, "2,0": 0, "4,0": 0}},
		[
			{"id": "a", "spawn": [2, 0], "hp": 6, "toughness": 3},
			{"id": "b", "spawn": [4, 0], "hp": 6, "toughness": 3}
		],
		{"topple": {"id": "topple", "type": "skill", "cost": 0, "topple": true}},
		["topple"],
		19,
		{"player_hp": 6, "base_speed": 3, "base_energy": 3},
		[]
	)
	rules.energy = 3
	var card: Dictionary = rules.cards["topple"]
	_check(str(rules.card_target_type(card)) == "single_enemy", "topple must be a single-enemy card")
	_check(not rules.play_card(0, Vector2i(2, 0)), "ambiguous single-enemy card must reject implicit target")
	_check(rules.play_card(0, Vector2i(2, 0), "a"), "explicit single-enemy target must be accepted when valid")


func _test_selected_card_index_is_removed() -> void:
	var rules := CombatRules.new()
	rules.setup(
		{"cols": 5, "rows": 1, "player": [0, 0], "enemy": [4, 0], "walls": [], "heights": {}},
		{"id": "target", "spawn": [4, 0], "hp": 6, "toughness": 3},
		{
			"guard": {"id": "guard", "type": "skill", "cost": 1, "gain_block": 2},
			"topple": {"id": "topple", "type": "skill", "cost": 0, "topple": true},
		},
		["guard", "topple", "guard"],
		23,
		{"player_hp": 6, "base_speed": 3, "base_energy": 3},
		[]
	)
	rules.energy = 3
	_check(rules.card_executor == null, "card executor should be created lazily before the first play")
	_check(rules.play_card(2, Vector2i(0, 0)), "selected duplicate card should be accepted")
	_check(rules.card_executor != null, "card play must be routed through the card executor")
	_check(rules.hand == ["guard", "topple"], "card play must remove the selected hand index")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
