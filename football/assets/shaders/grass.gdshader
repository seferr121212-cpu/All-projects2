shader_type spatial;
// Biçilmiş çim: kale çizgisine paralel açık/koyu şeritler, gürültüyle renk değişimi ve ince doku.
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 color_light : source_color = vec3(0.32, 0.58, 0.25);
uniform vec3 color_dark : source_color = vec3(0.24, 0.47, 0.19);
uniform float stripe_width = 5.25; // 105 m / 20 şerit
uniform float noise_scale = 0.18;
uniform float noise_strength = 0.07;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float stripe = step(0.5, fract(world_pos.x / (stripe_width * 2.0)));
	vec3 base = mix(color_dark, color_light, stripe);
	float n = vnoise(world_pos.xz * noise_scale) * 0.6 + vnoise(world_pos.xz * noise_scale * 7.0) * 0.4;
	base *= 1.0 + (n - 0.5) * 2.0 * noise_strength;
	float blades = hash(floor(world_pos.xz * 45.0));
	base *= 0.95 + blades * 0.1;
	ALBEDO = base;
	ROUGHNESS = mix(0.92, 0.78, stripe); // biçme yönü ışığı farklı yansıtır
	SPECULAR = 0.25;
}
