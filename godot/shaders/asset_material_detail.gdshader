shader_type spatial;

uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform vec4 base_color : source_color = vec4(1.0);
uniform int material_kind = 0;
uniform float micro_scale = 46.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 source = texture(base_texture, UV) * base_color;
	float noise = hash21(UV * micro_scale) - 0.5;
	float grain = sin(UV.y * micro_scale * 0.22 + sin(UV.x * 5.0) * 1.4) * 0.5 + 0.5;
	float broad = sin(UV.x * 11.0 + sin(UV.y * 3.0) * 1.7) * 0.5 + 0.5;
	vec3 color = source.rgb;
	float roughness = 0.72;
	float metal = 0.0;
	float specular = 0.50;
	float clearcoat = 0.0;
	if (material_kind == 0) {
		// ABS / painted plastic: tight highlight, almost no micro-colour drift.
		color *= 1.0 + noise * 0.018;
		roughness = 0.22;
		specular = 0.62;
		clearcoat = 0.22;
	} else if (material_kind == 1) {
		// Painted wood: directional, low-contrast grain.
		color *= 1.0 + (grain - 0.5) * 0.13 + noise * 0.028;
		roughness = 0.50;
		specular = 0.43;
		clearcoat = 0.12;
	} else if (material_kind == 2) {
		// Felt / cloth: broad fibres and a very soft response.
		color *= 1.0 + noise * 0.10 + (broad - 0.5) * 0.035;
		roughness = 0.96;
		specular = 0.18;
	} else if (material_kind == 3) {
		// Bare or brushed metal: restrained colour, readable specular.
		color *= 1.0 + noise * 0.045;
		roughness = 0.18;
		metal = 0.78;
		specular = 0.72;
	} else if (material_kind == 4) {
		// Paper: tiny fibre variation without changing the print palette.
		color *= 1.0 + noise * 0.055 + (broad - 0.5) * 0.018;
		roughness = 0.94;
		specular = 0.20;
	} else if (material_kind == 5) {
		// Ceramic: smoother than plastic, still opaque for stable toy readability.
		color *= 1.0 + noise * 0.028;
		roughness = 0.24;
		specular = 0.70;
		clearcoat = 0.30;
	} else if (material_kind == 6) {
		// Glass: low roughness and a light cool bias, kept opaque in the miniature.
		color = mix(color, vec3(0.72, 0.86, 0.90), 0.10);
		roughness = 0.08;
		metal = 0.05;
		specular = 0.78;
		clearcoat = 0.40;
	}
	ALBEDO = color;
	ROUGHNESS = roughness;
	METALLIC = metal;
	SPECULAR = specular;
	CLEARCOAT = clearcoat;
}
