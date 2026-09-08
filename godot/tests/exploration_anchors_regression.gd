extends SceneTree

const Discoveries = preload("res://scripts/exploration_anchors.gd")
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
	game.run_save_repository = load("res://scripts/run_save_repository.gd").new("user://exploration_anchors_regression.json", game.EXE_SOURCE_ID)
	game.reset_run(1337)
	game.phase = "explore"
	var room: Dictionary = game.room_rules.placed[Vector2i.ZERO].duplicate(true)
	var expected := [0, 1, 1, 2, 2, 2, 3, 3, 4, 4, 4]
	for order in range(1, 12):
		var cell := Vector2i(order, 0)
		var next := room.duplicate(true)
		next.instance_id = "test_%d" % order
		next.origin = [order, 0]
		next.world_cells = [[order, 0]]
		next.open_edges = []
		next.doors = [false, true, false, true]
		next.completed = false
		next.revealed = true
		next.erase("completion_order")
		game.room_rules.placed[cell] = next
		game.current_room_pos = cell
		game._complete_current_room()
		check(Discoveries.cells(game.room_rules).size() == expected[order - 1], "discovery cadence %d" % order)
		game._complete_current_room()
		check(Discoveries.cells(game.room_rules).size() == expected[order - 1], "completion must be idempotent")
	var before := Discoveries.cells(game.room_rules)
	check(game.house_root.get_node("ExplorationAnchors").get_child_count() == 8, "four visible markers and labels")
	game._save_run()
	check(game.continue_saved_run(), "isolated save resumes")
	check(Discoveries.cells(game.room_rules) == before, "anchor coordinates survive JSON save")
	for placed_room: Dictionary in game.room_rules.placed.values():
		placed_room.erase("signal_anchor_cell")
	game._save_run()
	check(game.continue_saved_run(), "legacy exploration save resumes")
	check(Discoveries.cells(game.room_rules) == before, "legacy discovery migration is deterministic")
	if "--capture" in OS.get_cmdline_user_args():
		game.phase = "explore"
		game.house_root.visible = true
		game.world_container.visible = true
		game.build_house_world()
		game._refresh_hud()
		await create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts")
		root.get_texture().get_image().save_png("res://artifacts/exploration_anchors.png")
	# Test the actual finale against the same connected map, with an anchor start.
	game.room_rules.placed[Vector2i.ZERO].open_edges = []
	game.room_rules.placed[Vector2i.ZERO].doors = [false, true, false, false]
	var finale = load("res://scripts/overworld_boss_rules.gd").new()
	finale.initialize(game.room_rules, before[0], {"hp":16}, game.content.cards, game.run_deck, 1337, game.content.run_rules, game.active_relics)
	check(finale.error.is_empty(), "finale initializes: " + finale.error)
	check(finale.anchors.size() == 4, "exactly four finale anchors")
	for cell: Vector2i in before:
		check(finale.anchors.has(cell), "finale retains discovered cell")
	check(finale.enemy_pos not in before, "boss spawn avoids anchors")
	game.run_save_repository.clear()
	game.queue_free()
	await process_frame
	print("EXPLORATION_ANCHORS: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
