shader_type canvas_item;
uniform sampler2D paper : filter_linear, repeat_disable;
uniform vec2 bank_centers = vec2(100.0,260.0);
uniform vec2 bank_widths = vec2(70.0);
uniform vec2 bank_crests = vec2(0.0);
uniform float accumulation = 0.0;
varying vec2 position;
varying float shade;
// Compute bank lighting per contour vertex, rather than per screen pixel.
void vertex() {
	position=VERTEX;
	vec2 dx=vec2(position.x)-bank_centers;
	vec2 hills=bank_crests*exp(-0.5*dx*dx/(bank_widths*bank_widths));
	float spread=max(0.0001,sqrt((hills.x-hills.y)*(hills.x-hills.y)+0.04*hills.x*hills.y));
	float height=0.5*(hills.x+hills.y+spread);
	float surface=490.0-height;
	float depth=max(0.0,position.y-surface);
	// Light comes from the upper left. The two banks shade their right flanks;
	// no independent marks are scattered across the snow.
	vec2 blend=0.5*(vec2(1.0)+(hills-hills.yx+0.02*hills.yx)/spread);
	float slope=dot(blend*hills,dx/(bank_widths*bank_widths));
	float flank=clamp(slope*0.10,-0.025,0.11)*exp(-depth/110.0)*accumulation;
	float overlap=min(hills.x,hills.y)/max(0.001,max(hills.x,hills.y));
	float valley=overlap*0.035*exp(-depth/85.0)*accumulation;
	shade=position.y<surface-16.0 ? 0.0 : flank+valley+0.025*(1.0-exp(-depth/100.0));
}
void fragment() {
	vec3 fiber=texture(paper,vec2(fract(position.x/500.0),0.10+fract(position.y/700.0)*0.3)).rgb;
	float grain=dot(fiber,vec3(0.299,0.587,0.114));
	COLOR.rgb*=vec3(0.91+0.09*grain)-vec3(shade,shade*0.8,shade*0.5);
}
