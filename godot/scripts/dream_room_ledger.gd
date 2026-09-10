class_name DreamRoomLedger
extends RefCounted

## Serializable room experiences used by the dream draw prototype.
## A physical room may occupy several cells, so instance_id is the only key.

const VERSION := 1

var _records: Dictionary = {}


func visit(record: Dictionary) -> void:
	var instance_id := str(record.get("instance_id", "")).strip_edges()
	if instance_id.is_empty() or not bool(record.get("visited", false)):
		return
	var room_id := str(record.get("room_id", record.get("id", "")))
	if _is_entrance_record(record, instance_id):
		return
	var previous: Dictionary = _records.get(instance_id, {})
	var normalized := {
		"instance_id": instance_id,
		"room_id": room_id,
		"name": str(record.get("name", room_id)),
		"kind": str(record.get("kind", "quiet")),
		"encounter_tier": str(record.get("encounter_tier", "")),
		"room_size": maxi(1, int(record.get("room_size", 1))),
		"visited": true,
		"hp_lost": maxi(0, int(previous.get("hp_lost", 0))),
		"rarity_rank": clampi(int(record.get("rarity_rank", previous.get("rarity_rank", 1))), 1, 3),
		"difficulty_rank": clampi(int(record.get("difficulty_rank", previous.get("difficulty_rank", _difficulty_for(record)))), 0, 2),
	}
	# Keep metadata from the first visit, but allow later calls to fill missing text.
	for key in ["name", "kind", "encounter_tier", "room_id"]:
		if str(normalized[key]).is_empty() and previous.has(key):
			normalized[key] = previous[key]
	_records[instance_id] = normalized


func record_hp_loss(instance_id: String, amount: int) -> void:
	var key := instance_id.strip_edges()
	if key.is_empty() or not _records.has(key) or amount <= 0:
		return
	var record: Dictionary = _records[key]
	record["hp_lost"] = maxi(int(record.get("hp_lost", 0)), int(record.get("hp_lost", 0)) + amount)
	_records[key] = record


func candidates(excluded_ids: Array) -> Array[Dictionary]:
	var excluded: Dictionary = {}
	for raw_id in excluded_ids:
		excluded[str(raw_id)] = true
	var excluded_room_ids: Dictionary = {}
	for raw_id in _records.keys():
		var instance_id := str(raw_id)
		if excluded.has(instance_id):
			excluded_room_ids[str((_records[instance_id] as Dictionary).get("room_id", ""))] = true
	var result: Array[Dictionary] = []
	for raw_id in _records.keys():
		var instance_id := str(raw_id)
		var record: Dictionary = _records[instance_id]
		var room_id := str(record.get("room_id", ""))
		if excluded.has(instance_id) or excluded.has(room_id) or excluded_room_ids.has(room_id):
			continue
		if bool(record.get("visited", false)):
			result.append(record.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_hp := int(a.get("hp_lost", 0))
		var b_hp := int(b.get("hp_lost", 0))
		if a_hp != b_hp:
			return a_hp > b_hp
		return str(a.get("instance_id", "")) < str(b.get("instance_id", ""))
	)
	return result


func snapshot() -> Dictionary:
	var records: Array[Dictionary] = []
	for record: Dictionary in candidates([]):
		records.append(record.duplicate(true))
	return {"version": VERSION, "records": records}


func restore(data: Dictionary) -> bool:
	if int(data.get("version", -1)) != VERSION:
		return false
	var raw_records: Variant = data.get("records", [])
	if not raw_records is Array:
		return false
	var restored: Dictionary = {}
	for raw: Variant in raw_records:
		if not raw is Dictionary:
			return false
		var record: Dictionary = raw as Dictionary
		var instance_id := str(record.get("instance_id", "")).strip_edges()
		if instance_id.is_empty() or not bool(record.get("visited", false)):
			return false
		if _is_entrance_record(record, instance_id):
			return false
		record["hp_lost"] = maxi(0, int(record.get("hp_lost", 0)))
		record["rarity_rank"] = clampi(int(record.get("rarity_rank", 1)), 1, 3)
		record["difficulty_rank"] = clampi(int(record.get("difficulty_rank", 0)), 0, 2)
		restored[instance_id] = record.duplicate(true)
	_records = restored
	return true


func _difficulty_for(record: Dictionary) -> int:
	var tier := str(record.get("encounter_tier", "")).to_lower()
	if tier in ["elite", "boss"]:
		return 2
	if tier in ["beat", "combat", "normal"] or str(record.get("kind", "")) == "combat":
		return 1
	return 0


func _is_entrance_record(record: Dictionary, instance_id: String = "") -> bool:
	var room_id := str(record.get("room_id", record.get("id", ""))).strip_edges()
	var name := str(record.get("name", "")).strip_edges()
	return instance_id == "start@0,0" or bool(record.get("is_entrance", false)) or room_id in ["", "start", "foyer", "玄关"] or name in ["玄关", "foyer", "起点"]
