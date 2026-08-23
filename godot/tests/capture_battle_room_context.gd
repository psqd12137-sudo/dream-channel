extends SceneTree

const OUTPUT_FULL := "res://artifacts/battle_room_context_full.png"
const OUTPUT_WORLD := "res://artifacts/battle_room_context_world.png"
const OUTPUT_OVERRIDE_WORLD := "res://artifacts/battle_room_context_living_override.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://channel_3d.tscn") as PackedScene
	var game := packed.instantiate() as Node3D
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_new_run(false, 2026082301)
	game.choose_omen(0)
	var hall: Dictionary = game._find_catalog_room("hall")
	game.start_combat(hall)
	await process_frame
	await process_frame
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var world_viewport := game.get_node("WorldLayer/WorldContainer/WorldViewport") as SubViewport
	var full_error := root.get_texture().get_image().save_png(OUTPUT_FULL)
	var world_error := world_viewport.get_texture().get_image().save_png(OUTPUT_WORLD)
	var living: Dictionary = game._find_catalog_room("living")
	game.start_combat(living)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var override_error := world_viewport.get_texture().get_image().save_png(OUTPUT_OVERRIDE_WORLD)
	if full_error != OK or world_error != OK or override_error != OK:
		push_error("CAPTURE_BATTLE_ROOM_CONTEXT: full=%s world=%s override=%s" % [error_string(full_error), error_string(world_error), error_string(override_error)])
		quit(1)
		return
	print("CAPTURE_BATTLE_ROOM_CONTEXT: PASS")
	quit(0)
