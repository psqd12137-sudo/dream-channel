extends SceneTree

const ROOT := "res://assets/third_party/kaykit_dungeon/models/"
const ASSETS := [
	"floor_wood_large.gltf.glb",
	"wall_half.gltf.glb",
	"wall.gltf.glb",
	"wall_doorway.glb",
	"wall_corner_small.gltf.glb",
	"wall_endcap.gltf.glb",
	"wall_pillar.gltf.glb",
	"pillar.gltf.glb",
	"stairs_wood.gltf.glb",
	"table_small.gltf.glb",
	"barrel_large.gltf.glb",
	"candle_lit.gltf.glb",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for asset: String in ASSETS:
		var packed := load(ROOT + asset) as PackedScene
		if packed == null:
			push_error("KAYKIT_BOUNDS: missing %s" % asset)
			continue
		var model := packed.instantiate() as Node3D
		root.add_child(model)
		await process_frame
		var bounds := AABB()
		var has_mesh := false
		for raw_mesh: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := raw_mesh as MeshInstance3D
			if mesh_node.mesh == null:
				continue
			var mesh_bounds := mesh_node.get_aabb()
			var transform := model.global_transform.affine_inverse() * mesh_node.global_transform
			bounds = transform * mesh_bounds if has_mesh else transform * mesh_bounds
			has_mesh = true
		print("KAYKIT_BOUNDS: %s size=%s position=%s" % [asset, bounds.size, bounds.position])
		model.queue_free()
		await process_frame
	quit(0)
