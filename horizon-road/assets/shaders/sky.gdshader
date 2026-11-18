shader_type sky;
// Stylised sky: gradient + sun scattering + moving noise clouds + stars + moon.
// All colours are driven per frame by AtmosphereController.

uniform vec3 zenith_color : source_color = vec3(0.24, 0.45, 0.82);
uniform vec3 horizon_color : source_color = vec3(0.7, 0.8, 0.88);
uniform vec3 ground_color : source_color = vec3(0.16, 0.2, 0.14);
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0);
uniform float sun_visibility = 1.0;
uniform vec3 moon_direction = vec3(0.0, -1.0, 0.0);
uniform float night = 0.0;
uniform float cloud_coverage = 0.3;
uniform float cloud_darkness = 0.0;
uniform vec3 cloud_lit_color : source_color = vec3(1.0);
uniform vec3 cloud_shadow_color : source_color = vec3(0.55, 0.6, 0.7);
uniform float cloud_speed = 0.003;
uniform float lightning_flash = 0.0;
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	float up = clamp(h, 0.0, 1.0);

	vec3 col = mix(horizon_color, zenith_color, pow(up, 0.45));
	col = mix(col, ground_color, 1.0 - smoothstep(-0.12, 0.0, h));

	float sd = max(dot(dir, sun_direction), 0.0);
	float sun_above = smoothstep(-0.18, 0.04, sun_direction.y);
	float horizon_band = pow(1.0 - abs(h), 5.0);
	col += sun_color * (pow(sd, 5.0) * 0.45 * horizon_band + pow(sd, 60.0) * 0.5) * sun_above * sun_visibility;

	float disc = smoothstep(0.99935, 0.9997, sd) * sun_above * sun_visibility;

	float md = dot(dir, moon_direction);
	float moon_disc = smoothstep(0.99955, 0.99972, md) * night;
	vec3 moon_col = vec3(0.85, 0.9, 1.0) * moon_disc * 3.0
			+ vec3(0.35, 0.45, 0.7) * pow(max(md, 0.0), 120.0) * 0.25 * night;

	vec3 stars = vec3(0.0);
	if (night > 0.01 && h > 0.0) {
		vec3 p = dir * 280.0;
		vec3 cell = floor(p);
		float r = hash13(cell);
		if (r > 0.9965) {
			float d = length(fract(p) - 0.5);
			float twinkle = 0.7 + 0.3 * sin(TIME * 2.5 + r * 400.0);
			stars = vec3(0.9, 0.93, 1.0) * (1.0 - smoothstep(0.0, 0.28, d)) * twinkle
					* ((r - 0.9965) / 0.0035) * night * smoothstep(0.0, 0.25, h) * 2.5;
		}
	}

	float cloud = 0.0;
	vec3 cloud_col = vec3(0.0);
	if (h > -0.02) {
		vec2 uv = dir.xz / (max(h, 0.0) + 0.1);
		vec2 wind = vec2(TIME * cloud_speed, TIME * cloud_speed * 0.35);
		float n = texture(cloud_noise, uv * 0.16 + wind).r * 0.68
				+ texture(cloud_noise, uv * 0.47 - wind * 1.6).r * 0.32;
		float threshold = 1.0 - cloud_coverage;
		cloud = smoothstep(threshold - 0.06, threshold + 0.22, n);
		cloud *= smoothstep(-0.02, 0.1, h);
		float density = smoothstep(threshold, threshold + 0.35, n);
		vec3 lit = mix(cloud_lit_color, cloud_shadow_color, clamp(density * 0.85 + cloud_darkness, 0.0, 1.0));
		// Silver lining on thin cloud edges facing the sun.
		lit += sun_color * pow(sd, 8.0) * (1.0 - density) * 0.8 * sun_above * sun_visibility;
		cloud_col = lit + vec3(0.8, 0.85, 1.0) * lightning_flash * (0.5 + density);
	}

	col += stars * (1.0 - cloud) + moon_col * (1.0 - cloud * 0.9);
	col = mix(col, cloud_col, cloud * 0.96);
	col += sun_color * disc * 14.0 * (1.0 - cloud);
	col += vec3(0.6, 0.65, 0.8) * lightning_flash * 0.3;
	COLOR = col;
}
