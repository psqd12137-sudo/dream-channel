extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var CombatRules = load("res://scripts/combat_rules.gd")
	var WebContentAdapter = load("res://scripts/web_content_adapter.gd")
	var content: Dictionary = WebContentAdapter.new().build_content(101)
	var combat = CombatRules.new()
	combat.setup({"cols": 5, "rows": 1, "player": [0, 0], "enemy": [1, 0], "walls": [], "heights": {}, "portals": []}, {"name": "测试敌人", "hp": 10, "damage": 20, "toughness": 1, "action_points": 1}, content.cards, ["guard"], 1, {"player_hp": 6, "base_speed": 3, "base_energy": 5}, [])
	var state = combat.enemy_by_id(combat.enemy_order[0])
	combat._apply_player_hit(state, "melee")
	_check(combat.actual_hp_lost_total == 6, "致命过量伤害只能累计玩家实际拥有的生命")
	combat.player_hp = 4
	combat.apply_player_self_damage(1)
	_check(combat.actual_hp_lost_total == 7, "玩家自损也必须进入实际损血累计")
	combat.player_hp = 6
	_check(combat.actual_hp_lost_total == 7, "治疗或直接恢复生命不能冲减累计损血")

	var ledger = load("res://scripts/dream_room_ledger.gd").new()
	ledger.visit({"instance_id": "start@0,0", "room_id": "foyer", "visited": true})
	ledger.visit({"instance_id": "unvisited", "room_id": "kitchen", "visited": false})
	_check(ledger.candidates([]).is_empty(), "玄关与未访问房间不能进入候选池")

	ledger.visit({"instance_id": "room-a@2,3", "room_id": "kitchen", "name": "厨房", "kind": "combat", "encounter_tier": "beat", "visited": true, "room_size": 3})
	ledger.visit({"instance_id": "room-a@2,3", "room_id": "kitchen", "name": "厨房", "kind": "combat", "encounter_tier": "beat", "visited": true, "room_size": 3})
	ledger.record_hp_loss("room-a@2,3", 3)
	ledger.record_hp_loss("room-a@2,3", -2)
	_check(ledger.candidates([]).size() == 1, "同一实例重复 visit 只能生成一个候选")
	_check(int(ledger.candidates([])[0].get("hp_lost", 0)) == 3, "负数损血与治疗不能抹去已记录损血")
	_check(ledger.candidates(["room-a@2,3"]).is_empty(), "已选实例必须从候选池排除")

	ledger.visit({"instance_id": "room-a@2,4", "room_id": "hall", "visited": true})
	ledger.record_hp_loss("room-a@2,4", 99)
	var candidates: Array[Dictionary] = ledger.candidates([])
	_check(candidates.size() == 2, "不同 instance_id 的房间应分别进入候选池")
	_check(str(candidates[0].get("instance_id", "")) == "room-a@2,4", "候选按受伤经历从高到低排序")

	var restored = load("res://scripts/dream_room_ledger.gd").new()
	_check(restored.restore(JSON.parse_string(JSON.stringify(ledger.snapshot()))), "账本快照应可恢复")
	_check(restored.candidates([]).size() == 2 and int(restored.candidates([])[0].get("hp_lost", 0)) == 99, "恢复后应保留房间经历与损血")
	_check(not restored.restore({"version": 999, "records": []}), "未知账本版本必须拒绝载入")

	# Sample defeat is an accident that completes the room once; formal defeat
	# keeps the original terminal behavior.
	var game = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	game.start_solo_stage_trial(20260910)
	game.choose_omen(0)
	var sample_room: Dictionary = _find_room(game, "living")
	game.room_rules.placed[Vector2i(1, 0)] = sample_room.duplicate(true)
	game.room_rules.placed[Vector2i(1, 0)]["instance_id"] = "sample_living@1,0"
	game.room_rules.placed[Vector2i(1, 0)]["visited"] = true
	game.room_rules.placed[Vector2i(1, 0)]["completed"] = false
	game.current_room_pos = Vector2i(1, 0)
	game.start_combat(game.room_rules.placed[Vector2i(1, 0)])
	game.combat.outcome = "defeat"
	game.combat.player_hp = 0
	game.combat.actual_hp_lost_total = 6
	game.return_from_combat()
	var sample_progress := int(game.run_progress)
	_check(game.phase == "explore" and game.player_hp == 3, "样片普通战败应恢复到最大生命50%并继续探索")
	_check(bool(game.room_rules.placed[Vector2i(1, 0)].get("completed", false)), "样片战败应一次完成房间")
	game.return_from_combat()
	_check(int(game.run_progress) == sample_progress, "样片战败后的房间不能重复刷完成进度")
	game._clear_run_save()
	game.go_home()

	game.start_new_run(false, 20260911)
	game.choose_omen(0)
	game.room_rules.placed[Vector2i(1, 0)] = sample_room.duplicate(true)
	game.room_rules.placed[Vector2i(1, 0)]["instance_id"] = "formal_living@1,0"
	game.current_room_pos = Vector2i(1, 0)
	game.start_combat(game.room_rules.placed[Vector2i(1, 0)])
	game.combat.outcome = "defeat"
	game.return_from_combat()
	_check(game.phase == "home" and not game.has_saved_run(), "正式模式普通战败应保持原清档返回行为")
	game.queue_free()
	await process_frame

	if failures.is_empty():
		print("DREAM_ROOM_LEDGER: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error("DREAM_ROOM_LEDGER: " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _find_room(game: Node, wanted_id: String) -> Dictionary:
	for room: Dictionary in game.room_catalog:
		if str(room.get("id", "")) == wanted_id:
			return room
	return {}
