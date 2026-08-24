class_name EnemyTurnScheduler
extends RefCounted

# 顺序敌方调度器（multi-enemy refactor plan 3.4 / 阶段 D）。
# - 每个敌方阶段复制当前 enemy_order 作为本阶段稳定队列；
# - 按 enemy_order 顺序处理，行动前重新确认仍存活；
# - 玩家死亡立即停止队列；全灭由伤害结算判定，不再触发残留行动；
# - 阶段中新生成的敌人不在本阶段队列里，从下一敌方阶段开始行动；
# - 所有敌人事件由 CombatRules._single_enemy_turn 生成并携带 actor_id。

var rules: RefCounted = null


func _init(target_rules: RefCounted = null) -> void:
	rules = target_rules


func run_turn(queue_override: Array = []) -> Array[Dictionary]:
	var turn_events: Array[Dictionary] = []
	if rules == null or rules.get("outcome") != "":
		return turn_events
	rules.call("_discard_unretained_hand")
	var queue: Array = queue_override.duplicate() if not queue_override.is_empty() else (rules.get("enemy_order") as Array).duplicate()
	for enemy_id in queue:
		var state: RefCounted = (rules.get("enemies") as Dictionary).get(enemy_id)
		if state == null or not state.call("alive"):
			continue
		rules.set("_acting_enemy", state)
		turn_events.append_array(rules.call("_single_enemy_turn", state))
		if rules.get("outcome") != "":
			break
	rules.set("_acting_enemy", null)
	rules.call("_finish_enemy_turn")
	return turn_events
