shader_type canvas_item;
uniform sampler2D paper : filter_linear, repeat_disable;
varying vec2 position;
void vertex() { position=VERTEX; }
void fragment() {
	vec3 fiber=texture(paper,vec2(fract(position.x/1600.0),0.10+fract(position.y/1400.0)*0.2)).rgb;
	float grain=dot(fiber,vec3(0.299,0.587,0.114));
	COLOR.rgb*=0.91+0.09*grain;
}
