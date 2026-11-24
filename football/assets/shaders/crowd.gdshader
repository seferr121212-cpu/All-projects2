shader_type spatial;
// Seyirci: MultiMesh örnek rengi + örneğe özgü fazla hafif sallanma; excitement ile zıplama.
render_mode diffuse_lambert, specular_disabled;

uniform float excitement : hint_range(0.0, 1.0) = 0.2;
uniform float time_offset = 0.0;

varying vec3 inst_color;

float h(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}

void vertex() {
	inst_color = COLOR.rgb;
	float id = float(INSTANCE_ID);
	float phase = h(id) * 6.2831;
	float rate = 1.5 + h(id + 3.1) * 2.0 + excitement * 5.0;
	float sway = sin(TIME * rate + phase);
	VERTEX.x += sway * 0.03 * VERTEX.y;
	float jump = max(0.0, sin(TIME * (6.0 + h(id + 7.7) * 3.0) + phase)) * excitement * excitement * 0.35;
	VERTEX.y += jump;
}

void fragment() {
	ALBEDO = inst_color;
	ROUGHNESS = 0.9;
}
