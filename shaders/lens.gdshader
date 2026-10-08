shader_type canvas_item;
render_mode unshaded;
uniform float darkness : hint_range(0.0, 1.0) = 1.0;
uniform float danger : hint_range(0.0, 1.0) = 0.0;
uniform float grain_strength = 0.025;
float random(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float edge = smoothstep(0.25, 1.45, length(centered));
	float grain = random(FRAGCOORD.xy + floor(TIME * 12.0));
	float alpha = max(darkness, edge * 0.59 + grain * grain_strength);
	COLOR = vec4(vec3(0.008 + danger * edge * 0.12, 0.012, 0.016), alpha);
}
