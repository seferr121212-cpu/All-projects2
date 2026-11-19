// Soft cloud shadows drifting across the land. Driven by the same weather
// coverage as the sky, so a partly cloudy day has patches of light and shade.
global uniform float cloud_shadow_strength;
global uniform float cloud_coverage;
global uniform vec2 cloud_shadow_offset;

float cs_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float cs_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(cs_hash(i), cs_hash(i + vec2(1.0, 0.0)), u.x),
			mix(cs_hash(i + vec2(0.0, 1.0)), cs_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float cloud_shadow(vec3 world_pos) {
	if (cloud_shadow_strength <= 0.001) {
		return 0.0;
	}
	vec2 p = world_pos.xz * 0.014 + cloud_shadow_offset;
	float n = cs_noise(p) * 0.55 + cs_noise(p * 2.3 + 7.1) * 0.3 + cs_noise(p * 5.1 + 3.7) * 0.15;
	// Stretch the fbm (it clusters around 0.5) so coverage maps to real patches.
	n = clamp((n - 0.5) * 2.2 + 0.5, 0.0, 1.0);
	float threshold = 1.0 - cloud_coverage;
	return smoothstep(threshold - 0.04, threshold + 0.16, n) * cloud_shadow_strength;
}

// Shade tint: under a cloud the light is softer and slightly blue, not just darker.
vec3 apply_cloud_shadow(vec3 albedo, vec3 world_pos) {
	float s = cloud_shadow(world_pos);
	return albedo * mix(vec3(1.0), vec3(0.5, 0.57, 0.72), s);
}
