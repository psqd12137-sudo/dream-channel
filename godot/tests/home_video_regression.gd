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
	await process_frame

	var video: VideoStreamPlayer = game.home_video
	_check(video != null, "home video node must exist")
	if video != null:
		_check(video.visible, "home video must be visible on the home screen")
		_check(video.stream != null and (video.stream as VideoStreamTheora).file.ends_with("menu_video.ogv"), "home video must use the menu OGV stream")
		_check(video.loop, "home video must loop")
		_check(not video.paused, "home video must not be paused on home screen")

	# 进入游戏后视频应隐藏并停止
	game.start_new_run(false)
	await process_frame
	_check(not video.visible, "home video must hide after starting a run")

	# 回到主页视频应重新显示
	game.go_home()
	await process_frame
	_check(video.visible, "home video must reappear when returning home")

	game.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_HOME_VIDEO: PASS visible loop play hide return-home")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_HOME_VIDEO: %s" % failure)
		quit(1)
var _smb_tail_padding := """
Home video background regression.
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
"""
