shader_type spatial;
// Calm highland lake: depth-tinted, sky-reflecting, ripples grow with wind and rain.

global uniform float wind_strength;
global uniform float wetness;

uniform vec3 shallow_color : source_color = vec3(0.24, 0.42, 0.38);
uniform vec3 deep_color : source_color = vec3(0.03, 0.12, 0.14);
uniform float depth_range = 3.0;
uniform sampler2D normal_noise : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float scene_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	view.xyz /= view.w;
	float water_depth = max(VERTEX.z - view.z, 0.0);
	float d = clamp(water_depth / depth_range, 0.0, 1.0);

	float agitation = 0.35 + wind_strength * 0.9 + wetness * 0.6;
	vec2 uv1 = world_pos.xz * 0.06 + TIME * vec2(0.012, 0.007) * agitation;
	vec2 uv2 = world_pos.xz * 0.11 - TIME * vec2(0.009, 0.015) * agitation;
	NORMAL_MAP = normalize(texture(normal_noise, uv1).rgb + texture(normal_noise, uv2).rgb - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.25 + agitation * 0.5;

	float shore = 1.0 - smoothstep(0.0, 0.35, water_depth);
	ALBEDO = mix(shallow_color, deep_color, d) + vec3(0.25) * shore;
	ALPHA = mix(0.5, 0.96, d);
	ROUGHNESS = 0.04 + wetness * 0.1;
	SPECULAR = 0.55;
}
