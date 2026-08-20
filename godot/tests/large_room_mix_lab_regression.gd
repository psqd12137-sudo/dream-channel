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
	game.go_home()
	game.start_kenney_build_lab()
	await process_frame

	_check(game.large_room_mix_test_mode, "the table-model test entry must enable the large-room mix experiment")
	_check(str(game.run_layout_profile.get("id", "")) == "large_room_test", "the test entry must expose its own layout profile")
	_check(int(game._find_catalog_room("living").get("room_size", 0)) == 3, "living room must become a three-cell room in the experiment")
	_check(str(game._find_catalog_room("kitchen").get("footprint_kind", "")) == "line3", "kitchen must become a three-cell line in the experiment")
	_check(int(game._find_catalog_room("greenhouse").get("room_size", 0)) == 3, "greenhouse must become a three-cell room in the experiment")
	_check(int(game._find_catalog_room("bedroom").get("room_size", 0)) == 3, "bedroom must become a three-cell room in the experiment")
	_check(int(game._find_catalog_room("nursery").get("room_size", 0)) == 3, "nursery must become a three-cell room in the experiment")
	_check(int(game._find_catalog_room("yard").get("room_size", 0)) == 5, "yard must become a five-cell landmark in the experiment")
	var catalog_counts := _catalog_size_counts(game.room_catalog)
	_check(int(catalog_counts[1]) == 6 and int(catalog_counts[3]) == 10 and int(catalog_counts[5]) == 5, "the experimental runtime pool must be 6/10/5 by room size, got %s" % catalog_counts)

	var composer: Node = game.house_root.get_node_or_null("KenneyFormalComposer")
	_check(composer != null and bool(composer.unify_room_floor_finish), "experimental multi-cell rooms must share one floor finish per room")
	var save_existed := FileAccess.file_exists(game.RUN_SAVE_PATH)
	var save_before := FileAccess.get_file_as_string(game.RUN_SAVE_PATH) if save_existed else ""
	game._save_run()
	_check(FileAccess.file_exists(game.RUN_SAVE_PATH) == save_existed, "the experiment must not create or remove the formal run save")
	if save_existed:
		_check(FileAccess.get_file_as_string(game.RUN_SAVE_PATH) == save_before, "the experiment must not overwrite the formal run save")

	var best_offers: Array[Dictionary] = []
	var best_size_variety := 0
	for frontier: Vector2i in game.room_rules.frontiers():
		var offers: Array[Dictionary] = game._make_build_offers(frontier)
		var sizes: Dictionary = {}
		for room: Dictionary in offers:
			sizes[int(room.get("room_size", 1))] = true
		if sizes.size() > best_size_variety:
			best_size_variety = sizes.size()
			best_offers = offers
	_check(best_offers.size() == 3, "the starting test frontier must still provide three tickets")
	_check(not best_offers.is_empty() and int(best_offers[0].get("room_size", 0)) == 3, "the foyer must lead with the planned three-cell beat")
	_check(best_size_variety >= 2, "the three tickets must span multiple room sizes when valid")
	for room: Dictionary in best_offers:
		_check(int(room.get("room_size", 1)) != 1, "the foyer must not immediately offer another single-cell room while larger rooms fit")

	game.reset_run(2026082001)
	await process_frame
	_check(not game.large_room_mix_test_mode and not game.show_house_diagnostics, "resetting into a formal run must disable every experiment flag")
	_check(int(game._find_catalog_room("living").get("room_size", 0)) == 1, "the experiment must not mutate the formal living-room catalog")
	_check(int(game._find_catalog_room("yard").get("room_size", 0)) == 1, "the experiment must not mutate the formal yard catalog")
	var formal_composer: Node = game.house_root.get_node_or_null("KenneyFormalComposer")
	_check(formal_composer != null and not bool(formal_composer.unify_room_floor_finish), "formal rendering must keep the experimental floor switch disabled")

	game.queue_free()
	await process_frame
	_finish()


func _catalog_size_counts(catalog: Array[Dictionary]) -> Dictionary:
	var counts := {1: 0, 3: 0, 5: 0}
	for room: Dictionary in catalog:
		var size := int(room.get("room_size", 1))
		if counts.has(size):
			counts[size] = int(counts[size]) + 1
	return counts


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_LARGE_ROOM_MIX_LAB: PASS isolated-catalog diverse-offers cadence unified-floor")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_LARGE_ROOM_MIX_LAB: %s" % failure)
		quit(1)
