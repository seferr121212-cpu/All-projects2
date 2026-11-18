shader_type canvas_item;
// Ot / sarkan kök sallanması: sprite'ın üst kısmı rüzgarda salınır.
uniform float amp = 1.6;
uniform float speed = 1.7;
uniform bool hanging = false;   // true: alttan sallanır (sarkan kök, zincir)

void vertex() {
	float w = hanging ? UV.y : (1.0 - UV.y);
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float gust = 0.6 + 0.4 * sin(TIME * 0.37 + wp.x * 0.003);
	VERTEX.x += sin(TIME * speed + wp.x * 0.021) * amp * w * gust;
}
