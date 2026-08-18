@tool
extends Node3D

@export var show_guides := true:
	set(value):
		show_guides = value
		_apply_guide_visibility()

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_apply_guide_visibility()
		return
	camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)


func _apply_guide_visibility() -> void:
	for node in get_tree().get_nodes_in_group("layout_guide"):
		if node is CanvasItem or node is Node3D:
			node.visible = show_guides
