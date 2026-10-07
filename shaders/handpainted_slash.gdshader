shader_type canvas_item;
render_mode unshaded;

uniform vec4 element_color : source_color = vec4(0.78, 0.82, 0.8, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.0;
uniform float radiance : hint_range(0.5, 2.0) = 0.95;

void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	float lightness = dot(ink.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 hue = mix(element_color.rgb, vec3(1.0), smoothstep(0.62, 1.0, lightness) * 0.8);
	COLOR = vec4(hue * max(lightness, 0.24) * radiance, ink.a * opacity);
}
