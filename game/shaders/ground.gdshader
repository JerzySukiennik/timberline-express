// Forest floor: two PBR sets blended by noise, gravel near the track (COLOR.r), distance-based macro tint.
shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D forest_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaves_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaves_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro_noise : hint_default_white, repeat_enable;
uniform float scale = 0.22;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz * scale;
	float n = texture(macro_noise, wpos.xz * 0.012).r;
	float n2 = texture(macro_noise, wpos.xz * 0.05 + 0.37).r;
	float leaf = smoothstep(0.42, 0.62, n * 0.7 + n2 * 0.3);
	vec3 fa = texture(forest_diff, uv).rgb;
	vec3 la = texture(leaves_diff, uv * 1.3).rgb;
	vec3 ga = texture(gravel_diff, uv * 1.6).rgb * vec3(0.85, 0.83, 0.8);
	vec3 fn = texture(forest_nor, uv).rgb;
	vec3 ln = texture(leaves_nor, uv * 1.3).rgb;
	vec3 gn = texture(gravel_nor, uv * 1.6).rgb;
	float g = clamp(COLOR.r, 0.0, 1.0);
	vec3 alb = mix(fa, la, leaf);
	vec3 nor = mix(fn, ln, leaf);
	alb = mix(alb, ga, g);
	nor = mix(nor, gn, g);
	alb *= mix(0.78, 1.08, n2);
	ALBEDO = alb;
	NORMAL_MAP = nor;
	vec3 arm = texture(forest_arm, uv).rgb;
	ROUGHNESS = mix(arm.g, 0.95, g);
	AO = mix(arm.r, 1.0, 0.4);
	AO_LIGHT_AFFECT = 0.4;
}
