shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.85, 0.70, 0.45, 1.0);
uniform vec4 accent_color : source_color = vec4(0.2, 0.6, 0.7, 1.0);
uniform int pattern_kind = 0;
uniform mat4 pattern_to_room = mat4(1.0);
uniform float pattern_scale = 0.85;
uniform float pattern_strength : hint_range(0.0, 1.0) = 0.42;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.55;
varying vec3 room_position;

void vertex() {
	room_position = (pattern_to_room * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Frozen mesh-to-module mapping: continuous within a toy, attached in motion.
	vec2 p = room_position.xz * pattern_scale;
	vec2 tile = floor(p);
	vec2 q = fract(p) - 0.5;
	float edge = max(fwidth(p.x), fwidth(p.y));
	float mask = 0.0;
	if (pattern_kind == 0) {
		mask = 1.0 - smoothstep(0.18 - edge, 0.18 + edge, length(q));
	} else if (pattern_kind == 1) {
		float wave = abs(sin(p.x * 6.283 + sin(p.y * 3.1416) * 0.8));
		mask = 1.0 - smoothstep(0.22 - edge, 0.22 + edge, wave);
	} else if (pattern_kind == 2) {
		mask = mod(tile.x + tile.y, 2.0);
	} else if (pattern_kind == 3) {
		mask = 1.0 - smoothstep(0.07 - edge, 0.07 + edge, abs(length(q) - 0.30));
	} else if (pattern_kind == 4) {
		float zigzag = abs(q.y - (abs(q.x) - 0.25));
		mask = 1.0 - smoothstep(0.08 - edge, 0.08 + edge, zigzag);
	} else {
		mask = mod(tile.x + tile.y, 2.0) * (1.0 - smoothstep(0.3 - edge, 0.3 + edge, length(q)));
	}
	vec3 ink = pattern_kind == 2 ? vec3(0.08, 0.10, 0.13) : accent_color.rgb;
	vec3 paper = pattern_kind == 2 ? vec3(0.91, 0.87, 0.76) : base_color.rgb;
	ALBEDO = mix(paper, ink, mask * pattern_strength);
	ROUGHNESS = surface_roughness;
	METALLIC = 0.0;
}
