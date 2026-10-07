shader_type canvas_item;

// Source sheet is opaque black. Only almost-black sheet padding is keyed out;
// grey stone is still lit by the dungeon lights and keeps its original pixels.
uniform float black_cutoff : hint_range(0.0, 0.05) = 0.018;
uniform float jade_emission : hint_range(0.0, 5.0) = 2.6;

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	float brightness = max(texel.r, max(texel.g, texel.b));
	float coverage = smoothstep(black_cutoff * 0.45, black_cutoff, brightness);
	float jade = smoothstep(0.10, 0.30, texel.g - max(texel.r, texel.b));
	texel.rgb *= 1.0 + jade * jade_emission;
	COLOR *= vec4(texel.rgb, texel.a * coverage);
}
