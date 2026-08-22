extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/asset_editor_3d.tscn") as PackedScene
	assert(scene != null, "asset editor scene missing")
	var editor := scene.instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	var loaded := int(editor.call("_load_template", "diorama_demo"))
	assert(loaded == 9, "expected 5 assets + 4 walls, got %d" % loaded)
	var exported := str(editor.call("_export_override", "living"))
	assert(not exported.is_empty(), "override export returned empty")
	var parsed: Variant = JSON.parse_string(exported)
	assert(parsed is Dictionary, "override export is not JSON object")
	var data: Dictionary = parsed
	assert(int(data.get("schema_version", 0)) == 3, "schema version mismatch")
	assert(str(data.get("room_id", "")) == "living", "room id mismatch")
	assert((data.get("assets", []) as Array).size() == 5, "asset count mismatch")
	assert((data.get("walls", []) as Array).size() == 4, "wall count mismatch")
	print("CHANNEL_FORMAL_OVERRIDE_EXPORT: PASS living assets=5 walls=4")
	quit(0)
