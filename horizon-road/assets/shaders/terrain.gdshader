shader_type spatial;
// Flat-shaded low-poly ground. Colour comes from per-face vertex colours;
// wetness/snow are global so the whole world reacts to weather together.

#include "res://assets/shaders/common_noise.gdshaderinc"
#include "res://assets/shaders/cloud_shadow.gdshaderinc"

global uniform float wetness;
global uniform float snow_cover;
global uniform vec3 season_tint;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;
	float grassy = clamp((base.g - max(base.r, base.b)) * 6.0, 0.0, 1.0);
	base = mix(base, base * mix(vec3(1.0), season_tint, 0.8), grassy);
	float v = value_noise(world_pos.xz * 0.04) * 0.6 + value_noise(world_pos.xz * 0.19) * 0.4;
	base *= 0.86 + v * 0.28;
	// Meadow patchwork: drier golden patches and deep lush hollows, so the
	// grass never reads as one flat green sheet.
	float patch_n = value_noise(world_pos.xz * 0.018 + 13.0) * 0.65 + value_noise(world_pos.xz * 0.07) * 0.35;
	vec3 dry = base * vec3(1.18, 1.04, 0.7);
	vec3 lush = base * vec3(0.78, 0.92, 0.82);
	base = mix(base, dry, smoothstep(0.55, 0.8, patch_n) * grassy * 0.75);
	base = mix(base, lush, smoothstep(0.42, 0.18, patch_n) * grassy * 0.7);
	// Steeper banks show soil and stones through the turf.
	float bank = smoothstep(0.86, 0.66, world_normal.y) * grassy;
	vec3 soil = vec3(0.36, 0.29, 0.21) * (0.85 + value_noise(world_pos.xz * 0.9) * 0.3);
	base = mix(base, soil, bank * 0.55);
	// Fine grass grain near the camera; fades out before it can shimmer.
	float view_dist = length(VERTEX);
	float grain_fade = 1.0 - smoothstep(25.0, 90.0, view_dist);
	float flat_ground = smoothstep(0.75, 0.95, world_normal.y);
	float grain = value_noise(world_pos.xz * 3.1) * 0.6 + value_noise(world_pos.xz * 7.3) * 0.4;
	base *= 1.0 + (grain - 0.5) * 0.28 * grain_fade * flat_ground;
	// Sparse lighter blades/flowers speckle.
	float speck = step(0.93, hash12(floor(world_pos.xz * 6.0)));
	base = mix(base, base * vec3(1.25, 1.3, 1.05), speck * grain_fade * flat_ground * 0.6);

	float flatness = smoothstep(0.7, 0.96, world_normal.y);
	float puddle = smoothstep(0.62, 0.78, value_noise(world_pos.xz * 0.11)) * flatness * smoothstep(0.45, 1.0, wetness);
	base *= mix(1.0, 0.6, wetness * 0.85);
	float rough = mix(0.95, 0.5, wetness);
	rough = mix(rough, 0.06, puddle);
	base = mix(base, base * 0.45, puddle);

	float snow = snow_cover * smoothstep(0.4, 0.75, world_normal.y);
	base = mix(base, vec3(0.86, 0.89, 0.95), snow);

	base = apply_cloud_shadow(base, world_pos);
	ALBEDO = base;
	ROUGHNESS = mix(rough, 0.75, snow);
	SPECULAR = mix(0.25, 0.6, max(wetness, puddle));
}
