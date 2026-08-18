extends SceneTree

const OUTPUT_ROOT := "res://artifacts/"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://channel_3d.tscn")
	var game: Node3D = packed.instantiate()
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.toggle_home_tests()
	await _capture("completion_01_home_tests.png")

	game.start_sideview_lab()
	await process_frame
	await _capture("completion_02_sideview.png")

	game.go_home()
	game.start_puzzle_lab()
	await process_frame
	await _capture("completion_03_puzzle.png")

	game.go_home()
	game.start_search_lab()
	game.orbit_search_camera(Vector2(-65.0, 10.0))
	await process_frame
	await _capture("completion_04_search.png")

	game.go_home()
	game.start_combat_lab("hall")
	game.combat.ambush_active = false
	game.combat.ambush_idle_turns = 1
	game.combat.enemy_revealed = false
	game.combat.player_sees_enemy = false
	game.combat.enemy_sees_player = false
	game.combat.last_seen = game.combat.INVALID_CELL
	game.combat.patrol_goal = game.combat.INVALID_CELL
	game.status_message = "无视野：敌人不会停摆；蓝色编号明确显示下一回合的巡逻顺序。"
	game.build_battle_world()
	game._refresh_hud()
	await process_frame
	await _capture("completion_05_patrol_intent.png")
	print("CAPTURE_COMPLETION_PASS: PASS")
	quit(0)


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT_ROOT + file_name)
	if error != OK:
		push_error("CAPTURE_COMPLETION_PASS: failed to save %s (%s)" % [file_name, error_string(error)])
