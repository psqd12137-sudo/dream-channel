extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://channel_3d.tscn")
	_check(packed != null, "channel_3d.tscn must load")
	if packed == null:
		_finish()
		return

	var game: Node = packed.instantiate()
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	_check(game.phase == "home", "the project must open on the Web-style home screen")
	game.start_new_run(false, 2026081901)

	_check(game is Node3D, "main scene root must be Node3D")
	_check(game.get_node_or_null("WorldLayer/WorldContainer/WorldViewport/WorldRoot/CameraRig/Camera3D") is Camera3D, "scene must contain Camera3D")
	_check(_count_meshes(game.get_node("WorldLayer/WorldContainer/WorldViewport/WorldRoot/HouseRoot")) > 0, "house must be built from MeshInstance3D nodes")
	_check(game.phase == "omen", "pressing start must open the omen choice")
	_check(game.omen_options.size() == 2, "latest EXE flow must offer two omens")
	_check(game.run_progress == 1, "the foyer must count as progress 1/12")

	game.choose_omen(0)
	_check(game.phase == "explore", "choosing an omen must unlock exploration")
	_check(game.active_relics.size() == 1, "the chosen omen must be active")

	var frontiers: Array[Vector2i] = game.room_rules.frontiers()
	_check(not frontiers.is_empty(), "the foyer must expose build frontiers")
	if not frontiers.is_empty():
		var target: Vector2i = frontiers[0]
		game.begin_build(target)
		_check(game.phase == "build", "clicking a frontier must start the build dock")
		_check(game.build_offers.size() == 3, "latest EXE flow must draw three room tickets")
		_check(game.can_place_selected_offer(), "the initially selected offer must have a legal rotation")
		game.place_selected_offer()
		_check(game.room_rules.placed.has(target), "placing a ticket must commit the room")
		var hidden_room: Dictionary = game.room_rules.placed.get(target, {})
		_check(not bool(hidden_room.get("revealed", true)), "a placed room must remain hidden")
		_check(game.run_progress == 1, "placement alone must not advance progress")
		game.enter_room(target)
		var revealed_room: Dictionary = game.room_rules.placed.get(target, {})
		_check(bool(revealed_room.get("revealed", false)), "entering must reveal the room")
		_check(game.phase == "room_ready", "a first visit must wait for room resolution")

	var combat_room: Dictionary = {}
	for room: Dictionary in game.room_catalog:
		if str(room.get("kind", "")) == "combat":
			combat_room = room
			break
	_check(not combat_room.is_empty(), "latest snapshot must contain a combat room")
	if not combat_room.is_empty():
		game.start_combat(combat_room)
		await process_frame
		_check(game.phase == "combat", "combat room resolution must switch to combat")
		_check(game.combat != null, "combat rules must be initialized")
		_check(game.get_node("WorldLayer/WorldContainer/WorldViewport/WorldRoot/BattleRoot").visible, "3D battle board must be visible")
		_check(_count_meshes(game.get_node("WorldLayer/WorldContainer/WorldViewport/WorldRoot/BattleRoot")) > 0, "battle board must contain MeshInstance3D geometry")

	game.queue_free()
	await process_frame
	_finish()


func _count_meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		count += _count_meshes(child)
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_LATEST_3D_SMOKE: PASS omen build hidden reveal combat meshes")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_LATEST_3D_SMOKE: %s" % failure)
		quit(1)
