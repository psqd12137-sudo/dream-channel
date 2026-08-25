shader_type spatial;

render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;

uniform vec4 smoke_color : source_color = vec4(0.95, 0.88, 0.68, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.34;
uniform float scroll_speed : hint_range(0.0, 0.2) = 0.035;
uniform float noise_scale : hint_range(0.5, 8.0) = 3.4;

float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float lower_left = hash21(cell);
	float lower_right = hash21(cell + vec2(1.0, 0.0));
	float upper_left = hash21(cell + vec2(0.0, 1.0));
	float upper_right = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(lower_left, lower_right, local.x), mix(upper_left, upper_right, local.x), local.y);
}

void fragment() {
	// CylinderMesh UVs are not guaranteed to expose a vertical range on every
	// backend, so use the local cylinder height as the vertical UV axis.
	vec2 uv = vec2(UV.x, clamp(VERTEX.y / 0.44 + 0.5, 0.0, 1.0));
	float height = smoothstep(0.0, 1.0, uv.y);
	float spread = mix(0.72, 1.18, height);
	float drift = sin(uv.y * 7.0 + TIME * 0.22) * 0.06;
	vec2 flow_uv = vec2(((uv.x - 0.5 - drift) / spread) + 0.5, uv.y * noise_scale - TIME * scroll_speed);
	float cloud = value_noise(flow_uv * vec2(2.4, 1.0));
	cloud = mix(cloud, value_noise(flow_uv * vec2(5.0, 2.2)), 0.36);
	float wisps = smoothstep(0.38, 0.72, cloud);
	float bottom_fade = smoothstep(0.0, 0.16, uv.y);
	float top_fade = 1.0 - smoothstep(0.70, 1.0, uv.y);
	float vertical_fade = 0.30 + 0.70 * bottom_fade * top_fade;
	float smoke_alpha = (0.28 + wisps * 0.72) * vertical_fade * opacity;
	ALBEDO = smoke_color.rgb;
	EMISSION = smoke_color.rgb * 0.12;
	ALPHA = smoke_alpha;
}
