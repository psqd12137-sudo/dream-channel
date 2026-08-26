extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://channel_3d.tscn") as PackedScene
	_check(packed != null, "channel scene must load")
	if packed == null:
		_finish()
		return
	var game := packed.instantiate() as Node3D
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	var taa_supported := DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() != "gl_compatibility"
	_check(game.world_viewport.use_taa or not taa_supported, "world viewport must enable built-in TAA when the renderer supports it")
	var room: Dictionary = _find_room(game.room_catalog, "living")
	room = room.duplicate(true)
	room["arena"] = {
		"cols": 6,
		"rows": 3,
		"player": [0, 1],
		"enemy": [5, 0],
		"walls": ["2, 0"],
		"heights": {"5,0": 1},
		"spawnNote": "多敌人场景验收"
	}
	room["enemies"] = [
		{"id": "alpha", "name": "阿尔法", "spawn": [5, 0], "hp": 6, "archetype": "execute"},
		{"id": "bravo", "name": "布拉沃", "spawn": [4, 1], "hp": 5, "archetype": "patrol"},
		{"id": "charlie", "name": "查理", "spawn": [5, 2], "hp": 4, "archetype": "ambush"},
		{"id": "delta", "name": "德尔塔", "spawn": [3, 0], "hp": 7, "archetype": "execute"}
	]
	game.start_combat(room)
	await process_frame
	var combat = game.combat
	_check(game.phase == "combat", "multi-enemy room must enter combat")
	_check(combat.enemy_order == ["alpha", "bravo", "charlie", "delta"], "enemy order must preserve authored order")
	_check(combat.enemies.size() == 4, "combat must retain all four enemy states")
	_check(game.enemy_nodes.size() == 4, "scene must create one node per enemy")
	for enemy_id in combat.enemy_order:
		var node: Node3D = game._enemy_node_for_id(enemy_id)
		_check(node != null, "enemy node must resolve by id: %s" % enemy_id)
		_check(node.get_node_or_null("Presenter") != null, "enemy presenter must exist: %s" % enemy_id)
	_check(game.battle_actor_root.get_node_or_null("Enemy") != null, "first enemy keeps legacy node name")
	_check(game.battle_actor_root.get_node_or_null("Enemy_bravo") != null, "additional enemy uses stable id node name")
	var midpoint: Vector3 = game._battle_follow_target_position()
	var expected := Vector3.ZERO
	var points := 1
	for enemy_id in combat.enemy_order:
		expected += game._battle_pawn_world(combat.enemy_by_id(enemy_id).pos, false, enemy_id)
		points += 1
	expected += game._battle_pawn_world(combat.player_pos, true)
	expected /= float(points)
	_check(midpoint.distance_to(expected) < 0.01, "battle camera follow must include every living enemy")
	game._play_enemy_state("charlie", "hurt", "受击")
	var charlie_presenter = game._enemy_node_for_id("charlie").get_node_or_null("Presenter")
	_check(charlie_presenter.current_state == "hurt", "targeted enemy animation must stay on its own node")
	var hud: Control = game.get_node("HUD/HUDRoot")
	_check(not hud.has_method("_draw_enemy_roster"), "HUD must remove the obsolete enemy roster module")
	_check(hud.has_method("_draw_enemy_intel_panel"), "HUD must expose enemy intel panel drawing")
	_check(hud.has_method("_draw_battle_tile_inspection"), "HUD must expose tile inspection panel drawing")
	_check(hud.has_method("_enemy_intent_sentence"), "HUD must expose enemy intent sentence")
	_check(not game.enemy_intel_visible(), "enemy intel must stay hidden in normal combat")
	game.battle_focused_enemy_id = "alpha"
	game.battle_turn_actor_id = "charlie"
	_check(hud.call("_focused_enemy_id") == "charlie", "HUD must follow the enemy currently taking its turn")
	game.battle_turn_actor_id = "player"
	_check(hud.call("_focused_enemy_id") == "alpha", "HUD must restore the manually focused enemy on the player turn")
	var alpha = combat.enemy_by_id("alpha")
	combat.traps[alpha.pos] = {"card_id": "guard", "slow": 2, "persistent": true}
	game.refresh_battle_state(false, false)
	await process_frame
	var salt_cell: Node3D = game.battle_board_root.get_node_or_null("Cell_%d_%d" % [alpha.pos.x, alpha.pos.y])
	var salt_visual: MeshInstance3D = salt_cell.get_node_or_null("Trap") as MeshInstance3D if salt_cell != null else null
	var salt_material: ShaderMaterial = salt_visual.material_override as ShaderMaterial if salt_visual != null else null
	var salt_mesh: QuadMesh = salt_visual.mesh as QuadMesh if salt_visual != null else null
	_check(salt_visual != null and salt_visual.get_meta("collision_free", false), "salt ring visual must be explicitly collision-free")
	_check(salt_material != null and salt_material.shader != null, "salt ring visual must use a shader material")
	_check(salt_mesh != null and salt_mesh.size.x > 1.9 and salt_mesh.size.y > 1.9, "salt ring visual must use a single ground mesh")
	_check(salt_material != null and salt_material.get_shader_parameter("salt_texture") != null, "salt ring shader must use the salt texture")
	_check(salt_material != null and not salt_material.shader.code.contains("depth_test_disabled"), "salt ring shader must respect actor depth ordering")
	alpha.status_effects["bleed"] = {"stacks": 2, "turns": 3}
	var status_text: String = hud.call("_enemy_status_text", alpha)
	_check(status_text.contains("盐圈束缚"), "salt trap must appear as an enemy status")
	_check(status_text.contains("流血×2"), "generic bleed status must appear with stacks")
	game.battle_world_renderer.update_battle_feedback_overlay()
	game.animation_busy = true
	game.battle_world_renderer.update_battle_debug_visibility()
	game.battle_world_renderer.update_battle_feedback_overlay()
	var intent_overlay_found := false
	for raw_overlay: Variant in game.battle_world_renderer.battle_intent_overlay_nodes.values():
		var overlay := raw_overlay as Control
		if overlay != null:
			intent_overlay_found = true
			_check(not overlay.visible, "enemy head intent must hide during turn animation")
	_check(intent_overlay_found, "enemy head intent overlay must exist before turn animation hides it")
	var hidden_debug_tile_found := false
	for cell_node: Node in game.battle_board_root.get_children():
		for child: Node in cell_node.get_children():
			if child.name.begins_with("Intent") or child.name.begins_with("PlayerReachable") or child.name.begins_with("PlayerPosition"):
				hidden_debug_tile_found = true
	_check(not hidden_debug_tile_found, "battle tile debug overlays must hide during turn animation")
	game.animation_busy = false
	game.battle_world_renderer.update_battle_debug_visibility()
	game.battle_world_renderer.update_battle_feedback_overlay()
	var restored_debug_tile_found := false
	for cell_node: Node in game.battle_board_root.get_children():
		for child: Node in cell_node.get_children():
			if child.name.begins_with("Intent") or child.name.begins_with("PlayerPosition"):
				restored_debug_tile_found = true
	_check(restored_debug_tile_found, "battle tile debug overlays must restore after turn animation")
	game.animation_duration_scale = 0.25
	game.animation_busy = true
	var ranged_events: Array[Dictionary] = [{
		"kind": "attack",
		"actor_id": "alpha",
		"attack_kind": "ranged",
		"target": combat.player_pos,
		"damage": 1
	}]
	game._animate_enemy_turn(ranged_events)
	await create_timer(0.10).timeout
	var ranged_popup: Label = game.battle_feedback_root.get_node_or_null("ActionCallout") as Label
	_check(ranged_popup != null and ranged_popup.text == "远程攻击", "ranged enemy attacks must show a floating callout")
	await create_timer(0.70).timeout
	var ranged_damage_popup: Label = game.battle_feedback_root.get_node_or_null("DamageFeedback") as Label
	_check(ranged_damage_popup != null and ranged_damage_popup.text.contains("-1"), "ranged damage must show the actual player damage after the projectile lands")
	await create_timer(0.70).timeout
	game.animation_busy = true
	var melee_events: Array[Dictionary] = [{
		"kind": "attack",
		"actor_id": "alpha",
		"attack_kind": "melee",
		"target": combat.player_pos,
		"damage": 2
	}]
	game._animate_enemy_turn(melee_events)
	await create_timer(0.10).timeout
	var melee_damage_popup: Label = game.battle_feedback_root.get_node_or_null("DamageFeedback") as Label
	_check(melee_damage_popup != null and melee_damage_popup.text.contains("-2"), "melee damage must show the actual player damage")
	await create_timer(0.70).timeout
	game.animation_busy = true
	var blocked_events: Array[Dictionary] = [{
		"kind": "attack",
		"actor_id": "alpha",
		"attack_kind": "melee",
		"target": combat.player_pos,
		"damage": 0,
		"blocked": 2
	}]
	game._animate_enemy_turn(blocked_events)
	await create_timer(0.10).timeout
	var blocked_popup_found := false
	for child: Node in game.battle_feedback_root.get_children():
		var label := child as Label
		if label != null and label.text == "格挡":
			blocked_popup_found = true
	_check(blocked_popup_found, "blocked damage must show a 格挡 callout")
	await create_timer(0.70).timeout
	game._show_enemy_callout_feedback("bravo", "陷阱")
	game._show_enemy_callout_feedback("bravo", "死亡")
	var trap_popup: Label = game.battle_feedback_root.get_node_or_null("ActionCallout") as Label
	_check(trap_popup != null and trap_popup.text == "陷阱", "the first feedback event must play first")
	await create_timer(0.70).timeout
	var death_after_trap_popup: Label = game.battle_feedback_root.get_node_or_null("ActionCallout") as Label
	_check(death_after_trap_popup != null and death_after_trap_popup.text == "死亡", "the death feedback must wait for the preceding trap feedback")
	await create_timer(0.70).timeout
	game.animation_duration_scale = 0.0
	game.test_combat_active = true
	_check(game.enemy_intel_visible(), "test combat must reveal enemy intel")
	var intel_rect: Rect2 = hud.call("_enemy_intel_rect")
	var tile_rect: Rect2 = hud.call("_battle_tile_inspection_rect")
	_check(tile_rect.position.y >= intel_rect.position.y + intel_rect.size.y, "tile inspection must move below enemy intel")
	game.test_combat_active = false
	var intel_relics: Array[String] = ["omen_bell"]
	game.active_relics = intel_relics
	_check(game.enemy_intel_visible(), "omen bell must reveal enemy intel")
	alpha.hp = 0
	game._queue_card_enemy_feedback_before_refresh([{"kind": "enemy_damaged", "target_enemy_id": "alpha", "damage": 1}])
	var feedback_root: Control = game.battle_feedback_root
	var lethal_damage_popup: Label = feedback_root.get_node_or_null("DamageFeedback") as Label
	_check(lethal_damage_popup != null and lethal_damage_popup.text.contains("-1"), "lethal damage must show damage before enemy cleanup")
	await create_timer(0.70).timeout
	var death_popup: Label = feedback_root.get_node_or_null("ActionCallout") as Label
	_check(death_popup != null and death_popup.text == "死亡", "lethal damage must show death feedback after its damage feedback")
	combat.outcome = "victory"
	game.battle_world_renderer.update_battle_feedback_overlay()
	_check(feedback_root.visible, "death feedback must remain visible after victory state hides combat intel")
	game.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _find_room(rooms: Array[Dictionary], room_id: String) -> Dictionary:
	for room: Dictionary in rooms:
		if str(room.get("id", "")) == room_id:
			return room
	return {}


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_MULTI_ENEMY_PRESENTATION: PASS nodes camera targeting animation hud")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_MULTI_ENEMY_PRESENTATION: %s" % failure)
		quit(1)
