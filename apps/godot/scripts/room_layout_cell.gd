@tool
extends Node3D

@export_multiline var display_name := "未命名\nroom":
	set(value):
		display_name = value
		_refresh_label()


func _ready() -> void:
	_refresh_label()


func _refresh_label() -> void:
	var label := get_node_or_null("Name") as Label3D
	if label != null:
		label.text = display_name
