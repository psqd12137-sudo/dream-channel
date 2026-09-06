extends "res://scripts/channel_host_fight.gd"

## Same telegraph contract as the host, but paths/areas use physical overworld cells.
func prepare(r, preserve_control_state: bool = false) -> void:
	if r.outcome != "":
		return
	var s = r.enemy_by_id(r.enemy_order[0])
	var saved_cancelled := cancelled
	var saved_weakened := weakened
	cancelled = false
	weakened = false
	s.revealed = true
	# A normal Boss turn must be able to close distance and still threaten the
	# player. Four AP supports up to two pursuit steps plus a two-AP attack.
	s.action_points = 4
	var kind := "pursuit"
	if r.round_number == 1:
		kind = "opening"
	elif r.round_number % 3 == 0:
		kind = "charge"
	elif phase_index >= 1 and r.round_number % 3 == 1:
		kind = "sweep"
	var target: Vector2i = r.player_pos
	if r.has_decoy():
		target = r.decoy_pos
	if target == s.pos or not r.graph.has(target):
		var keys: Array = r.graph.keys()
		target = keys[posmod(r.round_number, keys.size())]
	var path: Array[Vector2i] = []
	var cells: Array[Vector2i] = []
	var full: Array[Vector2i] = r._find_path(s.pos, target, {}, false)
	if kind == "pursuit" or kind == "charge":
		var limit: int = 2 if kind == "charge" else s.action_points
		for i in range(1, full.size()):
			if path.size() >= limit:
				break
			if kind == "charge":
				cells.append(full[i])
			if full[i] != target or target != r.player_pos and target != r.decoy_pos:
				path.append(full[i])
		var end: Vector2i = path.back() if not path.is_empty() else s.pos
		if kind == "pursuit" and r.manhattan(end, target) <= 1 and path.size() + 2 <= s.action_points:
			cells.append(target)
	elif kind == "sweep":
		# One room and one connected room; never the whole graph or all four anchors.
		cells.append(target)
		for neighbor: Vector2i in r.graph[target]:
			if neighbor != s.pos:
				cells.append(neighbor)
				break
	plan = {"kind": kind, "path": path, "cells": cells, "budget": s.action_points, "damage": 3 if kind in ["charge", "sweep"] else 2, "round": r.round_number, "decoy": target == r.decoy_pos and r.has_decoy()}
	camera_cells.clear()
	var active: Array = []
	for node: Vector2i in r.anchors:
		if int(r.anchors[node]) > 0:
			active.append(node)
	if not active.is_empty():
		camera_cells.append(active[posmod(r.round_number - 1, active.size())])
	if preserve_control_state:
		cancelled = saved_cancelled
		weakened = saved_weakened

func execute(r, s) -> Array[Dictionary]:
	# A bait that was present at telegraph time remains the announced target.
	var prepared_kind := str(plan.get("kind", "opening"))
	if prepared_kind == "pursuit":
		# Ordinary pursuit is not a locked telegraph. Rebuild it at the start
		# of the enemy phase so movement during the player's turn is respected.
		prepare(r, true)
	if bool(plan.get("decoy", false)) and r.has_decoy() and not cancelled:
		var events: Array[Dictionary] = []
		var budget: int = int(plan.budget) - (2 if weakened else 0)
		for node: Vector2i in plan.path:
			if budget <= 0 or r.outcome != "" or cancelled or s.status_effects.has("root"):
				break
			if node == r.player_pos or node == r.decoy_pos or r.manhattan(s.pos, node) != 1:
				break
			var interrupted: bool = r._move_enemy_to(s, node, "追向纸影", events)
			budget -= 1 + int(r.traps.get(s.pos, {}).get("slow", 0))
			if interrupted:
				break
		if not cancelled and r.outcome == "" and budget >= 2 and r.manhattan(s.pos, r.decoy_pos) <= 1:
			events.append(r._resolve_decoy_attack(s))
		if s.broken:
			s.toughness = s.max_toughness
			s.broken = false
		return events
	return super.execute(r, s)
