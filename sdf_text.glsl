@include common.glsl

@vs vs
layout(location=0) in vec4 a_pos;
layout(location=1) in vec2 a_texcoord;

uniform sdf_vs_uniforms {
    mat4 matrix;
    vec2 texsize;
};

out vec2 v_texcoord;

void main() {
    gl_Position = matrix * a_pos;
    v_texcoord = a_texcoord / texsize;
}
@end

@fs fs
uniform sampler2D font_atlas;

uniform sdf_fs_uniforms {
    vec4 color;
    float buf;
    float gamma;
    float debug;
};

in vec2 v_texcoord;
out vec4 frag_color;

void main() {
    float dist = texture(font_atlas, v_texcoord).r;

    if (debug > 0.0) {
        frag_color = vec4(dist, dist, dist, 1);
    } else {
        float alpha = smoothstep(buf - gamma, buf + gamma, dist);
        frag_color = vec4(color.rgb, alpha * color.a);
    }
}
@end

@program sdf_text vs fs
