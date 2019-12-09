@include common.glsl

@vs vs
#extension GL_ARB_shader_viewport_layer_array : require

in vec4 clip_position;
in vec2 uvIn;
out vec3 uvWithLayer;

void main() {
    gl_Layer = gl_InstanceID;
    gl_Position = clip_position;
    uvWithLayer = vec3(uvIn, gl_Layer);
}

@end

@fs fs
uniform sampler2DArray mainTexArray;

in vec3 uvWithLayer;
out vec4 frag_color;

void main() {
    frag_color = texture(mainTexArray, uvWithLayer);
}
@end

@program blit vs fs
