// Distant mountains: triplanar rock on steep faces, dark conifer belt, alpine meadow, snow caps above the line.
shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 forest_col : source_color = vec3(0.06, 0.12, 0.06);
uniform vec3 meadow_col : source_color = vec3(0.32, 0.36, 0.16);
uniform vec3 snow_col : source_color = vec3(0.92, 0.94, 0.97);
uniform float tree_line = 170.0;
uniform float snow_line = 300.0;
varying vec3 wpos;
varying vec3 wnor;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnor = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(wnor);
	n /= (n.x + n.y + n.z);
	float sc = 0.012;
	vec3 rock = texture(rock_tex, wpos.zy * sc).rgb * n.x + texture(rock_tex, wpos.xz * sc).rgb * n.y + texture(rock_tex, wpos.xy * sc).rgb * n.z;
	rock *= vec3(0.78, 0.78, 0.8);
	float slope = 1.0 - wnor.y;
	float nz = vnoise(wpos.xz * 0.012) * 0.7 + vnoise(wpos.xz * 0.06) * 0.3;
	float forest = (1.0 - smoothstep(tree_line - 25.0, tree_line + 25.0, wpos.y + nz * 40.0)) * (1.0 - smoothstep(0.35, 0.55, slope));
	vec3 grass = texture(grass_tex, wpos.xz * 0.02).rgb * meadow_col * 2.2;
	vec3 c = mix(rock, grass, (1.0 - smoothstep(0.25, 0.5, slope)) * 0.8);
	c = mix(c, forest_col * (0.7 + nz * 0.6), forest);
	float snow = smoothstep(snow_line, snow_line + 40.0, wpos.y + nz * 60.0) * (1.0 - smoothstep(0.55, 0.85, slope));
	c = mix(c, snow_col, snow);
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.6, snow);
}
