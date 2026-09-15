// Forest pond: depth-tinted, soft shoreline via depth buffer, two scrolling noise normals, fresnel sky reflection.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D wave_noise : hint_normal, repeat_enable;
uniform vec3 shallow : source_color = vec3(0.24, 0.3, 0.22);
uniform vec3 deep : source_color = vec3(0.04, 0.07, 0.07);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz * 0.09;
	vec3 n1 = texture(wave_noise, uv + TIME * vec2(0.012, 0.007)).rgb;
	vec3 n2 = texture(wave_noise, uv * 1.7 - TIME * vec2(0.009, 0.014)).rgb;
	NORMAL_MAP = normalize(mix(n1, n2, 0.5));
	NORMAL_MAP_DEPTH = 0.35;
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 world = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	world.xyz /= world.w;
	float water_depth = clamp((-world.z) - (-VERTEX.z), 0.0, 10.0);
	float t = smoothstep(0.0, 2.2, water_depth);
	vec3 refr = textureLod(screen_tex, SCREEN_UV + NORMAL_MAP.xy * 0.004, 0.0).rgb;
	vec3 col = mix(refr * shallow * 1.4, deep, smoothstep(0.0, 1.0, t));
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 4.0);
	ALBEDO = col;
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = clamp(smoothstep(0.0, 0.6, water_depth) * 0.9 + fres * 0.1, 0.0, 1.0);
}
