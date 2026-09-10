class_name DreamDrawRules
extends RefCounted

## Pure rules for the three stage dream nomination.  This file deliberately
## knows nothing about the map, UI, RNG ownership, or the finale.

static func probabilities(records: Array[Dictionary], nomination_id: String, config: Dictionary) -> Dictionary:
	var sorted: Array[Dictionary] = []
	for record: Dictionary in records:
		if str(record.get("instance_id", "")).strip_edges().is_empty():
			continue
		sorted.append(record.duplicate(true))
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("instance_id", "")) < str(b.get("instance_id", ""))
	)
	var count := sorted.size()
	if count < 2:
		return {}
	var nomination := nomination_id.strip_edges()
	if not nomination.is_empty() and not sorted.any(func(record: Dictionary) -> bool:
		return str(record.get("instance_id", "")) == nomination
	):
		return {}
	var cap := maxi(0, int(config.get("damage_weight_cap", 6)))
	var boost := float(config.get("nomination_boost", 2))
	var weights: Dictionary = {}
	var total := 0.0
	for record: Dictionary in sorted:
		var instance_id := str(record.get("instance_id", ""))
		var hp_lost := clampf(float(record.get("hp_lost", 0)), 0.0, float(cap))
		var weight := 1.0 + hp_lost / 2.0
		if instance_id == nomination:
			weight += boost
		weights[instance_id] = weight
		total += weight
	if total <= 0.0:
		return {}
	var uniform_mix := clampf(float(config.get("uniform_mix", 0.5)), 0.0, 1.0)
	var result: Dictionary = {}
	for record: Dictionary in sorted:
		var instance_id := str(record.get("instance_id", ""))
		var weighted := float(weights[instance_id]) / total
		result[instance_id] = uniform_mix / float(count) + (1.0 - uniform_mix) * weighted
	# Normalize once to absorb floating point drift while retaining the
	# formula's relative ordering and the stable sorted key order.
	var sum := 0.0
	for value: Variant in result.values():
		sum += float(value)
	if sum > 0.0:
		for instance_id: String in result.keys():
			result[instance_id] = float(result[instance_id]) / sum
	return result


static func pick(probability_map: Dictionary, roll: float) -> String:
	if probability_map.is_empty():
		return ""
	var ids: Array[String] = []
	for raw_id: Variant in probability_map.keys():
		ids.append(str(raw_id))
	ids.sort()
	var target := clampf(roll, 0.0, 0.999999999)
	var cursor := 0.0
	for instance_id: String in ids:
		cursor += maxf(0.0, float(probability_map.get(instance_id, 0.0)))
		if target < cursor:
			return instance_id
	return ids[-1]


static func token_score(record: Dictionary) -> int:
	var rarity := clampi(int(record.get("rarity_rank", 1)), 1, 3)
	var difficulty := clampi(int(record.get("difficulty_rank", 0)), 0, 2)
	return 2 * rarity + difficulty
