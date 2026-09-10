class_name DreamFinaleProfile
extends RefCounted

## Deterministic, serializable bridge from the three stage materials to the
## final PvE programme.  The profile is composed once when the programme list
## is opened and is then reused by both the preview and the actual finale.
const VERSION := 1


static func compose(materials: Array) -> Dictionary:
	if materials.size() != 3:
		return _error("终幕必须由恰好三份阶段素材组成。")
	var normalized: Array[Dictionary] = []
	var seen: Dictionary = {}
	for index in range(materials.size()):
		var raw: Variant = materials[index]
		if not raw is Dictionary:
			return _error("第 %d 份阶段素材资料缺失。" % (index + 1))
		var material: Dictionary = (raw as Dictionary).duplicate(true)
		var source_id := str(material.get("instance_id", material.get("room_id", material.get("id", "")))).strip_edges()
		if source_id.is_empty():
			return _error("第 %d 份阶段素材没有来源编号。" % (index + 1))
		if seen.has(source_id):
			return _error("终幕素材不能重复使用同一房间。")
		seen[source_id] = true
		material["source_id"] = source_id
		normalized.append(material)

	var first := normalized[0]
	var second := normalized[1]
	var third := normalized[2]
	var route_rule := "long_charge" if int(first.get("room_size", first.get("size", 1))) >= 3 else "short_charge"
	var anchor_rule := "relay" if str(second.get("kind", "quiet")) == "combat" else "breather"
	var climax_rule := "double_sweep" if str(third.get("kind", "quiet")) == "combat" else "spotlight"
	return {
		"version": VERSION,
		"valid": true,
		"error": "",
		"name": _name_for(route_rule, anchor_rule, climax_rule),
		"source_ids": [str(first.source_id), str(second.source_id), str(third.source_id)],
		"route_rule": route_rule,
		"anchor_rule": anchor_rule,
		"climax_rule": climax_rule,
		"route_room_id": str(first.get("room_id", first.get("id", ""))),
		"anchor_room_id": str(second.get("room_id", second.get("id", ""))),
		"climax_room_id": str(third.get("room_id", third.get("id", ""))),
	}


static func _name_for(route_rule: String, anchor_rule: String, climax_rule: String) -> String:
	var route_name := "长冲撞" if route_rule == "long_charge" else "短冲撞"
	var anchor_name := "接力熄锚" if anchor_rule == "relay" else "喘息熄锚"
	var climax_name := "双重扫场" if climax_rule == "double_sweep" else "聚光终击"
	return "%s · %s · %s" % [route_name, anchor_name, climax_name]


static func _error(message: String) -> Dictionary:
	return {
		"version": VERSION,
		"valid": false,
		"error": message,
		"name": "",
		"source_ids": [],
		"route_rule": "",
		"anchor_rule": "",
		"climax_rule": "",
	}
