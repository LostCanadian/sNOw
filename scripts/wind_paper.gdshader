shader_type canvas_item;
void fragment() {
	vec4 ink=texture(TEXTURE,UV);
	vec2 cell=fract(UV*4.0);
	float edge=smoothstep(0.01,0.10,min(min(cell.x,1.0-cell.x),min(cell.y,1.0-cell.y)));
	// Discard faint atlas mist between the actual paper ribbons.
	COLOR=vec4(ink.rgb,COLOR.a*smoothstep(0.08,0.65,ink.a)*edge);
}
