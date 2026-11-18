shader_type canvas_item;
// Kandilin üstünde sıcak hava dalgalanması (arkadaki görüntüyü büker).
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 0.0035;

void fragment() {
	float fade = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.55, UV.y) * smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x);
	vec2 off = vec2(sin(UV.y * 30.0 - TIME * 7.0) + sin(UV.y * 13.0 - TIME * 4.0 + UV.x * 6.0) * 0.6, 0.0) * strength * fade;
	COLOR = vec4(texture(screen_tex, SCREEN_UV + off).rgb, fade);
}
