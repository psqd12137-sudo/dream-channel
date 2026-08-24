extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presenter = load("res://scripts/character_presenter.gd").new()
	root.add_child(presenter)
	var manifest_file := FileAccess.open("res://data/presentation_manifest.json", FileAccess.READ)
	var manifest: Dictionary = JSON.parse_string(manifest_file.get_as_text())
	var player_config: Dictionary = manifest.get("actors", {}).get("player", {})
	presenter.configure("player:test", player_config)
	_check(presenter.get_node_or_null("ActionCallout") == null, "character presenter must not create overhead status words")
	_check(presenter.find_children("*", "Label3D", true, false).is_empty(), "player model hierarchy must contain no overhead UI")
	_check(presenter.current_model_animation().ends_with("Lili_Idle"), "player presenter must start in the repaired idle animation; got %s from %s" % [presenter.current_model_animation(), presenter.model_animation_names()])
	var game: Node3D = load("res://channel_3d.tscn").instantiate() as Node3D
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	game.start_character_animation_lab()
	_check(game.phase == "combat" and game.character_animation_demo_mode, "home development backend must enter the real combat scene in animation demo mode")
	_check(game.battle_actor_root.get_node_or_null("Player/Presenter") != null, "animation demo must use the real combat player presenter")
	var game_presenter = game.battle_actor_root.get_node_or_null("Player/Presenter")
	game.demo_character_attack()
	_check(game_presenter.current_model_animation().ends_with("Lili_Attack"), "attack demo must keep the repaired clip playing; got %s" % game_presenter.current_model_animation())
	game.demo_character_hurt()
	_check(game_presenter.current_model_animation().ends_with("Lili_Hurt"), "hurt demo must keep the repaired clip playing; got %s" % game_presenter.current_model_animation())
	var source: Vector2i = game.combat.player_pos
	game.demo_character_grid_step()
	_check(game.combat.player_pos != source, "grid-step demo must use the real combat movement rules")
	presenter.queue_free()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHARACTER_ANIMATION_LAB: PASS idle raw-walk grid-step no-callout")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHARACTER_ANIMATION_LAB: %s" % failure)
		quit(1)


func _animation_player(actor: Node) -> AnimationPlayer:
	if actor == null:
		return null
	var players := actor.find_children("*", "AnimationPlayer", true, false)
	return players[0] as AnimationPlayer if not players.is_empty() else null


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
