@tool
extends Control

const APP_FONT: Font = preload("res://assets/fonts/SourceHanSansCN-Regular.otf")


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 800)), Color("111923"), true)
	draw_rect(Rect2(20, 96, 952, 578), Color("263844"), true)
	draw_string(APP_FONT, Vector2(28, 42), "战斗 UI 调整场景 · 拖动彩色区域后保存", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("fff0cf"))
	draw_string(APP_FONT, Vector2(28, 70), "主游戏会读取 IntentArea / ActionArea / HandArea / DeckArea / DiscardArea 的 Rect。", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("a9c8c3"))

