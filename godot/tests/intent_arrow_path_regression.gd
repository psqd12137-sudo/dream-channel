extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node3D = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_combat_lab("hall")
	await process_frame
	await process_frame

	var renderer = game.battle_world_renderer
	renderer._add_battle_intent_path_arrow(
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
		Color("66b66d"),
		"turn-test"
	)
	await process_frame
	var arrow: MeshInstance3D = renderer.battle_intent_line_root.get_node_or_null("EnemyIntentArrow_turn-test")
	_check(arrow != null, "turning intent path must create a single arrow mesh")
	if arrow != null:
		var mesh := arrow.mesh as ImmediateMesh
		var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		_check(vertices.size() % 3 == 0, "intent arrow mesh must contain complete triangles for every route segment")
		var corner: Vector3 = game._battle_world(Vector2i(1, 0))
		var near_corner := false
		for vertex: Vector3 in vertices:
			if Vector2(vertex.x, vertex.z).distance_to(Vector2(corner.x, corner.z)) < 0.10:
				near_corner = true
				break
		_check(near_corner, "intent arrow geometry must pass through the intermediate turning tile")

	var attack_routes: Array = renderer._battle_intent_attack_paths(
		Vector2i(0, 0),
		{
			"path": [Vector2i(0, 1), Vector2i(1, 1)],
			"impact_cells": [Vector2i(2, 1)],
			"range_origin": Vector2i(0, 0),
		}
	)
	_check(attack_routes.size() == 1, "moving attack intent must create one routed attack path")
	if attack_routes.size() == 1:
		_check(
			attack_routes[0] == [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
			"moving attack intent must preserve every movement turn before the impact cell"
		)

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHANNEL_INTENT_ARROW_PATH: PASS turning-path mesh follows intermediate tile")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_INTENT_ARROW_PATH: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
