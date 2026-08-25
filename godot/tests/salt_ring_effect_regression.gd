extends SceneTree

const CombatRules = preload("res://scripts/combat_rules.gd")
const WebContentAdapter = preload("res://scripts/web_content_adapter.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var content: Dictionary = WebContentAdapter.new().build_content(27)
	var cards: Dictionary = content.get("cards", {})
	var arena := {
		"cols": 3,
		"rows": 1,
		"player": [0, 0],
		"enemy": [2, 0],
		"walls": [],
		"heights": {},
		"portals": [],
	}
	var rules := {"player_hp": 6, "base_speed": 3, "base_energy": 5, "hand_size": 4, "move_cost": 1}
	var combat := CombatRules.new()
	combat.setup(arena, _enemy(1), cards, ["guard", "focus", "tonic", "jab"], 27, rules, [])
	combat.traps[Vector2i(1, 0)] = {"card_id": "guard", "glyph": "盐", "damage": 0, "slow": 1, "persistent": true}
	var turn_events: Array[Dictionary] = combat.enemy_turn()
	var salt_trigger_found := false
	for event: Dictionary in turn_events:
		if str(event.get("kind", "")) == "enemy_trap_triggered":
			var trap: Dictionary = event.get("trap", {})
			if str(trap.get("card_id", "")) == "guard":
				salt_trigger_found = true
	_check(salt_trigger_found, "stepping on a zero-damage salt ring must publish a trigger event")

	var direct_arena: Dictionary = arena.duplicate(true)
	direct_arena["enemy"] = [1, 0]
	var direct_combat := CombatRules.new()
	direct_combat.setup(direct_arena, _enemy(1), cards, ["guard", "focus", "tonic", "jab"], 28, rules, [])
	var salt_index: int = direct_combat.hand.find("guard")
	_check(salt_index >= 0 and direct_combat.play_card(salt_index, direct_combat.enemy_pos), "salt ring should support direct enemy placement")
	var direct_event_found := false
	for event: Dictionary in direct_combat.last_card_events:
		var trap: Dictionary = event.get("trap", {})
		if str(trap.get("card_id", "")) == "guard":
			direct_event_found = true
	_check(direct_event_found, "direct salt ring placement must carry its trap visual marker even with zero damage")

	var game: Node3D = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_combat_lab("hall")
	await process_frame
	var enemy_id := str(game.combat.enemy_order[0]) if not game.combat.enemy_order.is_empty() else ""
	var enemy_state = game.combat.enemy_by_id(enemy_id) if not enemy_id.is_empty() else null
	if enemy_state != null:
		enemy_state.revealed = true
		game.refresh_battle_state(true, false)
		await process_frame
		game._show_enemy_salt_ring_effect(enemy_id)
	var enemy_node: Node3D = game._enemy_node_for_id(enemy_id)
	var effect := enemy_node.get_node_or_null("SaltRingHitEffect") if enemy_node != null else null
	_check(effect is AnimatedSprite3D, "salt ring hit must create an overhead AnimatedSprite3D")
	if effect is AnimatedSprite3D:
		var sprite := effect as AnimatedSprite3D
		_check(sprite.sprite_frames.has_animation("salt_ring"), "salt ring hit must expose the salt_ring animation")
		_check(sprite.sprite_frames.get_frame_count("salt_ring") == 9, "salt ring hit must use all nine sheet frames")
		_check(is_equal_approx(sprite.sprite_frames.get_animation_speed("salt_ring"), 12.0), "salt ring hit must play at 12 FPS")
		_check(not sprite.sprite_frames.get_animation_loop("salt_ring"), "salt ring hit must be a one-shot animation")
		var first_frame := sprite.sprite_frames.get_frame_texture("salt_ring", 0) as Texture2D
		var first_frame_image := first_frame.get_image() if first_frame != null else null
		_check(first_frame_image != null and first_frame_image.get_pixel(0, 0).a < 0.01, "salt ring hit must make the black sheet background transparent")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHANNEL_SALT_RING_EFFECT: PASS zero-damage trigger direct-hit marker nine-frame overhead animation")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_SALT_RING_EFFECT: %s" % failure)
		quit(1)


func _enemy(action_points: int) -> Dictionary:
	return {
		"name": "盐圈测试敌人",
		"hp": 10,
		"damage": 1,
		"toughness": 3,
		"action_points": action_points,
		"attack_cost": 2,
		"archetype": "execute",
		"archetype_label": "处决匣",
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
