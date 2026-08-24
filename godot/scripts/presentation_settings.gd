class_name ChannelPresentationSettings
extends RefCounted

## Window, post-process and title-video settings.
##
## This is intentionally independent from run state. These values describe
## the presentation shell and must survive title-screen transitions without
## becoming part of a playable run save.

const DISPLAY_SETTINGS_PATH := "user://channel_display.cfg"
const DISPLAY_RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var host: Node
var world_container: SubViewportContainer
var hud: Control
var home_video: VideoStreamPlayer

var resolution_index := 2
var fullscreen := false
var tilt_shift_enabled := true
var change_generation := 0


func _init(next_host: Node, next_world_container: SubViewportContainer, next_hud: Control, next_home_video: VideoStreamPlayer) -> void:
	host = next_host
	world_container = next_world_container
	hud = next_hud
	home_video = next_home_video


func resolution_label() -> String:
	var resolution: Vector2i = DISPLAY_RESOLUTIONS[resolution_index]
	return "%d×%d" % [resolution.x, resolution.y]


func mode_label() -> String:
	return "全屏" if fullscreen else "窗口"


func tilt_shift_label() -> String:
	return "移轴 开" if tilt_shift_enabled else "移轴 关"


func cycle_resolution() -> void:
	resolution_index = (resolution_index + 1) % DISPLAY_RESOLUTIONS.size()
	_apply_display_settings(true)


func toggle_mode() -> void:
	fullscreen = not fullscreen
	_apply_display_settings(true)


func toggle_tilt_shift() -> void:
	tilt_shift_enabled = not tilt_shift_enabled
	_apply_tilt_shift_state()
	_save_display_settings()
	host._refresh_hud()


func load_settings() -> void:
	var settings := ConfigFile.new()
	if settings.load(DISPLAY_SETTINGS_PATH) == OK:
		resolution_index = clampi(int(settings.get_value("display", "resolution_index", 2)), 0, DISPLAY_RESOLUTIONS.size() - 1)
		fullscreen = bool(settings.get_value("display", "fullscreen", false))
		tilt_shift_enabled = bool(settings.get_value("visual", "tilt_shift", true))
	_apply_display_settings(false)


func configure_home_video() -> void:
	if home_video == null:
		return
	var stream := VideoStreamTheora.new()
	stream.file = "res://assets/ui/menu_video.ogv"
	home_video.stream = stream
	home_video.loop = true


func set_home_video(active: bool) -> void:
	if home_video == null:
		return
	home_video.visible = active
	if active:
		home_video.paused = false
		home_video.play()
	else:
		home_video.paused = true
		home_video.stop()


func _apply_display_settings(save_settings: bool) -> void:
	change_generation += 1
	var generation := change_generation
	var requested_fullscreen := fullscreen
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await host.get_tree().process_frame
	if not host.is_inside_tree() or generation != change_generation:
		return
	if not requested_fullscreen:
		var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		var resolution := _fit_windowed_resolution(DISPLAY_RESOLUTIONS[resolution_index], usable.size)
		DisplayServer.window_set_size(resolution)
		DisplayServer.window_set_position(usable.position + (usable.size - resolution) / 2)
	await host.get_tree().process_frame
	if not host.is_inside_tree() or generation != change_generation:
		return
	var actual_mode := DisplayServer.window_get_mode()
	fullscreen = actual_mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if hud != null:
		hud.sync_layout()
	if save_settings:
		_save_display_settings()
	host._refresh_hud()


func _save_display_settings() -> void:
	var settings := ConfigFile.new()
	settings.load(DISPLAY_SETTINGS_PATH)
	settings.set_value("display", "resolution_index", resolution_index)
	settings.set_value("display", "fullscreen", fullscreen)
	settings.set_value("visual", "tilt_shift", tilt_shift_enabled)
	settings.save(DISPLAY_SETTINGS_PATH)


func _apply_tilt_shift_state() -> void:
	if world_container == null:
		return
	var shader_material := world_container.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("effect_enabled", tilt_shift_enabled)


func _fit_windowed_resolution(requested: Vector2i, usable_size: Vector2i) -> Vector2i:
	var maximum := Vector2i(maxi(640, usable_size.x - 64), maxi(360, usable_size.y - 96))
	if requested.x <= maximum.x and requested.y <= maximum.y:
		return requested
	var ratio := minf(float(maximum.x) / float(requested.x), float(maximum.y) / float(requested.y))
	return Vector2i(maxi(640, roundi(float(requested.x) * ratio)), maxi(360, roundi(float(requested.y) * ratio)))
