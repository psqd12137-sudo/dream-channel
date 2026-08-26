shader_type canvas_item;
render_mode unshaded;

// A low-resolution, palette-quantized pass for the isolated 3D test stage.
// The HUD is rendered on a separate CanvasLayer and is not affected.
uniform bool effect_enabled = true;
uniform float pixel_size : hint_range(1.0, 12.0) = 3.0;
uniform float palette_steps : hint_range(2.0, 16.0) = 5.0;
uniform float saturation : hint_range(0.5, 2.0) = 1.12;
uniform float contrast : hint_range(0.5, 1.8) = 1.08;
uniform float dither_strength : hint_range(0.0, 0.2) = 0.045;
uniform float vignette_strength : hint_range(0.0, 0.5) = 0.08;

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
		vec2 pixel_dimensions = max(vec2(1.0), 1.0 / TEXTURE_PIXEL_SIZE);
		vec2 pixel_grid = max(vec2(1.0), floor(pixel_dimensions / pixel_size));
		vec2 pixel_uv = (floor(UV * pixel_grid) + 0.5) / pixel_grid;
		vec4 pixel_source = texture(TEXTURE, pixel_uv);

		vec3 color = saturate_color(pixel_source.rgb, saturation);
		color = (color - 0.5) * contrast + 0.5;
		float dither = (hash21(floor(UV * pixel_grid)) - 0.5) * dither_strength;
		color += dither;
		color = floor(clamp(color, 0.0, 1.0) * (palette_steps - 1.0) + 0.5) / (palette_steps - 1.0);

		vec2 centered = UV * 2.0 - 1.0;
		float vignette = smoothstep(0.45, 1.35, dot(centered, centered));
		color *= 1.0 - vignette * vignette_strength;
		COLOR = vec4(color, pixel_source.a);
	} else {
		COLOR = source;
	}
}
