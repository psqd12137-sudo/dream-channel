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
	for raw_enemy_id in (rules.get("enemy_order") as Array).duplicate():
		var state = rules.call("enemy_by_id", str(raw_enemy_id))
		if state != null and state.call("alive"):
			rules.call("_refresh_enemy_vision", state, false)
		plan_enemy(str(raw_enemy_id))


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
	if state.has_trait("beam") or state.has_trait("trapAware") or state.has_trait("slam"):
		return "controller"
	if state.has_trait("lunge") or state.has_trait("cornerCut"):
		return "flanker"
	return "hunter"


func _build_plan(state, role: String) -> Dictionary:
	if state.ambush_active and not state.sees_player:
		return _plan(state, "ambush", state.pos, INVALID_CELL, "埋伏等待玩家暴露")
	if not state.sees_player:
		if state.last_seen != INVALID_CELL:
			return _plan(state, "search", state.last_seen, INVALID_CELL, "前往最后目击点")
		return _plan(state, "patrol", state.patrol_goal, INVALID_CELL, "没有目标，选择巡逻点")
	if decoy_target != INVALID_CELL:
		return _plan(state, "decoy_hunt", decoy_target, INVALID_CELL, "纸傀儡优先级高于玩家")
	var slot := _choose_attack_slot(state, role)
	if slot == INVALID_CELL:
		return _plan(state, "engage", focus_target, INVALID_CELL, "没有可用攻击位，直接压向玩家")
	match role:
		"flanker": return _plan(state, "flank", slot, slot, "侧翼占位，避免与正面敌人重叠")
		"controller": return _plan(state, "control", slot, slot, "优先占据攻击位并控制玩家走位")
	return _plan(state, "engage", slot, slot, "占据独立攻击位")


func _choose_attack_slot(state, role: String) -> Vector2i:
	var candidates: Array[Dictionary] = []
	var blocked: Dictionary = rules.call("occupied_enemy_cells", state.id)
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var cell: Vector2i = focus_target + direction
		if not rules.call("is_walkable", cell) or blocked.has(cell) or reservations.has(cell):
			continue
		var path: Array = rules.call("_find_path", state.pos, cell, blocked)
		if path.size() < 2 and state.pos != cell:
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
