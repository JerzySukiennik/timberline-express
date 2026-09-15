// Grass blades: bend in layered wind, root-to-tip colour ramp with world variation, translucent backlight,
// and shrink away with distance so there is no visible pop at the edge of the patch.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 root_col : source_color = vec3(0.06, 0.1, 0.03);
uniform vec3 tip_col : source_color = vec3(0.3, 0.4, 0.13);
uniform vec3 dry_col : source_color = vec3(0.5, 0.45, 0.24);
uniform sampler2D noise : hint_default_white, repeat_enable;
uniform float fade_start = 26.0;
uniform float fade_end = 42.0;

varying float h;
varying vec3 wpos;

void vertex() {
	h = UV.y;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = distance(wpos, CAMERA_POSITION_WORLD);
	float shrink = 1.0 - smoothstep(fade_start, fade_end, d);
	VERTEX *= vec3(1.0, shrink, 1.0);
	float gust = texture(noise, wpos.xz * 0.02 + vec2(TIME * 0.05, TIME * 0.03)).r;
	float w = sin(TIME * 1.7 + wpos.x * 0.6 + wpos.z * 0.4) * 0.5 + 0.5;
	vec2 dir = normalize(vec2(1.0, 0.35));
	float bend = (0.08 + gust * 0.28) * (0.6 + w * 0.4) * h * h;
	VERTEX.xz += dir * bend;
	VERTEX.y -= bend * 0.35 * h;
}

void fragment() {
	float v = texture(noise, wpos.xz * 0.05).r;
	vec3 tip = mix(tip_col, dry_col, smoothstep(0.55, 0.85, v));
	vec3 c = mix(root_col, tip, pow(h, 0.8));
	ALBEDO = c * (0.85 + v * 0.3);
	ROUGHNESS = 0.6;
	SPECULAR = 0.25;
	BACKLIGHT = c * 0.45;
	AO = mix(0.35, 1.0, h);
	AO_LIGHT_AFFECT = 0.6;
	if (!FRONT_FACING) NORMAL = -NORMAL;
}
