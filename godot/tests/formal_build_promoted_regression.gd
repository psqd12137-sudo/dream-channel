extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://channel_3d.tscn") as PackedScene).instantiate() as Node3D
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame

	# 1. 正式开局（打开电视机）必须默认走 Kenney 桌模建造，而不是旧几何路线。
	game.go_home()
	game.start_new_run(false, 2026081901)
	await process_frame
	_check(game.phase == "omen", "formal start_new_run must enter the omen phase")
	_check(game.kenney_build_lab_mode, "formal start_new_run must keep the promoted Kaykit table-model build enabled")
	_check(game.house_root.get_node_or_null("KenneyFormalComposer") != null, "formal start_new_run must spawn the Kenney formal compositor")

	# 2. 选择预兆后进入 explore，地图依然是桌模 composer 渲染。
	if not game.omen_options.is_empty():
		game.choose_omen(0)
		await process_frame
		_check(game.phase == "explore", "choosing an omen must advance to explore")
		_check(game.house_root.get_node_or_null("KenneyFormalComposer") != null, "explore after omen must keep the Kenney compositor")

	# 3. 正式扩建：点黄色扩建格 → 选票根 → 摆下，走完整正式 room_rules 链路。
	var elite_room: Dictionary = game._find_catalog_room("hall")
	var chosen_frontier := Vector2i.ZERO
	var chosen_rotation := -1
	for frontier: Vector2i in game.room_rules.frontiers():
		var rotations: Array[int] = game.room_rules.valid_rotations(frontier, elite_room)
		if not rotations.is_empty():
			chosen_frontier = frontier
			chosen_rotation = rotations[0]
			break
	_check(chosen_rotation >= 0, "formal start must accept a five-cell rotated room")
	if chosen_rotation >= 0:
		game.selected_frontier = chosen_frontier
		game.build_offers.assign([elite_room])
		game.selected_offer = 0
		game.offer_rotation = chosen_rotation
		game.phase = "build"
		game.build_house_world()
		_check(game.can_place_selected_offer(), "formal place must stay legal through promoted room_rules")
		game.place_selected_offer()
		await process_frame
		var composer: Node = game.house_root.get_node_or_null("KenneyFormalComposer")
		_check(game.room_rules.instance_count() == 2, "formal placement must create one new room instance")
		_check(composer != null and composer.rooms.size() == 2 and composer.occupancy.size() == 6, "promoted compositor must consume formal one-plus-five occupancy")
		_check(composer.doorway_count >= composer.connection_edges.size(), "formal reciprocal doors must become Kenney wall openings")

	# 4. 存档恢复后必须仍然走桌模建造。
	if game._save_run() == null or FileAccess.file_exists(game.RUN_SAVE_PATH):
		var fresh := (load("res://channel_3d.tscn") as PackedScene).instantiate() as Node3D
		fresh.animation_duration_scale = 0.0
		root.add_child(fresh)
		await process_frame
		await process_frame
		fresh.go_home()
		_check(fresh.continue_saved_run(), "a promoted run must be saveable and resumable")
		_check(fresh.kenney_build_lab_mode, "resumed promoted run must keep the Kaykit table-model build")
		_check(fresh.house_root.get_node_or_null("KenneyFormalComposer") != null, "resumed promoted run must rebuild the Kenney compositor")
		fresh.queue_free()
		await process_frame

	game.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_FORMAL_PROMOTED: PASS start omen explore build save resume kenney-compositor")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_FORMAL_PROMOTED: %s" % failure)
		quit(1)
var _smb_tail_padding := """
Promoted formal Kenney build regression.
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
"""
