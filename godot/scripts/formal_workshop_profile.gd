extends RefCounted

## Presentation contract for the first physical toy workshop demo.
## This resource describes visual continuity only; combat and room rules stay
## owned by the normal game systems.
class_name FormalWorkshopProfile

const DEMO_ROOM_ID := "reference_workshop_demo"

static func for_room(room_id: String) -> Dictionary:
	if room_id != DEMO_ROOM_ID:
		return {"error": "unknown_formal_workshop_room", "room_id": room_id}
	return {
		"room_id": DEMO_ROOM_ID,
		"workshop_scene": "reference_workshop",
		"room_presentation": {
			"center_base": "ToyWorkbench",
			"center_base_size": [8.0, 0.48, 8.0],
			"main_furniture_outline": "center_room_and_wall_modules",
			"cutting_mat": "CuttingMat",
			"cutting_mat_size": [8.8, 0.06, 8.6],
			"peripheral_parts": ["BookStack", "TapeRoll", "PartsTray", "LooseMetal"],
			"background": ["WorkshopBack", "WorkshopWindow", "ShelfLeft", "ShelfRight", "WallClock", "DeskLamp"],
			"outline_survives_projection": true
		},
		"material_families": ["plastic", "painted_wood", "felt", "metal", "paper", "ceramic", "glass", "clay"],
		"camera": {
			"framing": "orthographic_isometric",
			"center_room_priority": true,
			"orbit_reveals_one_near_wall": true,
			"dof_default": "off_or_weak"
		},
		"lighting": {
			"back_environment": "charcoal_wall_blue_window_shelves_clock",
			"key": "warm_desk_pool",
			"fill": "cool_window_fill",
			"low_contrast_surface_detail": true
		},
		"assembly": {
			"controller": "toy_room_assembly",
			"base_lands_before_walls": true,
			"late_part_allowed": true,
			"character_enters_after_snap": true,
			"visual_only": true
		},
		"logic_guards": {
			"decor_group": "workshop_decor",
			"decor_excluded_from_room_prop": true,
			"room_id_reused_by_tv_preview": true,
			"isolated_preview_save": true,
			"preserve_room_logic_grid": true,
			"preserve_character_occupancy": true
		}
	}
