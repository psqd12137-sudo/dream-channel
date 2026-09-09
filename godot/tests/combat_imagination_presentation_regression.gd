extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://channel_3d.tscn") as PackedScene
	_check(packed != null, "channel_3d.tscn must load")
	if packed == null:
		_finish()
		return
	var game := packed.instantiate() as Node3D
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_combat_lab("hall")
	await process_frame
	await process_frame
	var camera := game.camera as Camera3D
	var logical_before := _combat_snapshot(game.combat)
	_check(game.battle_imagination_mode == "imagination", "combat lab must start in imagination mode")
	_check(game.battle_imagination_profile.get("visual_scale", 0.0) > 0.0, "combat lab must expose an imagination profile")
	_check(game.battle_presentation_root != null, "combat lab must expose a presentation root")
	game.set_battle_imagination_mode("baseline")
	game.set_battle_imagination_mode("imagination")
	_check(_combat_snapshot(game.combat) == logical_before, "visual A/B switching must preserve combat state")
	var cell := Vector2i(2, 1)
	var projected := camera.unproject_position(game.battle_visual_world(cell))
	_check(game.battle_cell_from_viewport(projected) == cell, "scaled presentation must preserve battle picking")
	game.queue_free()
	await process_frame
	_finish()


func _combat_snapshot(combat: RefCounted) -> Dictionary:
	var enemies: Array[Dictionary] = []
	var footprint = combat.get("footprint")
	if footprint == null:
		footprint = []
	for enemy_id in combat.enemy_order:
		var enemy = combat.enemy_by_id(enemy_id)
		enemies.append({"id": str(enemy_id), "pos": enemy.pos, "alive": enemy.alive(), "revealed": enemy.revealed})
	return {
		"player_pos": combat.player_pos,
		"enemy_order": combat.enemy_order.duplicate(),
		"enemies": enemies,
		"energy": combat.energy,
		"walls": combat.walls.duplicate(true),
		"footprint": footprint.duplicate(true),
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("COMBAT_IMAGINATION_PRESENTATION: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("COMBAT_IMAGINATION_PRESENTATION: %s" % failure)
		quit(1)
