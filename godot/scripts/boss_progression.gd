extends RefCounted

## Formal-run Boss selection and presentation adapter.
##
## The Web snapshot already contains the Boss rules, profiles and endings. This
## helper keeps that data-driven boundary separate from the scene controller so
## the same selection/build rules can be covered without booting the full UI.


static func select_boss_id(snapshot: Dictionary, early_combat: int, late_combat: int) -> String:
	var rules: Array = snapshot.get("rules", [])
	for raw_rule in rules:
		if not raw_rule is Dictionary:
			continue
		var rule: Dictionary = raw_rule
		var when: Dictionary = rule.get("when", {})
		if when.has("earlyCombat") and early_combat != int(when.get("earlyCombat", 0)):
			continue
		if when.has("lateCombatMin") and late_combat < int(when.get("lateCombatMin", 0)):
			continue
		if when.has("lateCombatMax") and late_combat > int(when.get("lateCombatMax", 2147483647)):
			continue
		var candidate := str(rule.get("boss", ""))
		if not candidate.is_empty() and (snapshot.get("bosses", {}) as Dictionary).has(candidate):
			return candidate
	var bosses: Dictionary = snapshot.get("bosses", {})
	if bosses.has("rust_keeper"):
		return "rust_keeper"
	for raw_id in bosses.keys():
		return str(raw_id)
	return ""


static func build_boss_room(snapshot: Dictionary, pressure: Dictionary, altar_room: Dictionary, boss_id: String) -> Dictionary:
	var bosses: Dictionary = snapshot.get("bosses", {})
	var boss: Dictionary = (bosses.get(boss_id, {}) as Dictionary).duplicate(true)
	if boss.is_empty():
		return {}
	var boss_rule: Dictionary = pressure.get("boss", {})
	var profile: Dictionary = (pressure.get("bossProfiles", {}).get(boss_id, {}) as Dictionary).duplicate(true)
	var traits: Array = (boss_rule.get("traits", []) as Array).duplicate()
	var archetype := str(profile.get("archetype", boss_rule.get("archetype", "crush")))
	var boss_spec := {
		"id": "boss_%s" % boss_id,
		"spawn": (altar_room.get("arena", {}).get("enemy", [5, 0]) as Array).duplicate(),
		"name": str(boss.get("name", boss_id)),
		"hp": maxi(1, int(boss.get("hp", 16))),
		"damage": maxi(1, int(boss.get("damage", 2))),
		"toughness": maxi(0, 3 + int(boss_rule.get("toughBonus", 0))),
		"action_points": 4,
		"attack_cost": 2,
		"attack_range": 1,
		"killable": bool(profile.get("killable", true)),
		"archetype": archetype,
		"archetype_label": "Boss",
		"archetype_desc": str(boss.get("intro", "最终敌人")),
		"behavior_role": "hunter",
		"tier": 3,
		"traits": traits,
		"trait_labels": (pressure.get("traitLabels", {}) as Dictionary).duplicate(true),
	}
	var result := altar_room.duplicate(true)
	result["id"] = "altar"
	result["name"] = "祭坛 · %s" % str(boss.get("name", boss_id))
	result["description"] = str(boss.get("intro", "频道核心已经醒来。"))
	result["kind"] = "combat"
	result["boss_room"] = true
	result["boss_id"] = boss_id
	result["boss"] = boss
	result["boss_profile"] = profile
	result["enemy"] = boss_spec.duplicate(true)
	result["enemies"] = [boss_spec]
	return result


static func ending(snapshot: Dictionary, boss_id: String, success: bool) -> Dictionary:
	var bosses: Dictionary = snapshot.get("bosses", {})
	var boss: Dictionary = bosses.get(boss_id, {})
	var ending_id := str(boss.get("endingId", "end_fail")) if success else "end_fail"
	var endings: Dictionary = bosses.get("endings", {})
	var ending_data: Dictionary = endings.get(ending_id, endings.get("end_fail", {}))
	return {
		"id": ending_id,
		"title": str(ending_data.get("title", "结局")),
		"text": str(ending_data.get("text", "节目结束。")),
		"boss_name": str(boss.get("name", boss_id)),
		"boss_message": str(boss.get("victory", "")) if success else str(boss.get("defeat", "")),
		"success": success,
	}
