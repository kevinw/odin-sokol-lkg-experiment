
//------------------------------------------------------------------------------
//  shaders for mrt-sapp sample
//------------------------------------------------------------------------------
@ctype mat4 Mat4
@ctype vec2 Vec2

// shaders for offscreen-pass rendering
@vs vs_offscreen
#define NUM_VIEWS 16

#extension GL_ARB_shader_viewport_layer_array : require

uniform Offscreen_Params {
    mat4 mvps[NUM_VIEWS];
};

in vec4 pos;
in float bright0;

out float bright;

void main() {
    gl_Layer = gl_InstanceID;
    gl_Position = mvps[gl_Layer] * pos;
    bright = bright0;
}
@end

@fs fs_offscreen
in float bright;

layout(location=0) out vec4 frag_color_0;

void main() {
    frag_color_0 = vec4(bright, bright, bright, 1.0);
}
@end

@program offscreen vs_offscreen fs_offscreen

// shaders for rendering a fullscreen-quad in default pass
@vs vs_fsq
@glsl_options flip_vert_y

uniform FSQ_Params {
    vec2 offset;
};

in vec2 pos;

out vec2 uv;

void main() {
    gl_Position = vec4(pos * 2.0 - 1.0, 0.5, 1.0);
    uv = pos + vec2(offset.x, 0.0);
}
@end

@fs fs_fsq
#define NUM_VIEWS 16
uniform sampler2DArray tex0;

in vec2 uv;
out vec4 frag_color;

void main() {

    frag_color = vec4(0, 0, 0, 1.0);
    for (int slice = 0; slice < NUM_VIEWS; ++slice) {
        vec3 c = texture(tex0, vec3(uv, slice)).xyz;
        frag_color.xyz += c;
    }
}
@end

@program fsq vs_fsq fs_fsq

// shaders for rendering a debug visualization
@vs vs_dbg
@glsl_options flip_vert_y

in vec2 pos;
out vec2 uv;

void main() {
    gl_Position = vec4(pos*2.0-1.0, 0.5, 1.0);
    uv = pos;
}
@end

@fs fs_dbg
uniform sampler2DArray tex;
uniform DebugUniforms {
    float tex_slice;
};

in vec2 uv;
out vec4 frag_color;

void main() {
    frag_color = vec4(texture(tex,vec3(uv, tex_slice)).xyz, 1.0);
}
@end

@program dbg vs_dbg fs_dbg


