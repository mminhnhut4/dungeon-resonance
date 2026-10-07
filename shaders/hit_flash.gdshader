shader_type canvas_item;

uniform bool active = false;
uniform vec4 flash_color : source_color = vec4(1.0);
// Compatibility with existing adapters which read the resolved hurt clock.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 status_color : source_color = vec4(1.0);
uniform float status_strength : hint_range(0.0, 0.5) = 0.0;
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float strength = active ? 1.0 : flash;
	vec3 shaded = mix(source.rgb * sprite_tint.rgb, status_color.rgb * max(max(source.r, source.g), source.b), status_strength);
	COLOR = vec4(mix(shaded, flash_color.rgb, strength), source.a * sprite_tint.a);
}
