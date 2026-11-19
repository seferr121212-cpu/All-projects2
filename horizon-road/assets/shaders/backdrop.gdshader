shader_type spatial;
// Distant ranges around a region. Vertex colour gives the land cover
// (forest, dry hills, sand); slope turns it to layered rock and height
// above the snow line to snow, so silhouettes read as real mountains.

#include "res://assets/shaders/common_noise.gdshaderinc"
#include "res://assets/shaders/cloud_shadow.gdshaderinc"

global uniform float snow_cover;
global uniform vec3 season_tint;

uniform vec3 rock_color : source_color = vec3(0.42, 0.4, 0.38);
uniform vec3 rock_band_color : source_color = vec3(0.52, 0.47, 0.42);
uniform float snow_line = 330.0;
uniform float rock_slope = 0.42;
uniform float forest_speckle = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;
	float leafy = clamp((base.g - max(base.r, base.b)) * 6.0, 0.0, 1.0);
	base = mix(base, base * mix(vec3(1.0), season_tint, 0.8), leafy);
	// Canopy texture: clumps of darker and lighter crowns on forested slopes.
	float crowns = value_noise(world_pos.xz * 0.09) * 0.6 + value_noise(world_pos.xz * 0.31) * 0.4;
	base *= mix(1.0, 0.78 + crowns * 0.4, leafy * forest_speckle);

	float slope = 1.0 - world_normal.y;
	float rock = smoothstep(rock_slope, rock_slope + 0.18, slope + (value_noise(world_pos.xz * 0.02) - 0.5) * 0.2);
	float strata = sin(world_pos.y * 0.09 + value_noise(world_pos.xz * 0.01) * 6.0) * 0.5 + 0.5;
	vec3 rock_col = mix(rock_color, rock_band_color, smoothstep(0.4, 0.9, strata));
	rock_col *= 0.9 + value_noise(world_pos.xz * 0.05) * 0.2;
	base = mix(base, rock_col, rock);

	float line = snow_line * mix(1.0, 0.25, snow_cover) + (value_noise(world_pos.xz * 0.006) - 0.5) * 70.0;
	float snow = smoothstep(line - 8.0, line + 25.0, world_pos.y) * smoothstep(0.25, 0.55, world_normal.y + 0.15);
	snow = max(snow, snow_cover * smoothstep(0.45, 0.8, world_normal.y));
	base = mix(base, vec3(0.9, 0.92, 0.97), snow);

	base = apply_cloud_shadow(base, world_pos);
	ALBEDO = base;
	ROUGHNESS = mix(0.95, 0.7, snow);
	SPECULAR = mix(0.2, 0.45, snow);
}
