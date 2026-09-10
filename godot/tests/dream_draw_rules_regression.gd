extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var rules = load("res://scripts/dream_draw_rules.gd")
	var rows: Array[Dictionary] = [
		{"instance_id": "b", "hp_lost": 0},
		{"instance_id": "a", "hp_lost": 6}]
	var cfg := {"damage_weight_cap": 6, "nomination_boost": 2, "uniform_mix": 0.5}
	var p: Dictionary = rules.probabilities(rows, "a", cfg)
	_check(p.has("a") and p.has("b"), "both visited rooms receive a probability")
	_check(float(p["a"]) > float(p["b"]) and float(p["a"]) < 1.0 and float(p["b"]) > 0.0, "damage and nomination affect probability without certainty")
	_check(is_equal_approx(float(p["a"]) + float(p["b"]), 1.0), "probabilities sum to one")
	_check(rules.pick(p, 0.0) == "a", "zero roll selects stable first sorted bucket")
	_check(rules.pick(p, 0.999999) == "b", "upper roll selects stable final bucket")
	var one_row: Array[Dictionary] = [rows[0]]
	_check(rules.probabilities(one_row, "b", cfg).is_empty(), "one candidate cannot lock the script")
	_check(rules.probabilities(rows, "missing", cfg).is_empty(), "invalid nomination has no draw")
	_check(rules.token_score({"rarity_rank": 3, "difficulty_rank": 2}) == 8, "token score includes rarity and difficulty")
	var without_score: Dictionary = rules.probabilities(rows, "", cfg)
	_check(is_equal_approx(float(without_score["a"]) + float(without_score["b"]), 1.0), "abstention still produces a complete draw")
	if failures.is_empty():
		print("DREAM_DRAW_RULES: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error("DREAM_DRAW_RULES: " + failure)
		quit(1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
