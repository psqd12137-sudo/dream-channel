class_name EnemyAISquadBlackboard
extends RefCounted

## 回合级敌方战术黑板。
##
## 它不执行移动或伤害，只负责把共享事实（玩家最后位置、占位、攻击位）
## 转成每个敌人的短期战术计划。规则层仍然拥有最终的行动合法性检查。

const INVALID_CELL := Vector2i(-999, -999)

var rules: RefCounted = null
var round_number := 0
var focus_target := INVALID_CELL
var decoy_target := INVALID_CELL
var assignments: Dictionary = {}
var reservations: Dictionary = {}


func begin_turn(target_rules: RefCounted) -> void:
	rules = target_rules
	round_number = int(rules.get("round_number"))
	focus_target = rules.get("player_pos")
	decoy_target = rules.get("decoy_pos") if rules.call("has_decoy") else INVALID_CELL
	assignments.clear()
	reservations.clear()
	var live_enemy_ids: Array[String] = []
	for raw_enemy_id in (rules.get("enemy_order") as Array).duplicate():
		var enemy_id := str(raw_enemy_id)
		var state = rules.call("enemy_by_id", enemy_id)
		if state != null and state.call("alive"):
			rules.call("_refresh_enemy_vision", state, false)
			live_enemy_ids.append(enemy_id)
	# 背刺者的唯一合法攻击位必须先被编队黑板保留；否则普通近战
	# 会先抢走玩家背后一格，导致背刺者的预览和实际行动永远无法汇合。
	var planning_order: Array[String] = []
	for enemy_id in live_enemy_ids:
		var planning_state = rules.call("enemy_by_id", enemy_id)
		if planning_state != null and planning_state.has_trait("backstab"):
			planning_order.append(enemy_id)
	for enemy_id in live_enemy_ids:
		if enemy_id not in planning_order:
			planning_order.append(enemy_id)
	for enemy_id in planning_order:
		plan_enemy(enemy_id)


func plan_enemy(enemy_id: String) -> Dictionary:
	if rules == null:
		return {}
	var state = rules.call("enemy_by_id", enemy_id)
	if state == null or not state.call("alive"):
		assignments.erase(enemy_id)
		return {}
	var previous_cell: Vector2i = state.tactical_reserved_cell
	if previous_cell != INVALID_CELL and reservations.get(previous_cell, "") == enemy_id:
		reservations.erase(previous_cell)
	var role := _resolve_role(state)
	state.ai_role = role
	var plan := _build_plan(state, role)
	assignments[enemy_id] = plan
	state.ai_state = str(plan.get("state", "engage"))
	state.ai_reason = str(plan.get("reason", ""))
	state.tactical_goal = plan.get("goal", INVALID_CELL)
	state.tactical_reserved_cell = plan.get("reserved_cell", INVALID_CELL)
	state.tactical_plan_round = round_number
	var reserved: Vector2i = state.tactical_reserved_cell
	if reserved != INVALID_CELL:
		reservations[reserved] = enemy_id
	return plan


func plan_for(enemy_id: String) -> Dictionary:
	return assignments.get(enemy_id, {})


func _resolve_role(state) -> String:
	var configured := str(state.behavior_role)
	if configured != "" and configured != "auto":
		return configured
	if state.has_trait("backstab"):
		return "flanker"
	if state.has_trait("beam") or state.has_trait("trapAware") or state.has_trait("slam"):
		return "controller"
	if state.has_trait("lunge") or state.has_trait("cornerCut"):
		return "flanker"
	return "hunter"


func _build_plan(state, role: String) -> Dictionary:
	# 规则层只允许埋伏停留一拍；黑板必须使用同一边界，避免预览已经显示巡逻，
	# 实际执行却继续把敌人规划成埋伏状态。
	if state.ambush_active and not state.sees_player and state.ambush_idle_turns < 1:
		return _plan(state, "ambush", state.pos, INVALID_CELL, "埋伏等待玩家暴露")
	if not state.sees_player:
		if state.last_seen != INVALID_CELL:
			return _plan(state, "search", state.last_seen, INVALID_CELL, "前往最后目击点")
		return _plan(state, "patrol", state.patrol_goal, INVALID_CELL, "没有目标，选择巡逻点")
	if decoy_target != INVALID_CELL:
		return _plan(state, "decoy_hunt", decoy_target, INVALID_CELL, "纸傀儡优先级高于玩家")
	var slot := _choose_attack_slot(state, role)
	if slot == INVALID_CELL:
		if state.has_trait("backstab"):
			return _plan(state, "backstab", rules.call("player_back_cell"), INVALID_CELL, "暂时无法抵达背后，保持距离等待绕行")
		return _plan(state, "engage", focus_target, INVALID_CELL, "没有可用攻击位，直接压向玩家")
	if state.has_trait("backstab"):
		return _plan(state, "backstab", slot, slot, "绕到玩家背后，只从背部攻击")
	match role:
		"flanker": return _plan(state, "flank", slot, slot, "侧翼占位，避免与正面敌人重叠")
		"controller": return _plan(state, "control", slot, slot, "优先占据攻击位并控制玩家走位")
	if state.has_trait("ranged"):
		return _plan(state, "engage", slot, slot, "占据视线内的远程射击位")
	if state.has_trait("beam"):
		return _plan(state, "control", slot, slot, "占据直线射击位并控制玩家走位")
	return _plan(state, "engage", slot, slot, "占据独立攻击位")


func _choose_attack_slot(state, role: String) -> Vector2i:
	var candidates: Array[Dictionary] = []
	var blocked: Dictionary = rules.call("occupied_enemy_cells", state.id)
	var candidate_cells: Array[Vector2i] = []
	if state.has_trait("backstab"):
		candidate_cells.append(rules.call("player_back_cell"))
	elif state.has_trait("ranged") or state.has_trait("beam"):
		# 远程敌人不能继续套用近战四邻格；候选位必须由规则层
		# 的同一套攻击计划确认，确保 AI、预览和执行的射程/视线一致。
		for y in range(int(rules.get("rows"))):
			for x in range(int(rules.get("cols"))):
				candidate_cells.append(Vector2i(x, y))
	else:
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			candidate_cells.append(focus_target + direction)
	for cell in candidate_cells:
		if not rules.call("is_walkable", cell) or blocked.has(cell) or reservations.has(cell):
			continue
		var path: Array[Vector2i] = []
		var raw_path: Variant = rules.call("_backstab_path", state) if state.has_trait("backstab") else rules.call("_find_path", state.pos, cell, blocked)
		if raw_path is Array:
			path.assign(raw_path as Array)
		if path.size() < 2 and state.pos != cell:
			continue
		if state.has_trait("ranged") or state.has_trait("beam") or state.has_trait("backstab"):
			var attack_plan: Dictionary = rules.call("_enemy_attack_plan", state, cell, 99, true)
			if attack_plan.is_empty():
				continue
		var height := int(rules.call("_tile_height", cell))
		var side := absi(cell.x - focus_target.x)
		var portal_bonus := 1 if rules.get("portals").has(cell) else 0
		candidates.append({"cell": cell, "distance": path.size(), "height": height, "side": side, "portal": portal_bonus})
	if candidates.is_empty():
		return INVALID_CELL
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if role == "flanker" and int(a["side"]) != int(b["side"]):
			return int(a["side"]) > int(b["side"])
		if role == "controller":
			if int(a["portal"]) != int(b["portal"]):
				return int(a["portal"]) > int(b["portal"])
			if int(a["height"]) != int(b["height"]):
				return int(a["height"]) > int(b["height"])
		if int(a["distance"]) != int(b["distance"]):
			return int(a["distance"]) < int(b["distance"])
		return str(a["cell"]) < str(b["cell"])
	)
	return candidates[0]["cell"]


func _plan(state, ai_state: String, goal: Vector2i, reserved_cell: Vector2i, reason: String) -> Dictionary:
	return {
		"enemy_id": state.id,
		"role": state.ai_role if state.ai_role != "" else "hunter",
		"state": ai_state,
		"goal": goal,
		"reserved_cell": reserved_cell,
		"reason": reason,
		"round": round_number,
	}
