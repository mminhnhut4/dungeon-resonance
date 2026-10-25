shader_type canvas_item;
uniform float clock=0.0;
uniform float motion=0.0;
uniform float talking=0.0;
uniform float working=0.0;
uniform float hurt=0.0;
uniform float windup=0.0;
uniform float striking=0.0;
uniform float dying=0.0;
uniform float source_forward=1.0;
uniform float foot_y=0.98;
uniform float white_threshold=0.925;
varying vec4 actor_color;
void vertex(){
	actor_color=COLOR;
	float w=clamp((foot_y-UV.y)/max(foot_y,0.01),0.0,1.0);
	VERTEX.y*=1.0+sin(clock*2.6)*0.012;
	VERTEX.x+=motion*(sin(clock*10.0+w*3.0)*0.9*w+1.2*w);
	VERTEX.x+=talking*sin(clock*4.2)*pow(w,3.0)*1.8;
	VERTEX.y+=working*sin(clock*5.5)*w*0.9;
	VERTEX.x+=hurt*sin(clock*38.0)*w*1.5;
	VERTEX.x+=source_forward*(striking*5.0-windup*1.6)*w;
	VERTEX.y*=1.0-windup*0.025-dying*0.7;
}
void fragment(){
	vec4 c=texture(TEXTURE,UV);
	float least=min(c.r,min(c.g,c.b));
	float chroma=max(c.r,max(c.g,c.b))-least;
	// White source matte is already mixed into filtered edge texels. Key the
	// neutral fringe, then uncomposite its white contribution before blending.
	// PNG bytes stay intact; chromatic highlights and opaque dark ink survive.
	float white=smoothstep(0.72,0.985,least)*(1.0-smoothstep(0.06,0.30,chroma));
	// Identify the filtered silhouette against the exact white source padding.
	// Neutral cloth inside the model remains opaque; only a screen-pixel rim
	// adjacent to source background receives stronger white decontamination.
	vec2 edge=fwidth(UV)*0.8;
	vec3 e0=textureLod(TEXTURE,UV+vec2(edge.x,0.0),0.0).rgb;
	vec3 e1=textureLod(TEXTURE,UV-vec2(edge.x,0.0),0.0).rgb;
	vec3 e2=textureLod(TEXTURE,UV+vec2(0.0,edge.y),0.0).rgb;
	vec3 e3=textureLod(TEXTURE,UV-vec2(0.0,edge.y),0.0).rgb;
	float adjacent=max(max(min(e0.r,min(e0.g,e0.b)),min(e1.r,min(e1.g,e1.b))),max(min(e2.r,min(e2.g,e2.b)),min(e3.r,min(e3.g,e3.b))));
	white=max(white,step(0.994,adjacent)*clamp((least-0.18)/0.82,0.0,1.0));
	float opacity=(1.0-white)*(1.0-smoothstep(0.96,0.999,adjacent)*0.9);
	c.rgb=clamp((c.rgb-vec3(white))/max(opacity,0.015),vec3(0.0),vec3(1.0));
	c.rgb=mix(c.rgb,vec3(1.0,0.72,0.45),hurt*0.35);
	COLOR=vec4(c.rgb,c.a*opacity*(1.0-dying*dying))*actor_color;
}
