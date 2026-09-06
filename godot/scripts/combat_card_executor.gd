class_name CombatCardExecutor
extends RefCounted

# 卡牌执行器只负责一张牌的一次完整提交；具体效果仍由战斗规则提供。
var _combat_ref: WeakRef
var combat:
	get: return _combat_ref.get_ref() if _combat_ref != null else null


func _init(combat_rules) -> void:
	_combat_ref = weakref(combat_rules)


func execute(hand_index: int, target: Vector2i, enemy_id: String = "") -> bool:
	if combat == null or combat.outcome != "" or hand_index < 0 or hand_index >= combat.hand.size():
		return false
	var card_id := str(combat.hand[hand_index])
	if not combat.cards.has(card_id):
		return false
	var card: Dictionary = combat.cards[card_id]
	var cost: int = combat.card_cost(card)
	if combat.energy < cost:
		return false
	var target_state = combat.resolve_single_enemy(card, enemy_id)
	if combat.card_target_type(card) == "single_enemy" and target_state == null:
		# 多敌人时单体牌必须显式选中合法敌人，否则不消耗。
		return false
	combat.last_card_events.clear()
	if not _dispatch(card_id, card, target, target_state):
		return false
	_commit(card_id, card, cost, target, hand_index)
	return true


func _dispatch(card_id: String, card: Dictionary, target: Vector2i, target_state) -> bool:
	var card_type := str(card.get("type", ""))
	if card_type == "place":
		return combat._play_place(card, target)
	if card.has("allEnemies"):
		return combat._play_all_enemies(card_id, card)
	if card.has("area"):
		return combat._play_area(card_id, card, target)
	if card.has("randomEnemy"):
		return combat._play_random_enemy(card_id, card)
	if bool(card.get("shove", false)):
		return combat._play_shove(bool(card.get("preferPortal", false)), int(card.get("drawOnPortal", 0)), target_state)
	if bool(card.get("climbToHigher", false)):
		return combat._play_climb()
	if bool(card.get("topple", false)):
		return combat._play_topple(target_state)
	if card.has("puppetBang"):
		return combat._play_puppet_bang(card.get("puppetBang", {}), target_state)
	if card.has("saltLash"):
		return combat._play_salt_lash(card.get("saltLash", {}), target_state)
	if card.has("ifBlinded") or card.has("elseBlind"):
		return combat._play_blind_followup(card, target_state)
	if card.has("drainTough"):
		return combat._play_rupture(card, target_state)
	if card.has("gain_block"):
		combat.gain_player_shield(int(card.get("gain_block", 0)), card_id)
		return true
	if card.has("gainBlock"):
		combat.gain_player_shield(int(card.get("gainBlock", 0)), card_id)
		return true
	if card_type == "medicine" or card.has("gainEnergy"):
		combat.energy += int(card.get("gainEnergy", 0))
		combat.turn_energy_max = maxi(combat.turn_energy_max, combat.energy)
		combat.player_hp -= int(card.get("selfDamage", 0))
		return true
	if card_type == "ready":
		combat.ready_effect = (card.get("ready", {}) as Dictionary).duplicate(true)
		combat.ready_effect["card_id"] = card_id
		combat.ready_effect["name"] = str(card.get("name", card_id))
		combat.set_player_status(
			"ready",
			"buff",
			str(card.get("name", "预备")),
			1,
			-1,
			"until_triggered",
			card_id,
			"触发后消失")
		return true
	if card.has("grantRetain"):
		combat.retain_slots = maxi(combat.retain_slots, int(card.get("grantRetain", 0)))
		combat.set_player_status("retain", "buff", "预案", combat.retain_slots, -1, "permanent", card_id, "每回合可额外保留牌")
		return true
	if card.has("retainThisTurn"):
		combat.retain_this_turn += int(card.get("retainThisTurn", 0))
		combat.set_player_status("retain_this_turn", "buff", "本回合保留", combat.retain_this_turn, 1, "turns", card_id, "回合结束时生效")
		return true
	if card.has("discountNext"):
		combat.placement_discount += int(card.get("discountNext", 0))
		combat.set_player_status("place_discount", "buff", "放置减费", combat.placement_discount, 1, "next_action", card_id, "下一张放置牌")
		return true
	return false


func _commit(card_id: String, card: Dictionary, cost: int, target: Vector2i, hand_index: int) -> void:
	combat._commit_card_play(card_id, card, cost, target, hand_index)
