@include common.glsl

@vs vs


layout(location=0) in vec4 a_pos;
layout(location=1) in vec2 a_texcoord;
layout(location=2) in vec4 a_attribs;

#define MAX_VIEWS 45
#extension GL_ARB_shader_viewport_layer_array : require
uniform sdf_vs_uniforms {
    mat4 view_proj_array[MAX_VIEWS];
    mat4 model_matrix;
    vec2 texsize;
};

out vec2 v_texcoord;
out vec4 attrib;

void main() {
    gl_Layer = gl_InstanceID;
    gl_Position = view_proj_array[gl_Layer] * model_matrix * a_pos;
    v_texcoord = a_texcoord / texsize; // @Speed precompute this in a table on the cpu
    attrib = a_attribs;
}
@end

@fs fs
uniform sampler2D font_atlas;

uniform sdf_fs_uniforms {
    vec4 color;
    float debug;
};

in vec2 v_texcoord;
in vec4 attrib;
out vec4 frag_color;

void main() {
    float dist = texture(font_atlas, v_texcoord).r;
    float gamma = attrib[0];
    float buf = attrib[1];

    if (debug > 0.0) {
        frag_color = vec4(dist, dist, dist, 1);
    } else {
        float alpha = smoothstep(buf - gamma, buf + gamma, dist);
        frag_color = vec4(color.rgb, alpha * color.a);
    }
}
@end

@program sdf_text vs fs
