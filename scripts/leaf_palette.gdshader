shader_type canvas_item;
// Upper half: identity colours. Lower half: attached-leaf breeze mask.
// Explicit lookups avoid Compatibility's packed instance-colour path.
uniform sampler2D palette : filter_nearest, repeat_disable;
uniform bool shadow = false;
uniform float breeze_time = 0.0;
uniform float breeze_strength = 0.0;
void vertex() {
	ivec2 pixel=ivec2(INSTANCE_ID % 128,INSTANCE_ID / 128);
	COLOR=shadow ? vec4(0.17,0.17,0.10,0.20) : texelFetch(palette,pixel,0);
	if (breeze_strength>0.0 && texelFetch(palette,pixel+ivec2(0,17),0).r>0.5) {
		float seed=float(INSTANCE_ID);
		float gust=max(0.0,sin(breeze_time*0.7+seed*2.39996));
		gust*=gust;gust*=gust;gust*=gust;
		// Skip invisible bends. Ground/front passes never enter this branch.
		if (gust>0.025) {
			gust*=breeze_strength;
			float phase=breeze_time*(1.4+mod(seed,7.0)*0.08)+seed*0.754877;
			float sine=sin(phase);
			float angle=sine*0.055*gust;
			float c=cos(angle),s=sin(angle);
			VERTEX=mat2(vec2(c,s),vec2(-s,c))*VERTEX;
			VERTEX+=vec2(sine*0.55,cos(phase*0.8)*0.3)*gust/7.8;
		}
	}
}
