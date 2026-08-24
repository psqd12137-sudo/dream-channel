extends CanvasLayer

## 运行时渲染统计面板。
## F3 显示/隐藏；面板只在打开时扫描 Mesh，避免影响正常游戏性能。

const APP_FONT: Font = preload("res://assets/fonts/SourceHanSansCN-Regular.otf")
const REFRESH_INTERVAL := 0.25

var panel: PanelContainer
var label: Label
var refresh_elapsed := 0.0


func _ready() -> void:
	layer = 30
	panel = PanelContainer.new()
	panel.name = "RenderStatsPanel"
	panel.position = Vector2(18, 106)
	panel.custom_minimum_size = Vector2(390, 164)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101b22ed")
	style.border_color = Color("12b4aa")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	label = Label.new()
	label.name = "RenderStatsLabel"
	label.add_theme_font_override("font", APP_FONT)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("e5f5ef"))
	label.add_theme_color_override("font_shadow_color", Color("05090c"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.text = "面数统计\nF3 显示统计"
	panel.add_child(label)
	panel.visible = false
	set_process(false)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_F3:
		return
	panel.visible = not panel.visible
	set_process(panel.visible)
	if panel.visible:
		_refresh_stats()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	refresh_elapsed += delta
	if refresh_elapsed < REFRESH_INTERVAL:
		return
	refresh_elapsed = 0.0
	_refresh_stats()


func _refresh_stats() -> void:
	var scene := get_tree().current_scene
	var mesh_count := 0
	var visible_mesh_count := 0
	var geometry_triangles := 0
	if scene != null:
		for raw_node: Node in scene.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := raw_node as MeshInstance3D
			if mesh_instance == null or mesh_instance.mesh == null:
				continue
			mesh_count += 1
			if not mesh_instance.is_visible_in_tree():
				continue
			visible_mesh_count += 1
			geometry_triangles += _mesh_triangle_count(mesh_instance.mesh)

	var rendered_primitives := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var draw_calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var rendered_objects := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var phase := str(scene.get("phase")) if scene != null else "未知"
	var scenario_id := str(scene.get("test_mode_selected_id")) if scene != null else ""
	label.text = "面数统计（F3 隐藏）\n"
	label.text += "阶段：%s" % phase
	if not scenario_id.is_empty():
		label.text += "\n测试场：%s" % scenario_id
	label.text += "\n可见 Mesh：%d / 总 Mesh：%d" % [visible_mesh_count, mesh_count]
	label.text += "\n几何三角形：%s" % _format_number(geometry_triangles)
	label.text += "\n当前帧图元：%s" % _format_number(int(rendered_primitives))
	label.text += "\nDraw Calls：%s    渲染对象：%s" % [_format_number(int(draw_calls)), _format_number(int(rendered_objects))]
	label.text += "\n注：当前帧图元包含可见摄像机、阴影等渲染通道。"


func _mesh_triangle_count(mesh: Mesh) -> int:
	var total := 0
	for surface_index in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_VERTEX:
			continue
		var index_data: Variant = arrays[Mesh.ARRAY_INDEX]
		if index_data is PackedInt32Array and not (index_data as PackedInt32Array).is_empty():
			total += (index_data as PackedInt32Array).size() / 3
			continue
		var vertex_data: Variant = arrays[Mesh.ARRAY_VERTEX]
		if vertex_data is PackedVector3Array:
			total += (vertex_data as PackedVector3Array).size() / 3
	return total


func _format_number(value: int) -> String:
	return ("%,d" % value).replace(",", " ")
