class_name CombatStatus
extends RefCounted

## Canonical combat-status shape shared by rules and presentation.
## Resources such as HP, shield and toughness use the same display contract,
## but remain separate from ordinary buff/debuff lifecycle rules.

const CATEGORY_BUFF := "buff"
const CATEGORY_DEBUFF := "debuff"
const CATEGORY_CONTROL := "control"
const CATEGORY_PASSIVE := "passive"
const CATEGORY_RESOURCE := "resource"
const CATEGORY_HAZARD := "hazard"
const DURATION_PERMANENT := "permanent"
const DURATION_TURNS := "turns"
const DURATION_NEXT_ACTION := "next_action"
const DURATION_UNTIL_TRIGGERED := "until_triggered"
const DURATION_SOURCE := "source"
const NO_DURATION := -1
const PRESENTATION_BADGE := "badge"
const PRESENTATION_CARD_ICON := "card_icon"
const PRESENTATION_TEXTURE := "texture"
const PRESENTATION_MODEL := "model"


static func make(
		status_id: String,
		category: String,
		label: String,
	stacks: int = 1,
	duration: int = NO_DURATION,
	duration_type: String = DURATION_PERMANENT,
	source: String = "",
	detail: String = "",
	icon: String = "") -> Dictionary:
	return {
		"id": status_id,
		"category": category,
		"label": label,
		"stacks": maxi(0, stacks),
		"duration": duration,
		"duration_type": duration_type,
		"source": source,
		"detail": detail,
		"icon": icon,
		"presentation_kind": PRESENTATION_BADGE,
		"presentation_id": "",
	}


static func normalize(status_id: String, raw_status: Variant) -> Dictionary:
	var raw: Dictionary = raw_status if raw_status is Dictionary else {}
	var duration := int(raw.get("duration", raw.get("turns", NO_DURATION)))
	var duration_type := str(raw.get("duration_type", raw.get("durationType", "")))
	if duration_type.is_empty():
		duration_type = DURATION_TURNS if duration >= 0 else DURATION_PERMANENT
	var status := make(
		status_id,
		str(raw.get("category", CATEGORY_DEBUFF)),
		str(raw.get("label", status_id)),
		int(raw.get("stacks", 1)),
		duration,
		duration_type,
		str(raw.get("source", "")),
		str(raw.get("detail", raw.get("text", ""))))
	for presentation_field in ["icon", "presentation_kind", "presentation_id"]:
		if raw.has(presentation_field):
			status[presentation_field] = str(raw.get(presentation_field, ""))
	return status


static func display_text(status: Dictionary) -> String:
	var text := str(status.get("label", status.get("id", "状态")))
	var detail := str(status.get("detail", ""))
	if not detail.is_empty() and detail != text:
		text += " · " + detail
	var stacks := int(status.get("stacks", 0))
	var duration := int(status.get("duration", NO_DURATION))
	if stacks > 1:
		text += "×%d" % stacks
	if duration > 0:
		text += " · %d回合" % duration
	return text


static func put(ledger: Dictionary, status: Dictionary) -> void:
	var normalized := normalize(str(status.get("id", "")), status)
	var status_id := str(normalized.get("id", ""))
	if status_id.is_empty():
		return
	ledger[status_id] = normalized


static func remove(ledger: Dictionary, status_id: String) -> void:
	ledger.erase(status_id)


static func tick_turns(ledger: Dictionary) -> Array[String]:
	var expired: Array[String] = []
	for raw_status_id in ledger.keys().duplicate():
		var status_id := str(raw_status_id)
		var status := normalize(status_id, ledger[raw_status_id])
		if str(status.get("duration_type", "")) != DURATION_TURNS:
			continue
		var duration := int(status.get("duration", NO_DURATION)) - 1
		if duration <= 0:
			ledger.erase(raw_status_id)
			expired.append(status_id)
		else:
			status["duration"] = duration
			ledger[raw_status_id] = status
	return expired
