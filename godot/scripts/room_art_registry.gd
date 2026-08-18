extends RefCounted

const PROP_ROOT := "res://assets/quaternius/ultimate_house_interior/"
const LAYOUT_SCENE := preload("res://scenes/room_layout_lab.tscn")
const LAYOUT_ROOM_NODES := {
	"foyer": "Foyer",
	"porch": "Porch",
	"living": "Living",
	"kitchen": "Kitchen",
	"mudroom": "Mudroom",
	"pantry": "Pantry",
	"yard": "Yard",
	"shed": "Shed",
	"guest": "Guest",
	"gallery": "Gallery",
	"greenhouse": "Greenhouse",
	"bedroom": "Bedroom",
	"study": "Study",
	"nursery": "Nursery",
	"darkroom": "Darkroom",
	"attic": "Attic",
	"loft": "Loft",
	"boiler": "Boiler",
	"ritual": "Ritual",
	"altar": "Altar",
	"hall": "Hall",
	"parlor": "Parlor",
	"west_wing": "WestWing",
	"cellar": "Cellar",
}

const PROFILES := {
	"living": [
		{"asset": "Couch_Medium1.fbx", "position": Vector3(-0.68, 0.38, 0.62), "yaw": -90.0, "scale": 0.42},
		{"asset": "Table_RoundLarge.fbx", "position": Vector3(0.30, 0.38, 0.05), "yaw": 0.0, "scale": 0.42},
		{"asset": "Houseplant_3.fbx", "position": Vector3(0.92, 0.38, -0.78), "yaw": 25.0, "scale": 0.42},
	],
	"parlor": [
		{"asset": "Couch_Medium1.fbx", "position": Vector3(-0.72, 0.38, 0.72), "yaw": -90.0, "scale": 0.40},
		{"asset": "Table_RoundLarge.fbx", "position": Vector3(0.22, 0.38, 0.05), "yaw": 0.0, "scale": 0.40},
		{"asset": "Chair_2.fbx", "position": Vector3(0.82, 0.38, -0.60), "yaw": 155.0, "scale": 0.40},
		{"asset": "Light_Chandelier.fbx", "position": Vector3(0.0, 1.65, 0.0), "yaw": 0.0, "scale": 0.28},
	],
	"kitchen": [
		{"asset": "Kitchen_Fridge.fbx", "position": Vector3(-0.88, 0.38, 0.77), "yaw": 180.0, "scale": 0.42},
		{"asset": "Kitchen_Oven.fbx", "position": Vector3(-0.15, 0.38, 0.88), "yaw": 180.0, "scale": 0.42},
		{"asset": "Table_RoundLarge.fbx", "position": Vector3(0.68, 0.38, -0.35), "yaw": 0.0, "scale": 0.36},
	],
	"hall": [
		{"asset": "Bookshelf.fbx", "position": Vector3(0.90, 0.38, 0.10), "yaw": -90.0, "scale": 0.42},
		{"asset": "Door_3.fbx", "position": Vector3(-0.92, 0.38, 0.82), "yaw": 180.0, "scale": 0.38},
		{"asset": "Light_Chandelier.fbx", "position": Vector3(0.0, 1.65, 0.0), "yaw": 0.0, "scale": 0.25},
	],
	"west_wing": [
		{"asset": "Bed_Single.fbx", "position": Vector3(-0.45, 0.38, 0.28), "yaw": 90.0, "scale": 0.42},
		{"asset": "Window_Round1.fbx", "position": Vector3(0.12, 0.60, 1.20), "yaw": 180.0, "scale": 0.42},
		{"asset": "Chair_2.fbx", "position": Vector3(0.83, 0.38, -0.68), "yaw": 145.0, "scale": 0.38},
	],
	"cellar": [
		{"asset": "Fireplace.fbx", "position": Vector3(0.05, 0.38, 0.92), "yaw": 180.0, "scale": 0.43},
		{"asset": "Bookshelf.fbx", "position": Vector3(0.92, 0.38, -0.10), "yaw": -90.0, "scale": 0.38},
		{"asset": "Light_Chandelier.fbx", "position": Vector3(-0.45, 1.55, -0.35), "yaw": 0.0, "scale": 0.23},
	],
	"study": [
		{"asset": "Bookshelf.fbx", "position": Vector3(0.90, 0.38, 0.15), "yaw": -90.0, "scale": 0.40},
		{"asset": "Table_RoundLarge.fbx", "position": Vector3(-0.10, 0.38, -0.10), "yaw": 0.0, "scale": 0.36},
		{"asset": "Chair_2.fbx", "position": Vector3(-0.75, 0.38, -0.62), "yaw": -35.0, "scale": 0.38},
	],
	"bedroom": [
		{"asset": "Bed_Single.fbx", "position": Vector3(-0.42, 0.38, 0.20), "yaw": 90.0, "scale": 0.44},
		{"asset": "Houseplant_3.fbx", "position": Vector3(0.90, 0.38, -0.72), "yaw": 15.0, "scale": 0.40},
	],
	"greenhouse": [
		{"asset": "Houseplant_3.fbx", "position": Vector3(-0.72, 0.38, 0.65), "yaw": -20.0, "scale": 0.48},
		{"asset": "Houseplant_3.fbx", "position": Vector3(0.10, 0.38, -0.10), "yaw": 35.0, "scale": 0.36},
		{"asset": "Houseplant_3.fbx", "position": Vector3(0.78, 0.38, 0.55), "yaw": 90.0, "scale": 0.43},
	],
}

const PROFILE_ALIASES := {
	"foyer": "hall",
	"porch": "hall",
	"gallery": "study",
	"guest": "bedroom",
	"nursery": "bedroom",
	"pantry": "kitchen",
}


static func decorate(parent: Node3D, room: Dictionary, revealed: bool) -> int:
	if not revealed:
		return 0
	var room_id := str(room.get("id", ""))
	var authored_count := _decorate_from_layout(parent, room_id)
	if authored_count > 0:
		return authored_count
	var profile_id := str(PROFILE_ALIASES.get(room_id, room_id))
	var profile: Array = PROFILES.get(profile_id, [])
	var added := 0
	for index in range(profile.size()):
		var spec: Dictionary = profile[index]
		if _spawn_prop(parent, index, spec):
			added += 1
	return added


static func _decorate_from_layout(parent: Node3D, room_id: String) -> int:
	if not LAYOUT_ROOM_NODES.has(room_id):
		return 0
	var layout := LAYOUT_SCENE.instantiate()
	var layout_room := layout.get_node_or_null(NodePath(str(LAYOUT_ROOM_NODES[room_id]))) as Node3D
	if layout_room == null:
		layout.free()
		return 0
	var added := 0
	for child: Node in layout_room.get_children():
		if not child.get_groups().has(&"room_prop"):
			continue
		var prop := child.duplicate() as Node3D
		if prop == null:
			continue
		prop.name = "QuaterniusProp_%02d_%s" % [added, child.name]
		parent.add_child(prop)
		_set_prop_shadows(prop)
		added += 1
	layout.free()
	return added


static func asset_paths() -> Array[String]:
	var paths: Array[String] = []
	for profile: Array in PROFILES.values():
		for spec: Dictionary in profile:
			var path := PROP_ROOT + str(spec.get("asset", ""))
			if not path in paths:
				paths.append(path)
	return paths


static func _spawn_prop(parent: Node3D, index: int, spec: Dictionary) -> bool:
	var asset_name := str(spec.get("asset", ""))
	var packed := load(PROP_ROOT + asset_name) as PackedScene
	if packed == null:
		push_warning("Missing Quaternius room prop: %s" % asset_name)
		return false
	var prop := packed.instantiate() as Node3D
	if prop == null:
		return false
	prop.name = "QuaterniusProp_%02d_%s" % [index, asset_name.get_basename()]
	prop.position = spec.get("position", Vector3.ZERO)
	prop.rotation.y = deg_to_rad(float(spec.get("yaw", 0.0)))
	prop.scale = Vector3.ONE * float(spec.get("scale", 0.4))
	parent.add_child(prop)
	_set_prop_shadows(prop)
	return true


static func _set_prop_shadows(prop: Node3D) -> void:
	for child: Node in prop.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
