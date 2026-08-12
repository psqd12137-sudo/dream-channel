extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node3D = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_combat_lab("hall")
	var entrance: Vector2i = game.combat.portals.keys()[0]
	game.combat.player_pos = entrance
	game.combat.pending_player_portal = game.combat.portals[entrance]
	game.status_message = "已踩上传送门入口；必须主动选择穿过或留在这里。"
	game.build_battle_world()
	game._refresh_hud()
	await _capture("res://artifacts/combat_height_portal_choice.png")

	game.go_home()
	game.start_new_run(false)
	game.choose_omen(0)
	game.begin_build(game.room_rules.frontiers()[0])
	game.rotate_offer()
	await process_frame
	await _capture("res://artifacts/house_live_rotation_preview.png")
	print("CAPTURE_BOARD_PORTAL_BUILD: PASS")
	quit(0)


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("CAPTURE_BOARD_PORTAL_BUILD: %s" % error_string(error))
