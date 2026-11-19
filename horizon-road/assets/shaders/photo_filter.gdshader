shader_type canvas_item;
// Photo-mode look: colour filters + vignette, visible in the viewfinder and
// baked into the saved photo (the capture reads the whole viewport).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform int mode = 0; // 0 natural, 1 warm, 2 cool, 3 mono, 4 vintage, 5 vivid
uniform float vignette = 0.25;

vec3 saturate_color(vec3 c, float amount) {
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	return mix(vec3(l), c, amount);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	if (mode == 1) {
		c *= vec3(1.08, 1.0, 0.86);
		c = saturate_color(c, 1.08);
	} else if (mode == 2) {
		c *= vec3(0.9, 0.98, 1.1);
	} else if (mode == 3) {
		float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
		c = vec3(smoothstep(0.02, 0.98, l));
	} else if (mode == 4) {
		c = saturate_color(c, 0.7);
		c = c * vec3(1.06, 0.98, 0.82) + vec3(0.05, 0.035, 0.0);
		c = mix(c, vec3(dot(c, vec3(0.33))), 0.1);
	} else if (mode == 5) {
		c = saturate_color(c, 1.35);
		c = (c - 0.5) * 1.08 + 0.5;
	}
	vec2 d = SCREEN_UV - 0.5;
	float v = 1.0 - dot(d, d) * vignette * 2.2;
	COLOR = vec4(clamp(c * v, 0.0, 1.0), 1.0);
}
