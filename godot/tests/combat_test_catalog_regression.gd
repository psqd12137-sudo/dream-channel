extends SceneTree

const CombatTestCatalog = preload("res://scripts/combat_test_catalog.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := CombatTestCatalog.new()
	_check(catalog.load_from_path(), "combat test catalog must load")
	_check(catalog.errors.is_empty(), "valid catalog must have no errors: %s" % str(catalog.errors))
	_check(catalog.ids().size() == 8, "catalog must expose eight initial scenarios")
	_check(catalog.get_scenario("squad_roles").get("room", {}).get("enemies", []).size() == 3, "squad_roles must contain three enemies")
	var mixed_enemies: Array = catalog.get_scenario("mixed_assault").get("room", {}).get("enemies", [])
	_check(mixed_enemies.size() == 3, "mixed_assault must contain melee, ranged, and backstab enemies")
	_check(int(mixed_enemies[0].get("attack_range", 0)) == 1, "mixed_assault must configure a melee enemy")
	_check(int(mixed_enemies[0].get("action_points", 0)) == 2, "mixed_assault must keep the melee enemy movement budget short")
	_check(int(mixed_enemies[1].get("action_points", 0)) == 2, "mixed_assault must keep the ranged enemy movement budget short")
	_check(int(mixed_enemies[1].get("attack_range", 0)) == 2 and "ranged" in (mixed_enemies[1].get("traits", []) as Array), "mixed_assault must configure a compact two-cell ranged enemy")
	_check(int(mixed_enemies[2].get("hp", 0)) == 1 and int(mixed_enemies[2].get("damage", 0)) >= 8, "mixed_assault must configure the high-damage one-health backstab enemy")
	_check("backstab" in (mixed_enemies[2].get("traits", []) as Array) and str(mixed_enemies[2].get("archetype", "")) == "assassin", "mixed_assault must configure the black backstab archetype")
	_check(catalog.get_scenario("hud_eight").get("room", {}).get("enemies", []).size() == 8, "hud_eight must contain eight enemies")
	_check(catalog.get_scenario("missing").is_empty(), "unknown scenario must resolve to an empty dictionary")
	if failures.is_empty():
		print("CHANNEL_COMBAT_TEST_CATALOG: PASS load-eight-scenarios-validation")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_COMBAT_TEST_CATALOG: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
