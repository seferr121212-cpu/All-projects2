shader_type canvas_item;
// Duraklatma menüsü arka planı: bulanık ve karartılmış oyun ekranı.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float lod = 3.0;
uniform float dim = 0.55;
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb;
	c += textureLod(screen_tex, SCREEN_UV + vec2(0.004, 0.0), lod).rgb;
	c += textureLod(screen_tex, SCREEN_UV - vec2(0.004, 0.0), lod).rgb;
	c += textureLod(screen_tex, SCREEN_UV + vec2(0.0, 0.006), lod).rgb;
	c += textureLod(screen_tex, SCREEN_UV - vec2(0.0, 0.006), lod).rgb;
	COLOR = vec4(c / 5.0 * (1.0 - dim), 1.0);
}
