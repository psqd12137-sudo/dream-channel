extends SceneTree

const WebContentAdapter = preload("res://scripts/web_content_adapter.gd")
const BossProgression = preload("res://scripts/boss_progression.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var content: Dictionary = WebContentAdapter.new("res://data/web_snapshot/", "boss-test").build_content(1337)
	var boss_snapshot: Dictionary = content.get("bosses", {})
	var altar: Dictionary = content.get("boss_room", {})
	_check(not altar.is_empty(), "formal content must expose a separate altar room")
	_check(bool(altar.get("boss_room", false)), "altar room must be marked as a Boss room")
	_check(int(altar.get("arena", {}).get("cols", 0)) == 6 and int(altar.get("arena", {}).get("rows", 0)) == 4, "altar arena must use the dedicated 6x4 layout")
	_check("2,0" in (altar.get("arena", {}).get("anchors", []) as Array), "altar anchors must use runtime x,y coordinates")

	var expected_ids := ["channel_host", "whisper_wall", "director_cut", "hide_and_seek", "fog_walker", "stars_align", "rust_keeper"]
	for boss_id in expected_ids:
		_check(not (boss_snapshot.get("bosses", {}) as Dictionary).get(boss_id, {}).is_empty(), "Boss snapshot must contain %s" % boss_id)
	var host_id := BossProgression.select_boss_id(boss_snapshot, 2, 2)
	var fog_id := BossProgression.select_boss_id(boss_snapshot, 0, 0)
	_check(host_id == "channel_host", "Boss rule selection must match the channel host route")
	_check(fog_id == "fog_walker", "Boss rule selection must match the fog route")

	var pressure: Dictionary = content.get("pressure", {})
	var boss_room := BossProgression.build_boss_room(boss_snapshot, pressure, altar, host_id)
	var boss_enemy: Dictionary = boss_room.get("enemy", {})
	_check(bool(boss_room.get("boss_room", false)), "built Boss room must stay marked as Boss content")
	_check((boss_room.get("enemies", []) as Array).size() == 1, "Boss room must contain exactly one Boss enemy")
	_check(int(boss_enemy.get("hp", 0)) == 16, "channel host must use snapshot HP")
	_check("slam" in (boss_enemy.get("traits", []) as Array), "Boss room must inherit the pressure Boss traits")

	var packed: PackedScene = load("res://channel_3d.tscn")
	var game: Node3D = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.animation_duration_scale = 0.0
	game.start_new_run(false, 1337)
	game.choose_omen(0)
	game.run_progress = int(game.content.get("run_length", 12))
	game._prepare_boss_ready()
	_check(game.phase == "boss_ready", "reaching the run cap must open the Boss-ready phase")
	_check(not game.boss_id.is_empty(), "Boss-ready phase must lock a Boss id")
	# Legacy single-room rule regression; formal finale entry is covered by overworld_boss_regression.
	game.start_combat(BossProgression.build_boss_room(game.content.bosses, game.content.pressure, game.content.boss_room, game.boss_id))
	_check(game.phase == "combat" and game.combat_is_boss, "legacy Boss fixture starts its room combat")
	_check(game.combat != null and game.combat.enemy_order.size() == 1, "formal Boss combat must have one enemy")
	_check(not game.combat.enemy_death_allowed, "ritual Bosses must require the signal-anchor victory route")
	game.boss_directive_id = "closeup"
	game.boss_round_moved = false
	_check(game._boss_closeup_blocks_card({"name": "测试攻击", "target": "single_enemy"}), "closeup directive must block an attack before movement")
	_check(not game._boss_closeup_blocks_card({"name": "测试防御", "target": "self"}), "closeup directive must allow self-targeted preparation")
	game.boss_round_moved = true
	_check(not game._boss_closeup_blocks_card({"name": "测试攻击", "target": "single_enemy"}), "closeup directive must release cards after movement")
	game.boss_directive_id = "extra"
	game.boss_anchors_cleared = 2
	game.boss_broadcast_progress = 0
	game.boss_broadcast_max = 99
	game.combat.outcome = ""
	game._advance_boss_broadcast()
	_check(game.boss_broadcast_progress == 2, "extra directive must add one additional broadcast point")
	game.boss_anchors_cleared = 0
	var boss_state = game.combat.enemy_by_id(game.combat.enemy_order[0])
	game.combat.enemy_vision_suppressed = true
	boss_state.sees_player = true
	game.combat._refresh_enemy_vision(boss_state, false)
	_check(not boss_state.sees_player, "mute directive state must suppress enemy sight during its turn")
	game.combat.enemy_vision_suppressed = false
	game.combat._apply_enemy_damage(boss_state, 999, 0, "boss-test")
	_check(boss_state.hp == 1 and game.combat.outcome == "", "ritual Bosses must survive direct lethal damage")
	_check(game.boss_anchor_cells.size() > 0, "Boss combat must materialize signal anchors")
	if not game.boss_anchor_cells.is_empty():
		var first_anchor: Vector2i = game.boss_anchor_cells[0]
		game.combat.player_pos = first_anchor
		game.combat.energy = 20
		var anchor_hp_before := int(game.boss_anchor_hp.get(first_anchor, 0))
		game.dismantle_boss_anchor()
		_check(int(game.boss_anchor_hp.get(first_anchor, 0)) == anchor_hp_before - 1, "standing on an anchor must spend an action to damage it")
		var first_guard := 0
		while int(game.boss_anchor_hp.get(first_anchor, 0)) > 0 and first_guard < 8:
			first_guard += 1
			game.combat.energy = 20
			game.dismantle_boss_anchor()
		_check(first_guard < 8, "first signal anchor must be bounded")
		_check(game.boss_anchors_cleared == 1, "destroying an anchor must advance the cleared count")
		for anchor_value in game.boss_anchor_cells:
			var anchor: Vector2i = anchor_value
			if anchor == first_anchor:
				continue
			var anchor_guard := 0
			while int(game.boss_anchor_hp.get(anchor, 0)) > 0 and anchor_guard < 8:
				anchor_guard += 1
				game.combat.player_pos = anchor
				game.combat.energy = 20
				game.dismantle_boss_anchor()
			_check(anchor_guard < 8, "every signal anchor must be bounded")
		_check(game.combat.outcome == "victory", "ritual Bosses must win when all signal anchors are cleared")
	game.combat.outcome = ""
	game.boss_broadcast_progress = game.boss_broadcast_max - 1
	game._advance_boss_broadcast()
	_check(game.combat.outcome == "defeat", "broadcast overflow must end the Boss fight")
	game.combat.outcome = "victory"
	game.return_from_combat()
	_check(game.phase == "ending", "Boss victory must enter the ending screen")
	_check(game.combat == null and game.ending_success, "Boss victory ending must close the combat session")
	_check(not game.current_ending().get("title", "").is_empty(), "ending screen must resolve snapshot ending text")
	game.finish_ending()
	_check(game.phase == "home", "ending continue action must return to title")
	game.queue_free()
	await process_frame

	if failures.is_empty():
		print("CHANNEL_BOSS_PROGRESSION: PASS-rules-altar-combat-ending")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_BOSS_PROGRESSION: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
