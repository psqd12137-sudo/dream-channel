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
	var loaded := int(editor.call("_load_template", "preset_kitchen_01"))
	assert(loaded == 10, "expected 5 assets + 4 walls + 1 fixture, got %d" % loaded)
	var smoke_override_id := "__smoke_export__"
	var smoke_override_path := "res://data/editor/overrides/%s.json" % smoke_override_id
	var exported := str(editor.call("_export_override", smoke_override_id))
	assert(not exported.is_empty(), "override export returned empty")
	var parsed: Variant = JSON.parse_string(exported)
	assert(parsed is Dictionary, "override export is not JSON object")
	var data: Dictionary = parsed
	assert(int(data.get("schema_version", 0)) == 3, "schema version mismatch")
	assert(str(data.get("room_id", "")) == smoke_override_id, "room id mismatch")
	assert((data.get("assets", []) as Array).size() == 5, "asset count mismatch")
	assert((data.get("walls", []) as Array).size() == 4, "wall count mismatch")
	if FileAccess.file_exists(smoke_override_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(smoke_override_path))
	editor.queue_free()
	print("CHANNEL_FORMAL_OVERRIDE_EXPORT: PASS preset_kitchen_01 assets=5 walls=4")
	quit(0)
