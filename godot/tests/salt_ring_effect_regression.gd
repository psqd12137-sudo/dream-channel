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
	_check(salt_index >= 0 and not direct_combat.can_target_place_card(salt_index, direct_combat.enemy_pos), "salt ring must not target an enemy-occupied cell")
	_check(salt_index >= 0 and not direct_combat.play_card(salt_index, direct_combat.enemy_pos), "salt ring must not be smashed directly onto an enemy")
	_check(direct_combat.traps.is_empty() and direct_combat.energy == 5 and direct_combat.hand.has("guard"), "rejected salt ring smash must not consume card or energy")

	var placement_combat := CombatRules.new()
	placement_combat.setup(arena, _enemy(1), cards, ["guard", "focus", "tonic", "jab"], 31, rules, [])
	var placement_index: int = placement_combat.hand.find("guard")
	var placement_target := Vector2i(1, 0)
	_check(placement_index >= 0 and placement_combat.play_card(placement_index, placement_target), "salt ring placement must still succeed on an empty adjacent cell")
	_check(int(placement_combat.traps.get(placement_target, {}).get("charges", 0)) == 3, "new salt rings must start with three charges")

	var lifecycle_combat := CombatRules.new()
	lifecycle_combat.setup(arena, _enemy(1), cards, ["guard", "focus", "tonic", "jab"], 32, rules, [])
	var lifecycle_enemy_id := str(lifecycle_combat.enemy_order[0]) if not lifecycle_combat.enemy_order.is_empty() else ""
	var lifecycle_enemy = lifecycle_combat.enemy_by_id(lifecycle_enemy_id) if not lifecycle_enemy_id.is_empty() else null
	_check(lifecycle_enemy != null, "salt lifecycle test must expose an enemy")
	if lifecycle_enemy != null:
		var lifecycle_pos: Vector2i = lifecycle_enemy.pos
		lifecycle_combat.traps[lifecycle_pos] = {"card_id": "guard", "glyph": "盐", "damage": 0, "slow": 1, "persistent": true, "charges": 3}
		var first_trigger: Dictionary = lifecycle_combat._trigger_trap(lifecycle_enemy, lifecycle_pos)
		_check(int(first_trigger.get("trap", {}).get("charges", 0)) == 2 and int(lifecycle_combat.traps.get(lifecycle_pos, {}).get("charges", 0)) == 2, "first salt trigger must leave two charges")
		var second_trigger: Dictionary = lifecycle_combat._trigger_trap(lifecycle_enemy, lifecycle_pos)
		_check(int(second_trigger.get("trap", {}).get("charges", 0)) == 1 and int(lifecycle_combat.traps.get(lifecycle_pos, {}).get("charges", 0)) == 1, "second salt trigger must leave one charge")
		var third_trigger: Dictionary = lifecycle_combat._trigger_trap(lifecycle_enemy, lifecycle_pos)
		_check(int(third_trigger.get("trap", {}).get("charges", 0)) == 0 and not lifecycle_combat.traps.has(lifecycle_pos), "third salt trigger must remove the salt ring")

	var damage_combat := CombatRules.new()
	damage_combat.setup(direct_arena, _enemy(1), cards, ["jab", "focus", "tonic", "guard"], 29, rules, [])
	var jab_index: int = damage_combat.hand.find("jab")
	_check(jab_index >= 0 and damage_combat.can_target_place_card(jab_index, damage_combat.enemy_pos), "damage traps must retain explicit direct smash behavior")
	_check(jab_index >= 0 and damage_combat.play_card(jab_index, damage_combat.enemy_pos), "damage traps should still smash directly when allowed")
	var damage_enemy_id := str(damage_combat.enemy_order[0]) if not damage_combat.enemy_order.is_empty() else ""
	var damage_enemy = damage_combat.enemy_by_id(damage_enemy_id) if not damage_enemy_id.is_empty() else null
	_check(damage_enemy != null and damage_enemy.hp == 8, "direct jab smash must still deal its configured damage")

	var broken_combat := CombatRules.new()
	broken_combat.setup(arena, _enemy(1), cards, ["guard", "focus", "tonic", "jab"], 30, rules, [])
	var broken_enemy_id := str(broken_combat.enemy_order[0]) if not broken_combat.enemy_order.is_empty() else ""
	var broken_enemy = broken_combat.enemy_by_id(broken_enemy_id) if not broken_enemy_id.is_empty() else null
	_check(broken_enemy != null, "legacy single-enemy setup must expose its generated enemy id")
	if broken_enemy == null:
		quit(1)
		return
	broken_enemy.toughness = 1
	broken_combat._apply_enemy_damage(broken_enemy, 0, 1, "test")
	var broken_hp_before: int = broken_enemy.hp
	broken_combat.traps[broken_enemy.pos] = {"card_id": "guard", "glyph": "盐", "damage": 0, "slow": 1, "persistent": false}
	var broken_salt_result: Dictionary = broken_combat._trigger_trap(broken_enemy, broken_enemy.pos)
	_check(int(broken_salt_result.get("damage", 0)) == 0 and broken_enemy.hp == broken_hp_before, "salt ring must not convert a pending execute bonus into HP damage")
	_check(broken_enemy.execute_bonus_pending, "zero-damage salt ring must preserve the pending execute bonus")

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
	var trap_visual_root := Node3D.new()
	game.add_child(trap_visual_root)
	game.battle_world_renderer._add_trap_visual(trap_visual_root, {"card_id": "guard", "charges": 3}, 0.0)
	var full_ring := trap_visual_root.get_node_or_null("Trap") as MeshInstance3D
	var full_material := full_ring.material_override as ShaderMaterial if full_ring != null else null
	var full_texture := full_material.get_shader_parameter("salt_texture") as Texture2D if full_material != null else null
	_check(full_texture != null and full_texture.resource_path.ends_with("salt_ring_texture.png"), "three-charge salt ring must use the original texture")
	for child: Node in trap_visual_root.get_children():
		child.free()
	game.battle_world_renderer._add_trap_visual(trap_visual_root, {"card_id": "guard", "charges": 2}, 0.0)
	var worn_ring := trap_visual_root.get_node_or_null("Trap") as MeshInstance3D
	var worn_material := worn_ring.material_override as ShaderMaterial if worn_ring != null else null
	var worn_texture := worn_material.get_shader_parameter("salt_texture") as Texture2D if worn_material != null else null
	_check(worn_texture != null and worn_texture.resource_path.ends_with("salt_ring_texture_charges_2.png"), "two-charge salt ring must use figure 1 texture")
	for child: Node in trap_visual_root.get_children():
		child.free()
	game.battle_world_renderer._add_trap_visual(trap_visual_root, {"card_id": "guard", "charges": 1}, 0.0)
	var faint_ring := trap_visual_root.get_node_or_null("Trap") as MeshInstance3D
	var faint_material := faint_ring.material_override as ShaderMaterial if faint_ring != null else null
	var faint_texture := faint_material.get_shader_parameter("salt_texture") as Texture2D if faint_material != null else null
	_check(faint_texture != null and faint_texture.resource_path.ends_with("salt_ring_texture_charges_1.png"), "one-charge salt ring must use figure 2 texture")
	for child: Node in trap_visual_root.get_children():
		child.free()
	game.battle_world_renderer._add_trap_visual(trap_visual_root, {"card_id": "guard", "charges": 0}, 0.0)
	_check(trap_visual_root.get_child_count() == 0, "depleted salt ring must not create a visual")
	trap_visual_root.queue_free()
	var enemy_node: Node3D = game._enemy_node_for_id(enemy_id)
	var effect := enemy_node.get_node_or_null("SaltRingHitEffect") if enemy_node != null else null
	_check(effect is AnimatedSprite3D, "salt ring hit must create an overhead AnimatedSprite3D")
	if effect is AnimatedSprite3D:
		var sprite := effect as AnimatedSprite3D
		_check(sprite.sprite_frames.has_animation("salt_ring"), "salt ring hit must expose the salt_ring animation")
		_check(sprite.sprite_frames.get_frame_count("salt_ring") == 9, "salt ring hit must use all nine sheet frames")
		_check(is_equal_approx(sprite.sprite_frames.get_animation_speed("salt_ring"), 12.0), "salt ring hit must play at 12 FPS")
		_check(not sprite.sprite_frames.get_animation_loop("salt_ring"), "salt ring hit must be a one-shot animation")
		for frame_index in range(9):
			var frame_texture := sprite.sprite_frames.get_frame_texture("salt_ring", frame_index) as Texture2D
			var frame_image := frame_texture.get_image() if frame_texture != null else null
			var corners_clear := false
			if frame_image != null:
				var last_x := frame_image.get_width() - 1
				var last_y := frame_image.get_height() - 1
				corners_clear = frame_image.get_pixel(0, 0).a < 0.01 and frame_image.get_pixel(last_x, 0).a < 0.01 and frame_image.get_pixel(0, last_y).a < 0.01 and frame_image.get_pixel(last_x, last_y).a < 0.01
			_check(corners_clear, "salt ring hit frame %d must make all sheet corners transparent" % frame_index)
			var border_clear := true
			if frame_image != null:
				var last_x := frame_image.get_width() - 1
				var last_y := frame_image.get_height() - 1
				for edge_x in range(frame_image.get_width()):
					border_clear = border_clear and frame_image.get_pixel(edge_x, 0).a < 0.01 and frame_image.get_pixel(edge_x, last_y).a < 0.01
				for edge_y in range(frame_image.get_height()):
					border_clear = border_clear and frame_image.get_pixel(0, edge_y).a < 0.01 and frame_image.get_pixel(last_x, edge_y).a < 0.01
			_check(border_clear, "salt ring hit frame %d must remove the full sheet border" % frame_index)

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
