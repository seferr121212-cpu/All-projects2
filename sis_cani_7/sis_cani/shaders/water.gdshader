shader_type canvas_item;
// Karanlık su: derinlik gradyanı, dalgalanan yansıma çizgileri, ay parıltısı.
uniform vec4 top_color : source_color = vec4(0.12, 0.17, 0.24, 0.95);
uniform vec4 deep_color : source_color = vec4(0.015, 0.025, 0.04, 0.97);
uniform vec4 shine : source_color = vec4(0.55, 0.65, 0.78, 1.0);
uniform float rain = 0.0;          // yağmur halkaları
uniform vec4 warm : source_color = vec4(1.0, 0.7, 0.4, 1.0);
varying vec2 lp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float d = clamp(lp.y / 260.0, 0.0, 1.0);
	vec4 c = mix(top_color, deep_color, d);
	float wave = sin(lp.x * 0.018 + TIME * 1.3) * 3.0 + sin(lp.x * 0.05 - TIME * 2.1) * 1.5;
	float band = fract((lp.y + wave) / 18.0);
	float line_a = step(band, 0.08) * (1.0 - d) * step(6.0, lp.y);
	vec2 cell = floor(vec2(lp.x / 6.0, lp.y / 4.0));
	float sp = step(0.985, hash(cell + floor(TIME * 3.0))) * (1.0 - d);
	c.rgb = mix(c.rgb, shine.rgb, line_a * 0.35 + sp * 0.6);
	// köpük: yüzeye yakın kırık beyaz şeritler
	float foam_n = hash(floor(vec2(lp.x / 5.0 + TIME * 4.0, lp.y / 3.0)));
	float foam = step(0.8, foam_n) * (1.0 - smoothstep(0.0, 10.0, lp.y + sin(lp.x * 0.07 + TIME * 2.0) * 2.0));
	c.rgb = mix(c.rgb, vec3(0.75, 0.8, 0.85), foam * 0.6);
	// yağmur halkaları: yüzeye yakın küçük genişleyen elipsler
	if (rain > 0.001) {
		vec2 g = vec2(lp.x / 26.0, lp.y / 10.0);
		vec2 id = floor(g);
		float h = hash(id);
		float t = fract(TIME * (0.7 + h) + h * 9.0);
		vec2 f = fract(g) - 0.5;
		float r = length(f * vec2(1.0, 2.6));
		float ring = smoothstep(0.05, 0.0, abs(r - t * 0.48)) * (1.0 - t) * step(0.5, h);
		c.rgb = mix(c.rgb, shine.rgb, ring * rain * 0.5 * (1.0 - smoothstep(0.0, 70.0, lp.y)));
	}
	// sıcak ışık yansıması: yüzeyde titreşen kesik çizgiler (kandil/lamba ışığından)
	float shimmer = step(0.75, hash(floor(vec2(lp.x / 9.0, lp.y / 3.0 + TIME * 2.0)))) * (1.0 - smoothstep(0.0, 26.0, lp.y));
	c.rgb += warm.rgb * shimmer * 0.06;
	// yüzey çizgisi
	c.rgb = mix(c.rgb, shine.rgb, (1.0 - smoothstep(0.0, 4.0, lp.y)) * 0.7);
	COLOR = c;
}
