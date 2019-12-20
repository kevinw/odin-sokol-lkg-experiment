#version 450

layout (location = COLOR0) in vec4 color;

layout (location = SV_Target0) out vec4 frag_color;

void main() {
    //frag_color = mix(color, vec4(1, 0, 1, 1), (sin(time) + 1.0) * 0.5);
    frag_color = color;
}
