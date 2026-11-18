shader_type canvas_item;
// Yankı ışıkta donunca kenarları soğuk beyaz parlar; ışık gidince söner.
uniform float glow = 0.0;
uniform vec4 rim_color : source_color = vec4(0.85, 0.92, 1.0, 1.0);

void fragment() {
	vec4 c = COLOR;   // Godot 4: COLOR dokuyu zaten içerir
	if (glow > 0.001) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float a = texture(TEXTURE, UV + vec2(px.x, 0)).a + texture(TEXTURE, UV - vec2(px.x, 0)).a
			+ texture(TEXTURE, UV + vec2(0, px.y)).a + texture(TEXTURE, UV - vec2(0, px.y)).a;
		float edge = clamp(a, 0.0, 1.0) * (1.0 - step(0.5, texture(TEXTURE, UV).a));   // dış kenar
		float inner = step(0.5, texture(TEXTURE, UV).a) * (1.0 - clamp(a / 4.0, 0.0, 1.0)) * 4.0; // iç kenar
		float flick = 0.75 + 0.25 * sin(TIME * 23.0 + UV.y * 40.0);
		c.rgb = mix(c.rgb, rim_color.rgb, clamp(inner, 0.0, 1.0) * glow * flick);
		c = mix(c, vec4(rim_color.rgb, 1.0), edge * glow * 0.8 * flick);
	}
	COLOR = c;
}
