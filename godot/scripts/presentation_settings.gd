class_name ChannelPresentationSettings
extends RefCounted

## Window, post-process and title-video settings.
##
## This is intentionally independent from run state. These values describe
## the presentation shell and must survive title-screen transitions without
## becoming part of a playable run save.

const DISPLAY_SETTINGS_PATH := "user://channel_display.cfg"
const DISPLAY_RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const PIXEL_ART_SHADER_PATH := "res://shaders/pixel_art_3d.gdshader"

var host: Node
var world_container: SubViewportContainer
var world_viewport: SubViewport
var hud: Control
var home_video: VideoStreamPlayer

var resolution_index := 2
var fullscreen := false
var depth_of_field_enabled := true
var taa_enabled := true
var pixel_filter_enabled := false
var change_generation := 0
var default_world_material: Material
var pixel_filter_material: ShaderMaterial
var active_test_visual_filter_id := ""

# Compatibility alias for older callers. The user-facing setting is depth of
# field; the miniature tilt-shift shader remains an implementation detail.
var tilt_shift_enabled:
	get: return depth_of_field_enabled
	set(value): depth_of_field_enabled = bool(value)


func _init(next_host: Node, next_world_container: SubViewportContainer, next_world_viewport: SubViewport, next_hud: Control, next_home_video: VideoStreamPlayer) -> void:
	host = next_host
	world_container = next_world_container
	world_viewport = next_world_viewport
	hud = next_hud
	home_video = next_home_video
	default_world_material = world_container.material if world_container != null else null


func resolution_label() -> String:
	var resolution: Vector2i = DISPLAY_RESOLUTIONS[resolution_index]
	return "%d×%d" % [resolution.x, resolution.y]


func mode_label() -> String:
	return "全屏" if fullscreen else "窗口"


func tilt_shift_label() -> String:
	return depth_of_field_label()


func depth_of_field_label() -> String:
	return "景深 开" if depth_of_field_enabled else "景深 关"


func taa_label() -> String:
	return "TAA 开" if taa_enabled else "TAA 关"


func pixel_filter_label() -> String:
	return "像素滤镜 开" if pixel_filter_enabled else "像素滤镜 关"


func cycle_resolution() -> void:
	resolution_index = (resolution_index + 1) % DISPLAY_RESOLUTIONS.size()
	_apply_display_settings(true)


func toggle_mode() -> void:
	fullscreen = not fullscreen
	_apply_display_settings(true)


func toggle_depth_of_field() -> void:
	depth_of_field_enabled = not depth_of_field_enabled
	_apply_depth_of_field_state()
	_save_display_settings()
	host._refresh_hud()


func toggle_tilt_shift() -> void:
	# Legacy API alias; keep old integrations working while the setting uses
	# the stable depth_of_field name everywhere new code is added.
	toggle_depth_of_field()


func toggle_taa() -> void:
	taa_enabled = not taa_enabled
	_apply_taa_state()
	_save_display_settings()
	host._refresh_hud()


func toggle_pixel_filter() -> void:
	pixel_filter_enabled = not pixel_filter_enabled
	_apply_user_visual_filter()
	_save_display_settings()
	host._refresh_hud()


func apply_test_visual_filter(visual: Dictionary) -> void:
	clear_test_visual_filter()
	var filter_id: String = str(visual.get("filter", "")).strip_edges()
	if filter_id != "pixel_art_3d":
		return
	var shader: Shader = load(PIXEL_ART_SHADER_PATH) as Shader
	if shader == null or world_container == null:
		return
	pixel_filter_material = ShaderMaterial.new()
	pixel_filter_material.shader = shader
	pixel_filter_material.set_shader_parameter("effect_enabled", true)
	pixel_filter_material.set_shader_parameter("pixel_size", maxf(1.0, float(visual.get("pixel_size", 3.0))))
	pixel_filter_material.set_shader_parameter("palette_steps", maxf(2.0, float(visual.get("palette_steps", 5.0))))
	pixel_filter_material.set_shader_parameter("saturation", maxf(0.5, float(visual.get("saturation", 1.12))))
	pixel_filter_material.set_shader_parameter("contrast", maxf(0.5, float(visual.get("contrast", 1.08))))
	pixel_filter_material.set_shader_parameter("dither_strength", maxf(0.0, float(visual.get("dither_strength", 0.045))))
	world_container.material = pixel_filter_material
	active_test_visual_filter_id = filter_id


func clear_test_visual_filter() -> void:
	active_test_visual_filter_id = ""
	if world_container != null:
		world_container.material = default_world_material
	pixel_filter_material = null
	_apply_user_visual_filter()


func load_settings() -> void:
	var settings := ConfigFile.new()
	if settings.load(DISPLAY_SETTINGS_PATH) == OK:
		resolution_index = clampi(int(settings.get_value("display", "resolution_index", 2)), 0, DISPLAY_RESOLUTIONS.size() - 1)
		fullscreen = bool(settings.get_value("display", "fullscreen", false))
		depth_of_field_enabled = bool(settings.get_value("visual", "depth_of_field", settings.get_value("visual", "tilt_shift", true)))
		taa_enabled = bool(settings.get_value("visual", "taa", true))
		pixel_filter_enabled = bool(settings.get_value("visual", "pixel_filter", false))
	_apply_depth_of_field_state()
	_apply_taa_state()
	_apply_user_visual_filter()
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
	settings.set_value("visual", "depth_of_field", depth_of_field_enabled)
	# Keep writing the legacy key so older builds can still read the setting.
	settings.set_value("visual", "tilt_shift", depth_of_field_enabled)
	settings.set_value("visual", "taa", taa_enabled)
	settings.set_value("visual", "pixel_filter", pixel_filter_enabled)
	settings.save(DISPLAY_SETTINGS_PATH)


func _apply_depth_of_field_state() -> void:
	var shader_material: ShaderMaterial = default_world_material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("effect_enabled", depth_of_field_enabled)


func _apply_user_visual_filter() -> void:
	if world_container == null or active_test_visual_filter_id != "":
		return
	if not pixel_filter_enabled:
		world_container.material = default_world_material
		pixel_filter_material = null
		return
	var shader: Shader = load(PIXEL_ART_SHADER_PATH) as Shader
	if shader == null:
		return
	pixel_filter_material = ShaderMaterial.new()
	pixel_filter_material.shader = shader
	pixel_filter_material.set_shader_parameter("effect_enabled", true)
	pixel_filter_material.set_shader_parameter("pixel_size", 3.0)
	pixel_filter_material.set_shader_parameter("palette_steps", 5.0)
	pixel_filter_material.set_shader_parameter("saturation", 1.12)
	pixel_filter_material.set_shader_parameter("contrast", 1.08)
	pixel_filter_material.set_shader_parameter("dither_strength", 0.045)
	world_container.material = pixel_filter_material


func _apply_tilt_shift_state() -> void:
	# Legacy API alias for callers that still explicitly refresh the old effect.
	_apply_depth_of_field_state()


func _apply_taa_state() -> void:
	if world_viewport == null:
		return
	world_viewport.use_taa = taa_enabled


func _fit_windowed_resolution(requested: Vector2i, usable_size: Vector2i) -> Vector2i:
	var maximum := Vector2i(maxi(640, usable_size.x - 64), maxi(360, usable_size.y - 96))
	if requested.x <= maximum.x and requested.y <= maximum.y:
		return requested
	var ratio := minf(float(maximum.x) / float(requested.x), float(maximum.y) / float(requested.y))
	return Vector2i(maxi(640, roundi(float(requested.x) * ratio)), maxi(360, roundi(float(requested.y) * ratio)))
