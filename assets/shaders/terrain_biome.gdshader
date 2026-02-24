shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.24, 0.42, 0.28, 1.0);
uniform vec4 accent_color : source_color = vec4(0.16, 0.3, 0.2, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.92;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.02;
uniform float noise_scale : hint_range(0.01, 2.0) = 0.24;
uniform float accent_strength : hint_range(0.0, 1.0) = 0.42;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise_2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * noise_scale;
	float n0 = noise_2d(p);
	float n1 = noise_2d(p * 2.3 + vec2(41.2, -17.4));
	float mixed_noise = clamp(n0 * 0.65 + n1 * 0.35, 0.0, 1.0);
	float accent_mask = smoothstep(0.35, 0.88, mixed_noise) * accent_strength;

	vec3 albedo = mix(base_color.rgb, accent_color.rgb, accent_mask);
	float cavity = smoothstep(0.0, 0.7, mixed_noise);
	albedo *= mix(0.92, 1.08, cavity);

	ALBEDO = albedo;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
}
