shader_type canvas_item;
uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
varying vec4 vertex_color;
void vertex() { vertex_color = COLOR; }
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	COLOR = vec4(mix(source.rgb, flash_color.rgb, flash_strength), source.a) * vertex_color;
}
