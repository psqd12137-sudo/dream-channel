@tool
extends Node3D

@export_multiline var display_name := "未命名\nroom":
	set(value):
		display_name = value
		_refresh_label()

@export var layout_cells: Array[Vector2i] = [Vector2i.ZERO]:
	set(value):
		layout_cells = value
		_refresh_footprint()


func _ready() -> void:
	_refresh_label()
	_refresh_footprint()


func _refresh_label() -> void:
	var label := get_node_or_null("Name") as Label3D
	if label != null:
		label.text = display_name


func _refresh_footprint() -> void:
	var previous := get_node_or_null("GeneratedFootprint")
	if previous != null:
		previous.free()
	var base_template := get_node_or_null("Base") as CSGBox3D
	var floor_template := get_node_or_null("Floor") as CSGBox3D
	if base_template == null or floor_template == null:
		return
	var generated := Node3D.new()
	generated.name = "GeneratedFootprint"
	add_child(generated)
	for cell: Vector2i in layout_cells:
		if cell == Vector2i.ZERO:
			continue
		var offset := Vector3(float(cell.x) * 3.4, 0.0, float(cell.y) * 3.4)
		var extra_base := base_template.duplicate() as CSGBox3D
		extra_base.name = "Base_%d_%d" % [cell.x, cell.y]
		extra_base.position += offset
		generated.add_child(extra_base)
		var extra_floor := floor_template.duplicate() as CSGBox3D
		extra_floor.name = "Floor_%d_%d" % [cell.x, cell.y]
		extra_floor.position += offset
		generated.add_child(extra_floor)
