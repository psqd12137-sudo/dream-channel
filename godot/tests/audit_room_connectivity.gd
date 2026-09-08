extends SceneTree

func reachable(c):
	var seen := {}
	var queue: Array = [c.player_pos]
	if c.is_walkable(c.player_pos):
		seen[c.player_pos] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for dir in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = cell + dir
			if c.is_walkable(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen

func _initialize():
	var failures := 0
	var game = load("res://channel_3d.tscn").instantiate()
	# No scene-tree entry or run start: the user's save is never touched.
	game.battle_world_renderer = load("res://scripts/channel_battle_world_renderer.gd").new(game)
	var content = load("res://scripts/web_content_adapter.gd").new().build_content(20260908)
	for room in content.rooms:
		var c = load("res://scripts/combat_rules.gd").new()
		c.setup(room.arena, room.enemies, content.cards, [], 20260908, content.run_rules, [])
		var before = reachable(c)
		game.combat = c
		game.battle_room_context = load("res://scripts/battle_room_art_context.gd").build(room, c.cols, c.rows, game.BATTLE_CELL, 20260908)
		game._apply_battle_footprint_to_combat()
		game._align_battle_terrain_to_room_context()
		var seen = reachable(c)
		var unreachable: Array = []
		var enemies: Array = []
		var total := 0
		for y in range(c.rows):
			for x in range(c.cols):
				var cell := Vector2i(x,y)
				if c.is_walkable(cell):
					total += 1
					if not seen.has(cell):
						unreachable.append(str(cell))
		for id in c.enemy_order:
			var e = c.enemy_by_id(id)
			if not seen.has(e.pos):
				enemies.append(str(e.pos))
		print("AUDIT ", JSON.stringify({"id":room.id,"name":room.name,"kind":room.kind,"size":[c.cols,c.rows],"raw_reachable":before.size(),"walkable":total,"reachable":seen.size(),"unreachable":unreachable,"enemies_cut_off":enemies,"spawn":str(c.player_pos)}))
		if not unreachable.is_empty() or not enemies.is_empty():
			failures += 1
		for cell in game.battle_backstage_cells:
			if c.is_walkable(cell):
				failures += 1
	game.room_rules.placed.clear()
	for x in range(4):
		game.room_rules.placed[Vector2i(x, 0)] = {"instance_id": str(x), "visited": true, "doors": [false, true, false, true]}
	game.current_room_pos = Vector2i.ZERO
	if game.house_path_to(Vector2i(3, 0)).size() != 4:
		failures += 1
	game.room_rules.placed[Vector2i(1, 0)]["visited"] = false
	if not game.house_path_to(Vector2i(3, 0)).is_empty() or game.house_path_to(Vector2i(1, 0)).size() != 2:
		failures += 1
	game.room_rules.placed[Vector2i(1, 0)]["visited"] = true
	game.room_rules.placed[Vector2i(1, 0)]["doors"] = [false, false, false, true]
	if not game.house_path_to(Vector2i(3, 0)).is_empty():
		failures += 1
	print("ROOM_PASSABILITY: ", "PASS" if failures == 0 else "FAIL", " connectivity, footprint exclusions, explored-room routing")
	game.free()
	quit(1 if failures > 0 else 0)
