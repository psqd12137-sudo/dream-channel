shader_type spatial;

uniform vec4 wall_color : source_color = vec4(0.12, 0.24, 0.45, 1.0);
uniform vec4 accent_color : source_color = vec4(0.93, 0.58, 0.27, 1.0);
uniform vec2 panel_size = vec2(1.27, 1.08);
uniform int motif = 0;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.88;
varying vec2 panel_uv;

void vertex() {
	panel_uv = VERTEX.xy / panel_size + vec2(0.5);
}

void fragment() {
	vec2 p = panel_uv;
	float aa = max(fwidth(p.x), fwidth(p.y));
	vec3 color = wall_color.rgb;
	// A solid lower band grounds the miniature; motifs occupy one broad zone.
	float lower = 1.0 - smoothstep(0.25 - aa, 0.25 + aa, p.y);
	color = mix(color, wall_color.rgb * 0.43, lower);
	if (motif == 0) {
		vec2 arch = vec2((p.x - 0.58) / 0.30, max(p.y - 0.56, 0.0) / 0.30);
		float shape = (1.0 - smoothstep(1.0 - aa * 4.0, 1.0 + aa * 4.0, length(arch))) * smoothstep(0.26, 0.27, p.y);
		color = mix(color, accent_color.rgb, shape);
	} else if (motif == 1) {
		float diagonal = smoothstep(0.8 - aa, 0.8 + aa, p.x + p.y * 0.65);
		color = mix(color, accent_color.rgb, diagonal * 0.85);
		float stripe = 1.0 - smoothstep(0.12 - aa, 0.12 + aa, abs(fract((p.x + p.y) * 3.0) - 0.5));
		color = mix(color, vec3(0.055, 0.075, 0.12), stripe * step(p.x, 0.24));
	}
	ALBEDO = color;
	ROUGHNESS = surface_roughness;
	METALLIC = 0.0;
}
