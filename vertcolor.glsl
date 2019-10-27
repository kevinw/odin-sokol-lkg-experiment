@include common.glsl

@vs vs
in vec4 position;
in vec4 color0;
out vec4 color;

uniform vs_uniforms {
    mat4 mvp;
};

void main() {
    gl_Position = mvp * position;
    color = color0;
}
@end

@fs fs

uniform global_params {
    float time;
};

in vec4 color;
out vec4 frag_color;

void main() {
    frag_color = mix(color, vec4(1, 0, 1, 1), (sin(time) + 1.0) * 0.5);
}
@end

@program vertcolor vs fs
