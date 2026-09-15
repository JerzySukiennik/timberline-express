// Screen-space finish on top of Godot's tonemapper: sharpen, split-tone grade (warm highlights, cool shadows),
// vibrance, radial chromatic aberration, vignette and a whisper of film grain.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 sun_uv = vec2(0.5, 0.2);
uniform float sun_visible = 0.0;
uniform float rays = 0.35;
uniform bool rays_on = true;
uniform float sharpen = 0.45;
uniform float vibrance = 0.28;
uniform float contrast = 1.07;
uniform vec3 shadow_tint = vec3(0.93, 1.0, 1.06);
uniform vec3 highlight_tint = vec3(1.06, 1.0, 0.9);
uniform float vignette = 0.42;
uniform float aberration = 0.0012;
uniform float grain = 0.025;

float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 fromc = uv - 0.5;
	vec3 col;
	col.r = texture(screen_tex, uv - fromc * aberration).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv + fromc * aberration).b;
	vec3 blur = (texture(screen_tex, uv + vec2(px.x, 0)).rgb + texture(screen_tex, uv - vec2(px.x, 0)).rgb
		+ texture(screen_tex, uv + vec2(0, px.y)).rgb + texture(screen_tex, uv - vec2(0, px.y)).rgb) * 0.25;
	col += (col - blur) * sharpen;
	if (rays_on && sun_visible > 0.0) {
		// cheap screen-space light shafts: march toward the sun, gather bright sky pixels
		vec2 dir = (sun_uv - uv) / 14.0;
		vec2 p = uv;
		vec3 acc = vec3(0.0);
		float decay = 1.0;
		for (int i = 0; i < 14; i++) {
			p += dir;
			vec3 s = texture(screen_tex, p).rgb;
			float b = max(luma(s) - 0.72, 0.0);
			acc += s * b * decay;
			decay *= 0.9;
		}
		col += acc * rays * sun_visible * vec3(1.0, 0.86, 0.62) / 14.0 * 3.0;
	}
	float l = luma(col);
	col = mix(col * shadow_tint, col * highlight_tint, smoothstep(0.15, 0.75, l));
	col = (col - 0.5) * contrast + 0.5;
	float mx = max(col.r, max(col.g, col.b));
	float mn = min(col.r, min(col.g, col.b));
	float sat = mx - mn;
	col = mix(vec3(luma(col)), col, 1.0 + vibrance * (1.0 - sat));
	float vig = smoothstep(0.85, 0.2, length(fromc * vec2(1.25, 1.0)));
	col *= mix(1.0 - vignette, 1.0, vig);
	float n = fract(sin(dot(uv * TIME, vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grain;
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
