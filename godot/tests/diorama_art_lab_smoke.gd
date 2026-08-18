extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var lab_scene := load("res://scenes/diorama_art_lab.tscn") as PackedScene
	_check(lab_scene != null, "the isolated diorama art scene must load")
	if lab_scene != null:
		var lab := lab_scene.instantiate() as Node3D
		root.add_child(lab)
		await process_frame
		_check(lab.get_tree().get_nodes_in_group("diorama_option").size() == 3, "the scene must expose current, Kenney and Ruins comparison options")
		_check(lab.get_node_or_null("CurrentBaseline") != null, "comparison A must preserve the current room look")
		_check(lab.get_node_or_null("KenneyMiniDungeon/Gate") != null, "comparison B must use a real Mini Dungeon gate")
		_check(lab.get_node_or_null("QuaterniusRuins/Assets/Arch") != null, "comparison C must use a real Modular Ruins arch")
		_check(lab.get_node_or_null("QuaterniusRuins/RaisedCorner") != null, "the Ruins option must demonstrate asset-backed elevation")
		lab.queue_free()
		await process_frame

	var game := (load("res://channel_3d.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_diorama_art_lab()
	await process_frame
	_check(game.phase == "lab_diorama", "the A/B/C switch must open the isolated diorama lab")
	_check(game.lab_root.get_node_or_null("DioramaArtComparison") != null, "the lab must be instanced without changing existing room roots")
	_check(not game.house_root.visible and not game.battle_root.visible, "the comparison must stay isolated from gameplay layouts")
	game.go_home()
	_check(game.phase == "home", "the comparison lab must return to title cleanly")
	game.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_DIORAMA_ART_LAB: PASS current kenney ruins isolated-entry")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_DIORAMA_ART_LAB: %s" % failure)
		quit(1)
var _smb_tail_padding := """
This padding intentionally neutralizes stale bytes left by a non-truncating SMB
write on the shared workspace. Keep it until the file is rewritten on macOS.
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
"""
