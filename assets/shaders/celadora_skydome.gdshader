shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

uniform vec4 day_top : source_color = vec4(0.2, 0.42, 0.68, 1.0);
uniform vec4 day_horizon : source_color = vec4(0.56, 0.72, 0.86, 1.0);
uniform vec4 night_top : source_color = vec4(0.01, 0.03, 0.08, 1.0);
uniform vec4 night_horizon : source_color = vec4(0.05, 0.1, 0.2, 1.0);
uniform vec4 moon_glow : source_color = vec4(0.29, 0.68, 0.91, 1.0);
uniform float night_factor : hint_range(0.0, 1.0) = 0.0;

varying vec3 local_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 dir = normalize(local_pos);
	float height_t = clamp(dir.y * 0.5 + 0.5, 0.0, 1.0);

	vec3 top = mix(day_top.rgb, night_top.rgb, night_factor);
	vec3 horizon = mix(day_horizon.rgb, night_horizon.rgb, night_factor);
	vec3 sky = mix(horizon, top, pow(height_t, 1.2));

	vec2 star_uv = dir.xz * 120.0 + vec2(dir.y * 37.0, dir.y * 59.0);
	float star_n = hash(floor(star_uv));
	float stars = step(0.998, star_n) * night_factor * smoothstep(0.05, 0.8, 1.0 - height_t);

	ALBEDO = sky + moon_glow.rgb * night_factor * 0.05 + vec3(stars * 0.9);
}
