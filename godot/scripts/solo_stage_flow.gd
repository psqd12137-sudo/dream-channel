class_name SoloStageFlow
extends RefCounted

## Small, serializable controller for the three stage solo trial.
## It owns stage timing only; room candidates and draw presentation live elsewhere.

const VERSION := 1
const STAGE_COUNT := 3

var version := VERSION
var stage := 1
var results: Array[Dictionary] = []
var rng_state := ""
var pending_result: Dictionary = {}
var seed_value := 0
var milestones: Array[int] = [4, 8, 12]
var dream_rng := RandomNumberGenerator.new()

func reset(next_seed: int, config: Dictionary) -> void:
	seed_value = next_seed
	stage = 1
	results.clear()
	pending_result.clear()
	version = VERSION
	milestones = _read_milestones(config.get("milestones", [4, 8, 12]))
	var generator := RandomNumberGenerator.new()
	generator.seed = next_seed if next_seed != 0 else 1
	rng_state = str(generator.state)
	dream_rng.seed = next_seed if next_seed != 0 else 1
	dream_rng.state = int(rng_state)


func next_draw_roll() -> float:
	var roll := dream_rng.randf()
	rng_state = str(dream_rng.state)
	return roll


func due_stage(completed_count: int) -> int:
	if stage < 1 or stage > STAGE_COUNT:
		return 0
	if stage - 1 >= milestones.size():
		return 0
	return stage if completed_count >= milestones[stage - 1] else 0


func accept_result(result: Dictionary) -> bool:
	if stage < 1 or stage > STAGE_COUNT:
		return false
	var result_stage := int(result.get("stage", stage))
	if result_stage != stage:
		return false
	if not result.has("selected_id") and not result.has("nomination_id") and not bool(result.get("abstained", false)):
		return false
	pending_result = result.duplicate(true)
	results.append(pending_result.duplicate(true))
	stage += 1
	return true


func clear_pending_result() -> bool:
	if pending_result.is_empty():
		return false
	pending_result.clear()
	return true


func snapshot() -> Dictionary:
	return {
		"version": version,
		"stage": stage,
		"results": results.duplicate(true),
		"rng_state": rng_state,
		"pending_result": pending_result.duplicate(true),
		"seed": seed_value,
		"milestones": milestones.duplicate(),
	}


func restore(data: Dictionary) -> bool:
	if int(data.get("version", -1)) != VERSION:
		return false
	var saved_stage := int(data.get("stage", 0))
	var saved_results: Variant = data.get("results", [])
	if saved_stage < 1 or saved_stage > STAGE_COUNT + 1 or not saved_results is Array:
		return false
	if (saved_results as Array).size() > STAGE_COUNT:
		return false
	if saved_stage != (saved_results as Array).size() + 1:
		return false
	var saved_pending: Variant = data.get("pending_result", {})
	if not saved_pending is Dictionary:
		return false
	if not (saved_pending as Dictionary).is_empty() and (saved_results as Array).is_empty():
		return false
	var validated_results: Array[Dictionary] = []
	for index in range((saved_results as Array).size()):
		var raw: Variant = (saved_results as Array)[index]
		if not raw is Dictionary:
			return false
		var record: Dictionary = raw as Dictionary
		if int(record.get("stage", 0)) != index + 1:
			return false
		if not _is_result_shape_valid(record):
			return false
		validated_results.append(record.duplicate(true))
	var validated_pending: Dictionary = {}
	if not (saved_pending as Dictionary).is_empty():
		var pending: Dictionary = saved_pending as Dictionary
		if int(pending.get("stage", 0)) < 1 or int(pending.get("stage", 0)) > STAGE_COUNT:
			return false
		if int(pending.get("stage", 0)) != (saved_results as Array).size():
			return false
		if not _is_result_shape_valid(pending):
			return false
		validated_pending = pending.duplicate(true)
	var validated_rng_state := str(data.get("rng_state", ""))
	var validated_seed := int(data.get("seed", 0))
	var validated_milestones := _read_milestones(data.get("milestones", [4, 8, 12]))
	version = VERSION
	stage = saved_stage
	results = validated_results
	rng_state = validated_rng_state
	pending_result = validated_pending
	seed_value = validated_seed
	milestones = validated_milestones
	dream_rng.seed = validated_seed if validated_seed != 0 else 1
	if validated_rng_state.is_valid_int():
		dream_rng.state = int(validated_rng_state)
	return true


func is_finale_ready() -> bool:
	return results.size() == STAGE_COUNT and stage == STAGE_COUNT + 1


func _is_result_shape_valid(result: Dictionary) -> bool:
	return result.has("selected_id") or result.has("nomination_id") or bool(result.get("abstained", false))


func _read_milestones(raw: Variant) -> Array[int]:
	var parsed: Array[int] = []
	if raw is Array:
		for value: Variant in raw:
			if value is int or value is float:
				parsed.append(int(value))
	if parsed.size() != STAGE_COUNT:
		parsed = [4, 8, 12]
	return parsed
