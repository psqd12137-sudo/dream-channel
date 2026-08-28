extends SceneTree

const RoomFootprintCatalog = preload("res://scripts/room_footprint_catalog.gd")
const DungeonLayoutCatalog = preload("res://scripts/dungeon_layout_catalog.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var seen_layout_ids: Dictionary = {}
	for raw_room_id: Variant in RoomFootprintCatalog.ROOM_CONFIG.keys():
		var room_id := str(raw_room_id)
		var link := DungeonLayoutCatalog.link_for(room_id)
		_check(str(link.get("world_room_id", "")) == room_id, "mapping must preserve world room id: %s" % room_id)
		var layout_id := str(link.get("dungeon_layout_id", ""))
		_check(not layout_id.is_empty(), "mapping must provide a dungeon layout id: %s" % room_id)
		_check(not seen_layout_ids.has(layout_id), "dungeon layout ids must be unique: %s" % layout_id)
		seen_layout_ids[layout_id] = true
		_check(layout_id == DungeonLayoutCatalog.default_layout_id(room_id), "default layout id must be deterministic: %s" % room_id)
		var shape_id := str((RoomFootprintCatalog.ROOM_CONFIG[room_id] as Dictionary).get("shape", "single"))
		var expected_size := (RoomFootprintCatalog.SHAPES[shape_id] as Array).size()
		_check(int(link.get("default_footprint_size", 0)) == expected_size, "default footprint size must match world room: %s" % room_id)
	_check(DungeonLayoutCatalog.layout_path("boiler_dungeon_01") == "res://data/editor/dungeon_layouts/boiler_dungeon_01.json", "layout path must use dungeon layout directory")
	var missing := DungeonLayoutCatalog.load_layout("__missing_dungeon_layout__", "boiler")
	_check(missing.is_empty(), "missing dungeon layout must fall back without returning invalid data")
	if failures.is_empty():
		print("CHANNEL_DUNGEON_LAYOUT_CATALOG: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_DUNGEON_LAYOUT_CATALOG: " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
