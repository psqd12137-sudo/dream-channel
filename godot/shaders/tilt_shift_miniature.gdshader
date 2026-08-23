shader_type canvas_item;
render_mode unshaded;

// Screen-space miniature photography pass for the formal 3D viewport.
// The HUD is rendered by a separate CanvasLayer and stays perfectly sharp.
uniform bool effect_enabled = true;
uniform float focus_y : hint_range(0.0, 1.0) = 0.56;
uniform float focus_half_width : hint_range(0.02, 0.45) = 0.18;
uniform float focus_falloff : hint_range(0.02, 0.45) = 0.22;
uniform float max_blur_pixels : hint_range(0.0, 12.0) = 5.5;
uniform float color_saturation : hint_range(0.5, 1.5) = 1.08;
uniform float vignette_strength : hint_range(0.0, 0.6) = 0.14;
uniform float grain_strength : hint_range(0.0, 0.08) = 0.012;

float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}

vec3 saturate_color(vec3 color, float amount) {
	float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
	return mix(vec3(luminance), color, amount);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (effect_enabled) {
		float distance_from_band = max(abs(UV.y - focus_y) - focus_half_width, 0.0);
		float blur_amount = smoothstep(0.0, focus_falloff, distance_from_band);
		vec2 radius = TEXTURE_PIXEL_SIZE * max_blur_pixels * blur_amount;

		// A compact cross/diagonal kernel keeps the 952x578 game viewport affordable.
		vec4 blurred = source * 0.22;
		blurred += texture(TEXTURE, UV + vec2(radius.x, 0.0)) * 0.12;
		blurred += texture(TEXTURE, UV - vec2(radius.x, 0.0)) * 0.12;
		blurred += texture(TEXTURE, UV + vec2(0.0, radius.y)) * 0.12;
		blurred += texture(TEXTURE, UV - vec2(0.0, radius.y)) * 0.12;
		blurred += texture(TEXTURE, UV + radius * 0.72) * 0.075;
		blurred += texture(TEXTURE, UV - radius * 0.72) * 0.075;
		blurred += texture(TEXTURE, UV + vec2(radius.x, -radius.y) * 0.72) * 0.075;
		blurred += texture(TEXTURE, UV + vec2(-radius.x, radius.y) * 0.72) * 0.075;

		vec3 color = mix(source.rgb, blurred.rgb, blur_amount);
		color = saturate_color(color, color_saturation);
		vec2 centered = UV * 2.0 - 1.0;
		float vignette = smoothstep(0.48, 1.35, dot(centered, centered));
		color *= 1.0 - vignette * vignette_strength;
		float grain = hash21(FRAGCOORD.xy + vec2(TIME * 41.0, TIME * 17.0)) - 0.5;
		color += grain * grain_strength;
		COLOR = vec4(color, source.a);
	} else {
		COLOR = source;
	}
}
