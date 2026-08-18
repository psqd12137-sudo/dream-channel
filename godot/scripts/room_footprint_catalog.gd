extends RefCounted

const SHAPES := {
	"single": [[0, 0]],
	"line3": [[0, 0], [1, 0], [2, 0]],
	"l3": [[0, 0], [1, 0], [0, 1]],
	"plus5": [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]],
	"t5": [[0, 0], [-1, 0], [1, 0], [0, 1], [0, 2]],
	"p5": [[0, 0], [1, 0], [0, 1], [1, 1], [0, 2]],
	"stair5": [[0, 0], [1, 0], [1, 1], [2, 1], [2, 2]],
	"u5": [[0, 0], [1, 0], [2, 0], [0, 1], [2, 1]],
}

# Geometry and pacing are deliberately separate. A single-cell room may still
# be an empty beat, a recovery beat, or a light skirmish without changing shape.
const ROOM_CONFIG := {
	"foyer": {"shape": "single", "tier": "beat", "pace_role": "empty"},
	"porch": {"shape": "single", "tier": "beat", "pace_role": "empty"},
	"living": {"shape": "single", "tier": "beat", "pace_role": "recovery"},
	"kitchen": {"shape": "single", "tier": "beat", "pace_role": "skirmish"},
	"pantry": {"shape": "single", "tier": "beat", "pace_role": "empty"},
	"yard": {"shape": "single", "tier": "beat", "pace_role": "skirmish"},
	"shed": {"shape": "single", "tier": "beat", "pace_role": "empty"},
	"guest": {"shape": "single", "tier": "beat", "pace_role": "recovery"},
	"greenhouse": {"shape": "single", "tier": "beat", "pace_role": "empty"},
	"bedroom": {"shape": "single", "tier": "beat", "pace_role": "recovery"},
	"nursery": {"shape": "single", "tier": "beat", "pace_role": "skirmish"},
	"darkroom": {"shape": "single", "tier": "beat", "pace_role": "skirmish"},
	"attic": {"shape": "single", "tier": "beat", "pace_role": "skirmish"},
	"ritual": {"shape": "single", "tier": "beat", "pace_role": "recovery"},
	"mudroom": {"shape": "line3", "tier": "minigame", "pace_role": "chase"},
	"west_wing": {"shape": "line3", "tier": "minigame", "pace_role": "chase"},
	"parlor": {"shape": "l3", "tier": "minigame", "pace_role": "puzzle"},
	"gallery": {"shape": "l3", "tier": "minigame", "pace_role": "capture"},
	"loft": {"shape": "line3", "tier": "minigame", "pace_role": "chase"},
	"hall": {"shape": "plus5", "tier": "elite", "pace_role": "elite_combat"},
	"study": {"shape": "t5", "tier": "elite", "pace_role": "elite_combat"},
	"cellar": {"shape": "p5", "tier": "elite", "pace_role": "elite_combat"},
	"boiler": {"shape": "stair5", "tier": "elite", "pace_role": "elite_combat"},
	"altar": {"shape": "u5", "tier": "elite", "pace_role": "elite_combat"},
}


static func apply_to_room(room: Dictionary, room_id: String) -> void:
	var config: Dictionary = ROOM_CONFIG.get(room_id, {"shape": "single", "tier": "beat", "pace_role": "empty"})
	var shape_id := str(config.get("shape", "single"))
	room["footprint_kind"] = shape_id
	room["footprint"] = (SHAPES.get(shape_id, SHAPES["single"]) as Array).duplicate(true)
	room["room_size"] = (room["footprint"] as Array).size()
	room["encounter_tier"] = str(config.get("tier", "beat"))
	room["pace_role"] = str(config.get("pace_role", "empty"))
