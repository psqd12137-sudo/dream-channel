extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://channel_3d.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_tactile_lab()
	var lab = game.tactile_lab
	lab.set_reference_mode()
	if not lab.has_method("set_material_detail"):
		push_error("MATERIAL: missing per-asset material preset")
		quit(1)
		return
	if lab.material_detail_records.size() < 20:
		push_error("MATERIAL: too few captured asset surfaces")
		quit(1)
		return
	if lab.reference_material_detail_records.size() < 20:
		push_error("MATERIAL: reference workshop assets were not captured")
		quit(1)
		return
	var reference_kinds := {}
	for record: Dictionary in lab.reference_material_detail_records:
		reference_kinds[record.kind] = true
	for kind in ["painted_wood", "felt", "metal", "paper"]:
		if not reference_kinds.has(kind):
			push_error("MATERIAL: reference workshop missing " + kind + " profile")
			quit(1)
			return
	var kinds := {}
	for record: Dictionary in lab.material_detail_records:
		kinds[record.kind] = true
	for kind in ["plastic", "painted_wood", "felt", "metal", "paper"]:
		if not kinds.has(kind):
			push_error("MATERIAL: missing " + kind + " profile")
			quit(1)
			return
	var sample = lab.material_detail_records[0].detailed
	if sample == lab.material_detail_records[0].original:
		push_error("MATERIAL: C must use material copies")
		quit(1)
		return
	lab.set_material_detail(false)
	if lab.material_detail_enabled:
		push_error("MATERIAL: toggle did not disable")
		quit(1)
		return
	lab.set_material_detail(true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(1130, 433) * game.hud.ui_scale + game.hud.ui_offset
	game.hud._gui_input(click)
	if lab.material_detail_enabled:
		push_error("MATERIAL: real HUD toggle did not disable")
		quit(1)
		return
	game.hud._gui_input(click)
	if not lab.material_detail_enabled:
		push_error("MATERIAL: real HUD toggle did not restore")
		quit(1)
		return
	game.go_home()
	game.queue_free()
	await process_frame
	print("MATERIAL: PASS")
	quit()
