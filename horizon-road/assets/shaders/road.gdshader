shader_type spatial;
// Gravel highland road: two worn tyre tracks, a grassy crown, soft grass
// edges. UV.x runs across the road (0..1), UV.y along it in metres.

#include "res://assets/shaders/common_noise.gdshaderinc"

global uniform float wetness;
global uniform float snow_cover;

uniform vec3 gravel_color : source_color = vec3(0.56, 0.5, 0.42);
uniform vec3 track_color : source_color = vec3(0.4, 0.34, 0.27);
uniform vec3 grass_color : source_color = vec3(0.36, 0.48, 0.2);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float u = UV.x;
	float grain = hash12(floor(world_pos.xz * 9.0));
	float tracks = max(1.0 - smoothstep(0.03, 0.11, abs(u - 0.28)), 1.0 - smoothstep(0.03, 0.11, abs(u - 0.72)));
	vec3 c = mix(gravel_color, track_color, tracks * 0.75) * (0.9 + grain * 0.2);

	float crown = (1.0 - smoothstep(0.02, 0.09, abs(u - 0.5))) * smoothstep(0.35, 0.6, value_noise(world_pos.xz * 0.3));
	c = mix(c, grass_color, crown * 0.8);
	float edge = 1.0 - smoothstep(0.0, 0.14, min(u, 1.0 - u) + (value_noise(world_pos.xz * 0.7) - 0.5) * 0.08);
	c = mix(c, grass_color, edge);

	float puddle = tracks * smoothstep(0.5, 0.68, value_noise(world_pos.xz * 0.23)) * smoothstep(0.4, 1.0, wetness);
	c *= mix(1.0, 0.58, wetness);
	c = mix(c, c * 0.5, puddle);
	float snow = snow_cover * (0.75 - tracks * 0.35);
	c = mix(c, vec3(0.86, 0.88, 0.93), snow);

	ALBEDO = c;
	ROUGHNESS = mix(mix(0.95, 0.5, wetness), 0.05, puddle);
	SPECULAR = mix(0.25, 0.6, wetness);
}
