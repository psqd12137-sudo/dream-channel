extends SceneTree

const Layouts = preload("res://scripts/dungeon_layout_catalog.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _run() -> void:
	var game = load("res://channel_3d.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.animation_duration_scale = 0.0
	game.run_save_repository = load("res://scripts/run_save_repository.gd").new("user://complete_run_audit.json", game.EXE_SOURCE_ID)
	game.start_new_run(false, 1337)
	game.choose_omen(0)
	var living: Dictionary
	for room in game.room_catalog:
		if room.id == "living":
			living = room
	check(living.name == "客厅" and living.room_size == 1, "客厅 must remain living/single")
	game.start_combat(living)
	var energy: int = game.combat.base_energy
	game.phase = "explore"
	game._start_quiet_reward()
	game.choose_reward(2)
	game.start_combat(living)
	check(game.combat.base_energy == energy + 1, "speed growth must increase next battle AP")
	game.phase = "explore"
	for i in range(7):
		game.rng.randi()
	var checkpoint = game.rng.state
	game._start_card_reward("combat")
	var expected = game.reward_options.duplicate(true)
	game.rng.state = checkpoint
	game.reward_options.clear()
	game.phase = "explore"
	game._save_run()
	game.go_home()
	check(game.continue_saved_run(), "continue must succeed")
	game._start_card_reward("combat")
	check(game.reward_options == expected, "continue must preserve subsequent reward choices")
	game.skip_reward()

	var editor = load("res://scenes/asset_editor_3d.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	for size in [1, 3, 5]:
		editor._on_room_size_selected(editor.room_size.get_item_index(size))
		for i in editor.formal_room.item_count:
			var id = editor.formal_room.get_item_metadata(i)
			check(int(Layouts.link_for(id).default_footprint_size) == size, "room dropdown must be filtered")
	editor._load_formal_room_layout("parlor", false)
	check(editor.selected_room_size == 3, "会客室 remains three cells")
	editor._set_edit_layer("dungeon", false)
	check(editor.edit_layer_id == "world", "event-only room must skip dungeon")
	editor._load_formal_room_layout("living", false)
	editor._set_edit_layer("dungeon", false)
	var test_id := "__complete_run_runtime_test__"
	var path := Layouts.layout_path(test_id)
	if not FileAccess.file_exists(path):
		var world_before := FileAccess.get_file_as_string("res://data/editor/overrides/living.json")
		var data: Dictionary = JSON.parse_string(editor._export_dungeon_layout(test_id))
		var old_manifest := Layouts._manifest_cache.duplicate(true)
		Layouts._manifest_cache = {"links": [{"world_room_id": "living", "dungeon_layout_id": test_id, "has_dungeon": true}]}
		game.start_combat(living)
		check(game.battle_room_context.source == "dungeon_layout", "formal battle must load exported dungeon")
		var authored = game.battle_board_root.get_node_or_null("AuthoredDungeonLayout")
		check(authored != null, "formal battle must render authored spatial nodes")
		if authored != null:
			check(authored.get_child_count() == data.assets.size() + data.walls.size() + data.fixtures.size(), "all exported objects must be rendered")
		check(FileAccess.get_file_as_string("res://data/editor/overrides/living.json") == world_before, "dungeon must not overwrite world layout")
		Layouts._manifest_cache = old_manifest
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	else:
		check(false, "reserved test fixture already exists; not overwritten")
	editor.queue_free()
	await process_frame

	# Exercise the formal progression; combat results are simulated, not a balance test.
	game.start_new_run(false, 1337)
	game.choose_omen(0)
	var completed := 0
	while game.phase == "explore" and completed < 16:
		var placed := false
		var target := Vector2i.ZERO
		for frontier in game.room_rules.frontiers():
			game.begin_build(frontier)
			if game.can_place_selected_offer():
				target = frontier
				game.place_selected_offer()
				placed = true
				break
			game.cancel_build()
		if not placed:
			check(false, "no buildable frontier before finale")
			break
		check(not game.room_rules.placed[target].revealed, "placed room must be unknown")
		check(not str(game.room_rules.placed[target].name) in game.status_message, "placement must not leak room name")
		var path_to_room := route(game, game.current_room_pos, target)
		check(not path_to_room.is_empty(), "new room must be reachable through actual doors")
		for step in path_to_room:
			game.enter_room(step)
		check(game.current_room_pos == target, "movement must reach new room")
		game.resolve_current_room()
		if game.phase == "combat":
			game.combat.outcome = "victory"
			game.return_from_combat()
		elif not game.event_context.is_empty():
			game.finish_event_trial(completed % 2 == 0)
		if game.phase == "reward":
			game.choose_reward(0)
		completed += 1
		if game.phase == "explore" and completed == 4:
			game.go_home()
			check(game.continue_saved_run(), "mid-run continue")
	check(game.phase == "boss_ready", "normal progression must reach altar")
	if game.phase == "boss_ready":
		game.begin_boss_combat()
		check(game.combat_is_boss and game.phase == "world_boss", "altar must start Boss combat on the explored overworld")
		var explored_cells := 0
		for raw_cell in game.room_rules.placed.keys():
			var cell_room: Dictionary = game.room_rules.placed[raw_cell]
			if bool(cell_room.get("revealed", false)) or bool(cell_room.get("completed", false)):
				explored_cells += 1
		check(game.combat != null and game.combat.graph.size() == explored_cells, "finale board must preserve every explored physical map cell")
		game.combat.outcome = "victory"
		game.return_from_combat()
		check(game.phase == "ending" and game.ending_success, "boss victory must reach ending")
		game.finish_ending()
		check(game.phase == "home" and not game.has_saved_run(), "ending must return home and clear finished run")
	game.start_new_run(false, 1337)
	game.choose_omen(0)
	var legacy: Dictionary = game.run_save_repository.read()
	legacy.erase("rng_state")
	game.run_save_repository.write(legacy)
	game.go_home()
	check(game.continue_saved_run(), "legacy saves without RNG state must remain readable")
	game.start_combat(living)
	game.combat.outcome = "defeat"
	game.return_from_combat()
	check(game.phase == "home" and not game.has_saved_run(), "ordinary defeat must clear run")
	game.start_host_preview()
	game.begin_boss_combat()
	game.combat.outcome = "defeat"
	game.return_from_combat()
	check(game.phase == "ending" and not game.ending_success, "boss defeat must show failure ending")
	game.finish_ending()
	game._clear_run_save()
	game.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("COMPLETE_RUN_FLOW: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func route(game, start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start]
	var previous: Dictionary = {start: start}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == target:
			var result: Array[Vector2i] = []
			while cell != start:
				result.push_front(cell)
				cell = previous[cell]
			return result
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = cell + direction
			if not previous.has(next) and game._rooms_connected(cell, next):
				previous[next] = cell
				queue.append(next)
	return []
