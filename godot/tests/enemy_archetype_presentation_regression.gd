extends SceneTree

const CharacterPresenter = preload("res://scripts/character_presenter.gd")

const ARCHETYPES := ["execute", "armor", "stagger", "crush", "wire"]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var file := FileAccess.open("res://data/presentation_manifest.json", FileAccess.READ)
	_check(file != null, "presentation manifest must be readable")
	if file == null:
		_finish()
		return
	var manifest: Dictionary = JSON.parse_string(file.get_as_text())
	var base_enemy: Dictionary = manifest.get("actors", {}).get("enemy", {})
	var variants: Dictionary = manifest.get("enemy_archetypes", {})
	var assassin: Dictionary = variants.get("assassin", {})
	_check(str(assassin.get("model_path", "")).contains("BlueDemon.gltf"), "assassin must reuse the verified animated enemy silhouette")
	_check(str(assassin.get("animation_map", {}).get("attack", "")).to_lower() == "punch", "assassin must have an attack animation mapping")
	var model_paths: Dictionary = {}
	for archetype: String in ARCHETYPES:
		var variant: Dictionary = variants.get(archetype, {})
		var model_path := str(variant.get("model_path", ""))
		_check(not model_path.is_empty(), "%s must declare a model path" % archetype)
		_check(ResourceLoader.exists(model_path), "%s model must import as a Godot resource" % archetype)
		model_paths[model_path] = true
		var config := base_enemy.duplicate(true)
		config.merge(variant, true)
		var presenter := CharacterPresenter.new()
		root.add_child(presenter)
		presenter.configure("enemy:%s" % archetype, config)
		_check(presenter.has_3d_model(), "%s must instantiate a skinned animated model" % archetype)
		_check(presenter.current_model_animation().to_lower().contains("idle"), "%s must start in Idle" % archetype)
		for state: String in ["move", "attack", "hurt"]:
			presenter.play_state(state)
			var expected := str(config.get("animation_map", {}).get(state, "")).to_lower()
			_check(presenter.current_model_animation().to_lower().contains(expected), "%s must map %s to %s" % [archetype, state, expected])
		presenter.queue_free()
	_check(model_paths.size() == ARCHETYPES.size(), "all five enemy archetypes must use distinct silhouettes")
	var tinted_config := base_enemy.duplicate(true)
	tinted_config["model_tint"] = Color("4dbbff")
	tinted_config["model_tint_strength"] = 0.55
	var tinted_presenter := CharacterPresenter.new()
	root.add_child(tinted_presenter)
	tinted_presenter.configure("enemy:ranged", tinted_config)
	_check(_count_surface_overrides(tinted_presenter) > 0, "ranged tint must duplicate and recolor imported model materials")
	tinted_presenter.queue_free()

	var game := (load("res://channel_3d.tscn") as PackedScene).instantiate() as Node3D
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_combat_lab("hall")
	game.combat.enemy_archetype = "unregistered_test_enemy"
	game.build_battle_world()
	var fallback = game.battle_actor_root.get_node_or_null("Enemy/Presenter")
	_check(fallback != null and fallback.config.get("model_path", "") == base_enemy.get("model_path", ""), "unknown archetypes must retain the base enemy model fallback")
	var rendered_enemy = game.combat.enemy_by_id(game.combat.enemy_order[0])
	var ranged_traits: Array[String] = ["ranged"]
	rendered_enemy.traits = ranged_traits
	game.build_battle_world()
	var ranged_presenter = game.battle_actor_root.get_node_or_null("Enemy/Presenter")
	_check(ranged_presenter != null and float(ranged_presenter.config.get("model_tint_strength", 0.0)) > 0.0, "ranged enemy presentation must carry a visible model tint")
	var ranged_base := game.battle_actor_root.get_node_or_null("Enemy/PawnBase") as MeshInstance3D
	var ranged_base_material := ranged_base.material_override as StandardMaterial3D if ranged_base != null else null
	_check(ranged_base_material != null and ranged_base_material.albedo_color.b > ranged_base_material.albedo_color.r, "ranged enemy base must use the ranged color")
	game.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_ENEMY_ARCHETYPE_PRESENTATION: PASS five-model animation-map fallback")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_ENEMY_ARCHETYPE_PRESENTATION: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _count_surface_overrides(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				if mesh_instance.get_surface_override_material(surface_index) != null:
					count += 1
	for child in node.get_children():
		count += _count_surface_overrides(child)
	return count
