extends SceneTree

# 阶段 B：旧房间数据与旧单敌人行为的加载边界兼容回归。
# 旧键 room.enemy / arena.enemy 必须继续工作，并在加载边界转换为
# 长度 1 的标准敌人数组；旧字段不丢失。

const WebContentAdapter = preload("res://scripts/web_content_adapter.gd")
const CombatEnemyRoster = preload("res://scripts/combat_enemy_roster.gd")

const FLAG := "CHANNEL_MULTI_ENEMY_LEGACY"

var failures: Array[String] = []


func _init() -> void:
	_test_adapter_rooms_carry_standard_enemies()
	_test_legacy_rules_setup_unchanged()
	if failures.is_empty():
		print("%s: PASS old-format standard-array single-enemy-keyed" % FLAG)
		quit(0)
	else:
		for failure in failures:
			push_error("%s: %s" % [FLAG, failure])
		print("%s: FAIL count=%d" % [FLAG, failures.size()])
		quit(1)


func _test_adapter_rooms_carry_standard_enemies() -> void:
	var content: Dictionary = WebContentAdapter.new().build_content(21)
	_check(not content.is_empty(), "adapter must build content")
	var rooms: Array = content.get("rooms", [])
	_check(rooms.size() > 0, "adapter must expose rooms")
	var combat_rooms := 0
	for raw_room in rooms:
		var room: Dictionary = raw_room
		var enemies: Array = room.get("enemies", [])
		_check(enemies.size() == 1, "room %s must carry exactly 1 standard enemy, got %d" % [str(room.get("id")), enemies.size()])
		if enemies.size() != 1:
			continue
		combat_rooms += 1
		var spec: Dictionary = enemies[0]
		var legacy: Dictionary = room.get("enemy", {})
		_check(str(spec.get("id")) == str(legacy.get("id")), "room %s standard id must match legacy enemy id" % str(room.get("id")))
		var arena: Dictionary = room.get("arena", {})
		var arena_spawn: Array = arena.get("enemy", [])
		var spawn: Array = spec.get("spawn", [])
		_check(spawn.size() == 2 and arena_spawn.size() == 2 and spawn[0] == arena_spawn[0] and spawn[1] == arena_spawn[1], "room %s standard spawn must match arena.enemy" % str(room.get("id")))
		_check(int(spec.get("hp")) == int(legacy.get("hp")), "room %s standard hp must match legacy hp" % str(room.get("id")))
		_check(int(spec.get("damage")) == int(legacy.get("damage")), "room %s standard damage must match legacy damage" % str(room.get("id")))
		_check(legacy.has("toughness") and legacy.has("action_points") and legacy.has("attack_cost"), "room %s legacy enemy keys must remain" % str(room.get("id")))
	_check(combat_rooms > 0, "adapter must expose at least one room")


func _test_legacy_rules_setup_unchanged() -> void:
	# 旧调用方直接把 room.enemy 传给 CombatRules.setup 的路径保持原样：
	# 标准化不改变旧字段本身，仅新增标准数组。
	var room := {"id": "direct", "enemy": {"id": "direct_enemy", "name": "直连剪影", "hp": 5, "damage": 2, "toughness": 3, "action_points": 3, "attack_cost": 2}}
	var arena := {"cols": 5, "rows": 3, "player": [0, 1], "enemy": [4, 1], "walls": [], "heights": {}, "portals": []}
	var result: Dictionary = CombatEnemyRoster.normalize(room, arena)
	_check(bool(result["ok"]), "direct legacy normalize must succeed")
	var enemy: Dictionary = room["enemy"]
	_check(enemy["hp"] == 5 and enemy["damage"] == 2, "legacy enemy dict must not be mutated by normalization")
	var spec: Dictionary = (result["enemies"] as Array)[0]
	_check(int(spec["hp"]) == 5 and int(spec["damage"]) == 2 and int(spec["toughness"]) == 3, "legacy values must flow into standard spec")
	var states: Array = CombatEnemyRoster.build_states(result["enemies"])
	_check(states.size() == 1 and (states[0] as RefCounted).get("pos") == Vector2i(4, 1), "legacy state must spawn at arena.enemy")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
