extends SceneTree

const CombatRules = preload("res://scripts/combat_rules.gd")


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
	game.house_camera_closeup = true
	game._finish_enter_room(Vector2i.ZERO)
	assert(not game.house_camera_closeup, "ordinary room entry must stay overview")

	game.event_context = "puzzle"
	game.event_room_pos = Vector2i.ZERO
	game.phase = "lab_puzzle"
	game.finish_event_trial(false)
	assert(game.house_camera_closeup, "event exit must trigger closeup")

	var combat := CombatRules.new()
	combat.outcome = "victory"
	combat.player_hp = game.player_hp
	game.combat = combat
	game.phase = "combat"
	game.animation_busy = false
	game.house_camera_closeup = false
	game.return_from_combat()
	assert(game.house_camera_closeup, "combat exit must trigger closeup")

	print("CHANNEL_V7_SCALE_CAMERA: PASS visual_scale=%.2f entry_overview event_closeup combat_closeup" % game.VISUAL_CELL_SCALE)
	game.queue_free()
	await process_frame
	quit(0)
