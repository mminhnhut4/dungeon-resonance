shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 trail_color : source_color = vec4(1.0, 0.45, 0.13, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float pattern : hint_range(0.0, 3.0) = 0.0;
uniform float animation_phase = 0.0;
uniform float silver_core : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float edge = sin(clamp(UV.y, 0.0, 1.0) * 3.14159265);
	float core = pow(edge, 6.0);
	float tail = smoothstep(0.0, 0.18, UV.x);
	float texture_mask = 1.0;
	if (pattern > 1.5 && pattern < 2.5) {
		// Alternating bright links turn the whip ribbon into a charged chain.
		texture_mask = 0.42 + 0.58 * pow(abs(sin(UV.x * 45.0)), 3.0);
	} else if (pattern > 2.5) {
		texture_mask = 0.72 + 0.28 * sin(UV.x * 22.0 + animation_phase * 4.0);
	}
	vec3 luminous = mix(trail_color.rgb, vec3(1.0), core * 0.7);
	// This profile is frozen by the weapon clock, including during hit-stop.
	// A broad white-silver center is wrapped in a thinner jade glow.
	if (silver_core > 0.5) {
		float silver = smoothstep(0.30, 0.85, edge);
		luminous = mix(trail_color.rgb, vec3(1.18, 1.21, 1.19), silver);
		texture_mask *= smoothstep(0.0, 0.08, UV.x) * (1.0 - smoothstep(0.92, 1.0, UV.x));
	}
	COLOR = vec4(luminous, edge * tail * opacity * texture_mask * trail_color.a);
}
