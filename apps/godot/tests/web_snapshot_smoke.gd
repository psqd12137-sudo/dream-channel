extends SceneTree

const WebContentAdapter = preload("res://scripts/web_content_adapter.gd")
const CombatRules = preload("res://scripts/combat_rules.gd")

var failures: Array[String] = []


func _init() -> void:
	var content: Dictionary = WebContentAdapter.new().build_content(1337)
	_check(int(content.get("source_room_count", 0)) == 24, "source room count should be 24")
	_check(content.get("rooms", []).size() == 21, "offer catalog should exclude foyer and two boss rooms")
	_check(content.get("cards", {}).size() == 31, "card catalog should contain 31 Web cards")
	_check(content.get("relics", {}).size() == 8, "relic catalog should contain 8 omens")

	var living := _find_room(content.get("rooms", []), "living")
	_check(not living.is_empty(), "living room should be adapted")
	if not living.is_empty():
		var arena: Dictionary = living.get("arena", {})
		_check(arena.get("player", []) == [0, 2], "Web [row,col] player position should become [x,y]")
		_check(arena.get("enemy", []) == [4, 0], "Web [row,col] enemy position should become [x,y]")
		var combat = CombatRules.new()
		combat.setup(arena, living.get("enemy", {}), content["cards"], ["focus", "jab", "brace", "tonic"], 7, {"player_hp": 6, "base_speed": 3, "hand_size": 4, "move_cost": 1, "dice_faces": [2]}, content.get("active_relics", []))
		_check(combat.is_walkable(combat.player_pos), "adapted player position should be in bounds")
		_check(combat.is_walkable(combat.enemy_pos), "adapted enemy position should be in bounds")
		_check(combat.energy == 7, "three speed dice plus omen_signal should produce 7 AP with fixed faces")
		var focus_index: int = combat.hand.find("focus")
		_check(focus_index >= 0 and combat.play_card(focus_index, combat.enemy_pos), "focus should play as an instant skill")
		_check(combat.card_cost(content["cards"]["jab"]) == 0, "focus should discount the next placement")

	if failures.is_empty():
		print("CHANNEL_WEB_SNAPSHOT_SMOKE: PASS rooms=24 offers=21 cards=31 relics=8")
		quit(0)
	else:
		for failure in failures:
			push_error("CHANNEL_WEB_SNAPSHOT_SMOKE: %s" % failure)
		quit(1)


func _find_room(rooms: Array, id: String) -> Dictionary:
	for room in rooms:
		if str(room.get("id", "")) == id:
			return room
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
