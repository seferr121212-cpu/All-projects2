shader_type canvas_item;
// SİS ÇANI - son işleme: renk düzenleme, yumuşak parlama, vinyet, film greni.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.55;
uniform float grain = 0.045;
uniform float bloom = 0.55;
uniform float saturation = 0.88;
uniform float contrast = 1.1;
uniform vec3 shadow_tint : source_color = vec3(0.86, 0.93, 1.1);
uniform vec3 high_tint : source_color = vec3(1.1, 1.0, 0.88);
uniform float flash = 0.0;
uniform float aberration = 0.0;   // Büyük Yankı yakınken ekran bozulması
uniform float sepia = 0.0;        // 1953 geçmişi için eski film tonu
uniform float rain_lens = 0.0;    // ekranda yağmur damlaları (0..1)
uniform vec3 bloom_tint : source_color = vec3(1.0, 0.86, 0.66);
uniform vec3 flash_color : source_color = vec3(0.82, 0.88, 1.0);

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Camda kayan damlalar: hücre başına bir damla, aşağı kayar, iz bırakır. Kırılma için uv kayması döner.
vec2 drops(vec2 uv, float t) {
	vec2 off = vec2(0.0);
	vec2 grid = vec2(28.0, 12.0);
	vec2 st = uv * grid;
	vec2 id = floor(st);
	vec2 h = hash2(id);
	if (h.x > 0.55) {
		float speed = 0.05 + h.y * 0.12;
		float y = fract(h.y * 7.3 - t * speed);
		vec2 c = vec2(0.3 + h.x * 0.4, 1.0 - y);
		vec2 d = (fract(st) - c) * vec2(1.0, grid.x / grid.y * 0.45);
		float r = 0.11 + h.x * 0.06;
		float m = smoothstep(r, r * 0.4, length(d));
		off += d * m * 0.9;
		// iz
		float trail = smoothstep(0.03, 0.0, abs(fract(st).x - c.x)) * step(c.y, fract(st).y) * (1.0 - fract(st).y) * 0.4;
		off += vec2(0.0, trail * 0.02);
	}
	return off / grid;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (rain_lens > 0.001) {
		uv += drops(SCREEN_UV, TIME) * rain_lens * 3.0;
	}
	vec3 c = texture(screen_tex, uv).rgb;
	if (aberration > 0.001) {
		vec2 dir = (uv - 0.5) * aberration * 0.02;
		float wob = sin(uv.y * 80.0 + TIME * 12.0) * aberration * 0.002;
		c.r = texture(screen_tex, uv + dir + vec2(wob, 0.0)).r;
		c.b = texture(screen_tex, uv - dir - vec2(wob, 0.0)).b;
	}
	vec3 b = textureLod(screen_tex, uv, 2.5).rgb * 0.5 + textureLod(screen_tex, uv, 4.0).rgb * 0.5;
	b = max(b - vec3(0.35), vec3(0.0)) * 1.8;
	c += b * bloom * bloom_tint;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= mix(shadow_tint, high_tint, smoothstep(0.08, 0.6, l));
	vec2 d = uv - 0.5;
	d.x *= 1.3;
	c *= clamp(1.0 - dot(d, d) * vignette * 2.2, 0.0, 1.0);
	float n = fract(sin(dot(floor(uv * vec2(960.0, 540.0)) + floor(TIME * 24.0) * 1.37, vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain;
	if (sepia > 0.001) {
		float sl = dot(c, vec3(0.299, 0.587, 0.114));
		vec3 sp = vec3(sl * 1.07, sl * 0.88, sl * 0.66);
		c = mix(c, sp, sepia);
		// eski film: hafif titreme ve dikey çizik
		c *= 1.0 - sepia * 0.04 * sin(TIME * 37.0);
		float scratch = step(0.997, fract(sin(floor(uv.x * 400.0) + floor(TIME * 8.0)) * 9187.3));
		c += scratch * sepia * 0.12;
	}
	c = mix(c, flash_color * 1.15, flash);
	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
