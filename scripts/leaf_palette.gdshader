shader_type canvas_item;
// Stable identity colours, independent of the Compatibility instance-colour path.
uniform sampler2D palette : filter_nearest, repeat_disable;
uniform bool shadow = false;
void vertex() {
	COLOR = shadow ? vec4(0.17,0.17,0.10,0.20) : texelFetch(palette,ivec2(INSTANCE_ID % 128,INSTANCE_ID / 128),0);
}
