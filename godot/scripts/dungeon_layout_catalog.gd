extends RefCounted

const RoomFootprintCatalog = preload("res://scripts/room_footprint_catalog.gd")

const MANIFEST_PATH := "res://data/editor/dungeon_layout_manifest.json"
const LAYOUT_DIR := "res://data/editor/dungeon_layouts/"

static var _manifest_cache: Dictionary = {}
static var _room_records: Dictionary = {}


static func room_record(room_id: String) -> Dictionary:
	if _room_records.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/exe_snapshot/rooms.json"))
		if parsed is Dictionary:
			_room_records = parsed.get("rooms", {})
	return _room_records.get(room_id, {})


static func has_dungeon(room_id: String) -> bool:
	for link: Dictionary in _manifest().get("links", []):
		if str(link.get("world_room_id", "")) == room_id and link.has("has_dungeon"):
			return bool(link["has_dungeon"])
	return bool(room_record(room_id).get("combat", false)) or room_id == "altar"


static func link_for(world_room_id: String) -> Dictionary:
	var clean_id := _clean_id(world_room_id)
	var config: Dictionary = RoomFootprintCatalog.ROOM_CONFIG.get(clean_id, {})
	var shape_id := str(config.get("shape", "single"))
	var shape: Array = RoomFootprintCatalog.SHAPES.get(shape_id, RoomFootprintCatalog.SHAPES["single"])
	var fallback := {
		"world_room_id": clean_id,
		"dungeon_layout_id": default_layout_id(clean_id),
		"footprint_mode": "inherit",
		"default_footprint_kind": shape_id,
		"default_footprint_size": shape.size(),
	}
	for raw_link: Variant in _manifest().get("links", []):
		if not raw_link is Dictionary:
			continue
		var link := raw_link as Dictionary
		if str(link.get("world_room_id", "")) != clean_id:
			continue
		var result := fallback.duplicate(true)
		result["dungeon_layout_id"] = _clean_id(str(link.get("dungeon_layout_id", "")))
		if str(result["dungeon_layout_id"]).is_empty():
			result["dungeon_layout_id"] = default_layout_id(clean_id)
		result["footprint_mode"] = str(link.get("footprint_mode", "inherit"))
		return result
	return fallback


static func default_layout_id(world_room_id: String) -> String:
	var clean_id := _clean_id(world_room_id)
	return "%s_dungeon_01" % clean_id if not clean_id.is_empty() else "dungeon_01"


static func layout_path(layout_id: String) -> String:
	var clean_id := _clean_id(layout_id)
	return LAYOUT_DIR + clean_id + ".json"


static func load_layout(layout_id: String, world_room_id: String) -> Dictionary:
	var clean_layout_id := _clean_id(layout_id)
	var clean_world_id := _clean_id(world_room_id)
	if clean_layout_id.is_empty() or clean_world_id.is_empty():
		return {}
	var path := layout_path(clean_layout_id)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var data := parsed as Dictionary
	if int(data.get("schema_version", 0)) < 1:
		return {}
	if str(data.get("dungeon_layout_id", "")) != clean_layout_id:
		return {}
	if str(data.get("source_world_room_id", "")) != clean_world_id:
		return {}
	if not data.get("assets", null) is Array or not data.get("walls", null) is Array or not data.get("fixtures", null) is Array:
		return {}
	var shape_id := str(data.get("footprint_kind", "single"))
	if not RoomFootprintCatalog.SHAPES.has(shape_id):
		return {}
	if not data.get("footprint", null) is Array:
		return {}
	return data


static func make_payload(layout_id: String, world_room_id: String, state: Dictionary) -> Dictionary:
	var clean_layout_id := _clean_id(layout_id)
	var clean_world_id := _clean_id(world_room_id)
	var shape_id := str(state.get("room_shape", "single"))
	if not RoomFootprintCatalog.SHAPES.has(shape_id):
		shape_id = "single"
	return {
		"schema_version": 1,
		"dungeon_layout_id": clean_layout_id,
		"source_world_room_id": clean_world_id,
		"footprint_mode": "independent",
		"footprint_kind": shape_id,
		"footprint": (RoomFootprintCatalog.SHAPES[shape_id] as Array).duplicate(true),
		"room_rotation_quarters": posmod(int(state.get("room_rotation_quarters", 0)), 4),
		"assets": (state.get("assets", []) as Array).duplicate(true),
		"walls": (state.get("walls", []) as Array).duplicate(true),
		"fixtures": (state.get("fixtures", []) as Array).duplicate(true),
		"saved_at": Time.get_datetime_string_from_system(false, false),
	}


static func manifest_room_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_room_id: Variant in RoomFootprintCatalog.ROOM_CONFIG.keys():
		ids.append(str(raw_room_id))
	ids.sort()
	return ids


static func _manifest() -> Dictionary:
	if not _manifest_cache.is_empty():
		return _manifest_cache
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary:
		_manifest_cache = parsed as Dictionary
	return _manifest_cache


static func _clean_id(raw: String) -> String:
	var result := raw.strip_edges().to_lower()
	result = result.replace("/", "_").replace("\\", "_").replace(" ", "_")
	return result
