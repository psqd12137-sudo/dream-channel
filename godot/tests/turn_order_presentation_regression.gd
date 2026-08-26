extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node3D = (load("res://channel_3d.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	game.open_combat_test_mode()
	game.select_combat_test_scenario("squad_roles")
	_check(game.start_test_combat("manual"), "squad roles test combat must start")
	await process_frame
	var hud: Control = game.get_node("HUD/HUDRoot") as Control
	var enemy_id: String = str(game.combat.enemy_order[0])
	var alive_palette: Array[Color] = hud._turn_order_chip_palette(enemy_id, "player")
	_check(alive_palette[0] == Color("ee3e91").darkened(0.12), "living enemy chip must keep the subdued enemy color")
	_check(alive_palette[1] == Color("fffaf2"), "living enemy chip text must remain readable")

	game.combat.enemy_by_id(enemy_id).hp = 0
	var defeated_palette: Array[Color] = hud._turn_order_chip_palette(enemy_id, enemy_id)
	_check(defeated_palette[0] == Color("5e686e"), "defeated enemy chip must use the gray fill even when it is current")
	_check(defeated_palette[1] == Color("c0c8c8"), "defeated enemy chip must use muted text")
	var player_palette: Array[Color] = hud._turn_order_chip_palette("player", "player")
	_check(player_palette[0] == Color("ffe233"), "player chip must keep the active highlight")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("TURN_ORDER_PRESENTATION: PASS defeated-enemy-gray-chip")
		quit(0)
	else:
		for failure: String in failures:
			push_error("TURN_ORDER_PRESENTATION: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
