extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://channel_3d.tscn") as PackedScene
	_check(packed != null, "channel scene must load")
	if packed == null:
		_finish()
		return
	var game := packed.instantiate() as Node3D
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	var room: Dictionary = _find_room(game.room_catalog, "living")
	room = room.duplicate(true)
	room["arena"] = {
		"cols": 6,
		"rows": 3,
		"player": [0, 1],
		"enemy": [5, 0],
		"walls": ["2, 0"],
		"heights": {"5,0": 1},
		"spawnNote": "多敌人场景验收"
	}
	room["enemies"] = [
		{"id": "alpha", "name": "阿尔法", "spawn": [5, 0], "hp": 6, "archetype": "execute"},
		{"id": "bravo", "name": "布拉沃", "spawn": [4, 1], "hp": 5, "archetype": "patrol"},
		{"id": "charlie", "name": "查理", "spawn": [5, 2], "hp": 4, "archetype": "ambush"},
		{"id": "delta", "name": "德尔塔", "spawn": [3, 0], "hp": 7, "archetype": "execute"}
	]
	game.start_combat(room)
	await process_frame
	var combat = game.combat
	_check(game.phase == "combat", "multi-enemy room must enter combat")
	_check(combat.enemy_order == ["alpha", "bravo", "charlie", "delta"], "enemy order must preserve authored order")
	_check(combat.enemies.size() == 4, "combat must retain all four enemy states")
	_check(game.enemy_nodes.size() == 4, "scene must create one node per enemy")
	for enemy_id in combat.enemy_order:
		var node: Node3D = game._enemy_node_for_id(enemy_id)
		_check(node != null, "enemy node must resolve by id: %s" % enemy_id)
		_check(node.get_node_or_null("Presenter") != null, "enemy presenter must exist: %s" % enemy_id)
	_check(game.battle_actor_root.get_node_or_null("Enemy") != null, "first enemy keeps legacy node name")
	_check(game.battle_actor_root.get_node_or_null("Enemy_bravo") != null, "additional enemy uses stable id node name")
	var midpoint: Vector3 = game._battle_follow_target_position()
	var expected := Vector3.ZERO
	var points := 1
	for enemy_id in combat.enemy_order:
		expected += game._battle_pawn_world(combat.enemy_by_id(enemy_id).pos, false, enemy_id)
		points += 1
	expected += game._battle_pawn_world(combat.player_pos, true)
	expected /= float(points)
	_check(midpoint.distance_to(expected) < 0.01, "battle camera follow must include every living enemy")
	game._play_enemy_state("charlie", "hurt", "受击")
	var charlie_presenter = game._enemy_node_for_id("charlie").get_node_or_null("Presenter")
	_check(charlie_presenter.current_state == "hurt", "targeted enemy animation must stay on its own node")
	var hud: Control = game.get_node("HUD/HUDRoot")
	_check(hud.has_method("_draw_enemy_roster"), "HUD must expose multi-enemy roster drawing")
	game.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _find_room(rooms: Array[Dictionary], room_id: String) -> Dictionary:
	for room: Dictionary in rooms:
		if str(room.get("id", "")) == room_id:
			return room
	return {}


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_MULTI_ENEMY_PRESENTATION: PASS nodes camera targeting animation hud")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_MULTI_ENEMY_PRESENTATION: %s" % failure)
		quit(1)
