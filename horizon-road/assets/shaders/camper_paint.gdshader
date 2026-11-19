shader_type spatial;
// Two-tone glossy paint for the camper's rounded body. Windows, seams and
// wheel wells are painted procedurally from the local position so they
// follow the curved shell exactly; at night the living-area windows glow.

global uniform float wetness;
global uniform float snow_cover;
global uniform float night_lights;

uniform vec3 lower_color : source_color = vec3(0.2, 0.5, 0.5);
uniform vec3 upper_color : source_color = vec3(0.94, 0.89, 0.78);
uniform vec3 glass_color : source_color = vec3(0.07, 0.09, 0.12);
uniform vec3 curtain_color : source_color = vec3(0.9, 0.55, 0.26);
uniform float split_y = 1.42;
uniform float interior_glow = 0.0;

varying vec3 lp;
varying vec3 ln;

float rbox(vec2 p, vec2 c, vec2 half_size, float r) {
	vec2 q = abs(p - c) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	float aa = 0.012;
	vec3 col = mix(lower_color, upper_color, smoothstep(split_y - 0.01, split_y + 0.01, lp.y));
	// Chrome belt line between the two colours.
	float belt = 1.0 - smoothstep(0.025, 0.035, abs(lp.y - split_y));
	float metal = belt;
	col = mix(col, vec3(0.8, 0.81, 0.82), belt);

	float side = smoothstep(0.6, 0.85, abs(ln.x));
	float front = smoothstep(0.45, 0.75, -ln.z);
	float back = smoothstep(0.45, 0.75, ln.z);
	// Side windows: cab window plus two living-area windows.
	float w_cab = rbox(lp.zy, vec2(-1.62, 2.06), vec2(0.28, 0.27), 0.08);
	float w_mid = rbox(lp.zy, vec2(-0.2, 2.06), vec2(0.62, 0.27), 0.1);
	float w_back = rbox(lp.zy, vec2(1.32, 2.06), vec2(0.62, 0.27), 0.1);
	float living = min(w_mid, w_back);
	float w_side = min(w_cab, living);
	float side_glass = (1.0 - smoothstep(-aa, aa, w_side)) * side;
	float living_glass = (1.0 - smoothstep(-aa, aa, living)) * side;
	// Windscreen in two halves, and the rear window.
	float ws = rbox(vec2(abs(lp.x), lp.y), vec2(0.43, 2.07), vec2(0.38, 0.25), 0.1);
	float front_glass = (1.0 - smoothstep(-aa, aa, ws)) * front;
	float rw = rbox(lp.xy, vec2(0.0, 2.07), vec2(0.7, 0.24), 0.1);
	float back_glass = (1.0 - smoothstep(-aa, aa, rw)) * back;
	float glass = max(max(side_glass, front_glass), back_glass);
	// Rubber seal around every window.
	float seal_d = min(min(w_side / max(side, 0.001), ws / max(front, 0.001)), rw / max(back, 0.001));
	float seal = (1.0 - smoothstep(0.0, 0.03, abs(seal_d - 0.015))) * max(max(side, front), back);
	col = mix(col, vec3(0.12, 0.12, 0.13), seal * (1.0 - glass));

	// Half-drawn curtains at the bottom of the living windows.
	float curtain = living_glass * (1.0 - smoothstep(1.9, 1.92, lp.y));
	// Door seams and the sliding-door rail.
	float seams = side * (1.0 - smoothstep(0.008, 0.016, min(abs(lp.z + 1.3), abs(lp.z + 0.88))));
	seams = max(seams, side * step(0.0, lp.x) * (1.0 - smoothstep(0.008, 0.016, abs(lp.z - 0.48))) * step(lp.y, 2.35));
	col = mix(col, col * 0.45, seams * (1.0 - glass));
	// Wheel wells.
	float well = side * (1.0 - smoothstep(0.5, 0.52, min(length(lp.zy - vec2(-1.45, 0.45)), length(lp.zy - vec2(1.5, 0.45)))));
	col = mix(col, vec3(0.05), well);
	// Road dust on the lower sills; rinsed off by rain.
	float dust = (1.0 - smoothstep(0.5, 1.0, lp.y)) * (1.0 - wetness) * 0.45;
	col = mix(col, vec3(0.5, 0.42, 0.33), dust * (1.0 - well));

	vec3 glass_col = mix(glass_color, curtain_color, curtain);
	col = mix(col, glass_col, glass);
	float snow = snow_cover * smoothstep(0.6, 0.9, ln.y);
	col = mix(col, vec3(0.9, 0.92, 0.96), snow);

	ALBEDO = col;
	METALLIC = metal * 0.8;
	ROUGHNESS = mix(mix(0.32, 0.18, wetness), 0.04, glass * (1.0 - curtain));
	ROUGHNESS = mix(ROUGHNESS, 0.85, max(well, dust * 0.6));
	SPECULAR = mix(0.5, 0.9, glass);
	CLEARCOAT = (1.0 - glass) * (1.0 - well) * 0.6;
	CLEARCOAT_ROUGHNESS = 0.15;
	float glow = max(night_lights, interior_glow) * living_glass;
	EMISSION = vec3(1.0, 0.68, 0.36) * glow * mix(1.2, 2.2, curtain);
}
