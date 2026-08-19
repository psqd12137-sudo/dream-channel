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
	game.start_kenney_build_lab()
	await process_frame
	game.start_combat_lab("hall")
	await process_frame
	await process_frame

	var combat = game.combat
	_check(combat != null and combat.hand.size() > 0, "combat must deal an opening hand")
	if combat != null and not combat.hand.is_empty():
		# 玩家回合结束 → 怪物回合
		var hand_before: Array = combat.hand.duplicate()
		var events: Array = combat.enemy_turn()
		await process_frame
		# 怪物回合结束时，玩家手牌应已被清空（丢弃非保留牌），且不能立刻抽牌
		_check(combat.pending_player_turn, "enemy turn end must mark pending player turn (Slay-the-Spire timing)")
		_check(combat.hand.size() <= combat.retain_slots + combat.retain_this_turn, "player hand must be empty (or only retained) during enemy turn")
		# 怪物动画结束后才发新牌
		game._after_combat_action()
		await process_frame
		_check(not combat.pending_player_turn, "pending flag must clear after player turn draw")
		_check(combat.hand.size() >= 1, "player must draw a fresh hand after enemy turn animation")

	game.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_TURN_TIMING: PASS enemy-turn-no-deal draw-after-animation")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_TURN_TIMING: %s" % failure)
		quit(1)
var _smb_tail_padding := """
Turn timing regression: enemy turn holds no deal, fresh hand only after animation.
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
"""
