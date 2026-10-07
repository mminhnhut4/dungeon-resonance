shader_type canvas_item;
render_mode unshaded;

uniform float strength : hint_range(0.0, 0.4) = 0.18;

void fragment() {
	vec2 centered = abs(UV - vec2(0.5)) * 2.0;
	float edge = smoothstep(0.5, 1.32, length(centered));
	COLOR = vec4(0.025, 0.035, 0.065, edge * strength);
}
