extends RefCounted

## One authoritative, telegraphed programme for the channel host.
## Rules are passed in, rather than retained, to avoid a RefCounted cycle.
var phase_index := 0
var plan: Dictionary = {}
var camera_cells: Array[Vector2i] = []
var cancelled := false
var weakened := false
var break_count := 0
var relief_pending := 0
var last_break_round := -1
var executed_round := -1

func update_phase(r, cleared: int) -> String:
	var s = r.enemy_by_id(r.enemy_order[0])
	if s.hp * 2 <= s.max_hp or cleared >= 2:
		phase_index = maxi(phase_index, 1)
	if s.hp * 4 <= s.max_hp or cleared >= 3:
		phase_index = 2
	return ["开场录制", "节目失控", "最后加播"][phase_index]

func prepare(r) -> void:
	if r.outcome != "":
		return
	var s = r.enemy_by_id(r.enemy_order[0])
	s.revealed = true
	s.player_sees_enemy = true
	s.action_points = 5 if phase_index == 2 else 4
	cancelled = false
	weakened = false
	var kind := "pursuit"
	if r.round_number == 1:
		kind = "opening"
	elif r.round_number % 3 == 0:
		kind = "charge"
	elif phase_index >= 1 and r.round_number % 3 == 1:
		kind = "sweep"
	var path: Array[Vector2i] = []
	var cells: Array[Vector2i] = []
	if kind == "pursuit":
		var full: Array[Vector2i] = r._find_path(s.pos, r.player_pos, {}, false)
		var budget: int = s.action_points
		var origin: Vector2i = s.pos
		for i in range(1, full.size() - 1):
			if budget <= 0:
				break
			path.append(full[i])
			origin = full[i]
			budget -= 1
		if budget >= 2 and r.manhattan(origin, r.player_pos) == 1:
			cells.append(r.player_pos)
	elif kind == "charge":
		var delta: Vector2i = r.player_pos - s.pos
		var dir := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
		for step in range(1, 5):
			var cell: Vector2i = s.pos + dir * step
			if not r.is_walkable(cell):
				break
			path.append(cell)
			cells.append(cell)
	elif kind == "sweep":
		for x in range(r.cols):
			var cell := Vector2i(x, r.player_pos.y)
			if r.is_walkable(cell):
				cells.append(cell)
	plan = {"kind": kind, "path": path, "cells": cells, "budget": s.action_points, "damage": 3 if kind in ["charge", "sweep"] else 2, "round": r.round_number}
	camera_cells.clear()
	# A fixed vertical view strip, occluded by real tactical walls.
	var camera_x: int = posmod(r.round_number * 2, r.cols)
	var source := Vector2i(camera_x, 0)
	for y in range(r.rows):
		var cell := Vector2i(camera_x, y)
		if r.is_walkable(source) and r.is_walkable(cell) and r._has_line_of_sight(source, cell):
			camera_cells.append(cell)
	r.event_log.append("HostTelegraph round=%d kind=%s cells=%s" % [r.round_number, kind, str(cells)])

func on_break(r) -> void:
	break_count += 1
	if last_break_round != r.round_number:
		last_break_round = r.round_number
		relief_pending += 1
	if str(plan.get("kind", "")) in ["charge", "sweep"]:
		cancelled = true
	else:
		weakened = true
	r.event_log.append("HostInterrupted cancel=%s" % str(cancelled))

func preview(r, s) -> Dictionary:
	var result: Dictionary = r._empty_enemy_intent(s.id)
	result.merge({"enemy_revealed": true, "sees_player": true, "type": "attack", "attack_kind": "melee", "label": label(), "intent_value": str(plan.get("damage", 2))}, true)
	if cancelled or plan.get("kind") == "opening":
		result.merge({"type": "wait", "intent_value": "休息"}, true)
		return result
	var path: Array = plan.get("path", []).duplicate()
	var cells: Array = plan.get("cells", []).duplicate()
	if weakened:
		path = path.slice(0, maxi(0, int(plan.get("budget", 4)) - 2))
		if path.size() + 2 > int(plan.get("budget", 4)) - 2:
			cells.clear()
	result["path"] = path
	result["hurt"] = cells
	result["impact_cells"] = cells
	result["threat_cells"] = cells
	result["pending"] = true
	if cells.is_empty():
		result["type"] = "move"
		result["intent_value"] = str(path.size())
	return result

func label() -> String:
	if cancelled:
		return "破韧打断 · 本次行动取消"
	var labels := {"opening": "开场白 · 本轮不攻击", "pursuit": "请站到标记上 · 追击", "charge": "看镜头！· 直线冲撞 3", "sweep": "全体谢幕 · 横排扫场 3"}
	return str(labels.get(str(plan.get("kind", "opening")), "开场白")) + ("（行动力−2）" if weakened else "")

func execute(r, s) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if executed_round == r.round_number:
		return events
	executed_round = r.round_number
	var kind := str(plan.get("kind", "opening"))
	var budget: int = int(plan.get("budget", 4)) - (2 if weakened else 0)
	if not cancelled and kind != "opening":
		for cell: Vector2i in plan.get("path", []):
			if budget <= 0 or cancelled or r.outcome != "":
				break
			if s.status_effects.has("root"):
				break
			if not r.is_walkable(cell) or r.manhattan(s.pos, cell) != 1 or cell == r.player_pos:
				break
			var weakened_before := weakened
			var interrupted: bool = r._move_enemy_to(s, cell, "HostMove", events)
			budget -= 1
			budget -= int(r.traps.get(s.pos, {}).get("slow", 0))
			if weakened and not weakened_before:
				budget -= 2
			if interrupted or s.blind_turns > 0:
				break
		if not cancelled and s.alive() and r.outcome == "" and r.player_pos in plan.get("cells", []):
			var can_hit: bool = kind == "sweep" or (kind == "charge" and r.manhattan(s.pos, r.player_pos) <= 1) or (kind == "pursuit" and budget >= 2 and r.manhattan(s.pos, r.player_pos) == 1)
			if can_hit and s.blind_turns <= 0:
				var hit: Dictionary = r._apply_player_hit(s, "melee", int(plan.get("damage", 2)))
				hit.merge({"kind": "attack", "actor_id": s.id, "target": r.player_pos, "attack_kind": "melee", "label": label()}, true)
				events.append(hit)
	if events.is_empty():
		events.append({"kind": "wait", "actor_id": s.id, "label": "招式落空 / 录制空档" if not cancelled else "破韧 · 招式取消"})
	if s.broken:
		s.toughness = s.max_toughness
		s.broken = false
	return events
