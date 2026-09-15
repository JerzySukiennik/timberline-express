// Distant mountain ring: rock on steep faces, dark forest below the tree line, snow caps; heavy aerial perspective.
shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform vec3 forest_col : source_color = vec3(0.12, 0.17, 0.12);
uniform vec3 rock_col : source_color = vec3(0.36, 0.36, 0.35);
uniform vec3 snow_col : source_color = vec3(0.85, 0.87, 0.9);
uniform float tree_line = 150.0;
uniform float snow_line = 260.0;
varying vec3 wpos;
varying vec3 wnor;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnor = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float slope = 1.0 - wnor.y;
	float n = fract(sin(dot(floor(wpos.xz * 0.08), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 c = mix(forest_col * (0.8 + 0.4 * n), rock_col, smoothstep(tree_line - 30.0, tree_line + 30.0, wpos.y + n * 25.0));
	c = mix(c, rock_col * 0.8, smoothstep(0.45, 0.7, slope));
	c = mix(c, snow_col, smoothstep(snow_line, snow_line + 30.0, wpos.y + n * 30.0) * (1.0 - smoothstep(0.55, 0.8, slope)));
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
