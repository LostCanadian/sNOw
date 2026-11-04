shader_type canvas_item;
uniform sampler2D paper : filter_linear_mipmap, repeat_disable;
varying vec2 position;
void vertex() {
	position=VERTEX;
}
void fragment() {
	// The same fibrous paper as the clouds, sampled inside their opaque area.
	vec2 panel=abs(fract(position/192.0)*2.0-1.0);
	vec2 paper_uv=(vec2(824.0,376.0)+panel*96.0)/vec2(2172.0,724.0);
	vec3 fiber=texture(paper,paper_uv).rgb-textureLod(paper,paper_uv,2.0).rgb;
	float grain=dot(fiber,vec3(0.299,0.587,0.114));
	COLOR.rgb*=1.0+0.8*grain;
}
