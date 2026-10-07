shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	COLOR = vec4(mix(source.rgb * sprite_tint.rgb, vec3(1.0), flash), source.a * sprite_tint.a);
}
