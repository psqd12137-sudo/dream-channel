extends RefCounted

const CombatEnemyRoster = preload("res://scripts/combat_enemy_roster.gd")
const EnemyTurnScheduler = preload("res://scripts/enemy_turn_scheduler.gd")
const EnemyAISquadBlackboard = preload("res://scripts/enemy_ai_blackboard.gd")

const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const INVALID_CELL := Vector2i(-999, -999)
const LAST_SEEN_MEMORY_TURNS := 5

var cols := 5
var rows := 3
var walls: Dictionary = {}
var heights: Dictionary = {}
var portals: Dictionary = {}
var traps: Dictionary = {}

var player_pos := Vector2i.ZERO
var player_hp := 6
var player_block := 0
var energy := 3
var energy_roll := 1
var energy_rolls: Array[int] = []
var base_speed := 3
var base_energy := 5
var turn_energy_max := 5
var hand_size := 4
var move_cost := 1
var hostile_pass_cost := 1
var dice_faces: Array = []
var energy_bonus := 0
var placement_discount := 0
var ready_effect: Dictionary = {}
var retain_slots := 0
var retain_this_turn := 0
var damage_bonus := 0
var free_draw_bonus := 0
var free_draw_used := false
var pending_player_turn := false
var first_smash_bonus := 0
var first_smash_used := false
var decoy_pos := Vector2i(-1, -1)
var player_exposed := false

# 多敌人权威状态（multi-enemy refactor plan 3.1）：
# enemies 为 enemy_id -> CombatEnemyState；enemy_order 为确定性行动顺序。
# 下方 enemy_* 旧字段是路由到主敌人（enemy_order[0]）的兼容代理，
# 仅用于尚未迁移到 ID 契约的表现层与旧测试；阶段 G 删除。
var enemies: Dictionary = {}
var enemy_order: Array[String] = []
var setup_errors: Array[String] = []
var _acting_enemy: CombatEnemyState = null
var _ai_blackboard: EnemyAISquadBlackboard = null
var _fallback_enemy := CombatEnemyState.new()

var cards: Dictionary = {}
var deck: Array[String] = []
var discard: Array[String] = []
var hand: Array[String] = []
var last_card_events: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var round_number := 1
var outcome := ""
var event_log: Array[String] = []


func living_enemy_ids() -> Array[String]:
	var result: Array[String] = []
	for enemy_id in enemy_order:
		var state: CombatEnemyState = enemies.get(enemy_id)
		if state != null and state.alive():
			result.append(enemy_id)
	return result


func enemy_by_id(enemy_id: String) -> CombatEnemyState:
	return enemies.get(enemy_id)


func enemy_at(cell: Vector2i, living_only := true) -> CombatEnemyState:
	for enemy_id in enemy_order:
		var state: CombatEnemyState = enemies.get(enemy_id)
		if state == null or (living_only and not state.alive()):
			continue
		if state.pos == cell:
			return state
	return null


func occupied_enemy_cells(except_enemy_id := "") -> Dictionary:
	var result := {}
	for enemy_id in enemy_order:
		if str(enemy_id) == except_enemy_id:
			continue
		var state: CombatEnemyState = enemies.get(enemy_id)
		if state == null or not state.alive():
			continue
		result[state.pos] = enemy_id
	return result


func all_enemies_defeated() -> bool:
	return living_enemy_ids().is_empty()


func _primary_enemy_state() -> CombatEnemyState:
	if not enemy_order.is_empty() and enemies.has(enemy_order[0]):
		return enemies[enemy_order[0]]
	return _fallback_enemy


func _focus_enemy_state() -> CombatEnemyState:
	for enemy_id in enemy_order:
		var state: CombatEnemyState = enemies[enemy_id]
		if state.alive():
			return state
	return _primary_enemy_state()


func _iter_enemy_states() -> Array:
	var result: Array = []
	for enemy_id in enemy_order:
		result.append(enemies[enemy_id])
	return result


# --- 兼容代理属性：路由到主敌人，避免第二份状态（阶段 G 移除） ---

var enemy_pos: Vector2i:
	get: return _primary_enemy_state().pos
	set(value): _primary_enemy_state().pos = value

var enemy_hp: int:
	get: return _primary_enemy_state().hp
	set(value): _primary_enemy_state().hp = value

var enemy_max_hp: int:
	get: return _primary_enemy_state().max_hp
	set(value): _primary_enemy_state().max_hp = value

var enemy_toughness: int:
	get: return _primary_enemy_state().toughness
	set(value): _primary_enemy_state().toughness = value

var enemy_max_toughness: int:
	get: return _primary_enemy_state().max_toughness
	set(value): _primary_enemy_state().max_toughness = value

var enemy_damage: int:
	get: return _primary_enemy_state().damage
	set(value): _primary_enemy_state().damage = value

var enemy_action_points: int:
	get: return _primary_enemy_state().action_points
	set(value): _primary_enemy_state().action_points = value

var enemy_attack_cost: int:
	get: return _primary_enemy_state().attack_cost
	set(value): _primary_enemy_state().attack_cost = value

var enemy_blind_turns: int:
	get: return _primary_enemy_state().blind_turns
	set(value): _primary_enemy_state().blind_turns = value

var enemy_name: String:
	get: return _primary_enemy_state().name
	set(value): _primary_enemy_state().name = value

var enemy_tier: int:
	get: return _primary_enemy_state().tier
	set(value): _primary_enemy_state().tier = value

var ambush_active: bool:
	get: return _primary_enemy_state().ambush_active
	set(value): _primary_enemy_state().ambush_active = value

var ambush_idle_turns: int:
	get: return _primary_enemy_state().ambush_idle_turns
	set(value): _primary_enemy_state().ambush_idle_turns = value

var enemy_revealed: bool:
	get: return _primary_enemy_state().revealed
	set(value): _primary_enemy_state().revealed = value

var player_sees_enemy: bool:
	get: return _primary_enemy_state().player_sees_enemy
	set(value): _primary_enemy_state().player_sees_enemy = value

var enemy_sees_player: bool:
	get: return _primary_enemy_state().sees_player
	set(value): _primary_enemy_state().sees_player = value

var ambush_note: String:
	get: return _primary_enemy_state().ambush_note
	set(value): _primary_enemy_state().ambush_note = value

var last_seen: Vector2i:
	get: return _primary_enemy_state().last_seen
	set(value): _primary_enemy_state().last_seen = value

var last_seen_age: int:
	get: return _primary_enemy_state().last_seen_age
	set(value): _primary_enemy_state().last_seen_age = value

var patrol_goal: Vector2i:
	get: return _primary_enemy_state().patrol_goal
	set(value): _primary_enemy_state().patrol_goal = value

var enemy_archetype: String:
	get: return _primary_enemy_state().archetype
	set(value): _primary_enemy_state().archetype = value

var enemy_archetype_label: String:
	get: return _primary_enemy_state().archetype_label
	set(value): _primary_enemy_state().archetype_label = value

var enemy_archetype_desc: String:
	get: return _primary_enemy_state().archetype_desc
	set(value): _primary_enemy_state().archetype_desc = value

var enemy_traits: Array[String]:
	get: return _primary_enemy_state().traits
	set(value): _primary_enemy_state().traits = value

var enemy_trait_labels: Dictionary:
	get: return _primary_enemy_state().trait_labels
	set(value): _primary_enemy_state().trait_labels = value

var enemy_broken: bool:
	get: return _primary_enemy_state().broken
	set(value): _primary_enemy_state().broken = value

var execute_bonus_pending: bool:
	get: return _primary_enemy_state().execute_bonus_pending
	set(value): _primary_enemy_state().execute_bonus_pending = value

var crush_bonus_pending: bool:
	get: return _primary_enemy_state().crush_bonus_pending
	set(value): _primary_enemy_state().crush_bonus_pending = value

var stagger_pending: bool:
	get: return _primary_enemy_state().stagger_pending
	set(value): _primary_enemy_state().stagger_pending = value

var enemy_just_portaled: bool:
	get: return _primary_enemy_state().just_portaled
	set(value): _primary_enemy_state().just_portaled = value

var beam_pending_cells: Array[Vector2i]:
	get: return _primary_enemy_state().beam_pending_cells
	set(value): _primary_enemy_state().beam_pending_cells = value

var beam_pending_damage: int:
	get: return _primary_enemy_state().beam_pending_damage
	set(value): _primary_enemy_state().beam_pending_damage = value


func setup(arena: Dictionary, enemy: Variant, card_defs: Dictionary, starter: Array, seed: int, run_rules: Dictionary = {}, active_relics: Array = []) -> void:
	cols = int(arena.get("cols", 5))
	rows = int(arena.get("rows", 3))
	walls.clear()
	heights.clear()
	portals.clear()
	traps.clear()
	for raw in arena.get("walls", []):
		walls[_parse_pos(str(raw))] = true
	for raw_key in arena.get("heights", {}).keys():
		heights[_parse_pos(str(raw_key))] = int(arena["heights"][raw_key])
	for pair in arena.get("portals", []):
		if pair.size() == 2:
			var a := _parse_pos(str(pair[0]))
			var b := _parse_pos(str(pair[1]))
			portals[a] = b
			portals[b] = a
	player_pos = _array_pos(arena.get("player", [0, 1]))
	player_hp = int(run_rules.get("player_hp", 6))
	player_block = 0
	base_speed = int(run_rules.get("base_speed", 3))
	base_energy = maxi(1, int(run_rules.get("base_energy", base_speed + 2)))
	hand_size = int(run_rules.get("hand_size", 4))
	move_cost = int(run_rules.get("move_cost", 1))
	hostile_pass_cost = int(run_rules.get("hostile_pass_cost", 1))
	# Kept empty as a compatibility field for the archived 2D prototype. The
	# production 3D rules use a fixed action-point budget and never roll speed dice.
	dice_faces.clear()
	energy_bonus = 1 if "omen_signal" in active_relics else 0
	damage_bonus = 1 if "omen_salt" in active_relics else 0
	free_draw_bonus = 1 if "omen_lens" in active_relics else 0
	first_smash_bonus = 2 if "omen_flint" in active_relics else 0
	energy = base_energy + energy_bonus
	energy_roll = base_energy
	turn_energy_max = energy
	placement_discount = 0
	ready_effect.clear()
	retain_slots = 0
	retain_this_turn = 0
	free_draw_used = false
	first_smash_used = false
	decoy_pos = Vector2i(-1, -1)
	# 敌人集合：接受标准数组或旧单敌人字典，统一在加载边界标准化。
	enemies.clear()
	enemy_order.clear()
	setup_errors.clear()
	var roster_room := {}
	if enemy is Array:
		roster_room["enemies"] = enemy
	else:
		roster_room["enemy"] = enemy
	var roster := CombatEnemyRoster.normalize(roster_room, arena)
	for roster_error in roster.get("errors", []):
		setup_errors.append(str(roster_error))
		push_error("CombatRules setup: %s" % roster_error)
	for raw_state in CombatEnemyRoster.build_states(roster["enemies"]):
		var state: CombatEnemyState = raw_state
		if "omen_bell" in active_relics:
			state.ambush_active = false
			state.revealed = true
			state.player_sees_enemy = true
		state.ambush_note = str(arena.get("spawnNote", ""))
		enemies[state.id] = state
		enemy_order.append(state.id)
	cards = card_defs.duplicate(true)
	deck.clear()
	for card_id in starter:
		deck.append(str(card_id))
	discard.clear()
	hand.clear()
	rng.seed = seed
	_refresh_vision(false)
	_shuffle(deck)
	round_number = 1
	outcome = ""
	event_log.clear()
	event_log.append("CombatStarted seed=%d" % seed)
	var primary := _primary_enemy_state()
	if primary.ambush_active:
		event_log.append("AmbushHidden note=%s" % primary.ambush_note)
	elif bool(arena.get("ambush", false)):
		event_log.append("AmbushRevealedByOmen")
	_start_player_turn()
	if "omen_decoy" in active_relics and cards.has("decoy"):
		if hand.size() >= hand_size:
			deck.append(hand.pop_back())
		hand.append("decoy")


func move_player(target: Vector2i) -> bool:
	if not can_move_player(target):
		return false
	var cost := player_move_cost(target)
	player_pos = target
	energy -= cost
	_refresh_enemy_visibility()
	event_log.append("PlayerMoved pos=%s cost=%d shared=%s energy=%d" % [player_pos, cost, str(enemy_at(target, false) != null), energy])
	return true


func can_move_player(target: Vector2i) -> bool:
	return outcome == "" and energy >= player_move_cost(target) and is_walkable(target) and target != decoy_pos and manhattan(player_pos, target) == 1


func player_path_to(target: Vector2i) -> Array[Vector2i]:
	var empty_path: Array[Vector2i] = []
	if outcome != "" or target == player_pos or not is_walkable(target) or target == decoy_pos:
		if target == player_pos:
			empty_path.append(player_pos)
		return empty_path
	var blocked := occupied_enemy_cells()
	# 允许把目标本身作为终点，避免“点敌人格”永远被自己的阻挡集合拒绝。
	blocked.erase(target)
	var path := _find_path(player_pos, target, blocked, false)
	if path.size() < 2 or path.back() != target:
		return empty_path
	return path


func player_path_cost(path: Array[Vector2i]) -> int:
	var total := 0
	for index in range(1, path.size()):
		total += player_move_cost(path[index])
	return total


func player_reachable_cells() -> Array:
	var cells: Array = []
	if outcome != "":
		return cells
	for y in range(rows):
		for x in range(cols):
			var target := Vector2i(x, y)
			var path := player_path_to(target)
			if path.size() >= 2 and player_path_cost(path) <= energy:
				cells.append(target)
	return cells


func player_move_cost(target: Vector2i) -> int:
	return move_cost + (hostile_pass_cost if enemy_at(target) != null else 0)


func player_on_portal() -> bool:
	return portals.has(player_pos)


func player_portal_destination() -> Vector2i:
	return portals.get(player_pos, INVALID_CELL)


func can_use_player_portal() -> bool:
	var destination := player_portal_destination()
	return outcome == "" and destination != INVALID_CELL and energy >= move_cost and is_walkable(destination)


func use_player_portal() -> bool:
	if not can_use_player_portal():
		return false
	var entrance := player_pos
	player_pos = player_portal_destination()
	energy -= move_cost
	event_log.append("PlayerUsedPortal from=%s to=%s energy=%d" % [entrance, player_pos, energy])
	_refresh_enemy_visibility()
	return true


func can_target_place_card(hand_index: int, target: Vector2i) -> bool:
	if outcome != "" or hand_index < 0 or hand_index >= hand.size():
		return false
	var card: Dictionary = cards.get(hand[hand_index], {})
	if str(card.get("type", "")) != "place" or energy < card_cost(card):
		return false
	if not is_walkable(target) or target == player_pos:
		return false
	var adjacent := manhattan(player_pos, target) == 1
	var smash_state := enemy_at(target)
	var smash := smash_state != null and _has_line_of_sight(player_pos, smash_state.pos)
	if not adjacent and not smash:
		return false
	var place_data: Dictionary = card.get("place", {})
	if bool(place_data.get("decoy", false)):
		return adjacent and not smash and not traps.has(target)
	if not smash and (traps.has(target) or target == decoy_pos):
		return false
	return true


func play_card(hand_index: int, target: Vector2i, enemy_id: String = "") -> bool:
	if outcome != "" or hand_index < 0 or hand_index >= hand.size():
		return false
	var card_id := hand[hand_index]
	if not cards.has(card_id):
		return false
	var card: Dictionary = cards[card_id]
	var cost := card_cost(card)
	if energy < cost:
		return false
	var card_type := str(card.get("type", ""))
	var target_state := _resolve_single_enemy(card, enemy_id)
	if card_target_type(card) == "single_enemy" and target_state == null:
		# 多敌人时单体牌必须显式选中合法敌人，否则不消耗。
		return false
	last_card_events.clear()
	var accepted := false
	if card_type == "place":
		accepted = _play_place(card, target)
	elif card.has("allEnemies"):
		accepted = _play_all_enemies(card_id, card)
	elif card.has("area"):
		accepted = _play_area(card_id, card, target)
	elif card.has("randomEnemy"):
		accepted = _play_random_enemy(card_id, card)
	elif bool(card.get("shove", false)):
		accepted = _play_shove(bool(card.get("preferPortal", false)), int(card.get("drawOnPortal", 0)), target_state)
	elif bool(card.get("climbToHigher", false)):
		accepted = _play_climb()
	elif bool(card.get("topple", false)):
		accepted = _play_topple(target_state)
	elif card.has("puppetBang"):
		accepted = _play_puppet_bang(card.get("puppetBang", {}), target_state)
	elif card.has("saltLash"):
		accepted = _play_salt_lash(card.get("saltLash", {}), target_state)
	elif card.has("ifBlinded") or card.has("elseBlind"):
		accepted = _play_blind_followup(card, target_state)
	elif card.has("drainTough"):
		accepted = _play_rupture(card, target_state)
	elif card.has("gain_block"):
		player_block += int(card.get("gain_block", 0))
		accepted = true
	elif card.has("gainBlock"):
		player_block += int(card.get("gainBlock", 0))
		accepted = true
	elif card_type == "medicine" or card.has("gainEnergy"):
		energy += int(card.get("gainEnergy", 0))
		turn_energy_max = maxi(turn_energy_max, energy)
		player_hp -= int(card.get("selfDamage", 0))
		accepted = true
	elif card_type == "ready":
		ready_effect = (card.get("ready", {}) as Dictionary).duplicate(true)
		ready_effect["card_id"] = card_id
		ready_effect["name"] = str(card.get("name", card_id))
		accepted = true
	elif card.has("grantRetain"):
		retain_slots = maxi(retain_slots, int(card.get("grantRetain", 0)))
		accepted = true
	elif card.has("retainThisTurn"):
		retain_this_turn += int(card.get("retainThisTurn", 0))
		accepted = true
	elif card.has("discountNext"):
		placement_discount += int(card.get("discountNext", 0))
		accepted = true
	if not accepted:
		return false
	for enemy_state in _iter_enemy_states():
		if target == enemy_state.pos or _has_line_of_sight(player_pos, enemy_state.pos):
			reveal_enemy("card", enemy_state)
	energy -= cost
	if card_type == "place" and placement_discount > 0:
		placement_discount = 0
	hand.remove_at(hand_index)
	if not bool(card.get("exhaust", false)):
		discard.append(card_id)
	if cost == 0 and free_draw_bonus > 0 and not free_draw_used:
		free_draw_used = true
		_draw_cards(free_draw_bonus)
	event_log.append("CardPlayed id=%s energy=%d" % [card_id, energy])
	if player_hp <= 0:
		outcome = "defeat"
		event_log.append("CombatEnded outcome=defeat")
	return true


func card_cost(card: Dictionary) -> int:
	var result := int(card.get("cost", 0))
	if str(card.get("type", "")) == "place":
		result = maxi(0, result - placement_discount)
	return result


# 卡牌目标类型（multi-enemy refactor plan 3.3）：
# self / cell / single_enemy / all_enemies / area / random_enemy。
func card_target_type(card: Dictionary) -> String:
	var declared := str(card.get("target", ""))
	if declared != "":
		return declared
	if card.has("allEnemies"):
		return "all_enemies"
	if card.has("area"):
		return "area"
	if card.has("randomEnemy"):
		return "random_enemy"
	if str(card.get("type", "")) == "place":
		return "cell"
	if bool(card.get("shove", false)) or bool(card.get("topple", false)) or card.has("puppetBang") or card.has("saltLash") or card.has("ifBlinded") or card.has("elseBlind") or card.has("drainTough"):
		return "single_enemy"
	return "self"


# 单体牌目标解析：显式 ID 优先；恰有一个存活敌人时自动指向它；
# 存在多个合法目标时必须由调用方选择，返回 null 表示不可打出。
func resolve_single_enemy(card: Dictionary, enemy_id: String) -> CombatEnemyState:
	return _resolve_single_enemy(card, enemy_id)


func _resolve_single_enemy(card: Dictionary, enemy_id: String) -> CombatEnemyState:
	if card_target_type(card) != "single_enemy":
		return null
	if enemy_id != "":
		var state := enemy_by_id(enemy_id)
		return state if state != null and state.alive() else null
	var living := living_enemy_ids()
	if living.size() == 1:
		return enemies[living[0]]
	return null


func _play_all_enemies(card_id: String, card: Dictionary) -> bool:
	var effect: Dictionary = card.get("allEnemies", {})
	var source := "card:%s" % card_id
	for enemy_id in living_enemy_ids().duplicate():
		var state: CombatEnemyState = enemies[enemy_id]
		var dealt := _apply_enemy_damage(state, int(effect.get("damage", 0)), int(effect.get("tough", 0)), source)
		if bool(effect.get("blind", false)):
			_apply_blind(state, {"blind": true, "blind_turns": int(effect.get("blindTurns", 1))})
		last_card_events.append({"kind": "enemy_damaged", "target_enemy_id": enemy_id, "damage": dealt, "source": source})
	return true


func _play_area(card_id: String, card: Dictionary, center: Vector2i) -> bool:
	var effect: Dictionary = card.get("area", {})
	var radius := int(effect.get("radius", 1))
	var source := "card:%s" % card_id
	for enemy_id in living_enemy_ids().duplicate():
		var state: CombatEnemyState = enemies[enemy_id]
		if absi(state.pos.x - center.x) <= radius and absi(state.pos.y - center.y) <= radius:
			var dealt := _apply_enemy_damage(state, int(effect.get("damage", 0)), int(effect.get("tough", 0)), source)
			if bool(effect.get("blind", false)):
				_apply_blind(state, {"blind": true, "blind_turns": int(effect.get("blindTurns", 1))})
			last_card_events.append({"kind": "enemy_damaged", "target_enemy_id": enemy_id, "damage": dealt, "source": source})
	return true


func _play_random_enemy(card_id: String, card: Dictionary) -> bool:
	var effect: Dictionary = card.get("randomEnemy", {})
	var living := living_enemy_ids()
	if living.is_empty():
		return false
	var picked: String = living[rng.randi_range(0, living.size() - 1)]
	var source := "card:%s" % card_id
	var dealt := _apply_enemy_damage(enemies[picked], int(effect.get("damage", 0)), int(effect.get("tough", 0)), source)
	last_card_events.append({"kind": "enemy_damaged", "target_enemy_id": picked, "damage": dealt, "source": source})
	return true


func preview_intent(enemy_id := "") -> Dictionary:
	# 保留单敌人接口，调用方迁移期间仍可继续读取旧契约。
	var intents := preview_all_intents()
	var requested_id := str(enemy_id)
	if requested_id.is_empty():
		var focused := _focus_enemy_state()
		requested_id = focused.id if focused != null else ""
	return intents.get(requested_id, _empty_enemy_intent(requested_id))


func preview_all_intents() -> Dictionary:
	# 意图快照必须在同一轮黑板规划中生成；渲染层不应逐敌调用
	# preview_intent，否则会重复规划全体敌人并反复改写 AI 调试字段。
	var intents: Dictionary = {}
	var blackboard := EnemyAISquadBlackboard.new()
	blackboard.begin_turn(self)
	for enemy_id in living_enemy_ids():
		var state: CombatEnemyState = enemy_by_id(enemy_id)
		if state == null:
			continue
		var result := _preview_intent_for(state)
		result["ai_role"] = state.ai_role
		result["ai_state"] = state.ai_state
		result["ai_reason"] = state.ai_reason
		result["tactical_goal"] = state.tactical_goal
		result["tactical_plan"] = blackboard.plan_for(enemy_id).duplicate(true)
		intents[enemy_id] = result
	return intents


func _empty_enemy_intent(enemy_id := "") -> Dictionary:
	return {
		"path": [],
		"move_cells": [],
		"threat_cells": [],
		"hurt": [],
		"impact_cells": [],
		"coverage_cells": [],
		"line_cells": [],
		"range_origin": INVALID_CELL,
		"attack_range": 0,
		"label": "观望",
		"detail": "",
		"type": "stall",
		"enemy_revealed": false,
		"sees_player": false,
		"attack_kind": "",
		"hits": 0,
		"pending": false,
		"enemy_id": enemy_id,
	}


func _preview_intent_for(state: CombatEnemyState) -> Dictionary:
	var result := _empty_enemy_intent(state.id)
	result["enemy_revealed"] = state.revealed
	result["sees_player"] = state.sees_player
	result["attack_range"] = state.attack_range
	if state.revealed:
		var move_cells := enemy_reachable_cells(state)
		result["move_cells"] = move_cells
		var turn_budget := _enemy_turn_budget(state)
		var attack_cost := _effective_attack_cost(state)
		var attack_move_cells: Array = []
		if turn_budget >= attack_cost:
			# 红色威胁区必须为攻击保留行动力，不能把完整移动力再叠一遍攻击距离。
			attack_move_cells = enemy_reachable_cells(state, turn_budget - attack_cost)
			result["threat_cells"] = enemy_threat_cells(state, attack_move_cells)
	if state.revealed and state.sees_player:
		result["range_origin"] = state.pos
		result["coverage_cells"] = _enemy_attack_coverage(state, state.pos, state.sees_player)
	if outcome != "":
		return result
	if not state.beam_pending_cells.is_empty():
		result["hurt"] = state.beam_pending_cells.duplicate()
		result["impact_cells"] = state.beam_pending_cells.duplicate()
		result["line_cells"] = state.beam_pending_cells.duplicate()
		result["range_origin"] = state.pos
		result["label"] = "激光即将发射 %d" % state.beam_pending_damage
		result["detail"] = "上一拍锁定的红色射线将在敌方回合落下；离开红格即可躲避。"
		result["type"] = "attack"
		result["attack_kind"] = "beam"
		result["hits"] = 1
		result["pending"] = true
		return result
	if state.blind_turns > 0:
		result["label"] = "闪瞎 / Blinded"
		result["detail"] = "强光致盲：无法锁定攻击，会继续搜索。"
		result["type"] = "search"
		return result
	if state.ambush_active and not state.sees_player and state.ambush_idle_turns < 1:
		result["label"] = "埋伏·窥探"
		result["detail"] = "它最多藏这一拍；下个敌方回合会离开出生点巡逻。"
		result["type"] = "ambush"
		return result
	if player_exposed and state.has_trait("faceShock") and state.sees_player:
		var exposed_plan := _enemy_attack_plan(state, state.pos, _enemy_turn_budget(state), true)
		if exposed_plan.is_empty():
			result["hurt"] = [player_pos]
			result["impact_cells"] = [player_pos]
			result["label"] = "突脸惊吓 1"
			result["detail"] = "你重新暴露在视线中；即使它够不着也会造成 1 点惊吓。"
			result["type"] = "attack"
			result["attack_kind"] = "faceShock"
			result["hits"] = 1
			return result
	var goal := _enemy_goal(state)
	if goal == INVALID_CELL:
		result["label"] = "搜寻出口"
		result["detail"] = "暂时没有可达巡逻点。"
		return result
	var remaining := _enemy_turn_budget(state)
	if has_decoy() and manhattan(state.pos, decoy_pos) == 1 and remaining >= _effective_attack_cost(state):
		result["hurt"] = [decoy_pos]
		result["impact_cells"] = [decoy_pos]
		result["label"] = "撕碎纸影"
		result["detail"] = "纸影会替你承受这一击；敌人若仍有行动力会继续行动。"
		result["type"] = "attack"
		result["attack_kind"] = "decoy"
		return result
	if state.sees_player and manhattan(state.pos, player_pos) <= 1 and remaining < _effective_attack_cost(state):
		result["label"] = "等待攻击窗口"
		result["detail"] = "已经贴近目标，但剩余行动力不足以发动攻击。"
		result["type"] = "stall"
		return result
	var plan := _enemy_attack_plan(state, state.pos, remaining, state.sees_player)
	if not plan.is_empty():
		return _intent_from_attack_plan(state, plan, result)
	var step := _choose_enemy_step(state, state.pos, goal)
	if step != INVALID_CELL and step != goal and remaining > 0:
		result["path"] = [step]
		var after_remaining := remaining - 1 - int((traps.get(step, {}) as Dictionary).get("slow", 0))
		var sees_after := _has_line_of_sight(step, player_pos) and state.blind_turns <= 0
		var after_plan := _enemy_attack_plan(state, step, after_remaining, sees_after)
		if not after_plan.is_empty():
			after_plan["origin"] = step
			result = _intent_from_attack_plan(state, after_plan, result)
			result["path"] = [step]
	if result["type"] != "attack":
		if state.sees_player:
			result["type"] = "chase"
			result["label"] = "追击 %d步" % result["path"].size()
			result["detail"] = "已建立视野；蓝色编号是本回合移动顺序。"
		elif state.last_seen != INVALID_CELL:
			result["type"] = "search"
			result["label"] = "搜索 %d步" % result["path"].size()
			result["detail"] = "失去视野，正在搜索最后目击点 %s。" % state.last_seen
		else:
			result["type"] = "patrol"
			result["label"] = "巡逻 %d步" % result["path"].size()
			result["detail"] = "尚未发现你；蓝色编号是它即将巡逻的路线。"
	if (result["path"] as Array).is_empty() and result["type"] != "attack":
		result["label"] = "重新选点"
		result["detail"] = "当前巡逻点已到达，下回合会选择新的搜查方向。"
	return result


func enemy_turn() -> Array[Dictionary]:
	_ai_blackboard = EnemyAISquadBlackboard.new()
	_ai_blackboard.begin_turn(self)
	var events: Array[Dictionary] = EnemyTurnScheduler.new(self).run_turn()
	_ai_blackboard = null
	return events


func preview_tactical_plan(enemy_id: String) -> Dictionary:
	var blackboard := EnemyAISquadBlackboard.new()
	blackboard.begin_turn(self)
	return blackboard.plan_for(enemy_id)


func preview_all_tactical_plans() -> Dictionary:
	var blackboard := EnemyAISquadBlackboard.new()
	blackboard.begin_turn(self)
	return blackboard.assignments.duplicate(true)


func _single_enemy_turn(state: CombatEnemyState) -> Array[Dictionary]:
	var turn_events: Array[Dictionary] = []
	if outcome != "":
		return turn_events
	_refresh_enemy_vision(state, false)
	if _ai_blackboard != null:
		_ai_blackboard.plan_enemy(state.id)
	if not state.beam_pending_cells.is_empty():
		var firing_cells := state.beam_pending_cells.duplicate()
		var firing_damage := state.beam_pending_damage
		state.beam_pending_cells.clear()
		state.beam_pending_damage = 0
		var hit := player_pos in firing_cells
		var fire_event := {"kind": "beam_fire", "actor_id": state.id, "cells": firing_cells, "target": player_pos, "damage": 0, "label": "激光落下"}
		if hit:
			var hit_result := _apply_player_hit(state, "beam", firing_damage)
			fire_event.merge(hit_result, true)
		else:
			fire_event["label"] = "激光落空"
		turn_events.append(fire_event)
		event_log.append("EnemyBeamFired cells=%s hit=%s" % [str(firing_cells), str(hit)])
		return turn_events
	if state.ambush_active and not state.sees_player:
		state.ambush_idle_turns += 1
		if state.ambush_idle_turns <= 1:
			event_log.append("AmbushWaiting turn=%d" % state.ambush_idle_turns)
			turn_events.append({"kind": "wait", "actor_id": state.id, "label": "仍在埋伏点窥探"})
			return turn_events
		state.ambush_active = false
		state.patrol_goal = INVALID_CELL
		state.tactical_goal = INVALID_CELL
		state.tactical_reserved_cell = INVALID_CELL
		state.tactical_plan_round = 0
		event_log.append("AmbushReleasedToPatrol")
		turn_events.append({"kind": "alert", "actor_id": state.id, "label": "离开埋伏点，开始巡逻"})
	var remaining := _enemy_turn_budget(state)
	var guard := 20
	while remaining > 0 and outcome == "" and guard > 0:
		guard -= 1
		_refresh_enemy_vision(state, false)
		if player_exposed and state.sees_player:
			player_exposed = false
			if state.has_trait("cornerCut"):
				var free_step := _choose_enemy_step(state, state.pos, player_pos)
				if free_step != INVALID_CELL and free_step != player_pos:
					_move_enemy_to(state, free_step, "抄近路", turn_events, true)
					if outcome != "":
						break
			if state.has_trait("faceShock"):
				var shock_plan := _enemy_attack_plan(state, state.pos, remaining, state.sees_player)
				if shock_plan.is_empty():
					var shock_result := _apply_player_hit(state, "faceShock", 1)
					shock_result["kind"] = "face_shock"
					shock_result["actor_id"] = state.id
					shock_result["target"] = player_pos
					shock_result["label"] = "突脸惊吓"
					turn_events.append(shock_result)
					event_log.append("EnemyFaceShock damage=%d" % int(shock_result.get("damage", 0)))
				else:
					var shock_execution := _execute_enemy_attack_plan(state, shock_plan, remaining, "faceShock")
					turn_events.append_array(shock_execution.get("events", []))
					remaining -= int(shock_execution.get("cost", 0))
				break
		var adjacent_to_decoy := has_decoy() and manhattan(state.pos, decoy_pos) == 1
		if adjacent_to_decoy and remaining >= _effective_attack_cost(state):
			turn_events.append(_resolve_decoy_attack(state))
			remaining -= _effective_attack_cost(state)
			continue
		if state.sees_player and manhattan(state.pos, player_pos) <= 1 and remaining < _effective_attack_cost(state):
			turn_events.append({"kind": "wait", "actor_id": state.id, "label": "等待攻击窗口"})
			break
		var attack_plan := _enemy_attack_plan(state, state.pos, remaining, state.sees_player)
		if not attack_plan.is_empty():
			var execution := _execute_enemy_attack_plan(state, attack_plan, remaining)
			turn_events.append_array(execution.get("events", []))
			remaining -= int(execution.get("cost", 0))
			break
		var goal := _enemy_goal(state)
		if goal == INVALID_CELL:
			turn_events.append({"kind": "wait", "actor_id": state.id, "label": "没有可达的搜查点"})
			break
		var raw_step := _choose_enemy_step(state, state.pos, goal)
		if raw_step == INVALID_CELL:
			if not state.sees_player and state.last_seen == INVALID_CELL:
				state.patrol_goal = INVALID_CELL
				goal = _enemy_goal(state)
				raw_step = _choose_enemy_step(state, state.pos, goal) if goal != INVALID_CELL else INVALID_CELL
			if raw_step == INVALID_CELL:
				turn_events.append({"kind": "wait", "actor_id": state.id, "label": "在遮挡后重新判断方向"})
				break
		if raw_step == player_pos or (has_decoy() and raw_step == decoy_pos):
			turn_events.append({"kind": "wait", "actor_id": state.id, "label": "等待攻击窗口"})
			break
		var verb := "追击" if state.sees_player else "搜索" if state.last_seen != INVALID_CELL else "巡逻"
		_move_enemy_to(state, raw_step, verb, turn_events)
		remaining -= 1
		if traps.has(state.pos):
			remaining -= int((traps[state.pos] as Dictionary).get("slow", 0))
		if not state.sees_player and state.last_seen == INVALID_CELL and state.pos == state.patrol_goal:
			state.patrol_goal = INVALID_CELL
	return turn_events


func _resolve_decoy_attack(state: CombatEnemyState) -> Dictionary:
	var target := decoy_pos
	event_log.append("EnemyDestroyedDecoy pos=%s" % decoy_pos)
	decoy_pos = Vector2i(-1, -1)
	return {"kind": "attack", "actor_id": state.id, "target": target, "damage": 0, "label": "撕碎纸影", "attack_kind": "decoy"}


func _enemy_turn_budget(state: CombatEnemyState) -> int:
	return maxi(1, state.action_points - 2) if state.stagger_pending else state.action_points


func _effective_attack_cost(state: CombatEnemyState) -> int:
	return 1 if state.has_trait("relentless") and state.sees_player else state.attack_cost


func _enemy_attack_plan(state: CombatEnemyState, origin: Vector2i, remaining: int, sees_player: bool) -> Dictionary:
	if not sees_player or remaining <= 0:
		return {}
	var distance := manhattan(origin, player_pos)
	var attack_cost := 1 if state.has_trait("relentless") else state.attack_cost
	if state.has_trait("slam") and distance <= 1 and remaining >= attack_cost:
		return {"kind": "slam", "cost": attack_cost, "cells": _slam_cells(origin, player_pos)}
	if state.has_trait("beam") and distance >= 2 and distance <= 3 and (origin.x == player_pos.x or origin.y == player_pos.y) and remaining >= attack_cost:
		var beam_cells := _beam_cells(origin, player_pos)
		if player_pos in beam_cells:
			return {"kind": "beam_charge", "cost": attack_cost, "cells": beam_cells}
	if state.has_trait("ranged") and distance >= 2 and distance <= state.attack_range and _has_line_of_sight(origin, player_pos) and remaining >= attack_cost:
		return {"kind": "ranged", "cost": attack_cost, "cells": [player_pos]}
	if state.has_trait("ranged") and distance <= 1:
		return {}
	if distance <= 1 and remaining >= attack_cost:
		if state.has_trait("guardBreak") and _player_defense_total(origin) > 0 and remaining >= attack_cost + 1:
			return {"kind": "guardBreak", "cost": attack_cost + 1, "cells": [player_pos]}
		return {"kind": "melee", "cost": attack_cost, "cells": [player_pos]}
	if state.has_trait("lunge") and distance == 2:
		var landing := _lunge_landing(state, origin)
		if landing != INVALID_CELL and remaining >= attack_cost + 1:
			return {"kind": "lunge", "cost": attack_cost + 1, "cells": [landing, player_pos], "landing": landing}
	return {}


func _enemy_attack_coverage(state: CombatEnemyState, origin: Vector2i, can_see: bool = true) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not can_see:
		return cells
	for y in range(rows):
		for x in range(cols):
			var target := Vector2i(x, y)
			if target == origin or not is_walkable(target):
				continue
			var distance := manhattan(origin, target)
			var valid := false
			if state.has_trait("ranged"):
				valid = distance >= 2 and distance <= state.attack_range and _has_line_of_sight(origin, target)
			elif state.has_trait("beam"):
				valid = distance >= 2 and distance <= 3 and (origin.x == target.x or origin.y == target.y) and _has_line_of_sight(origin, target)
			elif state.has_trait("slam") or state.has_trait("guardBreak"):
				valid = distance <= 1
			elif state.has_trait("lunge"):
				valid = distance <= 2
			else:
				valid = distance <= 1
			if valid:
				cells.append(target)
	return cells


func enemy_reachable_cells(state: CombatEnemyState, budget: int = -1) -> Array:
	var cells: Array = []
	if state == null or not state.alive():
		return cells
	var movement_budget := _enemy_turn_budget(state) if budget < 0 else budget
	var blocked := occupied_enemy_cells(state.id)
	for y in range(rows):
		for x in range(cols):
			var target := Vector2i(x, y)
			if target == state.pos or target == player_pos or target == decoy_pos:
				continue
			if not is_walkable(target) or blocked.has(target):
				continue
			var path := _find_path(state.pos, target, blocked, false)
			if path.size() < 2 or path.back() != target:
				continue
			if _enemy_path_cost(path) <= movement_budget:
				cells.append(target)
	return cells


func enemy_threat_cells(state: CombatEnemyState, move_cells: Array) -> Array:
	var cells: Array = []
	if state == null or not state.alive() or state.blind_turns > 0:
		return cells
	var origins: Array = []
	origins.append(state.pos)
	for cell in move_cells:
		if cell not in origins:
			origins.append(cell)
	for origin in origins:
		for target in _enemy_attack_coverage(state, origin, true):
			if target not in cells:
				cells.append(target)
	return cells


func _enemy_path_cost(path: Array[Vector2i]) -> int:
	var total := 0
	for index in range(1, path.size()):
		var cell: Vector2i = path[index]
		total += 1 + int((traps.get(cell, {}) as Dictionary).get("slow", 0))
	return total


func _attack_line_cells(origin: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var samples := maxi(absi(target.x - origin.x), absi(target.y - origin.y))
	for i in range(1, samples):
		var t := float(i) / float(samples)
		var cell := Vector2i(roundi(lerpf(float(origin.x), float(target.x), t)), roundi(lerpf(float(origin.y), float(target.y), t)))
		if cell != origin and cell != target and cell not in cells:
			cells.append(cell)
	return cells


func _intent_from_attack_plan(state: CombatEnemyState, plan: Dictionary, base: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	var kind := str(plan.get("kind", "melee"))
	var display_kind := "beam" if kind == "beam_charge" else kind
	var attack_origin: Vector2i = plan.get("origin", state.pos)
	var hits := _planned_attack_hits(state, plan, _enemy_turn_budget(state))
	var damage := _raw_enemy_damage(state, state.pos)
	result["hurt"] = (plan.get("cells", [player_pos]) as Array).duplicate()
	result["impact_cells"] = result["hurt"].duplicate()
	result["range_origin"] = attack_origin
	result["coverage_cells"] = _enemy_attack_coverage(state, attack_origin, true)
	if kind == "beam_charge":
		result["line_cells"] = result["impact_cells"].duplicate()
	elif kind == "ranged":
		result["line_cells"] = _attack_line_cells(attack_origin, player_pos)
	result["type"] = "attack"
	result["attack_kind"] = display_kind
	result["hits"] = hits
	result["pending"] = kind == "beam_charge"
	var labels := {
		"melee": "挥击",
		"ranged": "远射",
		"lunge": "突进",
		"guardBreak": "破防",
		"slam": "砸地",
		"beam_charge": "激光蓄力",
	}
	var action_label := str(labels.get(kind, "攻击"))
	result["label"] = "%s %d%s" % [action_label, damage, "×%d" % hits if hits > 1 else ""]
	if kind == "beam_charge":
		result["detail"] = "本回合锁定红色射线，下一敌方回合落下；期间可以离开红格。"
	elif kind == "guardBreak":
		result["detail"] = "无视格挡、掩体与高差防护；额外消耗 1 点敌方行动力。"
	elif hits > 1:
		result["detail"] = "连击 %d 段，每段 %d 点；格挡池会逐段消耗。" % [hits, damage]
	else:
		result["detail"] = "红格将在敌方回合受到攻击；攻击和预警使用同一份行动计划。"
	return result


func _planned_attack_hits(state: CombatEnemyState, plan: Dictionary, remaining: int) -> int:
	if not state.has_trait("flurry") or str(plan.get("kind", "")) == "beam_charge":
		return 1
	var first_cost := int(plan.get("cost", _effective_attack_cost(state)))
	return 2 if remaining - first_cost >= _effective_attack_cost(state) else 1


func _execute_enemy_attack_plan(state: CombatEnemyState, plan: Dictionary, remaining: int, hit_kind_override: String = "") -> Dictionary:
	var events: Array[Dictionary] = []
	var kind := str(plan.get("kind", "melee"))
	var cost := int(plan.get("cost", _effective_attack_cost(state)))
	if kind == "beam_charge":
		state.beam_pending_cells.clear()
		for raw_cell in plan.get("cells", []):
			state.beam_pending_cells.append(raw_cell as Vector2i)
		state.beam_pending_damage = _raw_enemy_damage(state, state.pos)
		events.append({"kind": "beam_charge", "actor_id": state.id, "cells": state.beam_pending_cells.duplicate(), "damage": state.beam_pending_damage, "label": "激光蓄力"})
		event_log.append("EnemyBeamCharged cells=%s damage=%d" % [str(state.beam_pending_cells), state.beam_pending_damage])
		return {"events": events, "cost": cost}
	if kind == "lunge":
		var landing: Vector2i = plan.get("landing", INVALID_CELL)
		if landing != INVALID_CELL:
			_move_enemy_to(state, landing, "突进", events)
			if outcome != "":
				return {"events": events, "cost": cost}
	var hits := _planned_attack_hits(state, plan, remaining)
	var attack_kind := hit_kind_override if not hit_kind_override.is_empty() else kind
	for hit_index in range(hits):
		var hit_result := _apply_player_hit(state, attack_kind)
		hit_result["kind"] = "attack"
		hit_result["actor_id"] = state.id
		hit_result["target"] = player_pos
		hit_result["attack_kind"] = attack_kind
		hit_result["hit_index"] = hit_index + 1
		hit_result["hits"] = hits
		hit_result["cells"] = (plan.get("cells", [player_pos]) as Array).duplicate()
		hit_result["label"] = _attack_label(attack_kind, hit_index + 1, hits)
		events.append(hit_result)
		var stolen_id := str(hit_result.get("stolen_card", ""))
		if not stolen_id.is_empty():
			var stolen_name := str((cards.get(stolen_id, {}) as Dictionary).get("name", stolen_id))
			events.append({"kind": "grab", "actor_id": state.id, "card_id": stolen_id, "label": "搜刮·%s" % stolen_name})
		if outcome != "":
			break
	var total_cost := cost + maxi(0, hits - 1) * _effective_attack_cost(state)
	return {"events": events, "cost": total_cost}


func _apply_player_hit(state: CombatEnemyState, kind: String, damage_override: int = -1) -> Dictionary:
	var raw_damage := damage_override if damage_override >= 0 else _raw_enemy_damage(state, state.pos)
	var blocked := 0
	var damage := raw_damage
	if kind == "guardBreak":
		player_block = 0
	else:
		var cover := int((traps.get(player_pos, {}) as Dictionary).get("cover_block", 0)) if traps.has(player_pos) else 0
		var height_cover := 1 if _tile_height(player_pos) > _tile_height(state.pos) else 0
		var innate_block := mini(cover + height_cover, damage)
		damage -= innate_block
		var card_block := mini(player_block, damage)
		player_block -= card_block
		damage -= card_block
		blocked = innate_block + card_block
	player_hp -= damage
	var stolen_id := ""
	if damage > 0 and state.has_trait("grab"):
		stolen_id = _steal_player_card()
	event_log.append("EnemyAttack kind=%s damage=%d blocked=%d hp=%d" % [kind, damage, blocked, player_hp])
	if not stolen_id.is_empty():
		event_log.append("EnemyGrab card=%s" % stolen_id)
	if player_hp <= 0:
		outcome = "defeat"
		event_log.append("CombatEnded outcome=defeat")
	return {"damage": damage, "blocked": blocked, "raw_damage": raw_damage, "stolen_card": stolen_id}


func _steal_player_card() -> String:
	for zone in [hand, discard, deck]:
		for index in range(zone.size()):
			var card_id := str(zone[index])
			if bool((cards.get(card_id, {}) as Dictionary).get("stealable", false)):
				zone.remove_at(index)
				return card_id
	for zone in [hand, discard, deck]:
		if not zone.is_empty():
			return str(zone.pop_front())
	return ""


func _attack_label(kind: String, hit_index: int, hits: int) -> String:
	var labels := {"melee": "攻击", "faceShock": "突脸惊吓", "lunge": "突进", "guardBreak": "破防", "slam": "砸地", "beam": "激光"}
	var label := str(labels.get(kind, "攻击"))
	return "%s %d/%d" % [label, hit_index, hits] if hits > 1 else label


func _raw_enemy_damage(state: CombatEnemyState, origin: Vector2i) -> int:
	return state.damage + (1 if _tile_height(origin) > _tile_height(player_pos) else 0)


func _player_defense_total(origin: Vector2i) -> int:
	var cover := int((traps.get(player_pos, {}) as Dictionary).get("cover_block", 0)) if traps.has(player_pos) else 0
	return player_block + cover + (1 if _tile_height(player_pos) > _tile_height(origin) else 0)


func _slam_cells(origin: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var dx := signi(origin.x - target.x)
	var dy := signi(origin.y - target.y)
	var xs: Array[int] = []
	var ys: Array[int] = []
	xs.assign([target.x - 1, target.x] if dx < 0 else [target.x, target.x + 1])
	ys.assign([target.y - 1, target.y] if dy < 0 else [target.y, target.y + 1])
	var cells: Array[Vector2i] = []
	for y in ys:
		for x in xs:
			var cell := Vector2i(x, y)
			if is_walkable(cell):
				cells.append(cell)
	return cells


func _beam_cells(origin: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var direction := Vector2i.ZERO
	if origin.x == target.x:
		direction.y = signi(target.y - origin.y)
	elif origin.y == target.y:
		direction.x = signi(target.x - origin.x)
	for distance in range(1, 4):
		var cell := origin + direction * distance
		if direction == Vector2i.ZERO or not is_walkable(cell):
			break
		cells.append(cell)
	return cells


func _lunge_landing(state: CombatEnemyState, origin: Vector2i) -> Vector2i:
	var blocked := occupied_enemy_cells(state.id)
	var candidates: Array[Vector2i] = []
	for direction in DIRS:
		var cell: Vector2i = origin + direction
		if is_walkable(cell) and cell != player_pos and cell != decoy_pos and not blocked.has(cell) and manhattan(cell, player_pos) == 1:
			candidates.append(cell)
	if candidates.is_empty():
		return INVALID_CELL
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var cost_a := int((traps.get(a, {}) as Dictionary).get("slow", 0))
		var cost_b := int((traps.get(b, {}) as Dictionary).get("slow", 0))
		return cost_a < cost_b
	)
	return candidates[0]


func _choose_enemy_step(state: CombatEnemyState, origin: Vector2i, goal: Vector2i) -> Vector2i:
	if goal == INVALID_CELL:
		return INVALID_CELL
	# 动态阻挡：其他存活敌人所在格不可作为落点，也不可穿越。
	var blocked := occupied_enemy_cells(state.id)
	var candidates: Array[Dictionary] = []
	for direction in DIRS:
		var cell: Vector2i = origin + direction
		if not is_walkable(cell) or cell == player_pos or cell == decoy_pos or blocked.has(cell):
			continue
		var path := _find_path(cell, goal, blocked)
		if path.size() < 2 and cell != goal:
			continue
		var trap: Dictionary = traps.get(cell, {})
		var hazard := 2 if int(trap.get("damage", 0)) > 0 else 1 if int(trap.get("slow", 0)) > 0 else 0
		candidates.append({"cell": cell, "distance": path.size(), "hazard": hazard, "height": _tile_height(cell)})
	if portals.has(origin):
		var portal_cell: Vector2i = portals[origin]
		if is_walkable(portal_cell) and portal_cell != player_pos and portal_cell != decoy_pos and not blocked.has(portal_cell):
			var portal_path := _find_path(portal_cell, goal, blocked)
			candidates.append({"cell": portal_cell, "distance": portal_path.size(), "hazard": 0, "height": _tile_height(portal_cell)})
	if candidates.is_empty():
		return INVALID_CELL
	if state.has_trait("vault"):
		var current_distance := manhattan(origin, goal)
		var climb_options := candidates.filter(func(option: Dictionary) -> bool:
			return int(option["height"]) > _tile_height(origin) and manhattan(option["cell"], goal) <= current_distance
		)
		if not climb_options.is_empty():
			climb_options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["height"]) > int(b["height"]))
			return climb_options[0]["cell"]
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["distance"]) != int(b["distance"]):
			return int(a["distance"]) < int(b["distance"])
		if state.has_trait("trapAware") and int(a["hazard"]) != int(b["hazard"]):
			return int(a["hazard"]) < int(b["hazard"])
		if state.has_trait("vault") and int(a["height"]) != int(b["height"]):
			return int(a["height"]) > int(b["height"])
		return str(a["cell"]) < str(b["cell"])
	)
	return candidates[0]["cell"]


func _move_enemy_to(state: CombatEnemyState, target: Vector2i, verb: String, events: Array[Dictionary], free_step: bool = false) -> void:
	var was_adjacent := manhattan(state.pos, player_pos) == 1
	var from := state.pos
	state.just_portaled = portals.get(from, INVALID_CELL) == target
	state.pos = target
	events.append({"kind": "move", "actor_id": state.id, "from": from, "to": state.pos, "via_portal": state.just_portaled, "free": free_step, "label": verb})
	event_log.append("Enemy%s from=%s to=%s free=%s" % [verb, from, state.pos, str(free_step)])
	_trigger_trap(state, state.pos, has_decoy() and _enemy_goal(state) == decoy_pos)
	_refresh_vision(true)
	if not was_adjacent and manhattan(state.pos, player_pos) == 1:
		_trigger_ready(state)


func _finish_enemy_turn() -> void:
	for enemy_id in enemy_order:
		var state: CombatEnemyState = enemies[enemy_id]
		_refresh_enemy_vision(state, false)
		if not state.sees_player:
			state.last_seen_age += 1
			if state.last_seen != INVALID_CELL and state.last_seen_age >= LAST_SEEN_MEMORY_TURNS:
				state.last_seen = INVALID_CELL
				state.patrol_goal = INVALID_CELL
				event_log.append("EnemyLostTrail")
		else:
			state.last_seen_age = 0
	if outcome == "":
		for enemy_id in enemy_order:
			var state: CombatEnemyState = enemies[enemy_id]
			state.stagger_pending = false
			if state.blind_turns > 0:
				state.blind_turns -= 1
		round_number += 1
		# 杀戮尖塔式回合：怪物回合结束后不立即抽牌；
		# 由 channel_3d 在敌方动画播完后调用 start_player_turn() 才发新牌。
		pending_player_turn = true


func start_player_turn() -> void:
	pending_player_turn = false
	_start_player_turn()


func is_walkable(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < cols and pos.y < rows and not walls.has(pos)


func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _play_place(card: Dictionary, target: Vector2i) -> bool:
	if not is_walkable(target) or target == player_pos:
		return false
	var adjacent := manhattan(player_pos, target) == 1
	var smash_state := enemy_at(target)
	var smash := smash_state != null and _has_line_of_sight(player_pos, smash_state.pos)
	if not adjacent and not smash:
		return false
	var place_data: Dictionary = card.get("place", {})
	if bool(place_data.get("decoy", false)):
		if smash or not adjacent or traps.has(target):
			return false
		decoy_pos = target
		return true
	if place_data.has("gather") and not smash:
		return _place_gather(card, target)
	if not smash and (traps.has(target) or target == decoy_pos):
		return false
	var effect: Dictionary = (place_data.get("onStep", place_data) as Dictionary).duplicate(true)
	if place_data.has("enterTax"):
		effect["slow"] = int(place_data.get("enterTax", 0))
	if place_data.has("coverBlock"):
		effect["cover_block"] = int(place_data.get("coverBlock", 0))
	if effect.has("blind"):
		effect["blind_turns"] = int(effect.get("blindTurns", effect.get("blind_turns", 1)))
	effect["persistent"] = bool(effect.get("persistent", false)) or place_data.has("enterTax") or place_data.has("coverBlock")
	effect["glyph"] = str(place_data.get("glyph", "?"))
	effect["card_id"] = str(card.get("id", "unknown"))
	if smash and smash_state != null:
		var damage := int(effect.get("damage", 0))
		var smash_roll: Dictionary = place_data.get("smashRoll", {})
		if not smash_roll.is_empty():
			damage = _roll_smash_damage(smash_roll, str(card.get("id", "?")))
		if _tile_height(player_pos) > _tile_height(smash_state.pos):
			damage += int(place_data.get("heightSmashExtra", 1))
		if smash_state.broken:
			damage += int(place_data.get("smashBonusIfBroken", 0))
		if not first_smash_used:
			damage += first_smash_bonus
			first_smash_used = true
		var smash_tough := int(place_data.get("smashTough", 1 if damage > 0 else 0))
		var dealt := _apply_enemy_damage(smash_state, damage, smash_tough, "smash")
		last_card_events.append({"kind": "enemy_damaged", "target_enemy_id": smash_state.id, "damage": dealt, "source": "smash"})
		_apply_blind(smash_state, effect)
	else:
		traps[target] = effect
	return true


func _roll_smash_damage(spec: Dictionary, card_id: String) -> int:
	var dice := int(spec.get("dice", 1))
	var faces: Array = spec.get("faces", [1, 2, 3])
	var total := 0
	var parts: Array[int] = []
	for _i in range(dice):
		var face := int(faces[rng.randi_range(0, faces.size() - 1)]) if not faces.is_empty() else 1
		parts.append(face)
		total += face
	event_log.append("SmashRoll id=%s dice=%d result=%s total=%d" % [card_id, dice, str(parts), total])
	return total


func _play_shove(prefer_portal := false, draw_on_portal := 0, state: CombatEnemyState = null) -> bool:
	if state == null or not state.alive() or manhattan(state.pos, player_pos) != 1:
		return false
	var ported := _shove_enemy(state, prefer_portal)
	if ported:
		_draw_cards(draw_on_portal)
	return true


func _shove_enemy(state: CombatEnemyState, prefer_portal: bool) -> bool:
	var direct := state.pos + (state.pos - player_pos)
	var best := Vector2i(-999, -999)
	var best_score := -9999
	var blocked := occupied_enemy_cells(state.id)
	for raw_dir in DIRS:
		var dir: Vector2i = raw_dir
		var target: Vector2i = state.pos + dir
		if not is_walkable(target) or target == player_pos or blocked.has(target):
			continue
		var score := manhattan(target, player_pos)
		if target == direct:
			score += 20
		if traps.has(target):
			score += 100
		if portals.has(target):
			score += 120 if prefer_portal else 40
		if score > best_score:
			best_score = score
			best = target
	if best.x < -100:
		_drain_toughness(state, 1, "shove_wall")
		return false
	var landing := _follow_portal(best, "enemy", blocked)
	state.just_portaled = landing != best
	state.pos = landing
	_trigger_trap(state, state.pos)
	return state.just_portaled


func _trigger_trap(state: CombatEnemyState, pos: Vector2i, chasing_decoy: bool = false) -> void:
	if not traps.has(pos):
		return
	var trap: Dictionary = traps[pos]
	var damage := int(trap.get("damage", 0))
	if chasing_decoy and damage > 0:
		damage += 1
		event_log.append("ComboTriggered name=纸影连击")
	if state.just_portaled:
		damage += int(trap.get("portalBonus", 0))
	var default_tough := 2 if damage > 0 else 1 if int(trap.get("slow", 0)) > 0 else 0
	_apply_enemy_damage(state, damage, int(trap.get("tough", trap.get("toughness", default_tough))), "trap:%s" % str(trap.get("card_id", "trap")))
	_apply_blind(state, trap)
	if not bool(trap.get("persistent", false)):
		traps.erase(pos)


func _apply_enemy_damage(state: CombatEnemyState, damage: int, toughness_damage: int, source: String) -> int:
	if state == null:
		return 0
	var execute_before := state.execute_bonus_pending
	var crush_before := state.crush_bonus_pending
	_drain_toughness(state, toughness_damage, source)
	var dealt := maxi(0, damage)
	if dealt > 0:
		dealt += damage_bonus
	if not state.broken and state.archetype == "armor":
		dealt = maxi(0, dealt - 1)
	if not state.broken and state.archetype == "wire" and source == "smash":
		dealt = int(ceil(float(dealt) * 0.5))
	if execute_before and (source == "smash" or source.begins_with("trap:")):
		dealt += 2
		state.execute_bonus_pending = false
	if crush_before and dealt > 0:
		dealt += mini(dealt, 4)
		state.crush_bonus_pending = false
	state.hp -= dealt
	event_log.append("EnemyDamaged source=%s damage=%d hp=%d tough=%d enemy=%s" % [source, dealt, state.hp, state.toughness, state.id])
	if state.hp <= 0 and all_enemies_defeated():
		outcome = "victory"
		event_log.append("CombatEnded outcome=victory")
	return dealt


func _drain_toughness(state: CombatEnemyState, amount: int, source: String) -> bool:
	if state == null or amount <= 0 or state.toughness <= 0:
		return false
	state.toughness = maxi(0, state.toughness - amount)
	if state.toughness > 0:
		return false
	state.broken = true
	if state.archetype == "execute":
		state.execute_bonus_pending = true
	elif state.archetype == "stagger":
		state.stagger_pending = true
	elif state.archetype == "crush":
		state.crush_bonus_pending = true
	event_log.append("EnemyBroken source=%s archetype=%s" % [source, state.archetype])
	return true


func _start_player_turn() -> void:
	energy_rolls.clear()
	energy_roll = base_energy
	energy = energy_roll + energy_bonus
	turn_energy_max = energy
	player_block = 0
	free_draw_used = false
	_draw_to(hand_size)
	event_log.append("PlayerTurn round=%d fixed_energy=%d bonus=%d energy=%d" % [round_number, base_energy, energy_bonus, energy])


func _draw_to(target_count: int) -> void:
	while hand.size() < target_count:
		if deck.is_empty():
			if discard.is_empty():
				break
			deck.assign(discard)
			discard.clear()
			_shuffle(deck)
		hand.append(deck.pop_back())


func _discard_unretained_hand() -> void:
	var retained: Array[String] = []
	var budget := retain_slots + retain_this_turn
	for card_id in hand:
		var card: Dictionary = cards.get(card_id, {})
		if bool(card.get("retain", false)):
			retained.append(card_id)
		elif budget > 0:
			retained.append(card_id)
			budget -= 1
		else:
			if not bool(card.get("temp", false)) and not bool(card.get("exhaust", false)):
				discard.append(card_id)
	hand.assign(retained)
	retain_this_turn = 0


func _trigger_ready(state: CombatEnemyState) -> void:
	if ready_effect.is_empty():
		return
	player_block += int(ready_effect.get("gainBlock", 0))
	var ready_damage := int(ready_effect.get("damage", 0))
	var ready_tough := int(ready_effect.get("tough", 0))
	if ready_damage > 0 or ready_tough > 0:
		var dealt := _apply_enemy_damage(state, ready_damage, ready_tough, "ready")
		last_card_events.append({"kind": "enemy_damaged", "target_enemy_id": state.id, "damage": dealt, "source": "ready"})
	_draw_cards(int(ready_effect.get("draw", 0)))
	if bool(ready_effect.get("shove", false)) and outcome == "":
		var hp_before := state.hp
		var tough_before := state.toughness
		var ported := _shove_enemy(state, bool(ready_effect.get("preferPortal", false)))
		if hp_before == state.hp and tough_before == state.toughness:
			var wall_dealt := _apply_enemy_damage(state, 1, 1, "ready")
			last_card_events.append({"kind": "enemy_damaged", "target_enemy_id": state.id, "damage": wall_dealt, "source": "ready"})
		if ported:
			_draw_cards(int(ready_effect.get("drawOnPortal", 0)))
	event_log.append("ReadyTriggered id=%s" % str(ready_effect.get("card_id", "ready")))
	ready_effect.clear()


func _apply_blind(state: CombatEnemyState, effect: Dictionary) -> void:
	if bool(effect.get("blind", false)):
		state.blind_turns = maxi(state.blind_turns, int(effect.get("blind_turns", 1)))
		state.last_seen = INVALID_CELL
		state.last_seen_age = 0
		state.sees_player = false
		state.patrol_goal = INVALID_CELL
		event_log.append("EnemyBlinded turns=%d" % state.blind_turns)


func _play_climb() -> bool:
	var target := Vector2i(-1, -1)
	var target_height := _tile_height(player_pos)
	for raw_dir in DIRS:
		var dir: Vector2i = raw_dir
		var candidate: Vector2i = player_pos + dir
		var height := _tile_height(candidate)
		if is_walkable(candidate) and height > target_height:
			target = candidate
			target_height = height
	if target.x < 0:
		return false
	player_pos = target
	event_log.append("PlayerClimbed pos=%s height=%d" % [player_pos, target_height])
	return true


func _play_topple(state: CombatEnemyState) -> bool:
	if state == null or _tile_height(player_pos) <= _tile_height(state.pos):
		return false
	var dealt := _apply_enemy_damage(state, 2, 1, "skill:topple")
	last_card_events.append({"kind": "enemy_damaged", "target_enemy_id": state.id, "damage": dealt, "source": "skill:topple"})
	return true


func _play_puppet_bang(effect_value: Variant, state: CombatEnemyState) -> bool:
	if not has_decoy() or state == null:
		return false
	var effect: Dictionary = effect_value if effect_value is Dictionary else {}
	var dealt := _apply_enemy_damage(state, int(effect.get("damage", 3)), 0, "skill:puppet")
	last_card_events.append({"kind": "enemy_damaged", "target_enemy_id": state.id, "damage": dealt, "source": "skill:puppet"})
	decoy_pos = Vector2i(-1, -1)
	return true


func _play_salt_lash(effect_value: Variant, state: CombatEnemyState) -> bool:
	if state == null or not state.alive():
		return false
	if not traps.has(state.pos) or int((traps[state.pos] as Dictionary).get("slow", 0)) <= 0:
		return false
	var effect: Dictionary = effect_value if effect_value is Dictionary else {}
	var dealt := _apply_enemy_damage(state, int(effect.get("damage", 2)), int(effect.get("tough", 1)), "skill:salt_lash")
	last_card_events.append({"kind": "enemy_damaged", "target_enemy_id": state.id, "damage": dealt, "source": "skill:salt_lash"})
	return true


func _play_blind_followup(card: Dictionary, state: CombatEnemyState) -> bool:
	if state == null:
		return false
	if state.blind_turns > 0 and card.has("ifBlinded"):
		var effect: Dictionary = card.get("ifBlinded", {})
		var dealt := _apply_enemy_damage(state, int(effect.get("damage", 0)), int(effect.get("tough", 0)), "skill:blind_followup")
		last_card_events.append({"kind": "enemy_damaged", "target_enemy_id": state.id, "damage": dealt, "source": "skill:blind_followup"})
	else:
		state.blind_turns = maxi(state.blind_turns, int(card.get("elseBlind", 1)))
		event_log.append("EnemyBlinded turns=%d" % state.blind_turns)
	return true


func _play_rupture(card: Dictionary, state: CombatEnemyState) -> bool:
	if state == null:
		return false
	var was_broken := state.broken
	var broke := _drain_toughness(state, int(card.get("drainTough", 0)), "skill:rupture")
	if broke:
		_draw_cards(int(card.get("drawOnBreak", 0)))
	elif was_broken:
		placement_discount += int(card.get("discountIfBroken", 0))
	return true


func _place_gather(card: Dictionary, target: Vector2i) -> bool:
	if traps.has(target) or target == decoy_pos:
		return false
	var cfg: Dictionary = card.get("place", {}).get("gather", {})
	var candidates: Array[Dictionary] = []
	for raw_pos in traps.keys():
		var pos: Vector2i = raw_pos
		var trap: Dictionary = traps[pos]
		if absi(pos.x - target.x) <= 1 and absi(pos.y - target.y) <= 1 and int(trap.get("damage", 0)) > 0:
			candidates.append({"pos": pos, "damage": int(trap.get("damage", 0)), "blind": bool(trap.get("blind", false))})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["damage"]) > int(b["damage"]))
	var damage := 0
	var blind := false
	var take := mini(int(cfg.get("maxItems", 2)), candidates.size())
	for i in range(take):
		damage += int(candidates[i]["damage"])
		blind = blind or bool(candidates[i]["blind"])
		traps.erase(candidates[i]["pos"])
	damage = mini(int(cfg.get("damageCap", 5)), damage) if take > 0 else int(cfg.get("fallbackDamage", 1))
	traps[target] = {
		"card_id": str(card.get("id", "snare")),
		"glyph": "束" if take > 0 else str(card.get("place", {}).get("glyph", "绊")),
		"damage": damage,
		"blind": blind,
		"blind_turns": 1,
	}
	return true


func _draw_cards(count: int) -> void:
	if count <= 0:
		return
	_draw_to(hand.size() + count)


func _enemy_goal(state: CombatEnemyState) -> Vector2i:
	if state.tactical_plan_round == round_number and state.tactical_goal != INVALID_CELL:
		return state.tactical_goal
	if has_decoy():
		return decoy_pos
	if state.sees_player:
		return player_pos
	if state.last_seen != INVALID_CELL:
		return state.last_seen
	return _ensure_patrol_goal(state)


func reveal_enemy(reason: String = "sight", state: CombatEnemyState = null) -> void:
	var targets: Array = _iter_enemy_states() if state == null else [state]
	for enemy_state in targets:
		if not enemy_state.revealed:
			enemy_state.revealed = true
			event_log.append("AmbushRevealed reason=%s" % reason)
		if reason in ["sight", "card"]:
			enemy_state.ambush_active = false


func _refresh_enemy_visibility() -> void:
	_refresh_vision(true)


func _refresh_vision(emit_events: bool = true) -> void:
	for enemy_id in enemy_order:
		_refresh_enemy_vision(enemies[enemy_id], emit_events)


func _refresh_enemy_vision(state: CombatEnemyState, emit_events: bool = true) -> void:
	state.player_sees_enemy = _has_line_of_sight(player_pos, state.pos)
	var had_enemy_los := state.sees_player
	state.sees_player = _has_line_of_sight(state.pos, player_pos) and state.blind_turns <= 0
	if state.player_sees_enemy:
		reveal_enemy("player_sight", state)
	if state.sees_player:
		state.last_seen = player_pos
		state.last_seen_age = 0
		state.patrol_goal = INVALID_CELL
		if emit_events and not had_enemy_los:
			player_exposed = true
		if state.ambush_active:
			state.ambush_active = false
			if emit_events:
				event_log.append("AmbushSprung player=%s" % player_pos)
		if emit_events and not had_enemy_los:
			event_log.append("EnemyAcquiredSight player=%s" % player_pos)
	elif emit_events and had_enemy_los:
		event_log.append("EnemyLostSight last_seen=%s" % state.last_seen)


func _ensure_patrol_goal(state: CombatEnemyState) -> Vector2i:
	var blocked := occupied_enemy_cells(state.id)
	if state.patrol_goal != INVALID_CELL and state.patrol_goal != state.pos and is_walkable(state.patrol_goal) and not blocked.has(state.patrol_goal) and _find_path(state.pos, state.patrol_goal, blocked).size() >= 2:
		return state.patrol_goal
	var candidates: Array[Vector2i] = []
	for y in range(rows):
		for x in range(cols):
			var cell := Vector2i(x, y)
			if cell == state.pos or not is_walkable(cell) or blocked.has(cell):
				continue
			if _find_path(state.pos, cell, blocked).size() >= 2:
				candidates.append(cell)
	if candidates.is_empty():
		state.patrol_goal = INVALID_CELL
		return state.patrol_goal
	var bias := player_pos if state.last_seen == INVALID_CELL else state.last_seen
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var bias_a := manhattan(a, bias)
		var bias_b := manhattan(b, bias)
		if bias_a != bias_b:
			return bias_a < bias_b
		return manhattan(a, state.pos) > manhattan(b, state.pos)
	)
	var pool_size := mini(candidates.size(), maxi(3, ceili(float(candidates.size()) / 3.0)))
	state.patrol_goal = candidates[rng.randi_range(0, pool_size - 1)]
	event_log.append("PatrolGoalSelected goal=%s" % state.patrol_goal)
	return state.patrol_goal


func has_decoy() -> bool:
	return decoy_pos.x >= 0 and decoy_pos.y >= 0


func _tile_height(pos: Vector2i) -> int:
	return int(heights.get(pos, 0))


func _find_path(start: Vector2i, goal: Vector2i, blocked_cells: Dictionary = {}, allow_portals: bool = true) -> Array[Vector2i]:
	var queue: Array[Vector2i] = []
	queue.append(start)
	var came_from: Dictionary = {start: start}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == goal:
			break
		for dir in DIRS:
			var next: Vector2i = current + dir
			if not is_walkable(next) or came_from.has(next) or blocked_cells.has(next):
				continue
			came_from[next] = current
			queue.append(next)
		if allow_portals and portals.has(current):
			var portal_next: Vector2i = portals[current]
			if is_walkable(portal_next) and not came_from.has(portal_next) and not blocked_cells.has(portal_next):
				came_from[portal_next] = current
				queue.append(portal_next)
	if not came_from.has(goal):
		var fallback: Array[Vector2i] = []
		fallback.append(start)
		return fallback
	var reversed: Array[Vector2i] = []
	reversed.append(goal)
	var cursor := goal
	while cursor != start:
		cursor = came_from[cursor]
		reversed.append(cursor)
	reversed.reverse()
	return reversed


func _has_line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	if not is_walkable(a) or not is_walkable(b):
		return false
	var dx := b.x - a.x
	var dy := b.y - a.y
	var samples := maxi(absi(dx), absi(dy))
	if samples <= 1:
		return true
	var eye_height := maxi(_tile_height(a), _tile_height(b))
	var visited: Dictionary = {}
	for i in range(1, samples):
		var t := float(i) / float(samples)
		var cell := Vector2i(roundi(lerpf(float(a.x), float(b.x), t)), roundi(lerpf(float(a.y), float(b.y), t)))
		if visited.has(cell):
			continue
		visited[cell] = true
		if walls.has(cell) or _tile_height(cell) > eye_height:
			return false
	return true


func _follow_portal(pos: Vector2i, _who: String = "enemy", blocked_cells: Dictionary = {}) -> Vector2i:
	if not portals.has(pos):
		return pos
	var destination: Vector2i = portals[pos]
	if not is_walkable(destination) or blocked_cells.has(destination):
		return pos
	return destination


func _shuffle(items: Array[String]) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := items[i]
		items[i] = items[j]
		items[j] = temp


func _array_pos(raw: Array) -> Vector2i:
	return Vector2i(int(raw[0]), int(raw[1]))


func _parse_pos(raw: String) -> Vector2i:
	var parts := raw.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))
var _smb_tail_padding := """
[i] = items[j]
		items[j] = temp


func _array_pos(raw: Array) -> Vector2i:
	return Vector2i(int(raw[0]), int(raw[1]))


func _parse_pos(raw: String) -> Vector2i:
	var parts := raw.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

This padding block intentionally stays longer than an obsolete SMB file tail.
It prevents stale bytes on the shared volume from being parsed as GDScript.
"""
# SMB_SAFE_PADDING_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ
var _smb_tail_padding_2 := """
or2i:
	var parts := raw.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

Additional shared-volume tail padding keeps obsolete bytes inert.
"""
# SMB_SAFE_PADDING_2_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ
var _smb_tail_padding_3 := """
DING_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ
var _smb_tail_padding_2 := [obsolete triple quote removed]
or2i:
	var parts := raw.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

Additional shared-volume tail padding keeps obsolete bytes inert.
[obsolete triple quote removed]
# SMB_SAFE_PADDING_2_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ

Final oversized padding for SMB volumes that retain bytes after a shorter rewrite.
"""
# SMB_FINAL_PADDING_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz_0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ
