#version 330 core

@include common.glsl

@vs coc_vs

#extension GL_ARB_shader_viewport_layer_array : require

in vec2 pos;
in vec2 uv0;
out vec3 uvWithLayer;

void main() {
    gl_Position = vec4(pos, 0, 1);
    uvWithLayer = vec3(uv0, gl_InstanceID);
}
@end

@fs coc_fs
@include builtin.glsl

in vec3 uvWithLayer;

uniform sampler2DArray cameraDepth;

uniform dof_uniforms {
    float focusDistance;
    float focusRange;
};

out vec4 outColor;

float LinearEyeDepth(float depth) {
    float z_ndc = 2.0 * depth - 1.0;
    float z_eye = 2.0 * nearPlane * farPlane / (farPlane + nearPlane - z_ndc * (farPlane - nearPlane));
    return z_eye;
}

void main() {
    float depth = texture(cameraDepth, uvWithLayer).r;
    depth = LinearEyeDepth(depth);

    float coc = (depth - focusDistance) / focusRange;

    coc = clamp(coc, -1, 1);
    
    if (coc < 0)
        outColor = coc * -vec4(1, 0, 0, 1);
    else
        outColor = vec4(coc, coc, coc, 1);
}
@end

@program dof_coc coc_vs coc_fs
