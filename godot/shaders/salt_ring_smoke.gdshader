shader_type spatial;

// Keep depth testing enabled so the ground-level salt ring is occluded by enemy feet and bodies.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D salt_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 salt_tint : source_color = vec4(1.0, 0.95, 0.78, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.92;
uniform float rotation_speed : hint_range(-1.0, 1.0) = 0.08;
uniform float shimmer : hint_range(0.0, 0.05) = 0.008;
uniform float black_cutoff : hint_range(0.0, 0.3) = 0.025;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float angle = TIME * rotation_speed;
	mat2 rotation = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
	vec2 sample_uv = rotation * centered_uv + vec2(0.5);
	sample_uv += vec2(
		sin(TIME * 0.7 + UV.y * 12.0),
		cos(TIME * 0.55 + UV.x * 10.0)
	) * shimmer;
	vec4 salt = texture(salt_texture, sample_uv);
	float luminance = dot(salt.rgb, vec3(0.299, 0.587, 0.114));
	float salt_alpha = smoothstep(black_cutoff, black_cutoff + 0.08, luminance) * salt.a;
	float sparkle = 0.94 + 0.06 * sin(TIME * 1.8 + UV.x * 18.0 + UV.y * 11.0);
	ALBEDO = salt_tint.rgb * mix(0.82, 1.0, smoothstep(0.18, 0.82, luminance));
	EMISSION = salt_tint.rgb * 0.10 * sparkle;
	ALPHA = salt_alpha * opacity * sparkle;
}
