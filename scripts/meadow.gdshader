shader_type canvas_item;
uniform vec4 region_uv;
uniform float autumn = 0.0;
uniform float spring = 0.0;
uniform vec4 light : source_color = vec4(1.0);
void fragment() {
	vec4 paper=texture(TEXTURE,UV);
	vec2 p=(UV-region_uv.xy)/region_uv.zw;
	float grain=dot(paper.rgb,vec3(0.299,0.587,0.114));
	vec3 dry=grain*vec3(1.12,0.89,0.57);
	vec3 fresh=grain*vec3(0.78,1.10,0.48);
	vec3 grass=mix(paper.rgb,dry,autumn*0.8);
	grass=mix(grass,fresh,spring);
	// Transparent blades meet the painting without a horizontal cut edge.
	float feather=1.0-smoothstep(0.80,1.0,p.y);
	COLOR=vec4(grass*light.rgb,paper.a*feather*light.a);
}
