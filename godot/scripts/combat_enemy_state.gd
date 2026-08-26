class_name CombatEnemyState
extends RefCounted

# 单个敌人的唯一权威状态（multi-enemy refactor plan 3.1）。
# 阶段 B 仅建立数据容器与工厂；规则层迁移在阶段 C 进行。

const INVALID_CELL := Vector2i(-999, -999)
const CombatStatus = preload("res://scripts/combat_status.gd")

var id := ""
var spawn_order := 0
var pos := Vector2i.ZERO
var max_hp := 6
var hp := 6
var max_toughness := 3
var toughness := 3
var damage := 1
var action_points := 3
var attack_cost := 2
var attack_range := 1
var name := "雪花剪影"
var tier := 1
var archetype := "execute"
var archetype_label := "处决匣"
var archetype_desc := ""
var behavior_role := "auto"
var ai_role := "hunter"
var ai_state := "patrol"
var ai_reason := ""
var tactical_goal := INVALID_CELL
var tactical_reserved_cell := INVALID_CELL
var tactical_plan_round := 0
var traits: Array[String] = []
var trait_labels: Dictionary = {}
var revealed := true
var player_sees_enemy := true
var sees_player := true
var status_effects: Dictionary = {}
var blind_turns: int:
	get:
		var status: Dictionary = status_effects.get("blind", {})
		return int(status.get("duration", status.get("turns", 0)))
	set(value):
		if value <= 0:
			status_effects.erase("blind")
			return
		status_effects["blind"] = CombatStatus.make(
			"blind",
			CombatStatus.CATEGORY_CONTROL,
			"致盲",
			1,
			value,
			CombatStatus.DURATION_TURNS,
			"effect")
var last_seen := INVALID_CELL
var last_seen_age := 0
var patrol_goal := INVALID_CELL
var ambush_active := false
var ambush_idle_turns := 0
var ambush_note := ""
var backstab_reengaging := false
var broken := false
var execute_bonus_pending := false
var crush_bonus_pending := false
var stagger_pending: bool:
	get:
		return status_effects.has("stagger")
	set(value):
		if value:
			status_effects["stagger"] = CombatStatus.make(
				"stagger",
				CombatStatus.CATEGORY_CONTROL,
				"踉跄",
				1,
				1,
				CombatStatus.DURATION_TURNS,
				"toughness")
		else:
			status_effects.erase("stagger")
var just_portaled := false
var beam_pending_cells: Array[Vector2i] = []
var beam_pending_damage := 0


func alive() -> bool:
	return hp > 0


func has_trait(trait_id: String) -> bool:
	return trait_id in traits


func debug_snapshot() -> Dictionary:
	var trait_dump: Array = []
	for trait_id in traits:
		trait_dump.append(trait_id)
	var beam_dump: Array = []
	for cell in beam_pending_cells:
		beam_dump.append(cell)
	return {
		"id": id,
		"spawn_order": spawn_order,
		"pos": pos,
		"hp": hp,
		"max_hp": max_hp,
		"toughness": toughness,
		"max_toughness": max_toughness,
		"damage": damage,
		"action_points": action_points,
		"attack_cost": attack_cost,
		"attack_range": attack_range,
		"name": name,
		"tier": tier,
		"archetype": archetype,
		"archetype_label": archetype_label,
		"archetype_desc": archetype_desc,
		"behavior_role": behavior_role,
		"ai_role": ai_role,
		"ai_state": ai_state,
		"ai_reason": ai_reason,
		"tactical_goal": tactical_goal,
		"tactical_reserved_cell": tactical_reserved_cell,
		"tactical_plan_round": tactical_plan_round,
		"traits": trait_dump,
		"trait_labels": trait_labels.duplicate(true),
		"revealed": revealed,
		"player_sees_enemy": player_sees_enemy,
		"sees_player": sees_player,
		"blind_turns": blind_turns,
		"last_seen": last_seen,
		"last_seen_age": last_seen_age,
		"patrol_goal": patrol_goal,
		"ambush_active": ambush_active,
		"ambush_idle_turns": ambush_idle_turns,
		"ambush_note": ambush_note,
		"backstab_reengaging": backstab_reengaging,
		"status_effects": status_effects.duplicate(true),
		"broken": broken,
		"execute_bonus_pending": execute_bonus_pending,
		"crush_bonus_pending": crush_bonus_pending,
		"stagger_pending": stagger_pending,
		"just_portaled": just_portaled,
		"beam_pending_cells": beam_dump,
		"beam_pending_damage": beam_pending_damage,
		"alive": alive(),
	}
