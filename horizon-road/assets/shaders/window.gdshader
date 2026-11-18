shader_type spatial;
// House windows: dark glass by day, warm light at night (global night_lights).

global uniform float night_lights;

uniform vec3 glass_color : source_color = vec3(0.07, 0.09, 0.11);
uniform vec3 light_color : source_color = vec3(1.0, 0.7, 0.38);
uniform float emission_energy = 3.5;
instance uniform float lit = 1.0;

void fragment() {
	ALBEDO = glass_color;
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
	EMISSION = light_color * night_lights * lit * emission_energy;
}
