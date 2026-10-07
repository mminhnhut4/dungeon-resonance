shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float wave_radius : hint_range(0.0, 1.5) = 0.1;
uniform float opacity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(0.7, 0.85, 0.8, 1.0);

void fragment() {
	vec2 radial = UV * 2.0 - 1.0;
	float distance_from_center = length(radial);
	float ring = (1.0 - smoothstep(0.035, 0.14, abs(distance_from_center - wave_radius))) * (1.0 - smoothstep(0.82, 1.0, distance_from_center));
	vec2 normal = radial / max(distance_from_center, 0.001);
	vec2 distortion = normal * ring * opacity * 0.0015;
	vec3 scene = textureLod(screen_texture, SCREEN_UV + distortion, 0.0).rgb;
	COLOR = vec4(mix(scene, edge_color.rgb, ring * 0.12), ring * opacity);
}
