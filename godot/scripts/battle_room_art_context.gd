class_name BattleRoomArtContext
extends RefCounted

const RoomFootprintCatalog = preload("res://scripts/room_footprint_catalog.gd")
const RoomArtRegistry = preload("res://scripts/room_art_registry.gd")
const RoomPropCatalog = preload("res://scripts/room_prop_catalog.gd")

const EDITOR_CATALOG_PATH := "res://data/editor/asset_catalog.json"
const MODEL_CELL := 1.55
const MAX_CONTEXT_PROPS := 7
const QUATERNIUS_ROOT := "res://assets/quaternius/ultimate_house_interior/"
const KAYKIT_ROOT := "res://assets/third_party/kaykit_furniture_bits/gltf/"
const KAYKIT_DUNGEON_ROOT := "res://assets/third_party/kaykit_dungeon/models/"
const MINI_DUNGEON_ROOT := "res://assets/third_party/kenney_mini_dungeon/models/"
const HIGH_TERRAIN_ASSETS := [
	KAYKIT_DUNGEON_ROOT + "stairs_wood.gltf.glb",
	MINI_DUNGEON_ROOT + "wood-structure.glb",
	MINI_DUNGEON_ROOT + "stairs.glb",
]

const THEME_STYLES := {
	"living": {
		"floor_a": Color("c9b89b"), "floor_b": Color("9db9ad"), "rim": Color("6b5c52"), "blocker": Color("527868"), "accent": Color("eaa36f"), "shell_color": 0,
		"height_assets": {1: [KAYKIT_ROOT + "table_low.gltf", QUATERNIUS_ROOT + "Couch_Medium1.fbx"], 2: HIGH_TERRAIN_ASSETS},
	},
	"bedroom": {
		"floor_a": Color("c5b4ca"), "floor_b": Color("b4c6c7"), "rim": Color("65586e"), "blocker": Color("756283"), "accent": Color("e5a3b7"), "shell_color": 2,
		"height_assets": {1: [KAYKIT_ROOT + "bed_double_A.gltf", QUATERNIUS_ROOT + "Bed_Single.fbx"], 2: HIGH_TERRAIN_ASSETS},
	},
	"kitchen": {
		"floor_a": Color("b9d2ce"), "floor_b": Color("d8c49e"), "rim": Color("536a67"), "blocker": Color("527b76"), "accent": Color("efb14f"), "shell_color": 4,
		"height_assets": {1: [KAYKIT_ROOT + "table_medium.gltf"], 2: HIGH_TERRAIN_ASSETS},
	},
	"study": {
		"floor_a": Color("aebea6"), "floor_b": Color("c7b58f"), "rim": Color("5c6652"), "blocker": Color("617554"), "accent": Color("d8a95d"), "shell_color": 3,
		"height_assets": {1: [KAYKIT_ROOT + "table_medium_long.gltf"], 2: HIGH_TERRAIN_ASSETS},
	},
	"greenhouse": {
		"floor_a": Color("a8c9ac"), "floor_b": Color("c8c88d"), "rim": Color("4f6b56"), "blocker": Color("517a5d"), "accent": Color("e4c55e"), "shell_color": 1,
		"height_assets": {1: [KAYKIT_ROOT + "table_small.gltf"], 2: HIGH_TERRAIN_ASSETS},
	},
	"basement": {
		"floor_a": Color("8e9792"), "floor_b": Color("b19b82"), "rim": Color("4d5552"), "blocker": Color("4e665b"), "accent": Color("d98166"), "shell_color": 5,
		"height_assets": {1: [KAYKIT_ROOT + "table_small.gltf"], 2: HIGH_TERRAIN_ASSETS},
	},
}

static var _catalog_by_id: Dictionary = {}


static func build(room: Dictionary, cols: int, rows: int, battle_cell: float, generation_seed: int) -> Dictionary:
	var room_type := RoomArtRegistry.base_room_id(str(room.get("id", room.get("room_type", "living"))))
	var room_for_theme := room.duplicate(true)
	room_for_theme["room_type"] = room_type
	var footprint := _room_footprint(room_for_theme, room_type)
	var theme := RoomPropCatalog.theme_for_room(room_for_theme, 0)
	var style := (THEME_STYLES.get(theme, THEME_STYLES["living"]) as Dictionary).duplicate(true)
	var override := RoomArtRegistry.load_override(room_type)
	var props: Array[Dictionary] = []
	var source := "unpacking_seed"
	var composition_id := ""
	if not override.is_empty():
		props = _props_from_override(override)
		source = "override"
	else:
		var request := RoomPropCatalog.unpacking_template_request(room_for_theme, 0, generation_seed)
		props = _props_from_request(request)
		composition_id = str(request.get("composition_id", "fallback"))
	var wall_kinds: Array[String] = []
	for raw_wall: Variant in override.get("walls", []):
		var kind := str((raw_wall as Dictionary).get("kind", (raw_wall as Dictionary).get("wall_kind", "cb_wall")))
		if not kind.is_empty() and kind not in wall_kinds:
			wall_kinds.append(kind)
	return {
		"room_type": room_type,
		"theme": theme,
		"footprint_kind": str(footprint.get("kind", "single")),
		"footprint": (footprint.get("cells", [[0, 0]]) as Array).duplicate(true),
		"source": source,
		"composition_id": composition_id,
		"props": props,
		"wall_kinds": wall_kinds,
		"floor_a": style.get("floor_a", Color("c9b89b")),
		"floor_b": style.get("floor_b", Color("9db9ad")),
		"rim": style.get("rim", Color("6b5c52")),
		"blocker": style.get("blocker", Color("527868")),
		"accent": style.get("accent", Color("eaa36f")),
		"shell_color": int(style.get("shell_color", 0)),
		"height_assets": (style.get("height_assets", {}) as Dictionary).duplicate(true),
	}


static func _props_from_override(override: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var shape_id := str(override.get("room_shape", "single"))
	var bounds := _shape_bounds(shape_id)
	for raw_asset: Variant in override.get("assets", []):
		if result.size() >= MAX_CONTEXT_PROPS:
			break
		var asset := raw_asset as Dictionary
		var source_position := _array_vec3(asset.get("position", []))
		# Stacked detail props belong to the close-up room template. The battle
		# perimeter keeps their supporting furniture but avoids floating lamps.
		if source_position.y > 0.08:
			continue
		var asset_id := str(asset.get("id", asset.get("asset_id", "")))
		var entry := _asset_entry(asset_id)
		if entry.is_empty():
			continue
		var normalized := _normalized_room_position(source_position, bounds)
		result.append(_prop_record(asset_id, entry, normalized, float(asset.get("yaw", 0.0))))
	return result


static func _props_from_request(request: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var theme := str(request.get("theme", "living"))
	var seed := int(request.get("seed", 1))
	var index := 0
	for raw_item: Variant in request.get("items", []):
		if result.size() >= MAX_CONTEXT_PROPS:
			break
		var item := raw_item as Dictionary
		var slot := str(item.get("slot", RoomPropCatalog.SLOT_ACCENT))
		var preferred_id := str(item.get("asset_id", ""))
		var entries := RoomPropCatalog.entries_for(theme, slot)
		var entry: Dictionary = {}
		if not preferred_id.is_empty():
			entry = _asset_entry(preferred_id)
		if entry.is_empty() and not entries.is_empty():
			entry = entries[posmod(seed + index * 17, entries.size())]
		if entry.is_empty() or bool(entry.get("overlay", false)):
			index += 1
			continue
		var asset_id := str(entry.get("id", preferred_id))
		var normalized := _seed_normalized_position(index)
		result.append(_prop_record(asset_id, entry, normalized, float(posmod(seed + index, 4)) * PI * 0.5))
		index += 1
	return result


static func _prop_record(asset_id: String, entry: Dictionary, normalized: Vector2, yaw: float) -> Dictionary:
	return {
		"asset_id": asset_id,
		"path": str(entry.get("path", "")),
		"tall": bool(entry.get("tall", false)),
		"height_class": RoomPropCatalog.battle_height_class(asset_id),
		"battle_blocker": RoomPropCatalog.is_battle_blocker(asset_id),
		"finish": RoomPropCatalog.handmade_finish_for(asset_id),
		"normalized": [normalized.x, normalized.y],
		"yaw": yaw,
	}


static func _room_footprint(room: Dictionary, room_type: String) -> Dictionary:
	var config: Dictionary = RoomFootprintCatalog.ROOM_CONFIG.get(room_type, {})
	var kind := str(room.get("footprint_kind", config.get("shape", "single")))
	var cells: Array = room.get("footprint", [])
	if cells.is_empty():
		cells = (RoomFootprintCatalog.SHAPES.get(kind, RoomFootprintCatalog.SHAPES["single"]) as Array).duplicate(true)
	var serialized: Array = []
	for raw_cell: Variant in cells:
		if raw_cell is Vector2i:
			serialized.append([raw_cell.x, raw_cell.y])
		elif raw_cell is Array and (raw_cell as Array).size() >= 2:
			serialized.append([int(raw_cell[0]), int(raw_cell[1])])
	if serialized.is_empty():
		serialized.append([0, 0])
	return {"kind": kind, "cells": serialized}


static func _seed_normalized_position(index: int) -> Vector2:
	var pattern := [
		Vector2(0.16, 0.05), Vector2(0.50, 0.05), Vector2(0.84, 0.05),
		Vector2(0.95, 0.32), Vector2(0.95, 0.72), Vector2(0.72, 0.95),
		Vector2(0.28, 0.95), Vector2(0.05, 0.68), Vector2(0.05, 0.30),
	]
	return pattern[posmod(index, pattern.size())]


static func _shape_bounds(shape_id: String) -> Rect2:
	var raw_cells: Array = RoomFootprintCatalog.SHAPES.get(shape_id, RoomFootprintCatalog.SHAPES["single"])
	var min_cell := Vector2(INF, INF)
	var max_cell := Vector2(-INF, -INF)
	for raw_cell: Variant in raw_cells:
		var cell := Vector2(float((raw_cell as Array)[0]), float((raw_cell as Array)[1]))
		min_cell = min_cell.min(cell)
		max_cell = max_cell.max(cell)
	return Rect2(min_cell * MODEL_CELL, (max_cell - min_cell + Vector2.ONE) * MODEL_CELL)


static func _normalized_room_position(position: Vector3, bounds: Rect2) -> Vector2:
	return Vector2(
		clampf((position.x - bounds.position.x) / maxf(bounds.size.x, 0.001), 0.0, 1.0),
		clampf((position.z - bounds.position.y) / maxf(bounds.size.y, 0.001), 0.0, 1.0)
	)


static func _asset_entry(asset_id: String) -> Dictionary:
	_ensure_catalog()
	if _catalog_by_id.has(asset_id):
		return (_catalog_by_id[asset_id] as Dictionary).duplicate(true)
	for raw_entry: Dictionary in RoomPropCatalog.ENTRIES:
		if str(raw_entry.get("id", "")) == asset_id:
			return raw_entry.duplicate(true)
	return {}


static func _ensure_catalog() -> void:
	if not _catalog_by_id.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EDITOR_CATALOG_PATH))
	if not parsed is Dictionary:
		return
	for raw_entry: Variant in (parsed as Dictionary).get("assets", []):
		var entry := raw_entry as Dictionary
		_catalog_by_id[str(entry.get("id", ""))] = entry.duplicate(true)


static func _array_vec3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO
