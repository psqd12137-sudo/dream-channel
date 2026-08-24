class_name ChannelRunSaveRepository
extends RefCounted

## Persistence boundary for a playable Channel run.
##
## The game controller still decides when a run should be saved and what the
## payload means. This class owns only the file/JSON boundary so gameplay code
## does not need to know about FileAccess or user:// path normalization.

var save_path := ""
var source_id := ""


func _init(next_save_path: String, next_source_id: String) -> void:
	save_path = next_save_path
	source_id = next_source_id


func exists() -> bool:
	return FileAccess.file_exists(save_path)


func read() -> Dictionary:
	if not exists():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary:
		return {}
	var payload: Dictionary = parsed
	if str(payload.get("source", "")) != source_id:
		return {}
	return payload


func write(payload: Dictionary) -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	return true


func clear() -> bool:
	if not exists():
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path)) == OK
