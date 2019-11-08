@include common.glsl

@vs vs
in vec4 st_position;
in vec2 st_uv;
out vec2 uv;

void main() {
    gl_Position = st_position;
    uv = st_uv;
}
@end

@fs fs
@include globals.glsl
in vec2 uv;
out vec4 frag_color;

uniform st_fs_uniforms {
    vec3	iResolution; //	image/buffer	The viewport resolution (z is pixel aspect ratio, usually 1.0)
    float	iTime; //	image/sound/buffer	Current time in seconds
    float	iTimeDelta; //	image/buffer	Time it takes to render a frame, in seconds
    int	iFrame; //	image/buffer	Current frame
    float	iFrameRate; //	image/buffer	Number of frames rendered per second
    float	iChannelTime[4]; //	image/buffer	Time for channel (if video or sound), in seconds
    vec3	iChannelResolution[4]; //	image/buffer/sound	Input texture resolution for each channel
    vec4	iMouse; //	image/buffer	xy = current pixel coords (if LMB is down). zw = click pixel
    vec4	iDate; //	image/buffer/sound	Year, month, day, time in seconds in .xyzw
    float	iSampleRate; //	image/buffer/sound	The sound sample rate (typically 44100)
};

uniform sampler2D	iChannel0; //	image/buffer/sound	Sampler for input textures i
uniform sampler2D	iChannel1; //	image/buffer/sound	Sampler for input textures i
uniform sampler2D	iChannel2; //	image/buffer/sound	Sampler for input textures i
uniform sampler2D	iChannel3; //	image/buffer/sound	Sampler for input textures i

void mainImage(out vec4 fragColor, in vec2 fragCoord);

void main() {
    vec4 outColor;
    mainImage(outColor, gl_FragCoord.xy);
    frag_color = outColor;
}

///////////////////////////////////////////


vec2 center = vec2(0.5,0.5);
float speed = 0.035;

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float invAr = iResolution.y / iResolution.x;

    vec2 uv = fragCoord.xy / iResolution.xy;
	vec3 col = vec4(uv,0.5+0.5*sin(iTime),1.0).xyz;
   
     vec3 texcol;
			
	float x = (center.x-uv.x);
	float y = (center.y-uv.y) *invAr;
		
	//float r = -sqrt(x*x + y*y); //uncoment this line to symmetric ripples
	float r = -(x*x + y*y);
	float z = 1.0 + 0.5*sin((r+iTime*speed)/0.013);
	
	texcol.x = z;
	texcol.y = z;
	texcol.z = z;
	
	fragColor = vec4(col*texcol,1.0);
}

/////////////////////////////////////////////////////////////

@end

@program shadertoy vs fs
