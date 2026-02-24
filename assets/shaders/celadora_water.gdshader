shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.06, 0.27, 0.39, 1.0);
uniform vec4 deep_color : source_color = vec4(0.02, 0.1, 0.19, 1.0);
uniform vec4 moon_tint : source_color = vec4(0.28, 0.65, 0.78, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.1;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.03;
uniform float wave_height : hint_range(0.0, 0.4) = 0.08;
uniform float wave_scale : hint_range(0.02, 1.2) = 0.22;
uniform float wave_speed : hint_range(0.1, 2.0) = 0.6;
uniform float time_of_day : hint_range(0.0, 24.0) = 12.0;

varying vec3 world_pos;
varying float wave_mix;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave_a = sin((wp.x * wave_scale) + (TIME * wave_speed));
	float wave_b = cos((wp.z * (wave_scale * 1.2)) - (TIME * wave_speed * 0.83));
	float wave_c = sin(((wp.x + wp.z) * wave_scale * 0.7) + (TIME * wave_speed * 0.45));
	wave_mix = (wave_a + wave_b + wave_c) / 3.0;
	VERTEX.y += wave_mix * wave_height;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float day_phase = clamp(sin((time_of_day / 24.0) * 6.2831853) * 0.5 + 0.5, 0.0, 1.0);
	float foam = smoothstep(0.62, 0.96, abs(wave_mix));
	vec3 base_albedo = mix(deep_color.rgb, shallow_color.rgb, 0.55 + wave_mix * 0.3);
	vec3 tint = moon_tint.rgb * (1.0 - day_phase) * 0.35;
	base_albedo += tint;

	ALBEDO = base_albedo + vec3(foam * 0.03);
	EMISSION = tint * 0.35 + vec3(foam * 0.01);
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	NORMAL = normalize(vec3(
		sin((world_pos.x + TIME) * 0.35) * 0.22,
		1.0,
		cos((world_pos.z - TIME) * 0.37) * 0.22
	));
}
