shader_type canvas_item;
render_mode unshaded;
uniform float night_amount = 0.0;
uniform float dusk_amount = 0.0;
uniform float cloud_amount = 0.0;
uniform float spring_amount = 0.0;
uniform float panel_width = 0.3333333;
uniform sampler2D skyline_map : filter_linear, repeat_disable;
void fragment() {
	// The same original pixels/coordinates preserve every roof and mountain.
	vec4 paper = texture(TEXTURE, UV);
	vec3 day = paper.rgb * mix(vec3(1.24,1.20,1.03),vec3(0.94,1.00,1.06),cloud_amount);
	vec3 dusk = paper.rgb * vec3(1.22,0.79,0.73);
	vec3 night = paper.rgb * vec3(0.24,0.38,0.66);
	vec3 land = mix(mix(day,dusk,dusk_amount),night,night_amount);
	land = mix(land,paper.rgb*vec3(1.25,1.23,1.05),spring_amount);
	// Separate sky light from the fixed landscape, keeping its fine paper grain.
	vec2 pixel = TEXTURE_PIXEL_SIZE*2.0;
	vec3 blur = (texture(TEXTURE,UV+vec2(pixel.x,0)).rgb+texture(TEXTURE,UV-vec2(pixel.x,0)).rgb
		+texture(TEXTURE,UV+vec2(0,pixel.y)).rgb+texture(TEXTURE,UV-vec2(0,pixel.y)).rgb)*0.25;
	float grain = clamp(dot(paper.rgb-blur,vec3(0.3333))*2.0,-0.08,0.08);
	float horizon = smoothstep(0.0,0.57,UV.y);
	vec3 sunny = mix(vec3(0.38,0.66,0.82),vec3(0.98,0.88,0.66),horizon);
	vec3 cloudy = mix(vec3(0.42,0.51,0.61),vec3(0.70,0.74,0.76),horizon);
	vec3 twilight = mix(vec3(0.29,0.23,0.43),vec3(0.96,0.63,0.43),horizon);
	vec3 dark = mix(vec3(0.018,0.033,0.09),vec3(0.13,0.21,0.35),horizon);
	vec3 sky = mix(mix(mix(sunny,cloudy,cloud_amount),twilight,dusk_amount),dark,night_amount);
	sky = mix(sky,sunny,spring_amount)*(1.0+grain);
	float ridge = texture(skyline_map,vec2(UV.x/panel_width,0.5)).r;
	float edge = max(fwidth(UV.y),0.0006);
	float sky_mask = 1.0-smoothstep(ridge-edge,ridge+edge,UV.y);
	COLOR = vec4(mix(land,sky,sky_mask),paper.a);
}
