// First-person arms: vertex-colour regions (R = leather glove, G = flannel sleeve, rest = skin), procedural plaid.
shader_type spatial;
render_mode diffuse_burley;

uniform vec3 plaid_a : source_color = vec3(0.42, 0.07, 0.06);
uniform vec3 plaid_b : source_color = vec3(0.08, 0.07, 0.07);
uniform vec3 skin : source_color = vec3(0.72, 0.5, 0.39);
uniform vec3 leather : source_color = vec3(0.26, 0.16, 0.09);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float glove = COLOR.r;
	float sleeve = COLOR.g;
	vec2 uv = UV * vec2(8.0, 4.0);
	float bx = step(0.5, fract(uv.x));
	float by = step(0.5, fract(uv.y));
	float thin = step(0.92, fract(uv.x * 2.0)) + step(0.92, fract(uv.y * 2.0));
	vec3 plaid = mix(plaid_a, plaid_b, (bx * by) * 0.85);
	plaid = mix(plaid, plaid_a * 1.6 + 0.05, clamp(thin, 0.0, 1.0) * 0.35 * (1.0 - bx * by));
	float weave = vnoise(UV * vec2(260.0, 130.0));
	plaid *= 0.85 + weave * 0.25;
	float n = vnoise(UV * vec2(40.0, 60.0));
	vec3 sk = skin * (0.9 + n * 0.15);
	vec3 lea = leather * (0.75 + vnoise(UV * vec2(90.0, 120.0)) * 0.45);
	vec3 col = mix(mix(sk, lea, glove), plaid, sleeve);
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.55, 0.62, glove), 0.95, sleeve);
	SPECULAR = mix(0.35, 0.2, sleeve);
	SSS_STRENGTH = (1.0 - glove) * (1.0 - sleeve) * 0.3;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), vec3(0.5 + (weave - 0.5) * 0.25, 0.5 + (vnoise(UV * vec2(130.0, 260.0)) - 0.5) * 0.25, 1.0), sleeve);
}
