extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://channel_3d.tscn") as PackedScene
	assert(packed != null, "channel scene missing")
	var game := packed.instantiate() as Node3D
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.phase = "explore"
	game._set_house_camera()
	var overview_size: float = float(game.house_camera_size_target)
	var enabled := bool(game.toggle_house_camera_closeup())
	assert(enabled and game.house_camera_closeup, "C-toggle must enable house closeup")
	assert(game.house_camera_size_target < overview_size, "closeup target must be tighter than overview")
	var closeup_size: float = float(game.house_camera_size_target)
	await process_frame
	var disabled := bool(game.toggle_house_camera_closeup())
	assert(not disabled and not game.house_camera_closeup, "second toggle must restore overview")
	assert(is_equal_approx(game.house_camera_size_target, overview_size), "overview target size must be restored")
	print("CHANNEL_HOUSE_CAMERA_CLOSEUP: PASS overview=%.3f closeup=%.3f" % [overview_size, closeup_size])
	game.queue_free()
	await process_frame
	quit(0)
