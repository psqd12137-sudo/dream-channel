extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://channel_3d.tscn")
	var game: Node3D = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_check(game.phase == "home", "project must boot to the home screen")
	_check(not game.world_container.visible, "home must not render the gameplay viewport behind the title")

	game.toggle_home_tests()
	_check(game.home_tests_open, "program test desk must expand")
	game.start_sideview_lab()
	_check(game.phase == "lab_sideview" and game.lab_player != null, "sideview lab must create a controllable player")
	_check(game.lab_collectibles.size() == 3, "sideview lab must contain three pickup goals")
	game.go_home()

	game.start_puzzle_lab()
	_check(game.phase == "lab_puzzle", "puzzle lab must open")
	_check(game.puzzle_board.size() == 9 and game.puzzle_board.has(0), "puzzle must be a valid 3x3 sliding board")
	var board_before: Array[int] = game.puzzle_board.duplicate()
	var empty: int = game.puzzle_board.find(0)
	var neighbor := empty - 1 if empty % 3 > 0 else empty + 1
	game.puzzle_slide(neighbor)
	_check(game.puzzle_board != board_before, "clicking an adjacent puzzle tile must slide it")
	game.go_home()

	game.start_search_lab()
	_check(game.phase == "lab_search", "3D search lab must open")
	_check(game.search_targets.size() == 3, "search lab must place three hidden objects")
	game.go_home()
	_check(game.phase == "home", "every lab must return cleanly to title")

	game.start_combat_lab("hall")
	_check(game.phase == "combat" and game.combat != null, "combat intent lab must open a real battle")
	_check(not str(game.combat.preview_intent().get("detail", "")).is_empty(), "intent lab must always explain the preview")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHANNEL_COMPLETION_LABS: PASS home sideview puzzle search combat-lab")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_COMPLETION_LABS: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
