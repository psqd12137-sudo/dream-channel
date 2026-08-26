extends SceneTree

const WebContentAdapter = preload("res://scripts/web_content_adapter.gd")
const CombatRules = preload("res://scripts/combat_rules.gd")

var failures: Array[String] = []
var cards := {
	"med": {"id": "med", "name": "药", "type": "medicine", "stealable": true},
	"junk": {"id": "junk", "name": "杂物", "type": "skill"},
}
var rules := {"player_hp": 12, "base_speed": 3, "base_energy": 5, "hand_size": 2, "move_cost": 1}


func _init() -> void:
	_test_adapter_traits()
	_test_face_shock_and_corner_cut()
	_test_lunge_and_relentless()
	_test_vault_and_trap_aware()
	_test_guard_break_and_grab()
	_test_slam_beam_and_flurry()
	if failures.is_empty():
		print("CHANNEL_ENEMY_TRAITS: PASS 11 traits shared-intent execution")
		quit(0)
	else:
		for failure in failures:
			push_error("CHANNEL_ENEMY_TRAITS: %s" % failure)
		quit(1)


func _test_adapter_traits() -> void:
	var adapter := WebContentAdapter.new()
	var content: Dictionary = adapter.build_content(20260820)
	var rooms: Array = content.get("rooms", [])
	var living := _room_by_id(rooms, "living")
	var hall := _room_by_id(rooms, "hall")
	_check("faceShock" in living.get("enemy", {}).get("traits", []), "adapter must attach living room faceShock")
	_check("cornerCut" in living.get("enemy", {}).get("traits", []), "adapter must attach living room cornerCut")
	_check("beam" in hall.get("enemy", {}).get("traits", []), "hall's explicitly configured enemy must keep beam")
	var pressure: Dictionary = adapter._load_json("pressure.json")
	var ordinary := adapter._scale_enemy({"name": "普通敌人", "traits": []}, "hall", 1, pressure)
	_check("beam" not in ordinary.get("traits", []), "room beam must not turn an ordinary enemy into a ranged attacker")
	var authored_ranged := adapter._scale_enemy({"name": "远射敌人", "traits": ["ranged"]}, "living", 1, pressure)
	_check("ranged" in authored_ranged.get("traits", []), "an explicitly configured ranged enemy must keep ranged")


func _test_face_shock_and_corner_cut() -> void:
	var shock = _combat(_arena(5, 1, Vector2i(0, 0), Vector2i(4, 0)), ["faceShock"], 3, 1)
	shock.player_exposed = true
	shock.enemy_sees_player = true
	var shock_events: Array = shock.enemy_turn()
	_check(shock.player_hp == 11, "faceShock must deal 1 when reacquired target is out of reach")
	_check(shock_events.any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "face_shock"), "faceShock must emit a visible event")

	var cut = _combat(_arena(5, 1, Vector2i(0, 0), Vector2i(4, 0)), ["cornerCut"], 1, 2)
	cut.player_exposed = true
	cut.enemy_sees_player = true
	var cut_events: Array = cut.enemy_turn()
	_check(cut_events.any(func(event: Dictionary) -> bool: return bool(event.get("free", false))), "cornerCut must emit a free movement step")
	_check(cut.enemy_pos.x <= 2, "cornerCut free step must not consume the normal movement budget")


func _test_lunge_and_relentless() -> void:
	var lunge = _combat(_arena(3, 1, Vector2i(0, 0), Vector2i(2, 0)), ["lunge"], 3, 3)
	var lunge_intent: Dictionary = lunge.preview_intent()
	var lunge_events: Array = lunge.enemy_turn()
	_check(str(lunge_intent.get("attack_kind", "")) == "lunge", "lunge intent must identify the attack before execution")
	_check(lunge.enemy_pos == Vector2i(1, 0) and lunge.player_hp == 11, "lunge must land adjacent and deal damage from distance 2")
	_check(lunge_events.any(func(event: Dictionary) -> bool: return str(event.get("label", "")) == "突进"), "lunge must expose its movement event")

	var relentless = _combat(_arena(2, 1, Vector2i(0, 0), Vector2i(1, 0)), ["relentless"], 1, 4)
	relentless.enemy_turn()
	_check(relentless.player_hp == 11, "relentless must attack with only 1 action point while it has sight")


func _test_vault_and_trap_aware() -> void:
	var shaped_arena := _arena(4, 2, Vector2i(0, 0), Vector2i(2, 1))
	shaped_arena["heights"] = {"2,0": 1}
	var vault = _combat(shaped_arena, ["vault"], 1, 5)
	vault.enemy_turn()
	_check(vault.enemy_pos == Vector2i(2, 0), "vault must prefer a higher neighbor that does not increase target distance")

	var aware = _combat(_arena(4, 2, Vector2i(0, 0), Vector2i(2, 1)), ["trapAware"], 1, 6)
	aware.traps[Vector2i(1, 1)] = {"card_id": "hazard", "damage": 2}
	aware.enemy_turn()
	_check(aware.enemy_pos == Vector2i(2, 0), "trapAware must avoid an equally short hazardous step")


func _test_guard_break_and_grab() -> void:
	var breaker = _combat(_arena(2, 1, Vector2i(0, 0), Vector2i(1, 0)), ["guardBreak"], 3, 7, 2)
	breaker.player_block = 5
	var break_intent: Dictionary = breaker.preview_intent()
	breaker.enemy_turn()
	_check(str(break_intent.get("attack_kind", "")) == "guardBreak", "guardBreak must be announced when defense is present")
	_check(breaker.player_hp == 10 and breaker.player_block == 0, "guardBreak must ignore and clear card block")

	var grabber = _combat(_arena(2, 1, Vector2i(0, 0), Vector2i(1, 0)), ["grab"], 2, 8)
	var grab_events: Array = grabber.enemy_turn()
	var stolen := ""
	for event: Dictionary in grab_events:
		if not str(event.get("stolen_card", "")).is_empty():
			stolen = str(event["stolen_card"])
	_check(stolen == "med", "grab must prefer a stealable medicine after the hand enters discard")
	_check(not grabber.hand.has("med") and not grabber.discard.has("med") and not grabber.deck.has("med"), "grabbed card must leave all combat card zones")


func _test_slam_beam_and_flurry() -> void:
	var slam = _combat(_arena(4, 3, Vector2i(1, 1), Vector2i(2, 1)), ["slam"], 2, 9)
	var slam_intent: Dictionary = slam.preview_intent()
	var slam_events: Array = slam.enemy_turn()
	_check(str(slam_intent.get("attack_kind", "")) == "slam" and (slam_intent.get("hurt", []) as Array).size() == 4, "slam must telegraph its 2x2 area")
	_check(slam_events.any(func(event: Dictionary) -> bool: return str(event.get("attack_kind", "")) == "slam"), "slam execution must retain the telegraphed attack kind")

	var beam = _combat(_arena(4, 3, Vector2i(0, 1), Vector2i(3, 1)), ["beam"], 2, 10, 2)
	var charge_intent: Dictionary = beam.preview_intent()
	var hp_before: int = int(beam.player_hp)
	var charge_events: Array = beam.enemy_turn()
	_check(bool(charge_intent.get("pending", false)) and str(charge_intent.get("attack_kind", "")) == "beam", "beam must show a pending red line before charging")
	_check(beam.player_hp == hp_before and not beam.beam_pending_cells.is_empty(), "beam charge turn must not deal immediate damage")
	_check(charge_events.any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "beam_charge"), "beam must emit a charge event")
	beam.start_player_turn()
	var fire_intent: Dictionary = beam.preview_intent()
	var fire_events: Array = beam.enemy_turn()
	_check(bool(fire_intent.get("pending", false)) and Vector2i(0, 1) in fire_intent.get("hurt", []), "charged beam must preserve the original red cells across turns")
	_check(beam.player_hp == hp_before - 2, "charged beam must damage a player who remains in the locked line")
	_check(fire_events.any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "beam_fire"), "beam must emit a separate fire event")

	var flurry = _combat(_arena(2, 1, Vector2i(0, 0), Vector2i(1, 0)), ["flurry"], 4, 11)
	var flurry_intent: Dictionary = flurry.preview_intent()
	var flurry_events: Array = flurry.enemy_turn()
	var hit_count := 0
	for event: Dictionary in flurry_events:
		if str(event.get("kind", "")) == "attack":
			hit_count += 1
	_check(int(flurry_intent.get("hits", 0)) == 2 and hit_count == 2, "flurry intent and execution must agree on two hits")
	_check(flurry.player_hp == 10, "flurry must apply both damage segments")


func _combat(arena: Dictionary, traits: Array[String], action_points: int, seed: int, damage: int = 1):
	var combat = CombatRules.new()
	combat.setup(arena, {
		"name": "测试剪影",
		"hp": 10,
		"damage": damage,
		"toughness": 3,
		"action_points": action_points,
		"attack_cost": 2,
		"archetype": "execute",
		"traits": traits,
	}, cards, ["med", "junk"], seed, rules, [])
	return combat


func _arena(cols: int, rows: int, player: Vector2i, enemy: Vector2i) -> Dictionary:
	return {"cols": cols, "rows": rows, "player": [player.x, player.y], "enemy": [enemy.x, enemy.y], "walls": [], "heights": {}, "portals": []}


func _room_by_id(rooms: Array, room_id: String) -> Dictionary:
	for room: Dictionary in rooms:
		if str(room.get("id", "")) == room_id:
			return room
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
