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

	var game := (load("res://channel_3d.tscn") as PackedScene).instantiate() as Node3D
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_combat_lab("hall")
	game.combat.enemy_archetype = "unregistered_test_enemy"
	game.build_battle_world()
	var fallback = game.battle_root.get_node_or_null("Enemy/Presenter")
	_check(fallback != null and fallback.config.get("model_path", "") == base_enemy.get("model_path", ""), "unknown archetypes must retain the base enemy model fallback")
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
