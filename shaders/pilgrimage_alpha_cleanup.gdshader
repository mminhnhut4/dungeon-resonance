shader_type canvas_item;
// Non-destructive display cleanup. Source PNG alpha and pixels remain intact.
uniform float alpha_low : hint_range(0.0, 1.0) = 0.30;
uniform float alpha_high : hint_range(0.0, 1.0) = 0.88;
varying vec4 vertex_modulation;
void vertex() {
	vertex_modulation = COLOR;
}
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float clean_alpha = smoothstep(alpha_low, max(alpha_low + 0.001, alpha_high), source.a);
	COLOR = vec4(source.rgb, clean_alpha) * vertex_modulation;
}
