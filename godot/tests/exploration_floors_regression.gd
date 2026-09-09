extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var game = load("res://channel_3d.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.run_save_repository = load("res://scripts/run_save_repository.gd").new("user://exploration_floors_test.json", game.EXE_SOURCE_ID)
	game.reset_run(1337)
	game.animation_duration_scale = 0.0
	game.phase = "explore"
	# Simulate completed room content, retaining real placement and exploration.
	for order in range(5):
		game.begin_build(game.room_rules.frontiers()[0])
		game.place_selected_offer()
		await game.enter_room(game.pending_room_pos)
		game._complete_current_room()
		game.phase = "explore"
	var sites: Array[Vector2i] = []
	for cell: Vector2i in game.room_rules.placed:
		if game.room_rules.placed[cell].get("stair_entry_cell", []) == [cell.x, cell.y]:
			sites.append(cell)
	check(sites.size() == 2, "both stair sites discovered")
	for source: Vector2i in sites:
		await game.enter_room(source)
		var action: Dictionary = game.exploration_stair_action()
		check(not action.is_empty(), "stair action available")
		if action.is_empty():
			break
		game.use_exploration_stair()
		check(game.phase == "build" and not game.build_offers.is_empty(), "new floor offers")
		game.cancel_build()
		check(game.room_rules.stair_build.is_empty(), "cancel clears isolated placement allowance")
		game.use_exploration_stair()
		game.place_selected_offer()
		var destination: Vector2i = game.pending_room_pos
		game.use_exploration_stair()
		check(game.current_room_pos == destination, "stair enters new floor")
		check(game.exploration_floor_view() == int(action.floor), "camera follows floor")
		game._complete_current_room()
		game.phase = "explore"
		game.build_house_world()
		check(not game.house_root.get_node("KenneyFormalComposer").visible, "ground hidden upstairs/downstairs")
		var frontier := Vector2i(-999, -999)
		for cell: Vector2i in game.room_rules.frontiers():
			if int(game.room_rules.floor_metadata(cell).get("floor", 0)) == int(action.floor):
				frontier = cell
				break
		game.begin_build(frontier)
		check(not game.build_offers.is_empty(), "can keep building on floor")
		game.place_selected_offer()
		check(int(game.room_rules.placed[game.pending_room_pos].floor) == int(action.floor), "new room inherits floor")
		var saved_position: Vector2i = game.current_room_pos
		check(saved_position == game.pending_room_pos and game.phase == "room_ready", "reachable floor module automatically enters without resolving content")
		game._save_run()
		check(game.continue_saved_run(), "floor save resumes")
		check(game.current_room_pos == saved_position, "arrived position restored")
		game._complete_current_room()
		game.phase = "explore"
		await game.enter_room(destination)
		if "--capture" in OS.get_cmdline_user_args():
			game.reset_house_camera()
			await create_timer(1.5).timeout
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://artifacts")
			root.get_texture().get_image().save_png("res://artifacts/exploration_floor_%d.png" % int(action.floor))
		game.use_exploration_stair()
		check(game.current_room_pos == source, "return stair works after load")
	check(game.room_rules.stair_links.size() == 2, "two persistent connections")
	var finale = load("res://scripts/overworld_boss_rules.gd").new()
	finale.initialize(game.room_rules, game.current_room_pos, {"hp": 16}, game.content.cards, game.run_deck, 1337, game.content.run_rules, game.active_relics)
	check(finale.error.is_empty(), "three-floor finale initializes: " + finale.error)
	check(finale.stair_links.size() == 2, "finale inherits exploration stairs")
	for link: Dictionary in game.room_rules.stair_links:
		var start := Vector2i(int(link.from[0]), int(link.from[1]))
		var end := Vector2i(int(link.to[0]), int(link.to[1]))
		check(not finale._find_path(start, end).is_empty(), "finale can cross each staircase")
	game.run_save_repository.clear()
	game.queue_free()
	await process_frame
	print("EXPLORATION_FLOORS: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
