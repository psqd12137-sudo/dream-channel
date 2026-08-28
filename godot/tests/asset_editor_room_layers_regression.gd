extends SceneTree

const EditorScene = preload("res://scenes/asset_editor_3d.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var editor := EditorScene.instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	if not editor.has_method("_current_layout_target") or not editor.has_method("_set_edit_layer"):
		push_error("CHANNEL_ASSET_EDITOR_ROOM_LAYERS: editor layer API is not implemented")
		editor.queue_free()
		quit(1)
		return
	_check(str(editor.get("edit_layer_id")) == "world", "editor must start in world layer")
	_check(str(editor.get("formal_room_id")) == "living", "editor must keep the default source room")
	var world_target: Dictionary = editor.call("_current_layout_target")
	_check(str(world_target.get("layer", "")) == "world", "world target must report world layer")
	_check(str(world_target.get("world_room_id", "")) == "living", "world target must report selected source room")
	editor.call("_set_edit_layer", "dungeon", false)
	_check(str(editor.get("edit_layer_id")) == "dungeon", "editor must switch to dungeon layer")
	_check(str(editor.get("formal_room_id")) == "living", "layer switch must not change source room")
	var dungeon_target: Dictionary = editor.call("_current_layout_target")
	_check(str(dungeon_target.get("layer", "")) == "dungeon", "dungeon target must report dungeon layer")
	_check(str(dungeon_target.get("world_room_id", "")) == "living", "dungeon target must keep source room")
	_check(str(dungeon_target.get("dungeon_layout_id", "")) == "living_dungeon_01", "dungeon target must use deterministic layout id")
	editor.call("_set_edit_layer", "world", false)
	_check(str(editor.get("edit_layer_id")) == "world", "editor must switch back to world layer")
	_check(str(editor.get("formal_room_id")) == "living", "switching back must keep source room")
	editor.queue_free()
	if failures.is_empty():
		print("CHANNEL_ASSET_EDITOR_ROOM_LAYERS: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_ASSET_EDITOR_ROOM_LAYERS: " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
