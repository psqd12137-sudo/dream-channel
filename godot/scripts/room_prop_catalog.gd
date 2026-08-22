class_name RoomPropCatalog
extends RefCounted

const KAYKIT_ROOT := "res://assets/third_party/kaykit_furniture_bits/gltf/"
const QUATERNIUS_ROOT := "res://assets/quaternius/ultimate_house_interior/"
const LICENSE_PATHS := [
	"res://assets/third_party/kaykit_furniture_bits/LICENSE.txt",
	"res://assets/third_party/kaykit_furniture_bits/SOURCE.md",
	"res://assets/quaternius/ultimate_house_interior/LICENSE.txt",
	"res://assets/quaternius/ultimate_house_interior/SOURCE.md",
]

const SLOT_MAIN := "center_main"
const SLOT_WALL := "wall"
const SLOT_CORNER := "corner"
const SLOT_ACCENT := "accent"

const THEMES := ["living", "bedroom", "kitchen", "study", "greenhouse", "basement"]
const THEME_ANOMALIES := {
	"living": "applause_loop",
	"bedroom": "wrong_dream_eyes",
	"kitchen": "cold_oven_icicles",
	"study": "rewritten_cue_card",
	"greenhouse": "plastic_rain",
	"basement": "backstage_knocking",
}
const FELT_ASSETS := ["kk_couch", "kk_armchair", "kk_oval_rug", "kk_bed_double", "q_bed_single", "kk_pillow"]
const PAINTED_WOOD_ASSETS := ["kk_low_table", "kk_bedside", "kk_kitchen_table", "kk_stool", "kk_bookshelf", "kk_desk", "kk_chair", "kk_greenhouse_table", "kk_basement_cabinet", "kk_basement_table"]
const HANDMADE_FINISH_PALETTES := {
	"felt": [Color("e99eaa"), Color("8eb9b2"), Color("d1b7df")],
	"painted_wood": [Color("e3bd72"), Color("88aebe"), Color("d59482")],
	"clay": [Color("83c2ad"), Color("e0a579"), Color("a9a0ce")],
}
const THEME_COMPOSITIONS := {
	"living": [
		{"id": "conversation", "items": [[SLOT_WALL, "kk_couch"], [SLOT_MAIN, "kk_low_table"], [SLOT_CORNER, "kk_armchair"], [SLOT_CORNER, "kk_standing_lamp"], [SLOT_ACCENT, "kk_pillow"], [SLOT_ACCENT, "kk_books"]]},
		{"id": "fireside", "items": [[SLOT_WALL, "q_fireplace"], [SLOT_CORNER, "kk_armchair"], [SLOT_MAIN, "kk_oval_rug"], [SLOT_WALL, "kk_couch"], [SLOT_CORNER, "kk_standing_lamp"], [SLOT_ACCENT, "kk_books"]]},
	],
	"bedroom": [
		{"id": "double_bed", "items": [[SLOT_WALL, "kk_bed_double"], [SLOT_CORNER, "kk_bedside"], [SLOT_ACCENT, "kk_pillow"], [SLOT_CORNER, "kk_table_lamp"], [SLOT_CORNER, "kk_armchair"], [SLOT_MAIN, "kk_oval_rug"]]},
		{"id": "guest_bed", "items": [[SLOT_WALL, "q_bed_single"], [SLOT_CORNER, "kk_bedside"], [SLOT_CORNER, "kk_standing_lamp"], [SLOT_ACCENT, "kk_books"], [SLOT_CORNER, "kk_armchair"], [SLOT_ACCENT, "kk_pillow"]]},
	],
	"kitchen": [
		{"id": "family_table", "items": [[SLOT_MAIN, "kk_kitchen_table"], [SLOT_WALL, "q_oven"], [SLOT_ACCENT, "kk_stool"], [SLOT_WALL, "q_fridge"], [SLOT_ACCENT, "kk_stool"], [SLOT_CORNER, "kk_chair"]]},
		{"id": "cook_line", "items": [[SLOT_WALL, "q_oven"], [SLOT_WALL, "q_fridge"], [SLOT_MAIN, "kk_kitchen_table"], [SLOT_CORNER, "kk_chair"], [SLOT_ACCENT, "kk_stool"], [SLOT_ACCENT, "kk_stool"]]},
	],
	"study": [
		{"id": "writing", "items": [[SLOT_MAIN, "kk_desk"], [SLOT_ACCENT, "kk_chair"], [SLOT_WALL, "kk_bookshelf"], [SLOT_ACCENT, "kk_books"], [SLOT_CORNER, "kk_table_lamp"], [SLOT_CORNER, "kk_standing_lamp"]]},
		{"id": "library", "items": [[SLOT_WALL, "kk_bookshelf"], [SLOT_MAIN, "kk_desk"], [SLOT_CORNER, "kk_armchair"], [SLOT_ACCENT, "kk_books"], [SLOT_CORNER, "kk_standing_lamp"], [SLOT_ACCENT, "kk_chair"]]},
	],
	"greenhouse": [
		{"id": "potting", "items": [[SLOT_MAIN, "kk_greenhouse_table"], [SLOT_WALL, "kk_cactus_medium"], [SLOT_ACCENT, "kk_cactus_small"], [SLOT_CORNER, "q_houseplant"], [SLOT_ACCENT, "kk_cactus_small"], [SLOT_WALL, "kk_cactus_medium"]]},
		{"id": "indoor_garden", "items": [[SLOT_WALL, "q_houseplant"], [SLOT_MAIN, "kk_greenhouse_table"], [SLOT_CORNER, "kk_cactus_medium"], [SLOT_ACCENT, "kk_cactus_small"], [SLOT_CORNER, "q_houseplant"], [SLOT_ACCENT, "kk_cactus_small"]]},
	],
	"basement": [
		{"id": "workshop", "items": [[SLOT_MAIN, "kk_basement_table"], [SLOT_WALL, "kk_basement_cabinet"], [SLOT_ACCENT, "kk_stool"], [SLOT_CORNER, "kk_standing_lamp"], [SLOT_WALL, "q_fireplace"], [SLOT_ACCENT, "kk_stool"]]},
		{"id": "hearth_storage", "items": [[SLOT_WALL, "q_fireplace"], [SLOT_MAIN, "kk_basement_table"], [SLOT_CORNER, "kk_stool"], [SLOT_WALL, "kk_basement_cabinet"], [SLOT_CORNER, "kk_standing_lamp"], [SLOT_ACCENT, "kk_stool"]]},
	],
}
const INTERACTION_PROFILES := {
	"kk_couch": {"kind": "sit", "pose": "sit", "capacity": 2, "approach": Vector3(0.0, 0.0, 0.30), "anchor": Vector3(0.0, 0.16, 0.0), "spacing": 0.20, "facing_offset": PI},
	"kk_armchair": {"kind": "sit", "pose": "sit", "capacity": 1, "approach": Vector3(0.0, 0.0, 0.27), "anchor": Vector3(0.0, 0.16, 0.0), "spacing": 0.0, "facing_offset": PI},
	"kk_stool": {"kind": "sit", "pose": "sit", "capacity": 1, "approach": Vector3(0.0, 0.0, 0.24), "anchor": Vector3(0.0, 0.15, 0.0), "spacing": 0.0, "facing_offset": PI},
	"kk_chair": {"kind": "sit", "pose": "sit", "capacity": 1, "approach": Vector3(0.0, 0.0, 0.25), "anchor": Vector3(0.0, 0.16, 0.0), "spacing": 0.0, "facing_offset": PI},
	"kk_bed_double": {"kind": "rest", "pose": "rest", "capacity": 2, "approach": Vector3(0.0, 0.0, 0.34), "anchor": Vector3(0.0, 0.13, 0.0), "spacing": 0.18, "facing_offset": PI},
	"q_bed_single": {"kind": "rest", "pose": "rest", "capacity": 1, "approach": Vector3(0.0, 0.0, 0.32), "anchor": Vector3(0.0, 0.13, 0.0), "spacing": 0.0, "facing_offset": PI},
	"kk_desk": {"kind": "work", "pose": "stand", "capacity": 2, "approach": Vector3(0.0, 0.0, 0.34), "anchor": Vector3(0.0, 0.0, 0.34), "spacing": 0.20, "facing_offset": PI},
	"kk_bookshelf": {"kind": "browse", "pose": "stand", "capacity": 2, "approach": Vector3(0.0, 0.0, 0.28), "anchor": Vector3(0.0, 0.0, 0.28), "spacing": 0.18, "facing_offset": PI},
	"kk_kitchen_table": {"kind": "gather", "pose": "stand", "capacity": 2, "approach": Vector3(0.0, 0.0, 0.35), "anchor": Vector3(0.0, 0.0, 0.35), "spacing": 0.22, "facing_offset": PI},
	"kk_low_table": {"kind": "gather", "pose": "stand", "capacity": 2, "approach": Vector3(0.0, 0.0, 0.33), "anchor": Vector3(0.0, 0.0, 0.33), "spacing": 0.20, "facing_offset": PI},
	"kk_greenhouse_table": {"kind": "work", "pose": "stand", "capacity": 1, "approach": Vector3(0.0, 0.0, 0.30), "anchor": Vector3(0.0, 0.0, 0.30), "spacing": 0.0, "facing_offset": PI},
	"kk_basement_table": {"kind": "work", "pose": "stand", "capacity": 1, "approach": Vector3(0.0, 0.0, 0.30), "anchor": Vector3(0.0, 0.0, 0.30), "spacing": 0.0, "facing_offset": PI},
	"q_fireplace": {"kind": "warm", "pose": "stand", "capacity": 2, "approach": Vector3(0.0, 0.0, 0.38), "anchor": Vector3(0.0, 0.0, 0.38), "spacing": 0.20, "facing_offset": PI},
	"q_oven": {"kind": "cook", "pose": "work", "capacity": 1, "approach": Vector3(0.0, 0.0, 0.30), "anchor": Vector3(0.0, 0.0, 0.30), "spacing": 0.0, "facing_offset": PI},
	"kk_cactus_medium": {"kind": "tend", "pose": "work", "capacity": 1, "approach": Vector3(0.0, 0.0, 0.27), "anchor": Vector3(0.0, 0.0, 0.27), "spacing": 0.0, "facing_offset": PI},
	"q_houseplant": {"kind": "tend", "pose": "work", "capacity": 1, "approach": Vector3(0.0, 0.0, 0.27), "anchor": Vector3(0.0, 0.0, 0.27), "spacing": 0.0, "facing_offset": PI},
	# Editor-authored override ids.  Keep these aliases here so saved templates
	# receive the same interaction/animation semantics as generated props.
	"kk_bedside": {"kind": "stand", "pose": "stand", "capacity": 1, "approach": Vector3(0.0, 0.0, 0.28), "anchor": Vector3.ZERO, "spacing": 0.0, "facing_offset": PI},
	"kk_table_medium": {"kind": "gather", "pose": "stand", "capacity": 1, "approach": Vector3(0.0, 0.0, 0.32), "anchor": Vector3(0.0, 0.0, 0.32), "spacing": 0.0, "facing_offset": PI},
	"kk_plant_cactus_med": {"kind": "tend", "pose": "work", "capacity": 1, "approach": Vector3(0.0, 0.0, 0.25), "anchor": Vector3(0.0, 0.0, 0.25), "spacing": 0.0, "facing_offset": PI},
	"kk_lamp_table": {"kind": "stand", "pose": "stand", "capacity": 1, "approach": Vector3(0.0, 0.0, 0.25), "anchor": Vector3.ZERO, "spacing": 0.0, "facing_offset": PI},
}
const THEME_ALIASES := {
	"foyer": "living",
	"porch": "greenhouse",
	"living": "living",
	"parlor": "living",
	"guest": "bedroom",
	"bedroom": "bedroom",
	"nursery": "bedroom",
	"kitchen": "kitchen",
	"pantry": "kitchen",
	"study": "study",
	"gallery": "study",
	"hall": "study",
	"greenhouse": "greenhouse",
	"yard": "greenhouse",
	"shed": "basement",
	"cellar": "basement",
	"boiler": "basement",
	"darkroom": "basement",
	"ritual": "basement",
	"altar": "basement",
	"attic": "study",
	"loft": "bedroom",
	"west_wing": "bedroom",
	"mudroom": "living",
}

# Footprints are visual X/Z diameters in the compositor's 1.55 m cell space.
# Wall-following props are presentation-only and inherit their canonical edge cutaway.
const ENTRIES := [
	{"id": "kk_couch", "path": KAYKIT_ROOT + "couch_pillows.gltf", "themes": ["living"], "slots": [SLOT_WALL], "scale": 0.28, "footprint": Vector2(0.78, 0.34), "weight": 5, "wall_follow": true, "tall": false},
	{"id": "kk_armchair", "path": KAYKIT_ROOT + "armchair_pillows.gltf", "themes": ["living", "bedroom", "study"], "slots": [SLOT_WALL, SLOT_CORNER], "scale": 0.28, "footprint": Vector2(0.44, 0.42), "weight": 4, "wall_follow": true, "tall": false},
	{"id": "kk_low_table", "path": KAYKIT_ROOT + "table_low.gltf", "themes": ["living"], "slots": [SLOT_MAIN], "scale": 0.28, "footprint": Vector2(0.56, 0.46), "weight": 5, "wall_follow": false, "tall": false},
	{"id": "kk_oval_rug", "path": KAYKIT_ROOT + "rug_oval_A.gltf", "themes": ["living", "bedroom"], "slots": [SLOT_MAIN], "scale": 0.28, "footprint": Vector2(0.68, 0.52), "weight": 3, "wall_follow": false, "tall": false, "overlay": true},
	{"id": "kk_bed_double", "path": KAYKIT_ROOT + "bed_double_A.gltf", "themes": ["bedroom"], "slots": [SLOT_WALL], "scale": 0.28, "footprint": Vector2(0.66, 0.82), "weight": 5, "wall_follow": true, "tall": false},
	{"id": "q_bed_single", "path": QUATERNIUS_ROOT + "Bed_Single.fbx", "themes": ["bedroom"], "slots": [SLOT_WALL], "scale": 0.30, "footprint": Vector2(0.48, 0.68), "weight": 2, "wall_follow": true, "tall": false},
	{"id": "kk_bedside", "path": KAYKIT_ROOT + "cabinet_small_decorated.gltf", "themes": ["bedroom", "living"], "slots": [SLOT_CORNER], "scale": 0.28, "footprint": Vector2(0.32, 0.30), "weight": 4, "wall_follow": true, "tall": false},
	{"id": "kk_pillow", "path": KAYKIT_ROOT + "pillow_A.gltf", "themes": ["bedroom", "living"], "slots": [SLOT_ACCENT], "scale": 0.28, "footprint": Vector2(0.22, 0.22), "weight": 3, "wall_follow": false, "tall": false, "overlay": true, "repeatable": true},
	{"id": "q_fridge", "path": QUATERNIUS_ROOT + "Kitchen_Fridge.fbx", "themes": ["kitchen"], "slots": [SLOT_WALL], "scale": 0.27, "footprint": Vector2(0.36, 0.34), "weight": 4, "wall_follow": true, "tall": true},
	{"id": "q_oven", "path": QUATERNIUS_ROOT + "Kitchen_Oven.fbx", "themes": ["kitchen"], "slots": [SLOT_WALL], "scale": 0.27, "footprint": Vector2(0.36, 0.34), "weight": 5, "wall_follow": true, "tall": true},
	{"id": "kk_kitchen_table", "path": KAYKIT_ROOT + "table_medium.gltf", "themes": ["kitchen"], "slots": [SLOT_MAIN], "scale": 0.28, "footprint": Vector2(0.56, 0.56), "weight": 5, "wall_follow": false, "tall": false},
	{"id": "kk_stool", "path": KAYKIT_ROOT + "chair_stool_wood.gltf", "themes": ["kitchen", "basement"], "slots": [SLOT_CORNER, SLOT_ACCENT], "scale": 0.28, "footprint": Vector2(0.30, 0.30), "weight": 4, "wall_follow": false, "tall": false, "repeatable": true},
	{"id": "kk_bookshelf", "path": KAYKIT_ROOT + "shelf_B_large_decorated.gltf", "themes": ["study", "living"], "slots": [SLOT_WALL], "scale": 0.28, "footprint": Vector2(0.62, 0.28), "weight": 5, "wall_follow": true, "tall": true},
	{"id": "kk_desk", "path": KAYKIT_ROOT + "table_medium_long.gltf", "themes": ["study"], "slots": [SLOT_MAIN, SLOT_WALL], "scale": 0.28, "footprint": Vector2(0.68, 0.42), "weight": 5, "wall_follow": false, "tall": false},
	{"id": "kk_chair", "path": KAYKIT_ROOT + "chair_A_wood.gltf", "themes": ["study", "kitchen", "living"], "slots": [SLOT_CORNER, SLOT_ACCENT], "scale": 0.28, "footprint": Vector2(0.32, 0.34), "weight": 5, "wall_follow": false, "tall": false, "repeatable": true},
	{"id": "kk_books", "path": KAYKIT_ROOT + "book_set.gltf", "themes": ["study", "living", "bedroom"], "slots": [SLOT_ACCENT], "scale": 0.28, "footprint": Vector2(0.22, 0.16), "weight": 5, "wall_follow": false, "tall": false, "overlay": true, "repeatable": true},
	{"id": "kk_cactus_medium", "path": KAYKIT_ROOT + "cactus_medium_A.gltf", "themes": ["greenhouse"], "slots": [SLOT_CORNER, SLOT_WALL], "scale": 0.28, "footprint": Vector2(0.30, 0.30), "weight": 5, "wall_follow": true, "tall": true, "repeatable": true},
	{"id": "kk_cactus_small", "path": KAYKIT_ROOT + "cactus_small_B.gltf", "themes": ["greenhouse"], "slots": [SLOT_ACCENT, SLOT_CORNER], "scale": 0.28, "footprint": Vector2(0.22, 0.22), "weight": 5, "wall_follow": false, "tall": false, "repeatable": true},
	{"id": "q_houseplant", "path": QUATERNIUS_ROOT + "Houseplant_3.fbx", "themes": ["greenhouse", "living"], "slots": [SLOT_WALL, SLOT_CORNER], "scale": 0.30, "footprint": Vector2(0.28, 0.28), "weight": 2, "wall_follow": true, "tall": true, "repeatable": true},
	{"id": "kk_greenhouse_table", "path": KAYKIT_ROOT + "table_small.gltf", "themes": ["greenhouse"], "slots": [SLOT_MAIN], "scale": 0.28, "footprint": Vector2(0.42, 0.42), "weight": 3, "wall_follow": false, "tall": false},
	{"id": "q_fireplace", "path": QUATERNIUS_ROOT + "Fireplace.fbx", "themes": ["basement", "living"], "slots": [SLOT_WALL], "scale": 0.30, "footprint": Vector2(0.46, 0.30), "weight": 4, "wall_follow": true, "tall": true},
	{"id": "kk_basement_cabinet", "path": KAYKIT_ROOT + "cabinet_medium_decorated.gltf", "themes": ["basement"], "slots": [SLOT_WALL, SLOT_CORNER], "scale": 0.28, "footprint": Vector2(0.48, 0.30), "weight": 5, "wall_follow": true, "tall": true},
	{"id": "kk_basement_table", "path": KAYKIT_ROOT + "table_small.gltf", "themes": ["basement"], "slots": [SLOT_MAIN], "scale": 0.28, "footprint": Vector2(0.42, 0.42), "weight": 4, "wall_follow": false, "tall": false},
	{"id": "kk_standing_lamp", "path": KAYKIT_ROOT + "lamp_standing.gltf", "themes": ["living", "bedroom", "study", "basement"], "slots": [SLOT_CORNER], "scale": 0.28, "footprint": Vector2(0.28, 0.28), "weight": 3, "wall_follow": true, "tall": true},
	{"id": "kk_table_lamp", "path": KAYKIT_ROOT + "lamp_table.gltf", "themes": ["living", "bedroom", "study"], "slots": [SLOT_ACCENT], "scale": 0.28, "footprint": Vector2(0.20, 0.20), "weight": 3, "wall_follow": false, "tall": false, "overlay": true},
]


static func theme_for_room(room: Dictionary, room_index: int) -> String:
	var room_type := str(room.get("room_type", "")).to_lower()
	if THEME_ALIASES.has(room_type):
		return str(THEME_ALIASES[room_type])
	var room_id := str(room.get("id", "")).to_lower().split("@")[0]
	if THEME_ALIASES.has(room_id):
		return str(THEME_ALIASES[room_id])
	var room_name := str(room.get("name", "")).to_lower()
	for alias: String in THEME_ALIASES.keys():
		if room_name.contains(alias):
			return str(THEME_ALIASES[alias])
	return str(THEMES[posmod(room_index, THEMES.size())])


static func placement_request(room: Dictionary, room_index: int, generation_seed: int) -> Dictionary:
	var size := int(room.get("size", 1))
	var count_range := count_range_for_size(size)
	var layout_seed := _stable_seed(generation_seed, str(room.get("id", "R%02d" % room_index)))
	var count := int(count_range.x) + posmod(layout_seed, int(count_range.y - count_range.x + 1))
	var theme := theme_for_room(room, room_index)
	var compositions: Array = THEME_COMPOSITIONS.get(theme, [])
	var composition: Dictionary = compositions[posmod(layout_seed, compositions.size())] if not compositions.is_empty() else {}
	var items: Array[Dictionary] = []
	for raw_item: Array in composition.get("items", []):
		if items.size() >= count:
			break
		items.append({"slot": str(raw_item[0]), "asset_id": str(raw_item[1])})
	var fallback_slots := [SLOT_MAIN, SLOT_WALL, SLOT_CORNER, SLOT_ACCENT]
	while items.size() < count:
		items.append({"slot": str(fallback_slots[items.size() % fallback_slots.size()]), "asset_id": ""})
	var slots: Array[String] = []
	for item: Dictionary in items:
		slots.append(str(item["slot"]))
	return {
		"theme": theme,
		"composition_id": str(composition.get("id", "fallback")),
		"count": count,
		"slots": slots,
		"items": items,
		"seed": layout_seed,
	}


static func count_range_for_size(size: int) -> Vector2i:
	if size >= 5:
		return Vector2i(6, 8)
	if size >= 3:
		return Vector2i(4, 6)
	return Vector2i(2, 3)


static func entries_for(theme: String, slot: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_entry: Dictionary in ENTRIES:
		if theme in raw_entry.get("themes", []) and slot in raw_entry.get("slots", []):
			result.append(raw_entry)
	return result


static func interaction_profile(asset_id: String) -> Dictionary:
	return (INTERACTION_PROFILES.get(asset_id, {}) as Dictionary).duplicate(true)


static func handmade_finish_for(asset_id: String) -> String:
	if asset_id in FELT_ASSETS:
		return "felt"
	if asset_id in PAINTED_WOOD_ASSETS:
		return "painted_wood"
	return "clay"


static func handmade_tint_for(asset_id: String) -> Color:
	var finish := handmade_finish_for(asset_id)
	var palette: Array = HANDMADE_FINISH_PALETTES.get(finish, [Color.WHITE])
	return palette[posmod(asset_id.hash(), palette.size())]


static func anomaly_for_theme(theme: String) -> String:
	return str(THEME_ANOMALIES.get(theme, ""))


static func asset_paths() -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in ENTRIES:
		var path := str(entry.get("path", ""))
		if not path.is_empty() and not path in result:
			result.append(path)
	return result


static func license_paths() -> Array[String]:
	var result: Array[String] = []
	result.assign(LICENSE_PATHS)
	return result


static func kaykit_distribution_paths() -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(KAYKIT_ROOT)
	if directory == null:
		return result
	for file_name: String in directory.get_files():
		if file_name.get_extension().to_lower() == "gltf":
			result.append(KAYKIT_ROOT + file_name)
	result.sort()
	return result


static func _stable_seed(generation_seed: int, room_id: String) -> int:
	var value := generation_seed ^ 0x45d9f3b
	for byte: int in room_id.to_utf8_buffer():
		value = posmod((value ^ byte) * 16777619, 0x7fffffff)
	return value
