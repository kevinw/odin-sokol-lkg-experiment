@include common.glsl

@vs vs

@include base.glsl

layout (location = POSITION) in vec4 position;
layout (location = 1) in vec4 color0;

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

//@include globals.glsl

in vec4 color;
out vec4 frag_color;

void main() {
    //frag_color = mix(color, vec4(1, 0, 1, 1), (sin(time) + 1.0) * 0.5);
    frag_color = color;
}
@end

@program vertcolor vs fs
