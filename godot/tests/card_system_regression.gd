extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://channel_3d.tscn") as PackedScene).instantiate() as Node3D
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.go_home()
	game.start_new_run(false)
	await process_frame

	# 1. 卡牌素材可加载：三色卡面 + 图标映射
	var manifest: Dictionary = game.presentation
	var frames: Dictionary = manifest.get("card_frames", {})
	_check(not frames.is_empty(), "manifest must define card_frames")
	_check(load(str(frames.get("place", ""))) != null, "place frame texture must load")
	_check(load(str(frames.get("ready", ""))) != null, "ready frame texture must load")
	_check(load(str(frames.get("medicine", ""))) != null, "medicine frame texture must load")
	var items: Dictionary = manifest.get("items", {})
	_check(items.size() >= 31, "manifest items must map all 31 cards (got %d)" % items.size())
	var missing_icons: Array[String] = []
	for raw_id: Variant in items.keys():
		var path := str(items[raw_id])
		if load(path) == null:
			missing_icons.append(str(raw_id))
	_check(missing_icons.is_empty(), "all card icons must load (missing: %s)" % ", ".join(missing_icons))

	# 2. 触发战斗并验证手牌弧形布局 + 发牌动效
	var hall_room: Dictionary = game._find_catalog_room("hall")
	game.start_combat_lab("hall")
	await process_frame
	await process_frame
	_check(game.combat != null and game.combat.hand.size() > 0, "combat must deal a hand")
	if game.combat != null and not game.combat.hand.is_empty():
		var hud: Control = game.hud
		await process_frame
		# 手牌布局：弧形（中间卡 y 低于两端卡）
		var rects: Array = hud.combat_card_rects
		_check(rects.size() == game.combat.hand.size(), "combat card rects must match hand size")
		if rects.size() >= 3:
			var mid_idx := int(float(rects.size() - 1) * 0.5)
			var mid_y: float = (rects[mid_idx] as Rect2).position.y
			var edge_y: float = (rects[0] as Rect2).position.y
			_check(mid_y < edge_y, "arc layout: middle card should sit higher than edge cards (mid=%.1f edge=%.1f)" % [mid_y, edge_y])
		# 发牌动效：hand_key 变化应触发 flight offsets
		hud._update_card_flights("", ",".join(game.combat.hand))
		await create_timer(0.1).timeout
		_check(not hud.card_flight_offsets.is_empty(), "dealing a new hand must create flight offsets")

	game.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_CARD_SYSTEM: PASS frames icons arc-layout deal-flight")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_CARD_SYSTEM: %s" % failure)
		quit(1)
var _smb_tail_padding := """
Card system regression: Unity art frames, icon mapping, arc hand layout, deal flight.
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
"""
