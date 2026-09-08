extends Node3D
## Small playable experiment: arrange rooms, then test the exact same door graph.
const Model = preload("res://scripts/layout_intuition_model.gd")
const Composer = preload("res://scripts/pcg_hand_layout_lab.gd")
const Piece = preload("res://scripts/pcg_hand_room.gd")
const CELL := 1.55
var model = Model.new()
var selected := 0
var turns := 0
var hovered := Model.NONE
var obstruction := false
var probing := false
var camera: Camera3D
var geometry: Node3D
var overlay: Node3D
var preview_root: Node3D
var info: Label
var hint: Label
var panel: PanelContainer
var camera_center := Vector3(1.55, 0, 1.55)

func _ready() -> void:
	model.reset()
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101f29")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d5e8e5")
	env.ambient_light_energy = 0.65
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-30,0)
	light.light_energy = 1.1
	light.shadow_enabled = true
	add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10
	add_child(camera)
	camera.position = camera_center + Vector3(10,14,15)
	camera.look_at(camera_center)
	camera.current = true
	var canvas := CanvasLayer.new()
	add_child(canvas)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(20,20)
	panel.custom_minimum_size = Vector2(285,0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("182d37")
	panel_style.border_color = Color("35bfb1")
	panel_style.set_border_width_all(2)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel",panel_style)
	canvas.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "布局直觉实验室"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "补齐房子，让路线自然变顺。\n独立沙盒 · 不写正式存档"
	box.add_child(subtitle)
	for i in range(3):
		_button(box, "%d 格  %s" % [[1,3,5][i], model.options[i].name], func():
			selected = i
			probing = false
			_draw_route()
			_show_preview())
	_button(box, "旋转 90°  [R]", _rotate)
	_button(box, "撤销上次摆放", func():
		model.undo()
		_rebuild())
	_button(box, "查看起点 → 锚点路线", func():
		probing = true
		obstruction = false
		_draw_route())
	_button(box, "模拟封路 / 恢复通路", func():
		probing = true
		obstruction = not obstruction
		_draw_route())
	_button(box, "重新布置", func():
		model.reset()
		obstruction = false
		probing = false
		_rebuild())
	_button(box, "返回标题", func(): get_tree().change_scene_to_file("res://channel_3d.tscn"))
	info = Label.new()
	info.text = "鼠标悬停：预览接门\n左键：摆放　滚轮：缩放\n中键拖动：平移\n青色：起点　金色：锚点\n中央缺口可以补齐，也可向外扩建。"
	box.add_child(info)
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(275,90)
	box.add_child(hint)
	_rebuild()

func _button(parent: Node, text_value: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 36
	var style := StyleBoxFlat.new()
	style.bg_color = Color("285d65")
	style.border_color = Color("4b8b8a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal",style)
	button.pressed.connect(action)
	parent.add_child(button)

func _replace(old: Node3D) -> Node3D:
	if is_instance_valid(old):
		remove_child(old)
		old.queue_free()
	var fresh := Node3D.new()
	add_child(fresh)
	return fresh

func _rebuild() -> void:
	geometry = _replace(geometry)
	var composer = Composer.new()
	composer.animate_room_build = false
	composer.show_room_ids = false
	composer.show_summary_title = false
	composer.open_visited_connections = true
	var layout := Node3D.new()
	layout.name = "Layout"
	composer.add_child(layout)
	var rig := Node3D.new()
	rig.name = "StandaloneRig"
	var spare_camera := Camera3D.new()
	spare_camera.name = "Camera3D"
	rig.add_child(spare_camera)
	composer.add_child(rig)
	var seen := {}
	for cell: Vector2i in model.rules.placed:
		var room: Dictionary = model.rules.placed[cell]
		for next: Vector2i in model.neighbors(cell):
			composer.explicit_connection_edges[model.rules._edge_key(cell,next)] = true
		for dir: Vector2i in Model.Rules.DIRS:
			if not model.rules.placed.has(cell+dir) and model.rules.cell_has_door(cell, Model.Rules.DIRS.find(dir)):
				composer.explicit_open_edges[model.rules._edge_key(cell,cell+dir)] = true
		if seen.has(room.instance_id):
			continue
		seen[room.instance_id] = true
		var piece := Node3D.new()
		piece.set_script(Piece)
		piece.set("room_id", room.instance_id)
		piece.set("shape_id", room.footprint_kind)
		piece.position = Vector3(room.origin[0]*CELL,0,room.origin[1]*CELL)
		piece.rotation.y = int(room.rotation)*PI*0.5
		piece.set_meta("room_type", room.id)
		piece.set_meta("revealed", true)
		piece.set_meta("visited", true)
		piece.set_meta("completed", true)
		layout.add_child(piece)
	geometry.add_child(composer)
	_draw_route()
	_show_preview()

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if color.a < 1:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	mesh.material_override = material
	parent.add_child(mesh)

func _point(cell: Vector2i, height: float = 0.25) -> Vector3:
	return Vector3(cell.x*CELL,height,cell.y*CELL)

func _draw_route() -> void:
	overlay = _replace(overlay)
	_box(overlay,_point(Vector2i.ZERO,0.8),Vector3(0.25,0.65,0.25),Color("1edaca"))
	_box(overlay,_point(Vector2i(2,0),0.8),Vector3(0.3,0.65,0.3),Color("ffe066"))
	if not probing:
		return
	preview_root = _replace(preview_root)
	var route: Array[Vector2i] = model.route(Vector2i(0,1) if obstruction else Model.NONE)
	if obstruction:
		_box(overlay,_point(Vector2i(0,1),0.7),Vector3(1.1,0.22,1.1),Color("f15a77"))
	for i in range(1,route.size()):
		var a := _point(route[i-1],0.35)
		var b := _point(route[i],0.35)
		_box(overlay,(a+b)/2,Vector3(absf(a.x-b.x)+0.1,0.05,absf(a.z-b.z)+0.1),Color("ffe066"))
	hint.text = "封路后没有可达路线。\n试着连接另一侧的门。" if route.is_empty() else "真实门路：%d 步抵达锚点。\n%s" % [route.size()-1,"原通道封闭，仍能绕行。" if obstruction else "这是连接演示，不是完整 Boss 战。"]

func _show_preview() -> void:
	preview_root = _replace(preview_root)
	if hovered == Model.NONE or probing:
		return
	var p: Dictionary = model.preview(hovered,selected,turns)
	for cell: Vector2i in p.cells:
		_box(preview_root,_point(cell,0.3),Vector3(1.4,0.12,1.4),Color(0.2,0.9,0.75,0.65) if p.valid else Color(1,0.2,0.3,0.55))
	if p.valid:
		var edges: Array = model.rules._resolved_open_edges(p.cells,model.rules.rotated_doors(model.options[selected].doors,turns))
		for cell: Vector2i in p.cells:
			for direction: Vector2i in Model.Rules.DIRS:
				var other := cell+direction
				if model.rules.placed.has(other) and model.rules._edge_key(cell,other) in edges:
					_box(preview_root,(_point(cell,0.6)+_point(other,0.6))/2,Vector3(0.25,0.18,0.25),Color("ffe066"))
	hint.text = "%s · 旋转 %d°\n%s" % [model.options[selected].name,turns*90,"形成回路 · 接通 %d 个门口" % p.contacts if p.loop else "接通 %d 个门口" % p.contacts if p.valid else "这里放不下，或门位不匹配"]

func _rotate() -> void:
	turns = (turns+1)%4
	probing = false
	_draw_route()
	_show_preview()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_rotate()
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			camera.position += camera.global_basis.x * -event.relative.x*0.012 + camera.global_basis.y * event.relative.y*0.012
		var hit = Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(event.position),camera.project_ray_normal(event.position))
		if hit != null:
			hovered = Vector2i(roundi(hit.x/CELL),roundi(hit.z/CELL))
			_show_preview()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(6,camera.size-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(40,camera.size+1)
		elif event.button_index == MOUSE_BUTTON_LEFT and hovered != Model.NONE:
			var hit = Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(event.position),camera.project_ray_normal(event.position))
			if hit == null:
				return
			hovered = Vector2i(roundi(hit.x/CELL),roundi(hit.z/CELL))
			probing = false
			if model.place(hovered,selected,turns):
				_rebuild()
