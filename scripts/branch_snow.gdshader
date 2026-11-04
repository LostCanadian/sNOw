shader_type canvas_item;
uniform sampler2D paper : filter_linear_mipmap, repeat_disable;
uniform float accumulation = 0.0;
uniform vec2 texture_scale = vec2(3.413333,3.622642);
void fragment() {
	vec2 texel=TEXTURE_PIXEL_SIZE*texture_scale;
	float depth=0.3+1.1*accumulation;
	vec2 down=vec2(0.0,texel.y*depth);
	float here=texture(TEXTURE,UV).a;
	float lower=max(here,max(texture(TEXTURE,UV+down*0.5).a,texture(TEXTURE,UV+down).a));
	float upper=texture(TEXTURE,UV-down*0.6).a;
	float cap=smoothstep(0.15,0.85,lower)*(1.0-smoothstep(0.15,0.85,upper));
	if(cap<0.005) discard;
	// Neighbouring bark forms a shelf; upright twig tips do not get white dots.
	float shelf=min(texture(TEXTURE,UV+down*0.5-vec2(texel.x,0.0)).a,texture(TEXTURE,UV+down*0.5+vec2(texel.x,0.0)).a);
	vec2 panel=abs(fract(UV*vec2(300.0,424.0)/192.0)*2.0-1.0);
	vec2 paper_uv=(vec2(824.0,376.0)+panel*96.0)/vec2(2172.0,724.0);
	vec3 fiber=texture(paper,paper_uv).rgb-textureLod(paper,paper_uv,2.0).rgb;
	float grain=dot(fiber,vec3(0.299,0.587,0.114));
	vec3 snow=vec3(0.96,0.975,0.99)*(1.0+0.8*grain);
	COLOR=vec4(snow,cap*smoothstep(0.1,0.8,shelf)*smoothstep(0.0,0.9,accumulation)*0.88);
}
