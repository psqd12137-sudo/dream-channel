class_name BattleImaginationProfile
extends RefCounted

const VISUAL_SCALE_MIN := 0.90
const VISUAL_SCALE_MAX := 1.20
const VISUAL_PADDING_CELLS_MIN := 0.0
const VISUAL_PADDING_CELLS_MAX := 0.5
const PROP_SCALE_MIN := 1.00
const PROP_SCALE_MAX := 1.35


static func for_room(room_type: String, _theme: String, props: Array) -> Dictionary:
	var visual_scale := 1.00
	var material_family := "cardboard"
	match room_type:
		"living":
			visual_scale = 1.00
			material_family = "painted_wood"
		"bedroom":
			visual_scale = 1.08
			material_family = "felt"
		"kitchen":
			visual_scale = 0.96
			material_family = "plastic"
	var hero_prop_id := _first_valid_prop_id(props)
	return {
		"visual_scale": clampf(visual_scale, VISUAL_SCALE_MIN, VISUAL_SCALE_MAX),
		"visual_padding_cells": clampf(0.45, VISUAL_PADDING_CELLS_MIN, VISUAL_PADDING_CELLS_MAX),
		"prop_scale": clampf(1.12, PROP_SCALE_MIN, PROP_SCALE_MAX),
		"hero_prop_id": hero_prop_id,
		"material_family": material_family,
		"camera_pitch_offset": clampf(-0.08, -0.35, 0.35),
		"camera_distance_ratio": clampf(1.04, 0.80, 1.25),
		"camera_fit_margin": clampf(1.08, 0.85, 1.25),
		"dof_focus_width": clampf(2.4, 0.5, 5.0),
		"dof_blur_strength": clampf(0.28, 0.0, 1.0),
		"entry_stagger": clampf(0.08, 0.0, 1.0),
		"idle_motion_strength": clampf(0.16, 0.0, 1.0),
		"action_motion_strength": clampf(0.48, 0.0, 1.5),
	}


static func _first_valid_prop_id(props: Array) -> String:
	for raw_prop: Variant in props:
		if not raw_prop is Dictionary:
			continue
		var prop := raw_prop as Dictionary
		var asset_id := str(prop.get("asset_id", ""))
		if not asset_id.is_empty() and not str(prop.get("path", "")).is_empty():
			return asset_id
	return ""
