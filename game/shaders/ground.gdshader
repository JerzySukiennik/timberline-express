// Forest floor: grassy ground, leaf litter and dry dirt patches blended by macro noise, rock on steep slopes,
// gravel near the rails (COLOR.r). Detail and macro variation break up tiling.
shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D grass_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaf_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaf_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro_noise : hint_default_white, repeat_enable;
uniform float scale = 0.2;

varying vec3 wpos;
varying vec3 wnor;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnor = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = wpos.xz * scale;
	float n1 = texture(macro_noise, wpos.xz * 0.011).r;
	float n2 = texture(macro_noise, wpos.xz * 0.047 + 0.37).r;
	float n3 = texture(macro_noise, wpos.xz * 0.19 + 0.71).r;
	float leaf = smoothstep(0.5, 0.7, n1 * 0.75 + n3 * 0.25);
	float dirt = smoothstep(0.62, 0.8, n2 * 0.8 + n3 * 0.2) * (1.0 - leaf);
	float slope = 1.0 - wnor.y;
	float rock = smoothstep(0.28, 0.45, slope + (n3 - 0.5) * 0.12);
	float g = clamp(COLOR.r, 0.0, 1.0);

	vec3 a = texture(grass_diff, uv).rgb;
	vec3 an = texture(grass_nor, uv).rgb;
	a = mix(a, texture(leaf_diff, uv * 1.25).rgb, leaf);
	an = mix(an, texture(leaf_nor, uv * 1.25).rgb, leaf);
	a = mix(a, texture(dirt_diff, uv * 0.9).rgb, dirt);
	an = mix(an, texture(dirt_nor, uv * 0.9).rgb, dirt);
	vec2 ruv = vec2(wpos.x + wpos.z, wpos.y) * 0.12;
	a = mix(a, texture(rock_diff, ruv).rgb * vec3(0.8, 0.8, 0.82), rock);
	an = mix(an, texture(rock_nor, ruv).rgb, rock);
	a = mix(a, texture(gravel_diff, uv * 1.6).rgb * vec3(0.82, 0.8, 0.77), g);
	an = mix(an, texture(gravel_nor, uv * 1.6).rgb, g);
	// macro tint: lush patches and sun-dried patches
	vec3 lush = vec3(0.7, 0.95, 0.6);
	vec3 dry = vec3(0.95, 0.9, 0.72);
	a *= mix(lush, dry, smoothstep(0.35, 0.9, n2)) * mix(0.72, 0.98, n1);
	ALBEDO = a;
	NORMAL_MAP = an;
	NORMAL_MAP_DEPTH = 1.2;
	vec3 arm = texture(grass_arm, uv).rgb;
	ROUGHNESS = mix(mix(arm.g, 0.9, rock), 0.95, g);
	AO = mix(arm.r, 1.0, 0.3);
	AO_LIGHT_AFFECT = 0.5;
}
