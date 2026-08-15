extends RefCounted

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
var enemy_pos := Vector2i.ZERO
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
var dice_faces: Array = []
var energy_bonus := 0
var placement_discount := 0
var ready_effect: Dictionary = {}
var retain_slots := 0
var retain_this_turn := 0
var damage_bonus := 0
var free_draw_bonus := 0
var free_draw_used := false
var first_smash_bonus := 0
var first_smash_used := false
var decoy_pos := Vector2i(-1, -1)
var enemy_just_portaled := false
var pending_player_portal := INVALID_CELL
var enemy_hp := 6
var enemy_max_hp := 6
var enemy_toughness := 3
var enemy_max_toughness := 3
var enemy_damage := 1
var enemy_action_points := 3
var enemy_attack_cost := 2
var enemy_blind_turns := 0
var enemy_name := "雪花剪影"
var enemy_tier := 1
var ambush_active := false
var ambush_idle_turns := 0
var enemy_revealed := true
var player_sees_enemy := true
var enemy_sees_player := true
var ambush_note := ""
var last_seen := INVALID_CELL
var last_seen_age := 0
var patrol_goal := INVALID_CELL
var enemy_archetype := "execute"
var enemy_archetype_label := "处决匣"
var enemy_archetype_desc := ""
var enemy_broken := false
var execute_bonus_pending := false
var crush_bonus_pending := false
var stagger_pending := false

var cards: Dictionary = {}
var deck: Array[String] = []
var discard: Array[String] = []
var hand: Array[String] = []
var rng := RandomNumberGenerator.new()
var round_number := 1
var outcome := ""
var event_log: Array[String] = []


func setup(arena: Dictionary, enemy: Dictionary, card_defs: Dictionary, starter: Array, seed: int, run_rules: Dictionary = {}, active_relics: Array = []) -> void:
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
	enemy_pos = _array_pos(arena.get("enemy", [cols - 1, 1]))
	player_hp = int(run_rules.get("player_hp", 6))
	player_block = 0
	base_speed = int(run_rules.get("base_speed", 3))
	base_energy = maxi(1, int(run_rules.get("base_energy", base_speed + 2)))
	hand_size = int(run_rules.get("hand_size", 4))
	move_cost = int(run_rules.get("move_cost", 1))
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
	enemy_just_portaled = false
	pending_player_portal = INVALID_CELL
	enemy_hp = int(enemy.get("hp", 6))
	enemy_max_hp = enemy_hp
	enemy_toughness = int(enemy.get("toughness", 3))
	enemy_max_toughness = enemy_toughness
	enemy_damage = int(enemy.get("damage", 1))
	enemy_action_points = int(enemy.get("action_points", 3))
	enemy_attack_cost = int(enemy.get("attack_cost", 2))
	enemy_blind_turns = 0
	enemy_name = str(enemy.get("name", "雪花剪影"))
	enemy_tier = int(enemy.get("tier", 1))
	ambush_active = bool(arena.get("ambush", false)) and not ("omen_bell" in active_relics)
	ambush_idle_turns = 0
	enemy_revealed = not ambush_active
	player_sees_enemy = not ambush_active
	enemy_sees_player = false
	ambush_note = str(arena.get("spawnNote", ""))
	last_seen = INVALID_CELL
	last_seen_age = 0
	patrol_goal = INVALID_CELL
	enemy_archetype = str(enemy.get("archetype", "execute"))
	enemy_archetype_label = str(enemy.get("archetype_label", enemy_archetype))
	enemy_archetype_desc = str(enemy.get("archetype_desc", ""))
	enemy_broken = enemy_toughness <= 0
	execute_bonus_pending = false
	crush_bonus_pending = false
	stagger_pending = false
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
	if ambush_active:
		event_log.append("AmbushHidden note=%s" % ambush_note)
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
	player_pos = target
	pending_player_portal = portals.get(target, INVALID_CELL)
	energy -= move_cost
	_refresh_enemy_visibility()
	event_log.append("PlayerMoved pos=%s energy=%d%s" % [player_pos, energy, " portal_pending=%s" % pending_player_portal if pending_player_portal != INVALID_CELL else ""])
	return true


func can_move_player(target: Vector2i) -> bool:
	return outcome == "" and pending_player_portal == INVALID_CELL and energy >= move_cost and is_walkable(target) and target != enemy_pos and manhattan(player_pos, target) == 1


func has_pending_player_portal() -> bool:
	return pending_player_portal != INVALID_CELL


func can_use_pending_player_portal() -> bool:
	return pending_player_portal != INVALID_CELL and is_walkable(pending_player_portal) and pending_player_portal != enemy_pos


func resolve_player_portal(use_portal: bool) -> bool:
	if pending_player_portal == INVALID_CELL:
		return false
	var entrance := player_pos
	if use_portal:
		if not can_use_pending_player_portal():
			event_log.append("PlayerPortalBlocked exit=%s" % pending_player_portal)
			return false
		player_pos = pending_player_portal
		event_log.append("PlayerUsedPortal from=%s to=%s" % [entrance, player_pos])
	else:
		event_log.append("PlayerStayedAtPortal pos=%s" % entrance)
	pending_player_portal = INVALID_CELL
	_refresh_enemy_visibility()
	return true


func can_target_place_card(hand_index: int, target: Vector2i) -> bool:
	if outcome != "" or pending_player_portal != INVALID_CELL or hand_index < 0 or hand_index >= hand.size():
		return false
	var card: Dictionary = cards.get(hand[hand_index], {})
	if str(card.get("type", "")) != "place" or energy < card_cost(card):
		return false
	if not is_walkable(target) or target == player_pos:
		return false
	var adjacent := manhattan(player_pos, target) == 1
	var smash := target == enemy_pos and _has_line_of_sight(player_pos, enemy_pos)
	if not adjacent and not smash:
		return false
	var place_data: Dictionary = card.get("place", {})
	if bool(place_data.get("decoy", false)):
		return adjacent and not smash and not traps.has(target)
	if not smash and (traps.has(target) or target == decoy_pos):
		return false
	return true


func play_card(hand_index: int, target: Vector2i) -> bool:
	if outcome != "" or pending_player_portal != INVALID_CELL or hand_index < 0 or hand_index >= hand.size():
		return false
	var card_id := hand[hand_index]
	if not cards.has(card_id):
		return false
	var card: Dictionary = cards[card_id]
	var cost := card_cost(card)
	if energy < cost:
		return false
	var card_type := str(card.get("type", ""))
	var accepted := false
	if card_type == "place":
		accepted = _play_place(card, target)
	elif bool(card.get("shove", false)):
		accepted = _play_shove(bool(card.get("preferPortal", false)), int(card.get("drawOnPortal", 0)))
	elif bool(card.get("climbToHigher", false)):
		accepted = _play_climb()
	elif bool(card.get("topple", false)):
		accepted = _play_topple()
	elif card.has("puppetBang"):
		accepted = _play_puppet_bang(card.get("puppetBang", {}))
	elif card.has("saltLash"):
		accepted = _play_salt_lash(card.get("saltLash", {}))
	elif card.has("ifBlinded") or card.has("elseBlind"):
		accepted = _play_blind_followup(card)
	elif card.has("drainTough"):
		accepted = _play_rupture(card)
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
	if target == enemy_pos or _has_line_of_sight(player_pos, enemy_pos):
		reveal_enemy("card")
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


func preview_intent() -> Dictionary:
	var result := {"path": [], "hurt": [], "label": "观望", "detail": "", "type": "stall", "enemy_revealed": enemy_revealed, "sees_player": enemy_sees_player}
	if outcome != "":
		return result
	if enemy_blind_turns > 0:
		result["label"] = "闪瞎 / Blinded"
		result["detail"] = "强光致盲：无法锁定攻击，会继续搜索。"
		result["type"] = "search"
		return result
	if ambush_active and not enemy_sees_player and ambush_idle_turns < 1:
		result["label"] = "埋伏·窥探"
		result["detail"] = "它最多藏这一拍；下个敌方回合会离开出生点巡逻。"
		result["type"] = "ambush"
		return result
	var goal := _enemy_goal()
	if goal == INVALID_CELL:
		result["label"] = "搜寻出口"
		result["detail"] = "暂时没有可达巡逻点。"
		return result
	var simulated := enemy_pos
	var remaining := maxi(1, enemy_action_points - 2) if stagger_pending else enemy_action_points
	while remaining > 0:
		if manhattan(simulated, goal) == 1 and (enemy_sees_player or has_decoy()):
			if remaining >= enemy_attack_cost:
				result["hurt"].append(goal)
				result["label"] = "撕碎纸影" if has_decoy() else "攻击 %d / Hit %d" % [enemy_damage, enemy_damage]
				result["detail"] = "红格将在敌方回合受到 %d 点伤害。" % enemy_damage
				result["type"] = "attack"
			break
		var path := _find_path(simulated, goal)
		if path.size() < 2:
			break
		var next: Vector2i = path[1]
		if next == goal:
			break
		result["path"].append(next)
		simulated = _follow_portal(next)
		remaining -= 1
		if traps.has(simulated):
			remaining -= int((traps[simulated] as Dictionary).get("slow", 0))
	if result["type"] != "attack":
		if enemy_sees_player:
			result["type"] = "chase"
			result["label"] = "追击 %d步" % result["path"].size()
			result["detail"] = "已建立视野；蓝色编号是本回合移动顺序。"
		elif last_seen != INVALID_CELL:
			result["type"] = "search"
			result["label"] = "搜索 %d步" % result["path"].size()
			result["detail"] = "失去视野，正在搜索最后目击点 %s。" % last_seen
		else:
			result["type"] = "patrol"
			result["label"] = "巡逻 %d步" % result["path"].size()
			result["detail"] = "尚未发现你；蓝色编号是它即将巡逻的路线。"
	if result["path"].is_empty() and result["type"] != "attack":
		result["label"] = "重新选点"
		result["detail"] = "当前巡逻点已到达，下回合会选择新的搜查方向。"
	return result


func enemy_turn() -> Array[Dictionary]:
	var turn_events: Array[Dictionary] = []
	if outcome != "":
		return turn_events
	_discard_unretained_hand()
	_refresh_vision(false)
	if ambush_active and not enemy_sees_player:
		ambush_idle_turns += 1
		if ambush_idle_turns <= 1:
			event_log.append("AmbushWaiting turn=%d" % ambush_idle_turns)
			turn_events.append({"kind": "wait", "label": "仍在埋伏点窥探"})
			_finish_enemy_turn()
			return turn_events
		ambush_active = false
		patrol_goal = INVALID_CELL
		event_log.append("AmbushReleasedToPatrol")
		turn_events.append({"kind": "alert", "label": "离开埋伏点，开始巡逻"})
	var remaining := maxi(1, enemy_action_points - 2) if stagger_pending else enemy_action_points
	while remaining > 0 and outcome == "":
		_refresh_vision(false)
		var adjacent_to_decoy := has_decoy() and manhattan(enemy_pos, decoy_pos) == 1
		var adjacent_to_player := enemy_sees_player and manhattan(enemy_pos, player_pos) == 1
		if (adjacent_to_decoy or adjacent_to_player) and remaining >= enemy_attack_cost:
			var attack_event := _resolve_enemy_attack()
			turn_events.append(attack_event)
			break
		var goal := _enemy_goal()
		if goal == INVALID_CELL:
			turn_events.append({"kind": "wait", "label": "没有可达的搜查点"})
			break
		var path := _find_path(enemy_pos, goal)
		if path.size() < 2:
			if not enemy_sees_player and last_seen == INVALID_CELL:
				patrol_goal = INVALID_CELL
				goal = _enemy_goal()
				path = _find_path(enemy_pos, goal) if goal != INVALID_CELL else []
			if path.size() < 2:
				turn_events.append({"kind": "wait", "label": "在遮挡后重新判断方向"})
				break
		var raw_step: Vector2i = path[1]
		if raw_step == player_pos or (has_decoy() and raw_step == decoy_pos):
			turn_events.append({"kind": "wait", "label": "等待攻击窗口"})
			break
		var was_adjacent := manhattan(enemy_pos, player_pos) == 1
		var from := enemy_pos
		var landing := _follow_portal(raw_step)
		enemy_just_portaled = landing != raw_step
		enemy_pos = landing
		var verb := "追击" if enemy_sees_player else "搜索" if last_seen != INVALID_CELL else "巡逻"
		turn_events.append({"kind": "move", "from": from, "to": enemy_pos, "label": verb})
		event_log.append("Enemy%s from=%s to=%s" % [verb, from, enemy_pos])
		remaining -= 1
		_trigger_trap(enemy_pos)
		if traps.has(enemy_pos):
			remaining -= int((traps[enemy_pos] as Dictionary).get("slow", 0))
		_refresh_vision(true)
		if not was_adjacent and manhattan(enemy_pos, player_pos) == 1:
			_trigger_ready()
		if not enemy_sees_player and last_seen == INVALID_CELL and enemy_pos == patrol_goal:
			patrol_goal = INVALID_CELL
	_finish_enemy_turn()
	return turn_events


func _resolve_enemy_attack() -> Dictionary:
	if has_decoy() and manhattan(enemy_pos, decoy_pos) == 1:
		var target := decoy_pos
		event_log.append("EnemyDestroyedDecoy pos=%s" % decoy_pos)
		decoy_pos = Vector2i(-1, -1)
		return {"kind": "attack", "target": target, "damage": 0, "label": "撕碎纸影"}
	var cover := int((traps.get(player_pos, {}) as Dictionary).get("cover_block", 0)) if traps.has(player_pos) else 0
	var absorbed := mini(player_block + cover, enemy_damage)
	player_block -= mini(player_block, absorbed)
	var damage := enemy_damage - absorbed
	player_hp -= damage
	event_log.append("EnemyAttack damage=%d blocked=%d hp=%d" % [damage, absorbed, player_hp])
	if player_hp <= 0:
		outcome = "defeat"
		event_log.append("CombatEnded outcome=defeat")
	return {"kind": "attack", "target": player_pos, "damage": damage, "blocked": absorbed, "label": "攻击"}


func _finish_enemy_turn() -> void:
	_refresh_vision(false)
	if not enemy_sees_player:
		last_seen_age += 1
		if last_seen != INVALID_CELL and last_seen_age >= LAST_SEEN_MEMORY_TURNS:
			last_seen = INVALID_CELL
			patrol_goal = INVALID_CELL
			event_log.append("EnemyLostTrail")
	else:
		last_seen_age = 0
	if outcome == "":
		stagger_pending = false
		if enemy_blind_turns > 0:
			enemy_blind_turns -= 1
		round_number += 1
		_start_player_turn()


func is_walkable(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < cols and pos.y < rows and not walls.has(pos)


func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _play_place(card: Dictionary, target: Vector2i) -> bool:
	if not is_walkable(target) or target == player_pos:
		return false
	var adjacent := manhattan(player_pos, target) == 1
	var smash := target == enemy_pos and _has_line_of_sight(player_pos, enemy_pos)
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
	if smash:
		var damage := int(effect.get("damage", 0))
		var smash_roll: Dictionary = place_data.get("smashRoll", {})
		if not smash_roll.is_empty():
			damage = _roll_smash_damage(smash_roll, str(card.get("id", "?")))
		if _tile_height(player_pos) > _tile_height(enemy_pos):
			damage += int(place_data.get("heightSmashExtra", 1))
		if enemy_broken:
			damage += int(place_data.get("smashBonusIfBroken", 0))
		if not first_smash_used:
			damage += first_smash_bonus
			first_smash_used = true
		var smash_tough := int(place_data.get("smashTough", 1 if damage > 0 else 0))
		_apply_enemy_damage(damage, smash_tough, "smash")
		_apply_blind(effect)
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


func _play_shove(prefer_portal := false, draw_on_portal := 0) -> bool:
	if manhattan(player_pos, enemy_pos) != 1:
		return false
	var ported := _shove_enemy(prefer_portal)
	if ported:
		_draw_cards(draw_on_portal)
	return true


func _shove_enemy(prefer_portal: bool) -> bool:
	var direct := enemy_pos + (enemy_pos - player_pos)
	var best := Vector2i(-999, -999)
	var best_score := -9999
	for raw_dir in DIRS:
		var dir: Vector2i = raw_dir
		var target: Vector2i = enemy_pos + dir
		if not is_walkable(target) or target == player_pos:
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
		_drain_toughness(1, "shove_wall")
		return false
	var landing := _follow_portal(best)
	enemy_just_portaled = landing != best
	enemy_pos = landing
	_trigger_trap(enemy_pos)
	return enemy_just_portaled


func _trigger_trap(pos: Vector2i) -> void:
	if not traps.has(pos):
		return
	var trap: Dictionary = traps[pos]
	var damage := int(trap.get("damage", 0))
	if enemy_just_portaled:
		damage += int(trap.get("portalBonus", 0))
	var default_tough := 2 if damage > 0 else 1 if int(trap.get("slow", 0)) > 0 else 0
	_apply_enemy_damage(damage, int(trap.get("tough", trap.get("toughness", default_tough))), "trap:%s" % str(trap.get("card_id", "trap")))
	_apply_blind(trap)
	if not bool(trap.get("persistent", false)):
		traps.erase(pos)


func _apply_enemy_damage(damage: int, toughness_damage: int, source: String) -> void:
	var execute_before := execute_bonus_pending
	var crush_before := crush_bonus_pending
	_drain_toughness(toughness_damage, source)
	var dealt := maxi(0, damage)
	if dealt > 0:
		dealt += damage_bonus
	if not enemy_broken and enemy_archetype == "armor":
		dealt = maxi(0, dealt - 1)
	if not enemy_broken and enemy_archetype == "wire" and source == "smash":
		dealt = int(ceil(float(dealt) * 0.5))
	if execute_before and (source == "smash" or source.begins_with("trap:")):
		dealt += 2
		execute_bonus_pending = false
	if crush_before and dealt > 0:
		dealt += mini(dealt, 4)
		crush_bonus_pending = false
	enemy_hp -= dealt
	event_log.append("EnemyDamaged source=%s damage=%d hp=%d tough=%d" % [source, dealt, enemy_hp, enemy_toughness])
	if enemy_hp <= 0:
		outcome = "victory"
		event_log.append("CombatEnded outcome=victory")


func _drain_toughness(amount: int, source: String) -> bool:
	if amount <= 0 or enemy_toughness <= 0:
		return false
	enemy_toughness = maxi(0, enemy_toughness - amount)
	if enemy_toughness > 0:
		return false
	enemy_broken = true
	if enemy_archetype == "execute":
		execute_bonus_pending = true
	elif enemy_archetype == "stagger":
		stagger_pending = true
	elif enemy_archetype == "crush":
		crush_bonus_pending = true
	event_log.append("EnemyBroken source=%s archetype=%s" % [source, enemy_archetype])
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


func _trigger_ready() -> void:
	if ready_effect.is_empty():
		return
	player_block += int(ready_effect.get("gainBlock", 0))
	var ready_damage := int(ready_effect.get("damage", 0))
	var ready_tough := int(ready_effect.get("tough", 0))
	if ready_damage > 0 or ready_tough > 0:
		_apply_enemy_damage(ready_damage, ready_tough, "ready")
	_draw_cards(int(ready_effect.get("draw", 0)))
	if bool(ready_effect.get("shove", false)) and outcome == "":
		var hp_before := enemy_hp
		var tough_before := enemy_toughness
		var ported := _shove_enemy(bool(ready_effect.get("preferPortal", false)))
		if hp_before == enemy_hp and tough_before == enemy_toughness:
			_apply_enemy_damage(1, 1, "ready")
		if ported:
			_draw_cards(int(ready_effect.get("drawOnPortal", 0)))
	event_log.append("ReadyTriggered id=%s" % str(ready_effect.get("card_id", "ready")))
	ready_effect.clear()


func _apply_blind(effect: Dictionary) -> void:
	if bool(effect.get("blind", false)):
		enemy_blind_turns = maxi(enemy_blind_turns, int(effect.get("blind_turns", 1)))
		last_seen = INVALID_CELL
		last_seen_age = 0
		enemy_sees_player = false
		patrol_goal = INVALID_CELL
		event_log.append("EnemyBlinded turns=%d" % enemy_blind_turns)


func _play_climb() -> bool:
	var target := Vector2i(-1, -1)
	var target_height := _tile_height(player_pos)
	for raw_dir in DIRS:
		var dir: Vector2i = raw_dir
		var candidate: Vector2i = player_pos + dir
		var height := _tile_height(candidate)
		if is_walkable(candidate) and candidate != enemy_pos and height > target_height:
			target = candidate
			target_height = height
	if target.x < 0:
		return false
	player_pos = target
	event_log.append("PlayerClimbed pos=%s height=%d" % [player_pos, target_height])
	return true


func _play_topple() -> bool:
	if _tile_height(player_pos) <= _tile_height(enemy_pos):
		return false
	_apply_enemy_damage(2, 1, "skill:topple")
	return true


func _play_puppet_bang(effect_value: Variant) -> bool:
	if not has_decoy():
		return false
	var effect: Dictionary = effect_value if effect_value is Dictionary else {}
	_apply_enemy_damage(int(effect.get("damage", 3)), 0, "skill:puppet")
	decoy_pos = Vector2i(-1, -1)
	return true


func _play_salt_lash(effect_value: Variant) -> bool:
	if not traps.has(enemy_pos) or int((traps[enemy_pos] as Dictionary).get("slow", 0)) <= 0:
		return false
	var effect: Dictionary = effect_value if effect_value is Dictionary else {}
	_apply_enemy_damage(int(effect.get("damage", 2)), int(effect.get("tough", 1)), "skill:salt_lash")
	return true


func _play_blind_followup(card: Dictionary) -> bool:
	if enemy_blind_turns > 0 and card.has("ifBlinded"):
		var effect: Dictionary = card.get("ifBlinded", {})
		_apply_enemy_damage(int(effect.get("damage", 0)), int(effect.get("tough", 0)), "skill:blind_followup")
	else:
		enemy_blind_turns = maxi(enemy_blind_turns, int(card.get("elseBlind", 1)))
		event_log.append("EnemyBlinded turns=%d" % enemy_blind_turns)
	return true


func _play_rupture(card: Dictionary) -> bool:
	var was_broken := enemy_broken
	var broke := _drain_toughness(int(card.get("drainTough", 0)), "skill:rupture")
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


func _enemy_goal() -> Vector2i:
	if has_decoy():
		return decoy_pos
	if enemy_sees_player:
		return player_pos
	if last_seen != INVALID_CELL:
		return last_seen
	return _ensure_patrol_goal()


func reveal_enemy(reason: String = "sight") -> void:
	if not enemy_revealed:
		enemy_revealed = true
		event_log.append("AmbushRevealed reason=%s" % reason)
	if reason in ["sight", "card"]:
		ambush_active = false


func _refresh_enemy_visibility() -> void:
	_refresh_vision(true)


func _refresh_vision(emit_events: bool = true) -> void:
	player_sees_enemy = _has_line_of_sight(player_pos, enemy_pos)
	var had_enemy_los := enemy_sees_player
	enemy_sees_player = _has_line_of_sight(enemy_pos, player_pos) and enemy_blind_turns <= 0
	if player_sees_enemy:
		reveal_enemy("player_sight")
	if enemy_sees_player:
		last_seen = player_pos
		last_seen_age = 0
		patrol_goal = INVALID_CELL
		if ambush_active:
			ambush_active = false
			if emit_events:
				event_log.append("AmbushSprung player=%s" % player_pos)
		if emit_events and not had_enemy_los:
			event_log.append("EnemyAcquiredSight player=%s" % player_pos)
	elif emit_events and had_enemy_los:
		event_log.append("EnemyLostSight last_seen=%s" % last_seen)


func _ensure_patrol_goal() -> Vector2i:
	if patrol_goal != INVALID_CELL and patrol_goal != enemy_pos and is_walkable(patrol_goal) and _find_path(enemy_pos, patrol_goal).size() >= 2:
		return patrol_goal
	var candidates: Array[Vector2i] = []
	for y in range(rows):
		for x in range(cols):
			var cell := Vector2i(x, y)
			if cell == enemy_pos or not is_walkable(cell):
				continue
			if _find_path(enemy_pos, cell).size() >= 2:
				candidates.append(cell)
	if candidates.is_empty():
		patrol_goal = INVALID_CELL
		return patrol_goal
	var bias := player_pos if last_seen == INVALID_CELL else last_seen
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var bias_a := manhattan(a, bias)
		var bias_b := manhattan(b, bias)
		if bias_a != bias_b:
			return bias_a < bias_b
		return manhattan(a, enemy_pos) > manhattan(b, enemy_pos)
	)
	var pool_size := mini(candidates.size(), maxi(3, ceili(float(candidates.size()) / 3.0)))
	patrol_goal = candidates[rng.randi_range(0, pool_size - 1)]
	event_log.append("PatrolGoalSelected goal=%s" % patrol_goal)
	return patrol_goal


func has_decoy() -> bool:
	return decoy_pos.x >= 0 and decoy_pos.y >= 0


func _tile_height(pos: Vector2i) -> int:
	return int(heights.get(pos, 0))


func _find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == goal:
			break
		for dir in DIRS:
			var next: Vector2i = current + dir
			if not is_walkable(next) or came_from.has(next):
				continue
			came_from[next] = current
			queue.append(next)
	if not came_from.has(goal):
		return [start]
	var reversed: Array[Vector2i] = [goal]
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


func _follow_portal(pos: Vector2i) -> Vector2i:
	return portals.get(pos, pos)


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
