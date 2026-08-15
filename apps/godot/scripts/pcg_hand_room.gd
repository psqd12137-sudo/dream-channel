@tool
extends Node3D

@export var room_id := "room"
@export_enum("single", "line3", "l3", "plus5", "t5", "p5", "stair5", "u5") var shape_id := "single"
@export var elevated := false


func grid_origin(cell_size: float) -> Vector2i:
	return Vector2i(roundi(position.x / cell_size), roundi(position.z / cell_size))


func quarter_turns() -> int:
	return posmod(roundi(rotation.y / (PI * 0.5)), 4)


func layout_signature() -> String:
	return "%s|%s|%.4f,%.4f|%.4f|%s" % [room_id, shape_id, position.x, position.z, rotation.y, str(elevated)]


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var snapped_x := roundf(position.x / 1.55) * 1.55
	var snapped_z := roundf(position.z / 1.55) * 1.55
	if absf(position.x - snapped_x) > 0.01 or absf(position.z - snapped_z) > 0.01:
		warnings.append("房间没有落在 1.55m 网格上；生成器会使用最近格。")
	var snapped_yaw := roundf(rotation.y / (PI * 0.5)) * PI * 0.5
	if absf(wrapf(rotation.y - snapped_yaw, -PI, PI)) > 0.01:
		warnings.append("房间旋转不是 90° 的整数倍；生成器会使用最近朝向。")
	return warnings
