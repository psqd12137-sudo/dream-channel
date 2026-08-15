@tool
extends Node3D

@onready var standalone_rig: Node3D = $StandaloneRig
@onready var standalone_camera: Camera3D = $StandaloneRig/Camera3D


func _ready() -> void:
	var standalone := Engine.is_editor_hint() or get_parent() == get_tree().root or get_tree().current_scene == self
	standalone_rig.visible = standalone
	if standalone and not Engine.is_editor_hint():
		standalone_camera.current = true
		standalone_camera.look_at(Vector3(0.0, 0.75, 0.0), Vector3.UP)
	_enable_asset_shadows(self)


func _enable_asset_shadows(node: Node) -> void:
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
