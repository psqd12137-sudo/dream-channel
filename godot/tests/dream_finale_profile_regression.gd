extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var Profile = load("res://scripts/dream_finale_profile.gd")
	for first_large in [false, true]:
		for second_combat in [false, true]:
			for third_combat in [false, true]:
				var materials: Array = [
					{"instance_id": "first", "room_id": "room_first", "room_size": 3 if first_large else 1},
					{"instance_id": "second", "room_id": "room_second", "kind": "combat" if second_combat else "quiet"},
					{"instance_id": "third", "room_id": "room_third", "kind": "combat" if third_combat else "event"},
				]
				var profile: Dictionary = Profile.compose(materials)
				_check(bool(profile.get("valid", false)), "8 组合都应生成有效终幕 profile")
				_check(str(profile.get("route_rule", "")) == ("long_charge" if first_large else "short_charge"), "第一份房间决定冲撞长度")
				_check(str(profile.get("anchor_rule", "")) == ("relay" if second_combat else "breather"), "第二份房间决定熄锚规则")
				_check(str(profile.get("climax_rule", "")) == ("double_sweep" if third_combat else "spotlight"), "第三份房间决定终幕招式")
	var ordered: Dictionary = Profile.compose([
		{"instance_id": "a", "room_id": "one", "room_size": 3},
		{"instance_id": "b", "room_id": "two", "kind": "combat"},
		{"instance_id": "c", "room_id": "three", "kind": "quiet"},
	])
	_check(ordered.get("source_ids", []) == ["a", "b", "c"], "profile 必须保留三份素材的顺序")
	_check(not bool(Profile.compose([]).get("valid", true)), "缺少素材必须报错")
	_check(not bool(Profile.compose([{"instance_id": "a"}, {"instance_id": "b"}]).get("valid", true)), "少于三份素材必须报错")
	_check(not bool(Profile.compose([{"instance_id": "a"}, {"instance_id": "b"}, {}]).get("valid", true)), "缺少来源编号必须报错")
	_check(not bool(Profile.compose([{"instance_id": "a"}, {"instance_id": "a"}, {"instance_id": "c"}]).get("valid", true)), "重复素材必须报错")
	if failures.is_empty():
		print("DREAM_FINALE_PROFILE: PASS")
		quit(0)
	for failure: String in failures:
		push_error("DREAM_FINALE_PROFILE: " + failure)
	quit(1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
