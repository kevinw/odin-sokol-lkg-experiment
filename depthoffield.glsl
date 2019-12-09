#version 330 core

@include common.glsl

@vs dof_vs
#extension GL_ARB_shader_viewport_layer_array : require

in vec4 pos;
in vec2 uv0;
out vec3 uvWithLayer;

void main() {
    gl_Layer = gl_InstanceID;
    gl_Position = pos;
    uvWithLayer = vec3(uv0, gl_InstanceID);
}
@end

//////////////////////////////////////////////
// circle of confusion
//

@fs coc_fs
@include builtin.glsl

in vec3 uvWithLayer;

uniform sampler2DArray cameraDepth;

uniform dof_uniforms {
    float focusDistance;
    float focusRange;
    float bokeh_radius;
};

out float outColor;

float LinearEyeDepth(float depth) {
    float z_ndc = 2.0 * depth - 1.0;
    float z_eye = 2.0 * nearPlane * farPlane / (farPlane + nearPlane - z_ndc * (farPlane - nearPlane));
    return z_eye;
}

void main() {
    float depth = texture(cameraDepth, uvWithLayer).r;
    depth = LinearEyeDepth(depth);

    float coc = (depth - focusDistance) / focusRange;
    coc = clamp(coc, -1, 1) * bokeh_radius;
    outColor = coc;
}
@end

@program dof_coc dof_vs coc_fs

////////////////////
// prefilter
//
// samples color from the main camera, and includes the coc value in alpha
//

@fs dof_prefilter
in vec3 uvWithLayer;

uniform sampler2DArray prefilterColor;
uniform sampler2DArray prefilterCoc;

out vec4 outColor;

void main() {
    vec2 texelSize = textureSize(prefilterColor, 0).xy;
    texelSize.x = 1.0 / texelSize.x;
    texelSize.y = 1.0 / texelSize.y;

    vec4 o = texelSize.xyxy * vec2(-0.5, 0.5).xxyy;

    // TODO: use texture gathering here.
    float coc0 = texture(prefilterCoc, vec3(uvWithLayer.xy + o.xy, uvWithLayer.z)).r;
    float coc1 = texture(prefilterCoc, vec3(uvWithLayer.xy + o.zy, uvWithLayer.z)).r;
    float coc2 = texture(prefilterCoc, vec3(uvWithLayer.xy + o.xw, uvWithLayer.z)).r;
    float coc3 = texture(prefilterCoc, vec3(uvWithLayer.xy + o.zw, uvWithLayer.z)).r;
    
    // regular downsample
    //float coc = (coc0 + coc1 + coc2 + coc3) * 0.25;
    
    // instead, take the most extreme CoC value, either positive or negative.
    float cocMin = min(min(min(coc0, coc1), coc2), coc3);
	float cocMax = max(max(max(coc0, coc1), coc2), coc3);
    float coc = cocMax >= -cocMin ? cocMax : cocMin;

    outColor = vec4(texture(prefilterColor, uvWithLayer).rgb, coc);
}
@end

@program dof_prefilter dof_vs dof_prefilter

////////////////////////////////
// bokeh
//
@fs bokeh_fs

uniform sampler2DArray cameraColorWithCoc;

uniform bokeh_uniforms {
    float bokeh_radius;
};

in vec3 uvWithLayer;
out vec4 outColor;

// From https://github.com/Unity-Technologies/PostProcessing/
// blob/v2/PostProcessing/Shaders/Builtins/DiskKernels.hlsl

/*
const int kernelSampleCount = 16;
const vec2 kernel[kernelSampleCount] = {
    vec2(0, 0),
    vec2(0.54545456, 0),
    vec2(0.16855472, 0.5187581),
    vec2(-0.44128203, 0.3206101),
    vec2(-0.44128197, -0.3206102),
    vec2(0.1685548, -0.5187581),
    vec2(1, 0),
    vec2(0.809017, 0.58778524),
    vec2(0.30901697, 0.95105654),
    vec2(-0.30901703, 0.9510565),
    vec2(-0.80901706, 0.5877852),
    vec2(-1, 0),
    vec2(-0.80901694, -0.58778536),
    vec2(-0.30901664, -0.9510566),
    vec2(0.30901712, -0.9510565),
    vec2(0.80901694, -0.5877853),
};
*/
const int kernelSampleCount = 22;
const vec2 kernel[kernelSampleCount] = {
	vec2(0, 0),
	vec2(0.53333336, 0),
	vec2(0.3325279, 0.4169768),
	vec2(-0.11867785, 0.5199616),
	vec2(-0.48051673, 0.2314047),
	vec2(-0.48051673, -0.23140468),
	vec2(-0.11867763, -0.51996166),
	vec2(0.33252785, -0.4169769),
	vec2(1, 0),
	vec2(0.90096885, 0.43388376),
	vec2(0.6234898, 0.7818315),
	vec2(0.22252098, 0.9749279),
	vec2(-0.22252095, 0.9749279),
	vec2(-0.62349, 0.7818314),
	vec2(-0.90096885, 0.43388382),
	vec2(-1, 0),
	vec2(-0.90096885, -0.43388376),
	vec2(-0.6234896, -0.7818316),
	vec2(-0.22252055, -0.974928),
	vec2(0.2225215, -0.9749278),
	vec2(0.6234897, -0.7818316),
	vec2(0.90096885, -0.43388376),
};

float saturate(float s) { return clamp(s, 0, 1); }

float Weigh(float coc, float radius) {
    return saturate((coc - radius + 2) / 2);
}

void main() {
    vec3 color = vec3(0, 0, 0);

    // Vector4(1 / width, 1 / height, width, height)
    //
    vec2 texelSize = textureSize(cameraColorWithCoc, 0).xy;
    texelSize.x = 1.0 / texelSize.x;
    texelSize.y = 1.0 / texelSize.y;

    float weight = 0;

    for (int k = 0; k < kernelSampleCount; ++k) {
        vec2 o = kernel[k] * bokeh_radius;
        float radius = length(o); // TODO: precompute these above
        o *= texelSize.xy;

        vec4 s = texture(cameraColorWithCoc, uvWithLayer + vec3(o, 0));

        float sw = Weigh(abs(s.a), radius);
        color += s.rgb * sw;
        weight += sw;
    }

    color *= 1.0 / weight;

    outColor = vec4(color, 1);
}

@end // bokeh_fs

@program dof_bokeh dof_vs bokeh_fs

//////////////////////////////
// postfilter
//
@fs dof_postfilter_fs

in vec3 uvWithLayer;
uniform sampler2DArray colorArray;
out vec4 outColor;

void main() {
    vec2 texelSize = textureSize(colorArray, 0).xy;
    texelSize.x = 1.0 / texelSize.x;
    texelSize.y = 1.0 / texelSize.y;

    vec4 o = texelSize.xyxy * vec2(-0.5, 0.5).xxyy;
    // a 3x3 tent filter
    vec4 s =
        texture(colorArray, vec3(uvWithLayer.xy + o.xy, uvWithLayer.z)) +
        texture(colorArray, vec3(uvWithLayer.xy + o.zy, uvWithLayer.z)) +
        texture(colorArray, vec3(uvWithLayer.xy + o.xw, uvWithLayer.z)) +
        texture(colorArray, vec3(uvWithLayer.xy + o.zw, uvWithLayer.z));
    outColor = s * 0.25;
}
@end

@program dof_postfilter dof_vs dof_postfilter_fs

////////////
// combine
//
@fs dof_combine_fs
in vec3 uvWithLayer;
uniform sampler2DArray mainCameraColor;
uniform sampler2DArray cocTexArr;
uniform sampler2DArray dofTex;
out vec4 outColor;
void main() {
    vec4 source = texture(mainCameraColor, uvWithLayer);

    float coc = texture(cocTexArr, uvWithLayer).r;
    vec4  dof = texture(dofTex, uvWithLayer);

    float dofStrength = smoothstep(0.1, 1, abs(coc));
    vec3 color = mix(source.rgb, dof.rgb, dofStrength);

    outColor = vec4(color, source.a);
}

@end

@program dof_combine dof_vs dof_combine_fs
