shader_type canvas_item;
render_mode unshaded;
uniform float phase_angle = 0.0;
uniform float cloud_dimming = 1.0;
void fragment() {
	vec2 p=(UV-vec2(0.5))*(2.0/0.9);
	float radius=length(p);
	float edge=max(fwidth(radius),0.001);
	float silhouette=1.0-smoothstep(1.0-edge,1.0+edge,radius);
	vec3 normal=vec3(p,sqrt(max(0.0,1.0-dot(p,p))));
	vec3 sunlight=vec3(sin(phase_angle),0.0,cos(phase_angle));
	float lit=smoothstep(-0.04,0.04,dot(normal,sunlight));
	// Sample the paper sprite's opaque interior for subtle lunar paper fibres.
	float grain=dot(texture(TEXTURE,vec2(0.40,0.25)+UV*0.16).rgb,vec3(0.333333));
	vec3 paper=vec3(0.88,0.91,0.84)*(0.87+grain*0.13);
	COLOR=vec4(mix(vec3(0.20,0.30,0.45),paper,lit),silhouette*(0.08+lit*0.92)*cloud_dimming);
}
