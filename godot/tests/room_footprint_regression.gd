extends SceneTree

const RoomRules = preload("res://scripts/room_rules.gd")
const RoomFootprintCatalog = preload("res://scripts/room_footprint_catalog.gd")
const WebContentAdapter = preload("res://scripts/web_content_adapter.gd")

var failures: Array[String] = []


func _init() -> void:
	var content: Dictionary = WebContentAdapter.new("res://data/web_snapshot/", "test").build_content(1337)
	var tier_counts := {"beat": 0, "minigame": 0, "elite": 0}
	for room: Dictionary in content.get("rooms", []):
		var tier := str(room.get("encounter_tier", ""))
		tier_counts[tier] = int(tier_counts.get(tier, 0)) + 1
		_check(int(room.get("room_size", 0)) in [1, 3, 5], "every room must use a 1/3/5 footprint")
	_check(int(tier_counts["beat"]) == 12, "build catalog must keep twelve one-cell pacing rooms after excluding start and finale")
	_check(int(tier_counts["minigame"]) == 5, "catalog must expose five three-cell minigame rooms")
	_check(int(tier_counts["elite"]) == 4, "non-boss catalog must expose four five-cell elite rooms")
	_check(RoomFootprintCatalog.ROOM_CONFIG.size() == 24, "footprint catalog must classify all 24 rooms including start and boss")
	for room: Dictionary in content.get("rooms", []):
		var isolated_rules = RoomRules.new()
		isolated_rules.reset({"id": "start", "doors": [true, true, true, true], "footprint": [[0, 0]], "room_size": 1})
		var has_legal_entrance := false
		for frontier: Vector2i in isolated_rules.frontiers():
			if not isolated_rules.valid_rotations(frontier, room).is_empty():
				has_legal_entrance = true
				break
		_check(has_legal_entrance, "%s must have at least one legal entrance alignment around an isolated room" % str(room.get("id", "room")))

	var rules = RoomRules.new()
	rules.reset({"id": "start", "doors": [true, true, true, true], "footprint": [[0, 0]], "room_size": 1})
	var line_room := {
		"id": "line_test",
		"doors": [false, false, false, true],
		"footprint": [[0, 0], [1, 0], [2, 0]],
		"room_size": 3,
	}
	_check(rules.can_place(Vector2i.RIGHT, line_room, 0), "three-cell line must attach through its entrance cell")
	_check(rules.place(Vector2i.RIGHT, line_room, 0), "legal three-cell room must occupy all cells")
	_check(rules.placed.has(Vector2i(1, 0)) and rules.placed.has(Vector2i(2, 0)) and rules.placed.has(Vector2i(3, 0)), "line room must reserve three world cells")
	_check(rules.same_instance(Vector2i(1, 0), Vector2i(3, 0)), "all occupied cells must share one room instance")
	_check(rules.instance_count() == 2, "three occupied cells must count as one room plus start")
	rules.set_instance_flag(Vector2i(2, 0), "completed", true)
	_check(bool(rules.placed[Vector2i(1, 0)].get("completed", false)) and bool(rules.placed[Vector2i(3, 0)].get("completed", false)), "completion from any cell must synchronize across the whole room")
	_check(rules.cell_has_door(Vector2i(1, 0), 1), "adjacent cells inside one room must always connect")
	_check((rules.placed[Vector2i(1, 0)].get("open_edges", []) as Array).size() == 1, "a three-cell room direction must resolve to one exact outer-edge doorway instead of opening every parallel cell")

	var plus_rules = RoomRules.new()
	plus_rules.reset({"id": "start", "doors": [true, true, true, true], "footprint": [[0, 0]], "room_size": 1})
	var plus_room := {"id": "plus_test", "doors": [true, true, true, true], "footprint": RoomFootprintCatalog.SHAPES["plus5"], "room_size": 5}
	var plus_target := Vector2i.RIGHT
	_check(plus_rules.can_place(plus_target, plus_room, 0), "center-origin plus room must align a boundary cell to the selected frontier")
	_check(plus_rules.place(plus_target, plus_room, 0), "five-cell plus room must place without covering the existing room")
	_check(plus_rules.placed.has(plus_target) and plus_rules.instance_count() == 2, "selected frontier must become an occupied cell of the placed plus room")
	_check(not plus_rules.same_instance(Vector2i.ZERO, plus_target), "the connected one-cell and five-cell footprints must remain distinguishable room instances")
	_check(plus_rules.cell_has_door(Vector2i.ZERO, 1) and plus_rules.cell_has_door(plus_target, 3), "the one-to-five boundary must preserve a reciprocal doorway connection")
	_check((plus_rules.placed[plus_target].get("open_edges", []) as Array).size() == 4, "a four-direction five-cell room must store four exact world-edge sockets")

	if failures.is_empty():
		print("CHANNEL_ROOM_FOOTPRINT: PASS tiers multi-cell occupancy shared-completion")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_ROOM_FOOTPRINT: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
