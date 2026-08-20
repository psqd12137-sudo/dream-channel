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
	game.start_combat_lab("hall")
	await process_frame
	await process_frame
	_check(game.combat != null and game.combat.hand.size() > 0, "combat must deal a hand")
	if game.combat != null and not game.combat.hand.is_empty():
		var hud: Control = game.hud
		# 等发牌飞行动画结束（flight offsets 清空）再检查静态布局
		await create_timer(0.5).timeout
		hud.queue_redraw()
		await process_frame
		# 手牌布局：固定宽度、均匀重叠错落（不再按数量压扁）
		var rects: Array = hud.combat_card_rects
		_check(rects.size() == game.combat.hand.size(), "combat card rects must match hand size")
		if rects.size() >= 2:
			var first_w: float = (rects[0] as Rect2).size.x
			var gap: float = (rects[1] as Rect2).position.x - (rects[0] as Rect2).position.x
			_check(is_equal_approx(first_w, 120.0), "hand cards must keep a fixed width")
			_check(gap > 0.0 and gap < first_w, "hand cards must overlap with fixed spacing")
			for i in range(1, rects.size()):
				_check(is_equal_approx((rects[i] as Rect2).position.x - (rects[i - 1] as Rect2).position.x, gap), "hand spacing must stay uniform")
		# 发牌动效：逐张飞行（stagger 延迟应使不同卡同时处于不同进度）
		hud._update_card_flights("", ",".join(game.combat.hand))
		await create_timer(0.06).timeout
		var offsets_after: Dictionary = hud.card_flight_offsets
		_check(not offsets_after.is_empty(), "dealing a new hand must create flight offsets")
		# 逐张验证：第一张卡已飞行一段，最后一张还在初始位置附近
		var ids: Array = []
		for raw_id: Variant in offsets_after.keys():
			ids.append(str(raw_id))
		if ids.size() >= 2:
			var first_offset: Vector2 = offsets_after[ids[0]]
			var last_offset: Vector2 = offsets_after[ids[ids.size() - 1]]
			_check(first_offset.length_squared() < last_offset.length_squared() or not is_equal_approx(first_offset.length(), last_offset.length()), "staggered deal: cards should fly one by one (first=%.0f last=%.0f)" % [first_offset.length(), last_offset.length()])
		# 收牌动效：打出一张卡后应进入离场列表并飞向弃牌堆
		if game.combat.hand.size() > 0:
			var played_id := str(game.combat.hand[0])
			hud._update_card_flights(",".join(game.combat.hand), ",".join(game.combat.hand.slice(1)))
			await process_frame
			var found_exit := false
			for entry: Dictionary in hud.exiting_cards:
				if str(entry.get("id", "")) == played_id:
					found_exit = true
					break
			_check(found_exit, "discarded card must enter exiting_cards for flight to discard pile")
			await create_timer(0.30).timeout
			var still_exit := false
			for entry: Dictionary in hud.exiting_cards:
				if str(entry.get("id", "")) == played_id:
					still_exit = true
					break
			_check(not still_exit, "exiting card must be removed after flight completes")

	game.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_CARD_SYSTEM: PASS frames icons staggered-hand deal-flight")
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
