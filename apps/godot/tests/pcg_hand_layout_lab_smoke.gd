extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/pcg_hand_layout_lab.tscn") as PackedScene
	_check(packed != null, "the authored PCG layout scene must load")
	if packed == null:
		_finish()
		return
	var composer := packed.instantiate() as Node3D
	root.add_child(composer)
	await process_frame
	_check(composer.authored_layout_is_valid(), "the starter authored layout must be connected and overlap-free")
	_check(composer.rooms.size() == 7 and composer.occupancy.size() == 19, "the starter scene must simulate seven mixed 1/3/5 rooms occupying nineteen cells")
	_check(composer.connection_edges.size() == 6 and composer.doorway_count == 6, "each room after the first must receive one explicit cross-room doorway")
	_check(composer.room_visual_roots.size() == 7, "each authored multi-cell room must remain one visual and animation root")
	_check(composer.stair_count > 0, "the elevated authored room must receive a stair at its doorway")
	var first_room: Dictionary = composer.rooms[0]
	var second_room: Dictionary = composer.rooms[1]
	_check(int(first_room.get("size", 0)) == 1 and int(second_room.get("size", 0)) == 5, "the authored sample must explicitly begin with one-cell to five-cell placement")
	var last_piece := composer.get_node("Layout/R06_Quiet_1") as Node3D
	last_piece.position = Vector3.ZERO
	composer.regenerate(composer.generation_seed)
	_check(not composer.authored_layout_is_valid() and not composer.layout_errors.is_empty(), "overlapping a hand-placed room must produce a visible validation error")
	composer.queue_free()
	await process_frame

	var game := (load("res://channel_3d.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_pcg_hand_layout_lab()
	await process_frame
	_check(game.phase == "lab_hand_diorama", "the main game must expose the authored layout through an isolated runtime entry")
	_check(game.lab_root.get_node_or_null("PcgHandLayout") != null, "the authored layout entry must not replace the formal house root")
	game.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_PCG_HAND_LAYOUT: PASS authored 1-3-5 snap validation stitching runtime-entry")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_PCG_HAND_LAYOUT: %s" % failure)
		quit(1)
