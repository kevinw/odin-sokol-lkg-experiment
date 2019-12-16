@include common.glsl


@vs vs
in vec3 gz_position;
in vec3 normal0;
in vec4 gz_color0;

out vec3 normal;
out vec4 color;

uniform vs_gizmo_uniforms {
    mat4 mvp;
};

void main() {
    gl_Position = mvp * vec4(gz_position, 1.0);
    normal = normal0;
    color = gz_color0;
}
@end

@fs fs
@include globals.glsl

in vec3 normal;
in vec4 color;

out vec4 frag_color;

void main() {
    frag_color = color;
}
@end

@program gizmos vs fs
