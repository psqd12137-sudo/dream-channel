extends SceneTree

const WebContentAdapter = preload("res://scripts/web_content_adapter.gd")
const CombatRules = preload("res://scripts/combat_rules.gd")

var failures: Array[String] = []


func _init() -> void:
	var content: Dictionary = WebContentAdapter.new().build_content(2522061406)
	var hall := _find_room(content.get("rooms", []), "hall")
	var combat = CombatRules.new()
	combat.setup(hall.get("arena", {}), hall.get("enemy", {}), content.get("cards", {}), ["focus", "guard", "tonic", "brace"], 77, {"player_hp": 6, "base_speed": 3, "hand_size": 4, "move_cost": 1, "dice_faces": [1]}, [])
	combat.enemy_revealed = false
	combat.enemy_sees_player = false
	combat.player_sees_enemy = false
	combat.ambush_active = true
	combat.ambush_idle_turns = 0
	combat.last_seen = combat.INVALID_CELL
	combat.patrol_goal = combat.INVALID_CELL

	var first_intent: Dictionary = combat.preview_intent()
	_check(str(first_intent.get("type", "")) == "ambush", "first hidden turn must clearly announce the ambush wait")
	var start: Vector2i = combat.enemy_pos
	var first_events: Array[Dictionary] = combat.enemy_turn()
	_check(combat.enemy_pos == start, "ambush may hold for one enemy turn")
	_check(first_events.any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "wait"), "ambush hold must emit a visible wait event")

	combat.energy = 3
	var patrol_intent: Dictionary = combat.preview_intent()
	_check(str(patrol_intent.get("type", "")) == "patrol", "after one beat the hidden enemy must publish patrol intent")
	_check(not (patrol_intent.get("path", []) as Array).is_empty(), "patrol intent must show a blue movement path")
	var patrol_events: Array[Dictionary] = combat.enemy_turn()
	_check(combat.enemy_pos != start, "hidden enemy must actually leave the spawn and patrol")
	_check(patrol_events.any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "move"), "patrol must emit movement events for animation")

	combat.enemy_sees_player = true
	combat.enemy_revealed = true
	combat.player_sees_enemy = true
	combat.last_seen = combat.player_pos
	var chase_intent: Dictionary = combat.preview_intent()
	_check(str(chase_intent.get("type", "")) in ["chase", "attack"], "established sight must switch intent to chase or attack")
	_check(not str(chase_intent.get("detail", "")).is_empty(), "every chase/attack intent must have a visible explanation")

	if failures.is_empty():
		print("CHANNEL_ENEMY_PATROL_INTENT: PASS ambush-wait patrol-path movement chase-intent")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_ENEMY_PATROL_INTENT: %s" % failure)
		quit(1)


func _find_room(rooms: Array, room_id: String) -> Dictionary:
	for room: Dictionary in rooms:
		if str(room.get("id", "")) == room_id:
			return room
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
