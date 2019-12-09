#version 330 core

@include common.glsl

@fs fs
#define FLIP_Y 1

in vec2 texCoords;
out vec4 fragColor;

// Calibration values
uniform lkg_fs_uniforms {
    float pitch;
    float tilt;
    float center;
    float invView;
    float subp;
    int ri;
    int bi;

    // quilt settings
    vec4 tile;
    vec4 viewPortion;
    vec4 aspect;

    int debugTile;
    int debug;
};

#define DEBUG_OFF 0
#define DEBUG_DEPTH 1
#define DEBUG_COLOR 2
#define DEBUG_DOF_COC 3
#define DEBUG_DOF_BOKEH 4

uniform sampler2DArray screenTex, depthTex, cocTex, bokehTex;

vec3 texArr(vec3 uvz)
{
    // decide which section to take from based on the z.
    float z = floor(uvz.z * tile.z);

    vec2 uv2 = uvz.xy;
#ifdef FLIP_Y
    uv2.y = 1.0 - uv2.y;
#endif
    return vec3(uv2, z);
    /*
    float x = (mod(z, tile.x) + uvz.x) / tile.x;
    float y = (floor(z / tile.x) + uvz.y) / tile.y;
    return vec2(x, y) * viewPortion.xy;
    */
}

vec3 clip(vec3 toclip)
{
    // recreate CG clip function (clear pixel if any component is negative)
    vec3 empty = vec3(0,0,0);
    bvec3 lt = lessThan(toclip, empty);
    bvec3 lt2 = lessThan(1.0-toclip, empty);
    bvec3 lt3 = bvec3(lt.x||lt2.x,lt.y||lt2.y,lt.z||lt2.z);
    empty += float(!any(lt3));
    // empty is (0,0,0) if there are negative values, (1,1,1) if there are not
    return toclip * empty;
}

void main()
{
    vec3 nuv = vec3(texCoords.xy, 0.0);
    nuv -= 0.5;
    float modx = clamp (step(aspect.y, aspect.x) * step(aspect.z, 0.5) + step(aspect.x, aspect.y) * step(0.5, aspect.z), 0, 1);
    nuv.x = modx * nuv.x * aspect.x / aspect.y + (1.0-modx) * nuv.x;
    nuv.y = modx * nuv.y + (1.0-modx) * nuv.y * aspect.y / aspect.x;
    nuv += 0.5;
    nuv = clip (nuv);
    vec4 rgb[3];
    for (int i=0; i < 3; i++)
    {
        nuv.z = (texCoords.x + i * subp + texCoords.y * tilt) * pitch - center;
        nuv.z = mod(nuv.z + ceil(abs(nuv.z)), 1.0);
        nuv.z = (1.0 - invView) * nuv.z + invView * (1.0 - nuv.z);

        if (debug == DEBUG_DOF_COC) {
            rgb[i] = texture(cocTex, texArr(nuv));
        } else if (debug == DEBUG_DOF_BOKEH) {
            rgb[i] = texture(bokehTex, texArr(nuv));
        } else {
            rgb[i] = texture(screenTex, texArr(nuv));
        }
    }

    vec2 debugUV = texCoords.xy;
#ifdef FLIP_Y
    debugUV.y = 1.0 - debugUV.y;
#endif

    vec4 debugColor;

    // TODO: #if DEBUG or something
    if (debug == DEBUG_DEPTH) {
        float depth = texture(depthTex, vec3(debugUV, debugTile)).r;
        float VAL = 0.985;
        depth = clamp(depth - VAL, 0, 1) / (1.0 - VAL);
        debugColor = vec4(depth.xxx, 1);
    } else if (debug == DEBUG_COLOR) {
        debugColor = texture(screenTex, vec3(debugUV, debugTile));
    }

    int debug_on = clamp(debug, 0, 1);
    if (debug == DEBUG_DOF_COC || debug == DEBUG_DOF_BOKEH)
        debug_on = 0;

    fragColor = vec4(rgb[ri].r, rgb[1].g, rgb[bi].b, 1.0)
        * (1 - debug_on) + debugColor * debug_on;
}
@end

@vs vs
layout (location = 0)
in vec2 vertPos_data;

out vec2 texCoords;

void main()
{
        gl_Position = vec4(vertPos_data.xy, 0.0, 1.0);
        texCoords = (vertPos_data.xy + 1.0) * 0.5;
}
@end

@program lenticular vs fs
