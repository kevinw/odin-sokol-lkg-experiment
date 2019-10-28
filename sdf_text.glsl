@include common.glsl

@vs vs
in vec2 a_pos;
in vec2 a_texcoord;

uniform sdf_vs_uniforms {
    mat4 u_matrix;
    vec2 u_texsize;
};

out vec2 v_texcoord;

void main() {
    gl_Position = u_matrix * vec4(a_pos.xy, 0.5, 1);
    v_texcoord = a_texcoord / u_texsize;
}
@end

@fs fs
uniform sampler2D u_texture;
uniform sdf_fs_uniforms {
    vec4 u_color;
    float u_buffer;
    float u_gamma;
    float u_debug;
};

in vec2 v_texcoord;
out vec4 frag_color;

void main() {
    float dist = texture(u_texture, v_texcoord).r;

    if (u_debug > 0.0) {
        frag_color = vec4(dist, dist, dist, 1);
    } else {
        float alpha = smoothstep(u_buffer - u_gamma, u_buffer + u_gamma, dist);
        frag_color = vec4(u_color.rgb, alpha * u_color.a);
    }
}
@end

@program sdf_text vs fs
