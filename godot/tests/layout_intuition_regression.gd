extends SceneTree

func _initialize() -> void:
	if not ResourceLoader.exists("res://scripts/layout_intuition_model.gd"):
		push_error("layout intuition model missing")
		quit(1)
		return
	var model = load("res://scripts/layout_intuition_model.gd").new()
	model.reset()
	assert(model.route().size() == 7, "U-shaped baseline takes six steps")
	assert(model.route(Vector2i(0, 1)).is_empty(), "one blocked branch cuts initial route")
	assert(not model.preview(Vector2i.ZERO, 0, 0).get("valid"), "cannot overlap")
	var p: Dictionary = model.preview(Vector2i(1, 0), 0, 0)
	assert(p.valid and p.contacts == 2 and p.loop, "gap creates two-door loop")
	assert(model.place(Vector2i(1, 0), 0, 0))
	assert(model.route().size() == 3, "closed loop creates shortcut")
	assert(model.route(Vector2i(0, 1)).size() == 3, "shortcut survives blocked old corridor")
	model.undo()
	assert(model.route().size() == 7, "undo restores original graph")
	for i in range(3):
		assert(model.rules.footprint_cells(model.options[i]).size() == [1, 3, 5][i])
	model.reset()
	assert(model.place(Vector2i(0,-1),1,0), "three-cell corridor can extend baseline")
	assert(model.rules.placed.size() == 10)
	model.reset()
	assert(model.place(Vector2i(-1,0),2,0), "five-cell hall can extend baseline")
	assert(model.rules.placed.size() == 12)
	print("LAYOUT_INTUITION: PASS")
	quit()
