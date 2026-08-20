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
	game.start_new_run(false, 2026082101)
	game.choose_omen(0)
	await process_frame
	var camera: Camera3D = game.camera
	_check(game.phase == "explore" or game.phase == "omen", "run must be in house phase before camera dolly checks")

	# 1) 入场运镜：animation_duration_scale == 0 时应立即就位（不残留远景）
	_check(is_equal_approx(game.house_camera_intro_weight, 1.0), "intro must complete instantly at zero animation scale")
	_check(is_equal_approx(camera.size, game.house_camera_fit_size), "intro end must restore fit scale")

	# 2) 入场运镜（真实时长）：由远至近，weight 从 0 开始增长
	game.animation_duration_scale = 1.0
	var fit_size: float = game.house_camera_fit_size
	game._start_camera_intro()
	_check(not is_equal_approx(game.house_camera_intro_weight, 1.0), "intro must begin from the far view")
	_check(camera.size > fit_size * 1.5, "intro far view must show a wider field than the fit size")
	var intro_tween: Tween = game.house_camera_intro_tween
	_check(intro_tween != null and intro_tween.is_running(), "intro must run a camera tween")
	await create_timer(0.45).timeout
	_check(game.house_camera_intro_weight > 0.0 and game.house_camera_intro_weight < 1.0, "intro must progress from far to near over time")
	if intro_tween != null and intro_tween.is_valid():
		intro_tween.kill()
	game.house_camera_intro_weight = 1.0
	game.animation_duration_scale = 0.0

	# 3) 玩家移动时延迟跟随：只平移不旋转——进入相邻房间后镜头 target 向玩家收敛，旋转角度保持不变
	var token: Node3D = game.house_root.get_node_or_null("LiliToken") as Node3D
	_check(token != null, "house player token must exist")
	var start_target: Vector3 = game.house_camera_target
	var yaw_at_start: float = game.house_camera_yaw
	_check(not game.house_camera_following, "camera must not follow before any movement")
	var frontier: Vector2i = game.room_rules.frontiers()[0]
	game.begin_build(frontier)
	game.select_offer(0)
	game.place_selected_offer()
	await process_frame
	game.enter_room(frontier)
	_check(game.house_camera_following, "entering a room must arm the follow camera")
	await process_frame
	token = game.house_root.get_node_or_null("LiliToken") as Node3D
	var player_pos: Vector3 = Vector3(token.position.x, 0.0, token.position.z) if token != null else game._house_world(game.current_room_pos)
	var framed_pos: Vector3 = player_pos + game._house_camera_frame_offset()
	for i in range(24):
		game._process(0.1)
	_check(start_target.distance_to(player_pos) > 1.0, "the camera must start away from the player after entering a room")
	_check(game.house_camera_target.distance_to(framed_pos) < start_target.distance_to(player_pos) * 0.4, "follow camera must converge toward the framed player position")
	_check(is_equal_approx(game.house_camera_yaw, yaw_at_start), "follow camera must not rotate itself while tracking the player")

	# 4) 松手后延迟回位到玩家正上方：拖动后松手，延迟结束仅把位置对准玩家，旋转保持玩家选择的旋转
	game.orbit_house_camera(Vector2(140.0, 0.0))
	game.pan_house_camera(Vector2(-70.0, -30.0))
	_check(game.house_camera_user_hold, "dragging must put the camera in user hold")
	_check(is_equal_approx(game.house_camera_return_delay, 0.0), "user drag must cancel any pending return")
	var orbit_yaw: float = game.house_camera_yaw
	var orbit_pitch: float = game.house_camera_pitch
	var orbit_zoom: float = game.house_camera_zoom_ratio
	var adjusted_target: Vector3 = game.house_camera_target
	var framed_pos_after: Vector3 = player_pos + game._house_camera_frame_offset()
	_check(adjusted_target.distance_to(framed_pos_after) > 0.8, "pan must actually move the camera target away from the framed player position")
	game.release_house_camera_gesture()
	_check(is_equal_approx(game.house_camera_return_delay, game.HOUSE_CAMERA_RETURN_DELAY), "release must arm the delayed return")
	for i in range(15):
		game._process(0.1)
	_check(game.house_camera_return_delay <= 0.0, "return delay must elapse after the configured pause")
	_check(game.house_camera_target.distance_to(framed_pos_after) < 0.6, "return must settle the camera on the framed player position")
	_check(game.house_camera_target.distance_to(framed_pos_after) < adjusted_target.distance_to(framed_pos_after) * 0.5, "return must actually move the camera toward the player")
	_check(is_equal_approx(game.house_camera_yaw, orbit_yaw), "return must keep the rotation the player chose")
	_check(is_equal_approx(game.house_camera_pitch, orbit_pitch), "return must keep the pitch the player chose")
	_check(is_equal_approx(game.house_camera_zoom_ratio, orbit_zoom), "return must keep the zoom the player chose")
	_check(not game.house_camera_returning, "return must finish cleanly")

	# 5) 战斗走格跟随：走格后战斗镜头 target 向玩家收敛
	game.start_combat_lab("hall")
	await process_frame
	var battle_target0: Vector3 = game.battle_camera_target
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var target_cell: Vector2i = game.combat.player_pos + direction
		if game.combat.can_move_player(target_cell):
			game.handle_battle_cell(target_cell)
			break
	_check(game.battle_camera_following, "battle step must arm the follow camera")
	for i in range(12):
		game._process(0.1)
	var battle_player: Vector3 = game._battle_pawn_world(game.combat.player_pos, true)
	_check(game.battle_camera_target.distance_to(battle_player) < battle_target0.distance_to(battle_player) * 0.5, "battle follow camera must converge toward the player")
	game.orbit_battle_camera(Vector2(60.0, 0.0))
	_check(not game.battle_camera_following, "battle orbit must release the follow camera")

	game.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_CAMERA_DOLLY_FOLLOW: PASS intro dolly delayed follow rotation-preserved return")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_CAMERA_DOLLY_FOLLOW: %s" % failure)
		quit(1)
