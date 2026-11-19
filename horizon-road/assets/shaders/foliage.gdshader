shader_type spatial;
// Trees, bushes, grass. Sways with the global wind; leaves glow when back-lit
// by a low sun, which is most of the golden-hour look.

#include "res://assets/shaders/cloud_shadow.gdshaderinc"

global uniform float wind_strength;
global uniform float wetness;
global uniform float snow_cover;

uniform float sway_strength = 0.12;
uniform float sway_height = 6.0;
uniform float backlight_amount = 0.3;
uniform float snow_amount = 1.0;

varying vec3 world_normal;
varying vec3 world_pos;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float h = clamp(VERTEX.y / sway_height, 0.0, 1.0);
	float bend = h * h;
	float phase = origin.x * 0.13 + origin.z * 0.09;
	float w = 0.25 + wind_strength * 1.3;
	float gust = sin(TIME * 0.6 + origin.x * 0.015 + origin.z * 0.01) * 0.5 + 0.5;
	vec3 disp = vec3(sin(TIME * 1.7 + phase), 0.0, cos(TIME * 1.3 + phase * 1.4) * 0.6);
	VERTEX += disp * sway_strength * w * (0.5 + gust * 0.7) * bend;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = COLOR.rgb;
	base *= mix(1.0, 0.72, wetness);
	float snow = snow_cover * snow_amount * smoothstep(0.3, 0.8, world_normal.y);
	base = mix(base, vec3(0.88, 0.9, 0.95), snow);
	float shade = cloud_shadow(world_pos);
	base = apply_cloud_shadow(base, world_pos);
	ALBEDO = base;
	ROUGHNESS = mix(0.85, 0.45, wetness);
	SPECULAR = 0.25;
	BACKLIGHT = base * backlight_amount * (1.0 - snow) * (1.0 - shade);
}
