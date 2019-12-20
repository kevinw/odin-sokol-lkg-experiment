#version 450

layout (location = POSITION) in vec4 position;
layout (location = COLOR0) in vec4 color0;

layout (location = COLOR0) out vec4 color;

layout (binding = 0) uniform vs_uniforms {
    mat4 mvp;
    float foo;
};

void main() {
    gl_Position = mvp * position;
    color = color0;
}
