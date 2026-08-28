extends SceneTree

const EditorScene = preload("res://scenes/asset_editor_3d.tscn")
const DungeonLayoutCatalog = preload("res://scripts/dungeon_layout_catalog.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var editor := EditorScene.instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	editor.call("_set_edit_layer", "dungeon", false)
	if not editor.has_method("_export_dungeon_layout"):
		push_error("CHANNEL_DUNGEON_LAYOUT_EXPORT: export API is not implemented")
		editor.queue_free()
		quit(1)
		return
	var world_before := FileAccess.get_file_as_string("res://data/editor/overrides/living.json")
	var exported := str(editor.call("_export_dungeon_layout", "__smoke_dungeon__"))
	var parsed: Variant = JSON.parse_string(exported)
	_check(parsed is Dictionary, "export must return JSON object")
	if parsed is Dictionary:
		var data := parsed as Dictionary
		_check(int(data.get("schema_version", 0)) == 1, "dungeon schema version must be 1")
		_check(str(data.get("dungeon_layout_id", "")) == "__smoke_dungeon__", "dungeon layout id must be preserved")
		_check(str(data.get("source_world_room_id", "")) == "living", "source world room must be preserved")
		_check(str(data.get("footprint_kind", "")) == "single", "dungeon fallback must inherit selected room footprint")
		_check(data.get("assets", null) is Array, "dungeon export must include spatial assets")
		_check(data.get("walls", null) is Array, "dungeon export must include spatial walls")
		_check(not data.has("enemies") and not data.has("arena") and not data.has("cards") and not data.has("rewards"), "dungeon export must not include gameplay data")
	_check(FileAccess.file_exists(DungeonLayoutCatalog.layout_path("__smoke_dungeon__")), "dungeon export must write to dungeon layout directory")
	_check(FileAccess.get_file_as_string("res://data/editor/overrides/living.json") == world_before, "dungeon export must not modify world override")
	var smoke_path := ProjectSettings.globalize_path(DungeonLayoutCatalog.layout_path("__smoke_dungeon__"))
	if FileAccess.file_exists(DungeonLayoutCatalog.layout_path("__smoke_dungeon__")):
		DirAccess.remove_absolute(smoke_path)
	editor.queue_free()
	if failures.is_empty():
		print("CHANNEL_DUNGEON_LAYOUT_EXPORT: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_DUNGEON_LAYOUT_EXPORT: " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
