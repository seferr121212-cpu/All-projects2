shader_type spatial;
// Flat-shaded low-poly ground. Colour comes from per-face vertex colours;
// wetness/snow are global so the whole world reacts to weather together.

#include "res://assets/shaders/common_noise.gdshaderinc"

global uniform float wetness;
global uniform float snow_cover;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;
	float v = value_noise(world_pos.xz * 0.04) * 0.6 + value_noise(world_pos.xz * 0.19) * 0.4;
	base *= 0.88 + v * 0.24;

	float flatness = smoothstep(0.7, 0.96, world_normal.y);
	float puddle = smoothstep(0.62, 0.78, value_noise(world_pos.xz * 0.11)) * flatness * smoothstep(0.45, 1.0, wetness);
	base *= mix(1.0, 0.6, wetness * 0.85);
	float rough = mix(0.95, 0.5, wetness);
	rough = mix(rough, 0.06, puddle);
	base = mix(base, base * 0.45, puddle);

	float snow = snow_cover * smoothstep(0.4, 0.75, world_normal.y);
	base = mix(base, vec3(0.86, 0.89, 0.95), snow);

	ALBEDO = base;
	ROUGHNESS = mix(rough, 0.75, snow);
	SPECULAR = mix(0.25, 0.6, max(wetness, puddle));
}
