extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://channel_3d.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.reset_run(1511875452)
	var target := Vector2i(0, -1)
	var offers: Array[Dictionary] = game._make_build_offers(target)
	var sizes := {}
	for room: Dictionary in offers:
		sizes[int(room.get("room_size", 1))] = true
	_check(sizes.size() >= 2, "seed 1511875452 must offer more than one room size at the first expansion")
	_check(not (sizes.size() == 1 and sizes.has(1)), "compact profile must not collapse every offer to one-cell rooms")
	for seed_value: int in [1511875452, 1, 2, 3, 4, 5, 2026081901]:
		game.reset_run(seed_value)
		var legal_sizes := _legal_sizes(game, target)
		var seed_sizes := {}
		for room: Dictionary in game._make_build_offers(target):
			seed_sizes[int(room.get("room_size", 1))] = true
		if legal_sizes.size() >= 2:
			_check(seed_sizes.size() >= 2, "seed %d must preserve size variety when multiple sizes are legal" % seed_value)
	var first_signature := _offer_signature(offers)
	game.reset_run(1511875452)
	var repeated_signature := _offer_signature(game._make_build_offers(target))
	_check(first_signature == repeated_signature, "same seed must reproduce the same room offer order")
	_add_single_room_streak(game)
	var correction: Array[Dictionary] = game._make_build_offers(target)
	var correction_has_large := false
	for room: Dictionary in correction:
		if int(room.get("room_size", 1)) > 1:
			correction_has_large = true
	_check(correction_has_large, "three consecutive one-cell choices must trigger a larger-room correction")
	print("LAYOUT_OFFER_REGRESSION: ", "PASS" if failures == 0 else "FAIL")
	game.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _offer_signature(offers: Array[Dictionary]) -> Array[String]:
	var signature: Array[String] = []
	for room: Dictionary in offers:
		signature.append("%s:%s" % [str(room.get("id", "")), str(room.get("room_size", 1))])
	return signature


func _add_single_room_streak(game: Node) -> void:
	var completion_order := 100
	var index := 0
	for pos: Vector2i in [Vector2i(20, 20), Vector2i(21, 20), Vector2i(22, 20)]:
		game.room_rules.placed[pos] = {
			"instance_id": "synthetic_single_%d" % index,
			"room_size": 1,
			"footprint": [[0, 0]],
			"completion_order": completion_order,
			"completed": true,
		}
		completion_order += 1
		index += 1


func _legal_sizes(game: Node, target: Vector2i) -> Dictionary:
	var sizes := {}
	for room: Dictionary in game.remaining_rooms:
		if not game.room_rules.valid_rotations(target, room).is_empty():
			sizes[int(room.get("room_size", 1))] = true
	return sizes
