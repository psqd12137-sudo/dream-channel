class_name CombatTestSession
extends RefCounted

var active := false
var scenario_id := ""
var scenario: Dictionary = {}
var mode := "manual"
var round_count := 0
var max_rounds := 10
var paused := true
var last_events: Array[Dictionary] = []
var anomalies: Array[String] = []
var last_summary: Dictionary = {}


func begin(next_scenario: Dictionary, next_mode: String) -> void:
	active = true
	scenario = next_scenario.duplicate(true)
	scenario_id = str(scenario.get("id", ""))
	mode = next_mode
	var observer: Dictionary = scenario.get("observer", {})
	max_rounds = maxi(1, int(observer.get("max_rounds", 10)))
	round_count = 0
	paused = next_mode != "observer_auto"
	last_events.clear()
	anomalies.clear()
	last_summary.clear()


func clear() -> void:
	active = false
	scenario_id = ""
	scenario.clear()
	mode = "manual"
	round_count = 0
	max_rounds = 10
	paused = true
	last_events.clear()
	anomalies.clear()
	last_summary.clear()


func record_enemy_phase(events: Array[Dictionary], rules: RefCounted) -> void:
	last_events = events.duplicate(true)
	round_count += 1
	for event in events:
		if str(event.get("actor_id", "")).is_empty():
			anomalies.append("事件缺少 actor_id：%s" % str(event))
	if rules.get("outcome") != "":
		paused = true
	if round_count >= max_rounds:
		paused = true
	last_summary = build_summary(rules)


func build_summary(rules: RefCounted) -> Dictionary:
	var enemies: Array[Dictionary] = []
	for enemy_id in rules.get("enemy_order") as Array:
		var state = rules.call("enemy_by_id", str(enemy_id))
		if state != null:
			enemies.append(state.call("debug_snapshot"))
	return {
		"scenario_id": scenario_id,
		"mode": mode,
		"seed": int(scenario.get("seed", 0)),
		"rounds": round_count,
		"outcome": str(rules.get("outcome")),
		"player_hp": int(rules.get("player_hp")),
		"enemies": enemies,
		"anomalies": anomalies.duplicate(),
	}


func can_advance() -> bool:
	return active and not paused and round_count < max_rounds
