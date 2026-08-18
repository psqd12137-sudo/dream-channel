extends SceneTree

const RoomRules = preload("res://scripts/room_rules.gd")
const CombatRules = preload("res://scripts/combat_rules.gd")


func _init() -> void:
	var raw := FileAccess.get_file_as_string("res://data/prototype_content.json")
	var content: Dictionary = JSON.parse_string(raw)
	assert(not content.is_empty(), "content JSON must load")
	assert(int(content.get("schema_version", 0)) == 1, "schema version must be 1")

	var room_rules = RoomRules.new()
	room_rules.reset(content["start_room"])
	var room: Dictionary = content["rooms"][0]
	var target := Vector2i.RIGHT
	assert(not room_rules.can_place(target, room, 0), "closed west edge must reject start-room east door")
	assert(room_rules.can_place(target, room, 2), "180 degree rotation must open west edge")
	assert(room_rules.place(target, room, 2), "legal room placement must commit")
	assert(room_rules.placed.size() == 2, "board must contain start plus placed room")

	var combat = CombatRules.new()
	combat.setup(room["arena"], content["enemy"], content["cards"], content["starter_deck"], 1339)
	combat.hand.assign(["spike", "salt", "keepsake", "shove"])
	combat.energy = 4
	assert(combat.play_card(0, Vector2i(1, 1)), "spike should place next to player")
	var hp_before: int = combat.enemy_hp
	var intent: Dictionary = combat.preview_intent()
	assert(not intent["path"].is_empty(), "enemy must have a chase path")
	combat.enemy_turn()
	assert(combat.enemy_hp < hp_before, "enemy must take damage after chasing onto spike")
	assert(combat.event_log.size() >= 4, "combat must emit deterministic facts")

	print("CHANNEL_GODOT_SMOKE: PASS rooms=%d enemy_hp=%d log=%d" % [room_rules.placed.size(), combat.enemy_hp, combat.event_log.size()])
	quit(0)

