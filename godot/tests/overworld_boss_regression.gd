extends SceneTree

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://channel_3d.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.animation_duration_scale = 0.0
	var save_before_preview: Dictionary = game.run_save_repository.read().duplicate(true)
	game.start_host_preview()
	var before: Dictionary = game.room_rules.placed.duplicate(true)
	game.begin_boss_combat()
	check(game.run_save_repository.read() == save_before_preview, "world preview entry cannot overwrite a formal save")
	var ok: bool = game.phase == "world_boss" and game.house_root.visible and not game.battle_root.visible
	if not ok:
		push_error("Boss must remain on the generated overworld, not open an isolated combat room")
	if game.room_rules.placed != before:
		push_error("Boss entry must preserve the exact generated room layout")
		ok = false
	check(ok, "overworld entry preserves layout and rendering root")
	var r = game.combat
	check(r.graph.size() >= 24, "Boss board must contain every occupied overworld cell")
	check(r.cell_nodes[Vector2i(1, 0)] != r.cell_nodes[Vector2i(2, 0)], "adjacent cells inside a three-cell room remain separate battle cells")
	check(r.cell_nodes[Vector2i(3, 0)] != r.cell_nodes[Vector2i(4, 2)], "cells inside a five-cell room remain separate battle cells")
	check(r.player_pos == Vector2i(0, 0) and r.is_walkable(Vector2i(1, 0)), "battle coordinates use the original overworld grid")
	check(r.graph[Vector2i(1, 0)].has(Vector2i(2, 0)), "same-room neighboring cells connect without an artificial room jump")
	check(r.anchors.size() == 4, "four objectives are distributed across distinct rooms")
	if "--capture-world" in OS.get_cmdline_user_args():
		for frame in range(120):
			await process_frame
			if frame >= 15 and game.hud.card_flight_offsets.is_empty():
				break
		# The dummy/headless renderer does not always emit frame_post_draw; one
		# extra frame is enough for the overlay to reach the capture buffer.
		await process_frame
		var capture_texture: Texture2D = root.get_texture()
		if capture_texture != null:
			capture_texture.get_image().save_png("res://artifacts/overworld_boss_playable.png")
	else:
		_test_clock_and_replay(game)
		_test_unified_turn_cards(game)
		_test_boss_pursuit_and_attack(game)
		_test_ritual(game)
		_test_kill(game)
		_test_graph_doors()
		# Full production persistence path, not just the rules snapshot.
		game.boss_preview_active = false
		game._save_run()
		var expected: Dictionary = game.combat.snapshot()
		var hp: int = game.combat.player_hp
		game.go_home()
		check(game.continue_saved_run(), "continue loads world finale")
		check(game.phase == "world_boss" and JSON.parse_string(JSON.stringify(game.combat.snapshot())) == JSON.parse_string(JSON.stringify(expected)) and game.combat.player_hp == hp and game.combat.outcome == "victory", "continue reconstructs exact world finale state")
		var save_before_failures: Dictionary = game.run_save_repository.read().duplicate(true)
		_test_failures(game)
		check(game.run_save_repository.read() == save_before_failures, "world preview endings cannot clear a formal save")
	game.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("OVERWORLD_BOSS: PASS graph-entry-turn-based-ritual-save")
	quit(0 if failures.is_empty() else 1)

func _test_clock_and_replay(game) -> void:
	var r = game.combat
	var ap: int = r.energy
	var neighbor: Vector2i = r.graph[r.player_pos][0]
	check(r.step_to(neighbor), "movement follows a connected door")
	check(r.energy < ap, "movement spends AP")
	var snapshot: Dictionary = r.snapshot()
	var original_pos: Vector2i = r.player_pos
	var original_ap: int = r.energy
	game._begin_world_boss(JSON.parse_string(JSON.stringify(snapshot)))
	r = game.combat
	check(r.player_pos == original_pos and r.energy == original_ap, "JSON replay restores player node and AP")
	var round_before: int = r.round_number
	var broadcast_before: int = r.broadcast
	r.tick(10.0)
	check(r.round_number == round_before and r.broadcast == broadcast_before, "waiting never advances the Boss turn automatically")
	game.end_combat_turn()
	check(r.round_number == round_before + 1 and r.broadcast >= broadcast_before + 2, "ending the turn advances the Boss and broadcast")
	game._refresh_world_boss()

func _test_unified_turn_cards(game) -> void:
	game.go_home()
	game.start_host_preview()
	game.begin_boss_combat()
	var r = game.combat
	var before_round: int = r.round_number
	var before_broadcast: int = r.broadcast
	var before_hp: int = r.player_hp
	var waiting_ap: int = r.energy
	game._process(60.0)
	check(r.round_number == before_round and r.broadcast == before_broadcast and r.player_hp == before_hp and r.energy == waiting_ap, "等待不会自动跳过回合或推进失败计量")
	r.hand.assign(["tonic", "jab"])
	game.select_or_play_card(0)
	check(r.hand.size() == 1, "远离Boss时可通过正式界面使用补剂")
	game.select_or_play_card(0)
	check(game.selected_card == 0, "远离Boss时可选择放置牌")
	var neighbor: Vector2i = r.graph[r.player_pos][0]
	game.world_boss_click(neighbor)
	check(r.traps.has(neighbor) and r.hand.is_empty(), "远离Boss时可通过正式界面放置陷阱")
	waiting_ap = r.energy
	check(r.step_to(neighbor), "移动仍然使用大地图门图")
	check(r.energy == waiting_ap - int(r.move_cost), "大地图移动消耗当前回合AP")
	var end_round: int = r.round_number
	var end_broadcast: int = r.broadcast
	game.end_combat_turn()
	check(r.round_number == end_round + 1 and r.broadcast >= end_broadcast + 2, "点击结束回合才结算Boss和播出")
	game._refresh_world_boss()

func _test_ritual(game) -> void:
	game.go_home()
	game.start_host_preview()
	game.begin_boss_combat()
	var r = game.combat
	var guard := 0
	while r.outcome == "" and guard < 120:
		guard += 1
		# Let movement animation finish without advancing the combat turn.
		r.tick(0.35)
		if r.manhattan(r.player_pos, r.enemy_pos) <= 3:
			var guard_index: int = r.hand.find("guard")
			if guard_index >= 0:
				for guard_target: Vector2i in r.graph.get(r.player_pos, []):
					if guard_target != r.enemy_pos and r.use_card(guard_index, guard_target):
						break
		if r.dismantle():
			continue
		var best: Array[Vector2i] = []
		for node: Vector2i in r.anchors:
			if r.anchors[node] <= 0:
				continue
			var path: Array[Vector2i] = r._find_path(r.player_pos, node)
			if path.size() > 1 and (best.is_empty() or path.size() < best.size()):
				best = path
		if best.size() > 1 and r.energy >= 1 and r.step_to(best[1]):
			continue
		r.pulse()
	print("WORLD_RITUAL: rounds=%d hp=%d anchors=%d clock=%d outcome=%s" % [r.round_number, r.player_hp, r.cleared(), r.broadcast, r.outcome])
	check(r.outcome == "victory" and r.cleared() == 4, "actual cross-room moves and normal AP can complete ritual")
	game._refresh_world_boss()

func _test_boss_pursuit_and_attack(game) -> void:
	game.go_home()
	game.start_host_preview()
	game.begin_boss_combat()
	var r = game.combat
	var boss = r.enemy_by_id(r.enemy_order[0])
	check(boss.action_points >= 4, "Boss普通行动应有4点AP同时追击和攻击")
	var adjacent: Vector2i = r.graph[r.enemy_pos][0]
	r.player_pos = adjacent
	r.round_number = 2
	r.host_fight.prepare(r)
	var hp_before: int = r.player_hp
	r.pulse()
	check(r.player_hp < hp_before, "玩家停在Boss攻击范围内时Boss应主动攻击")
	game.go_home()
	game.start_host_preview()
	game.begin_boss_combat()
	r = game.combat
	boss = r.enemy_by_id(r.enemy_order[0])
	var old_target: Vector2i = r.player_pos
	for candidate: Vector2i in r.graph.keys():
		if r._find_path(r.enemy_pos, candidate).size() >= 4:
			old_target = candidate
			break
	r.player_pos = old_target
	r.round_number = 2
	r.host_fight.prepare(r)
	r.player_pos = r.graph[r.enemy_pos][0]
	hp_before = r.player_hp
	var events: Array[Dictionary] = r.enemy_turn()
	var replanned_attack := false
	for event: Dictionary in events:
		if str(event.get("kind", "")) == "attack":
			replanned_attack = true
			break
	check(replanned_attack and r.player_hp < hp_before, "普通追击应按敌方行动时的玩家位置重新寻路并攻击")
	# Replanning must not resurrect a cancelled/weakened Boss state. These
	# flags are produced by player actions and survive until the next intended
	# player-turn reset.
	r.host_fight.cancelled = true
	r.host_fight.weakened = true
	r.player_pos = r.graph[r.enemy_pos][0]
	r.host_fight.prepare(r)
	r.host_fight.cancelled = true
	r.host_fight.weakened = true
	r.enemy_turn()
	check(r.host_fight.cancelled and r.host_fight.weakened, "Boss普通追击重算路径时应保留取消与削弱状态")
	game._refresh_world_boss()

func _test_graph_doors() -> void:
	var rooms = preload("res://scripts/room_rules.gd").new()
	for x in range(6):
		rooms.placed[Vector2i(x, 0)] = {"instance_id": str(x), "name": str(x), "doors": [false, x != 4, false, true], "revealed": true, "completed": true}
	var r = preload("res://scripts/overworld_boss_rules.gd").new()
	r.initialize(rooms, Vector2i.ZERO, {}, {}, [], 1, {"player_hp": 6}, [])
	check(not r.graph[Vector2i(4, 0)].has(Vector2i(5, 0)), "touching rooms without matching doors are not connected")

func _test_kill(game) -> void:
	game.go_home()
	game.start_host_preview()
	game.begin_boss_combat()
	var r = game.combat
	var guard := 0
	var played_count := 0
	while r.outcome == "" and guard < 150:
		guard += 1
		var played := false
		for id in ["focus", "tonic", "flare", "jab", "keepsake"]:
			var index: int = r.hand.find(id)
			if index >= 0 and r.use_card(index, r.enemy_pos if id in ["flare", "jab"] else r.player_pos):
				played = true
				played_count += 1
				break
		if played:
			continue
		var path: Array[Vector2i] = r._find_path(r.player_pos, r.enemy_pos)
		if path.size() > 2 and r.step_to(path[1]):
			continue
		r.pulse()
	print("WORLD_KILL: rounds=%d hp=%d boss_hp=%d clock=%d outcome=%s cards=%d" % [r.round_number, r.player_hp, r.enemy_hp, r.broadcast, r.outcome, played_count])
	check(r.outcome == "victory" and r.enemy_hp <= 0 and played_count > 0, "real map movement and starter cards can defeat Boss")
	game._refresh_world_boss()

func _test_failures(game) -> void:
	game.go_home()
	game.start_host_preview()
	game.begin_boss_combat()
	game.combat.broadcast = 17
	game.combat.pulse()
	check(game.combat.outcome == "defeat" and game.combat.finish_reason == "broadcast", "broadcast overflow fails the world finale")
	game._refresh_world_boss()
	game.world_boss_action("end")
	check(game.phase == "ending" and game.boss_finish_reason == "broadcast", "broadcast failure reaches matching ending")
	game.go_home()
	game.start_host_preview()
	game.begin_boss_combat()
	game.combat._apply_player_hit(game.combat.enemy_by_id(game.combat.enemy_order[0]), "melee", 99)
	game.combat.after_action()
	check(game.combat.finish_reason == "hp", "lethal damage remains distinct from broadcast")
	game._refresh_world_boss()
	game.world_boss_action("end")
	check(game.phase == "ending" and game.boss_finish_reason == "hp", "HP failure reaches matching ending")
