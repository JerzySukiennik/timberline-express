// Alpha-clipped conifer/fern cards with gentle wind sway, backlit translucency and two-sided lighting.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(0.78, 0.84, 0.72, 1.0);
uniform float alpha_cut = 0.45;
uniform float sway = 0.05;
uniform float sway_height = 10.0;
uniform float backlight = 0.55;
uniform bool flip_back = true;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = clamp(VERTEX.y / sway_height, 0.0, 1.5);
	float t = TIME * 0.9 + w.x * 0.07 + w.z * 0.05;
	VERTEX.x += sin(t) * sway * h * h;
	VERTEX.z += cos(t * 0.8) * sway * 0.6 * h * h;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	if (c.a < alpha_cut) discard;
	float depth_ao = clamp(UV.y * 0.0 + 1.0, 0.0, 1.0);
	ALBEDO = c.rgb * tint.rgb * vec3(0.92, 1.04, 0.86);
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	BACKLIGHT = vec3(backlight) * c.rgb;
	if (flip_back && !FRONT_FACING) NORMAL = -NORMAL;
}
