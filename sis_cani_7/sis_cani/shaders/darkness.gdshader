shader_type canvas_item;
// SİS ÇANI - karanlık + sis katmanı.
// Tüm ışıklar ekran koordinatında (piksel) gelir. Işığın olmadığı her yer karanlık ve sislidir.

uniform vec4 lights[32];          // xy: ekran px, z: yarıçap px, w: şiddet
uniform int light_count = 0;
uniform vec4 beams[8];            // ax, ay, bx, by
uniform int beam_count = 0;
uniform vec4 cone = vec4(0.0);    // xy: başlangıç, z: uzunluk (0 = kapalı), w: yarım açı
uniform vec2 cone_dir = vec2(1.0, 0.0);
uniform vec2 screen_size = vec2(1920.0, 1080.0);
uniform vec2 cam_offset = vec2(0.0);
uniform float darkness : hint_range(0.0, 1.0) = 0.72;
uniform vec3 dark_color : source_color = vec3(0.01, 0.012, 0.02);
uniform vec3 warm_color : source_color = vec3(1.0, 0.62, 0.3);
uniform vec3 fog_color : source_color = vec3(0.52, 0.57, 0.64);
uniform float fog_amount = 0.32;
uniform float red_mode = 0.0;
uniform float flash = 0.0;        // çan dalgası / son sahne beyazlaması

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}
float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec2 p = UV * screen_size;
	float light = 0.0;
	for (int i = 0; i < 32; i++) {
		if (i >= light_count) { break; }
		vec4 L = lights[i];
		float d = length(p - L.xy);
		float a = 1.0 - smoothstep(L.z * 0.3, L.z, d);
		light = max(light, a * L.w);
	}
	if (cone.z > 0.0) {
		vec2 v = p - cone.xy;
		float d = length(v);
		float ca = dot(normalize(v + vec2(0.0001)), cone_dir);
		float ang = acos(clamp(ca, -1.0, 1.0));
		float a = (1.0 - smoothstep(cone.z * 0.45, cone.z, d)) * (1.0 - smoothstep(cone.w * 0.55, cone.w, ang));
		light = max(light, a * 0.95);
	}
	float beam_core = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= beam_count) { break; }
		float d = seg_dist(p, beams[i].xy, beams[i].zw);
		float a = 1.0 - smoothstep(5.0, 34.0, d);
		light = max(light, a);
		beam_core = max(beam_core, 1.0 - smoothstep(0.0, 6.0, d));
	}
	light = clamp(light, 0.0, 1.0);

	vec2 fp = (p + cam_offset * 0.7) / vec2(520.0, 140.0);
	float f = fbm(fp + vec2(TIME * 0.035, TIME * 0.008));
	float f2 = fbm(fp * 0.6 - vec2(TIME * 0.02, 0.0));
	float sy = p.y / screen_size.y;
	float band = smoothstep(0.35, 0.75, sy) * (1.0 - smoothstep(0.92, 1.0, sy)) + 0.25;
	float fog = smoothstep(0.35, 0.8, (f + f2) * 0.5) * fog_amount * band * 1.3;
	fog *= (1.0 - light * 0.75);

	vec3 lit_col = mix(warm_color, vec3(1.0, 0.18, 0.12), red_mode);
	float dark_a = darkness * (1.0 - light);
	vec3 col = mix(dark_color, lit_col, clamp(light * 0.9 - dark_a, 0.0, 1.0));
	float alpha = max(dark_a, light * 0.14);
	col = mix(col, fog_color, fog / max(alpha + fog, 0.001));
	alpha = clamp(alpha + fog * 0.55, 0.0, 1.0);
	col += lit_col * beam_core * 0.3;
	col = mix(col, vec3(1.0, 0.95, 0.85), flash);
	alpha = mix(alpha, 1.0, flash);
	COLOR = vec4(col, alpha);
}
