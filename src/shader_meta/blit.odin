package shader_meta;

import sg "../../lib/odin-sokol/src/sokol_gfx"
import "../math"

/*
    #version:1# (machine generated, don't edit!)

    Generated by sokol-shdc (https://github.com/floooh/sokol-tools)

    Overview:

        Shader program 'blit':
            Get shader desc: blit_shader_desc()
            Vertex shader: vs
                Attribute slots:
                    ATTR_vs_clip_position = 0
                    ATTR_vs_uvIn = 1
            Fragment shader: fs
                Image 'mainTexArray':
                    Type: sg.Image_Type.ARRAY
                    Bind slot: SLOT_mainTexArray = 0


    Shader descriptor structs:

        sg_shader blit = sg_make_shader(blit_shader_desc());

    Vertex attribute locations for vertex shader 'vs':

        sg_pipeline pip = sg_make_pipeline(&(sg_pipeline_desc){
            .layout = {
                .attrs = {
                    [ATTR_vs_clip_position] = { ... },
                    [ATTR_vs_uvIn] = { ... },
                },
            },
            ...});

    Image bind slots, use as index in sg_bindings.vs_images[] or .fs_images[]

        SLOT_mainTexArray = 0;

*/
// #include <stdint.h>
// #include <stdbool.h>
//#if !defined(SOKOL_SHDC_ALIGN)
//  #if defined(_MSC_VER)
//    #define SOKOL_SHDC_ALIGN(a) __declspec(align(a))
//  #else
//    #define SOKOL_SHDC_ALIGN(a) __attribute__((aligned(a)))
//  #endif
//#endif
ATTR_vs_clip_position :: 0;
ATTR_vs_uvIn :: 1;

/* @(private) _get_attr_slot :: proc(attr_type: Attr_Type) -> int {
// TODO!
    return 0;
} */
SLOT_mainTexArray :: 0;
when SOKOL_D3D11 {
/*
    static float4 gl_Position;
    static int gl_InstanceID;
    static uint gl_Layer;
    static float4 clip_position;
    static float3 uvWithLayer;
    static float2 uvIn;
    
    struct SPIRV_Cross_Input
    {
        float4 clip_position : TEXCOORD0;
        float2 uvIn : TEXCOORD1;
        uint gl_InstanceID : SV_InstanceID;
    };
    
    struct SPIRV_Cross_Output
    {
        float3 uvWithLayer : TEXCOORD0;
        float4 gl_Position : SV_Position;
        uint gl_Layer : SV_RenderTargetArrayIndex;
    };
    
    #line 12 ""
    void vert_main()
    {
    #line 12 ""
        gl_Layer = gl_InstanceID;
    #line 13 ""
        gl_Position = clip_position;
    #line 14 ""
        uvWithLayer = float3(uvIn, float(gl_Layer));
    }
    
    SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
    {
        gl_InstanceID = int(stage_input.gl_InstanceID);
        clip_position = stage_input.clip_position;
        uvIn = stage_input.uvIn;
        vert_main();
        SPIRV_Cross_Output stage_output;
        stage_output.gl_Position = gl_Position;
        stage_output.gl_Layer = gl_Layer;
        stage_output.uvWithLayer = uvWithLayer;
        return stage_output;
    }
*/

_vs_source_hlsl5_blit := [?]u8 {
    0x73,0x74,0x61,0x74,0x69,0x63,0x20,0x66,0x6c,0x6f,0x61,0x74,0x34,0x20,0x67,0x6c,
    0x5f,0x50,0x6f,0x73,0x69,0x74,0x69,0x6f,0x6e,0x3b,0x0a,0x73,0x74,0x61,0x74,0x69,
    0x63,0x20,0x69,0x6e,0x74,0x20,0x67,0x6c,0x5f,0x49,0x6e,0x73,0x74,0x61,0x6e,0x63,
    0x65,0x49,0x44,0x3b,0x0a,0x73,0x74,0x61,0x74,0x69,0x63,0x20,0x75,0x69,0x6e,0x74,
    0x20,0x67,0x6c,0x5f,0x4c,0x61,0x79,0x65,0x72,0x3b,0x0a,0x73,0x74,0x61,0x74,0x69,
    0x63,0x20,0x66,0x6c,0x6f,0x61,0x74,0x34,0x20,0x63,0x6c,0x69,0x70,0x5f,0x70,0x6f,
    0x73,0x69,0x74,0x69,0x6f,0x6e,0x3b,0x0a,0x73,0x74,0x61,0x74,0x69,0x63,0x20,0x66,
    0x6c,0x6f,0x61,0x74,0x33,0x20,0x75,0x76,0x57,0x69,0x74,0x68,0x4c,0x61,0x79,0x65,
    0x72,0x3b,0x0a,0x73,0x74,0x61,0x74,0x69,0x63,0x20,0x66,0x6c,0x6f,0x61,0x74,0x32,
    0x20,0x75,0x76,0x49,0x6e,0x3b,0x0a,0x0a,0x73,0x74,0x72,0x75,0x63,0x74,0x20,0x53,
    0x50,0x49,0x52,0x56,0x5f,0x43,0x72,0x6f,0x73,0x73,0x5f,0x49,0x6e,0x70,0x75,0x74,
    0x0a,0x7b,0x0a,0x20,0x20,0x20,0x20,0x66,0x6c,0x6f,0x61,0x74,0x34,0x20,0x63,0x6c,
    0x69,0x70,0x5f,0x70,0x6f,0x73,0x69,0x74,0x69,0x6f,0x6e,0x20,0x3a,0x20,0x54,0x45,
    0x58,0x43,0x4f,0x4f,0x52,0x44,0x30,0x3b,0x0a,0x20,0x20,0x20,0x20,0x66,0x6c,0x6f,
    0x61,0x74,0x32,0x20,0x75,0x76,0x49,0x6e,0x20,0x3a,0x20,0x54,0x45,0x58,0x43,0x4f,
    0x4f,0x52,0x44,0x31,0x3b,0x0a,0x20,0x20,0x20,0x20,0x75,0x69,0x6e,0x74,0x20,0x67,
    0x6c,0x5f,0x49,0x6e,0x73,0x74,0x61,0x6e,0x63,0x65,0x49,0x44,0x20,0x3a,0x20,0x53,
    0x56,0x5f,0x49,0x6e,0x73,0x74,0x61,0x6e,0x63,0x65,0x49,0x44,0x3b,0x0a,0x7d,0x3b,
    0x0a,0x0a,0x73,0x74,0x72,0x75,0x63,0x74,0x20,0x53,0x50,0x49,0x52,0x56,0x5f,0x43,
    0x72,0x6f,0x73,0x73,0x5f,0x4f,0x75,0x74,0x70,0x75,0x74,0x0a,0x7b,0x0a,0x20,0x20,
    0x20,0x20,0x66,0x6c,0x6f,0x61,0x74,0x33,0x20,0x75,0x76,0x57,0x69,0x74,0x68,0x4c,
    0x61,0x79,0x65,0x72,0x20,0x3a,0x20,0x54,0x45,0x58,0x43,0x4f,0x4f,0x52,0x44,0x30,
    0x3b,0x0a,0x20,0x20,0x20,0x20,0x66,0x6c,0x6f,0x61,0x74,0x34,0x20,0x67,0x6c,0x5f,
    0x50,0x6f,0x73,0x69,0x74,0x69,0x6f,0x6e,0x20,0x3a,0x20,0x53,0x56,0x5f,0x50,0x6f,
    0x73,0x69,0x74,0x69,0x6f,0x6e,0x3b,0x0a,0x20,0x20,0x20,0x20,0x75,0x69,0x6e,0x74,
    0x20,0x67,0x6c,0x5f,0x4c,0x61,0x79,0x65,0x72,0x20,0x3a,0x20,0x53,0x56,0x5f,0x52,
    0x65,0x6e,0x64,0x65,0x72,0x54,0x61,0x72,0x67,0x65,0x74,0x41,0x72,0x72,0x61,0x79,
    0x49,0x6e,0x64,0x65,0x78,0x3b,0x0a,0x7d,0x3b,0x0a,0x0a,0x23,0x6c,0x69,0x6e,0x65,
    0x20,0x31,0x32,0x20,0x22,0x22,0x0a,0x76,0x6f,0x69,0x64,0x20,0x76,0x65,0x72,0x74,
    0x5f,0x6d,0x61,0x69,0x6e,0x28,0x29,0x0a,0x7b,0x0a,0x23,0x6c,0x69,0x6e,0x65,0x20,
    0x31,0x32,0x20,0x22,0x22,0x0a,0x20,0x20,0x20,0x20,0x67,0x6c,0x5f,0x4c,0x61,0x79,
    0x65,0x72,0x20,0x3d,0x20,0x67,0x6c,0x5f,0x49,0x6e,0x73,0x74,0x61,0x6e,0x63,0x65,
    0x49,0x44,0x3b,0x0a,0x23,0x6c,0x69,0x6e,0x65,0x20,0x31,0x33,0x20,0x22,0x22,0x0a,
    0x20,0x20,0x20,0x20,0x67,0x6c,0x5f,0x50,0x6f,0x73,0x69,0x74,0x69,0x6f,0x6e,0x20,
    0x3d,0x20,0x63,0x6c,0x69,0x70,0x5f,0x70,0x6f,0x73,0x69,0x74,0x69,0x6f,0x6e,0x3b,
    0x0a,0x23,0x6c,0x69,0x6e,0x65,0x20,0x31,0x34,0x20,0x22,0x22,0x0a,0x20,0x20,0x20,
    0x20,0x75,0x76,0x57,0x69,0x74,0x68,0x4c,0x61,0x79,0x65,0x72,0x20,0x3d,0x20,0x66,
    0x6c,0x6f,0x61,0x74,0x33,0x28,0x75,0x76,0x49,0x6e,0x2c,0x20,0x66,0x6c,0x6f,0x61,
    0x74,0x28,0x67,0x6c,0x5f,0x4c,0x61,0x79,0x65,0x72,0x29,0x29,0x3b,0x0a,0x7d,0x0a,
    0x0a,0x53,0x50,0x49,0x52,0x56,0x5f,0x43,0x72,0x6f,0x73,0x73,0x5f,0x4f,0x75,0x74,
    0x70,0x75,0x74,0x20,0x6d,0x61,0x69,0x6e,0x28,0x53,0x50,0x49,0x52,0x56,0x5f,0x43,
    0x72,0x6f,0x73,0x73,0x5f,0x49,0x6e,0x70,0x75,0x74,0x20,0x73,0x74,0x61,0x67,0x65,
    0x5f,0x69,0x6e,0x70,0x75,0x74,0x29,0x0a,0x7b,0x0a,0x20,0x20,0x20,0x20,0x67,0x6c,
    0x5f,0x49,0x6e,0x73,0x74,0x61,0x6e,0x63,0x65,0x49,0x44,0x20,0x3d,0x20,0x69,0x6e,
    0x74,0x28,0x73,0x74,0x61,0x67,0x65,0x5f,0x69,0x6e,0x70,0x75,0x74,0x2e,0x67,0x6c,
    0x5f,0x49,0x6e,0x73,0x74,0x61,0x6e,0x63,0x65,0x49,0x44,0x29,0x3b,0x0a,0x20,0x20,
    0x20,0x20,0x63,0x6c,0x69,0x70,0x5f,0x70,0x6f,0x73,0x69,0x74,0x69,0x6f,0x6e,0x20,
    0x3d,0x20,0x73,0x74,0x61,0x67,0x65,0x5f,0x69,0x6e,0x70,0x75,0x74,0x2e,0x63,0x6c,
    0x69,0x70,0x5f,0x70,0x6f,0x73,0x69,0x74,0x69,0x6f,0x6e,0x3b,0x0a,0x20,0x20,0x20,
    0x20,0x75,0x76,0x49,0x6e,0x20,0x3d,0x20,0x73,0x74,0x61,0x67,0x65,0x5f,0x69,0x6e,
    0x70,0x75,0x74,0x2e,0x75,0x76,0x49,0x6e,0x3b,0x0a,0x20,0x20,0x20,0x20,0x76,0x65,
    0x72,0x74,0x5f,0x6d,0x61,0x69,0x6e,0x28,0x29,0x3b,0x0a,0x20,0x20,0x20,0x20,0x53,
    0x50,0x49,0x52,0x56,0x5f,0x43,0x72,0x6f,0x73,0x73,0x5f,0x4f,0x75,0x74,0x70,0x75,
    0x74,0x20,0x73,0x74,0x61,0x67,0x65,0x5f,0x6f,0x75,0x74,0x70,0x75,0x74,0x3b,0x0a,
    0x20,0x20,0x20,0x20,0x73,0x74,0x61,0x67,0x65,0x5f,0x6f,0x75,0x74,0x70,0x75,0x74,
    0x2e,0x67,0x6c,0x5f,0x50,0x6f,0x73,0x69,0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,0x67,
    0x6c,0x5f,0x50,0x6f,0x73,0x69,0x74,0x69,0x6f,0x6e,0x3b,0x0a,0x20,0x20,0x20,0x20,
    0x73,0x74,0x61,0x67,0x65,0x5f,0x6f,0x75,0x74,0x70,0x75,0x74,0x2e,0x67,0x6c,0x5f,
    0x4c,0x61,0x79,0x65,0x72,0x20,0x3d,0x20,0x67,0x6c,0x5f,0x4c,0x61,0x79,0x65,0x72,
    0x3b,0x0a,0x20,0x20,0x20,0x20,0x73,0x74,0x61,0x67,0x65,0x5f,0x6f,0x75,0x74,0x70,
    0x75,0x74,0x2e,0x75,0x76,0x57,0x69,0x74,0x68,0x4c,0x61,0x79,0x65,0x72,0x20,0x3d,
    0x20,0x75,0x76,0x57,0x69,0x74,0x68,0x4c,0x61,0x79,0x65,0x72,0x3b,0x0a,0x20,0x20,
    0x20,0x20,0x72,0x65,0x74,0x75,0x72,0x6e,0x20,0x73,0x74,0x61,0x67,0x65,0x5f,0x6f,
    0x75,0x74,0x70,0x75,0x74,0x3b,0x0a,0x7d,0x0a,0x00,
};
/*
    Texture2DArray<float4> mainTexArray : register(t0);
    SamplerState _mainTexArray_sampler : register(s0);
    
    static float4 frag_color;
    static float3 uvWithLayer;
    
    struct SPIRV_Cross_Input
    {
        float3 uvWithLayer : TEXCOORD0;
    };
    
    struct SPIRV_Cross_Output
    {
        float4 frag_color : SV_Target0;
    };
    
    #line 11 ""
    void frag_main()
    {
    #line 11 ""
        frag_color = mainTexArray.Sample(_mainTexArray_sampler, uvWithLayer);
    }
    
    SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
    {
        uvWithLayer = stage_input.uvWithLayer;
        frag_main();
        SPIRV_Cross_Output stage_output;
        stage_output.frag_color = frag_color;
        return stage_output;
    }
*/

_fs_source_hlsl5_blit := [?]u8 {
    0x54,0x65,0x78,0x74,0x75,0x72,0x65,0x32,0x44,0x41,0x72,0x72,0x61,0x79,0x3c,0x66,
    0x6c,0x6f,0x61,0x74,0x34,0x3e,0x20,0x6d,0x61,0x69,0x6e,0x54,0x65,0x78,0x41,0x72,
    0x72,0x61,0x79,0x20,0x3a,0x20,0x72,0x65,0x67,0x69,0x73,0x74,0x65,0x72,0x28,0x74,
    0x30,0x29,0x3b,0x0a,0x53,0x61,0x6d,0x70,0x6c,0x65,0x72,0x53,0x74,0x61,0x74,0x65,
    0x20,0x5f,0x6d,0x61,0x69,0x6e,0x54,0x65,0x78,0x41,0x72,0x72,0x61,0x79,0x5f,0x73,
    0x61,0x6d,0x70,0x6c,0x65,0x72,0x20,0x3a,0x20,0x72,0x65,0x67,0x69,0x73,0x74,0x65,
    0x72,0x28,0x73,0x30,0x29,0x3b,0x0a,0x0a,0x73,0x74,0x61,0x74,0x69,0x63,0x20,0x66,
    0x6c,0x6f,0x61,0x74,0x34,0x20,0x66,0x72,0x61,0x67,0x5f,0x63,0x6f,0x6c,0x6f,0x72,
    0x3b,0x0a,0x73,0x74,0x61,0x74,0x69,0x63,0x20,0x66,0x6c,0x6f,0x61,0x74,0x33,0x20,
    0x75,0x76,0x57,0x69,0x74,0x68,0x4c,0x61,0x79,0x65,0x72,0x3b,0x0a,0x0a,0x73,0x74,
    0x72,0x75,0x63,0x74,0x20,0x53,0x50,0x49,0x52,0x56,0x5f,0x43,0x72,0x6f,0x73,0x73,
    0x5f,0x49,0x6e,0x70,0x75,0x74,0x0a,0x7b,0x0a,0x20,0x20,0x20,0x20,0x66,0x6c,0x6f,
    0x61,0x74,0x33,0x20,0x75,0x76,0x57,0x69,0x74,0x68,0x4c,0x61,0x79,0x65,0x72,0x20,
    0x3a,0x20,0x54,0x45,0x58,0x43,0x4f,0x4f,0x52,0x44,0x30,0x3b,0x0a,0x7d,0x3b,0x0a,
    0x0a,0x73,0x74,0x72,0x75,0x63,0x74,0x20,0x53,0x50,0x49,0x52,0x56,0x5f,0x43,0x72,
    0x6f,0x73,0x73,0x5f,0x4f,0x75,0x74,0x70,0x75,0x74,0x0a,0x7b,0x0a,0x20,0x20,0x20,
    0x20,0x66,0x6c,0x6f,0x61,0x74,0x34,0x20,0x66,0x72,0x61,0x67,0x5f,0x63,0x6f,0x6c,
    0x6f,0x72,0x20,0x3a,0x20,0x53,0x56,0x5f,0x54,0x61,0x72,0x67,0x65,0x74,0x30,0x3b,
    0x0a,0x7d,0x3b,0x0a,0x0a,0x23,0x6c,0x69,0x6e,0x65,0x20,0x31,0x31,0x20,0x22,0x22,
    0x0a,0x76,0x6f,0x69,0x64,0x20,0x66,0x72,0x61,0x67,0x5f,0x6d,0x61,0x69,0x6e,0x28,
    0x29,0x0a,0x7b,0x0a,0x23,0x6c,0x69,0x6e,0x65,0x20,0x31,0x31,0x20,0x22,0x22,0x0a,
    0x20,0x20,0x20,0x20,0x66,0x72,0x61,0x67,0x5f,0x63,0x6f,0x6c,0x6f,0x72,0x20,0x3d,
    0x20,0x6d,0x61,0x69,0x6e,0x54,0x65,0x78,0x41,0x72,0x72,0x61,0x79,0x2e,0x53,0x61,
    0x6d,0x70,0x6c,0x65,0x28,0x5f,0x6d,0x61,0x69,0x6e,0x54,0x65,0x78,0x41,0x72,0x72,
    0x61,0x79,0x5f,0x73,0x61,0x6d,0x70,0x6c,0x65,0x72,0x2c,0x20,0x75,0x76,0x57,0x69,
    0x74,0x68,0x4c,0x61,0x79,0x65,0x72,0x29,0x3b,0x0a,0x7d,0x0a,0x0a,0x53,0x50,0x49,
    0x52,0x56,0x5f,0x43,0x72,0x6f,0x73,0x73,0x5f,0x4f,0x75,0x74,0x70,0x75,0x74,0x20,
    0x6d,0x61,0x69,0x6e,0x28,0x53,0x50,0x49,0x52,0x56,0x5f,0x43,0x72,0x6f,0x73,0x73,
    0x5f,0x49,0x6e,0x70,0x75,0x74,0x20,0x73,0x74,0x61,0x67,0x65,0x5f,0x69,0x6e,0x70,
    0x75,0x74,0x29,0x0a,0x7b,0x0a,0x20,0x20,0x20,0x20,0x75,0x76,0x57,0x69,0x74,0x68,
    0x4c,0x61,0x79,0x65,0x72,0x20,0x3d,0x20,0x73,0x74,0x61,0x67,0x65,0x5f,0x69,0x6e,
    0x70,0x75,0x74,0x2e,0x75,0x76,0x57,0x69,0x74,0x68,0x4c,0x61,0x79,0x65,0x72,0x3b,
    0x0a,0x20,0x20,0x20,0x20,0x66,0x72,0x61,0x67,0x5f,0x6d,0x61,0x69,0x6e,0x28,0x29,
    0x3b,0x0a,0x20,0x20,0x20,0x20,0x53,0x50,0x49,0x52,0x56,0x5f,0x43,0x72,0x6f,0x73,
    0x73,0x5f,0x4f,0x75,0x74,0x70,0x75,0x74,0x20,0x73,0x74,0x61,0x67,0x65,0x5f,0x6f,
    0x75,0x74,0x70,0x75,0x74,0x3b,0x0a,0x20,0x20,0x20,0x20,0x73,0x74,0x61,0x67,0x65,
    0x5f,0x6f,0x75,0x74,0x70,0x75,0x74,0x2e,0x66,0x72,0x61,0x67,0x5f,0x63,0x6f,0x6c,
    0x6f,0x72,0x20,0x3d,0x20,0x66,0x72,0x61,0x67,0x5f,0x63,0x6f,0x6c,0x6f,0x72,0x3b,
    0x0a,0x20,0x20,0x20,0x20,0x72,0x65,0x74,0x75,0x72,0x6e,0x20,0x73,0x74,0x61,0x67,
    0x65,0x5f,0x6f,0x75,0x74,0x70,0x75,0x74,0x3b,0x0a,0x7d,0x0a,0x00,
};
blit_shader_desc_hlsl5 := sg.Shader_Desc {
  0, /* _start_canary */
  { /*attrs*/{"clip_position","TEXCOORD",0},{"uvIn","TEXCOORD",1},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0}, },
  { /* vs */
    cstring(&_vs_source_hlsl5_blit[0]), /* source */
    nil,  /* bytecode */
    0,  /* bytecode_size */
    "main", /* entry */
    { /* uniform blocks */
      {
        0, /* size */
        { /* uniforms */{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0}, },
      },
      {
        0, /* size */
        { /* uniforms */{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0}, },
      },
      {
        0, /* size */
        { /* uniforms */{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0}, },
      },
      {
        0, /* size */
        { /* uniforms */{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0}, },
      },
    },
    { /* images */ {nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT}, },
  },
  { /* fs */
    cstring(&_fs_source_hlsl5_blit[0]), /* source */
    nil,  /* bytecode */
    0,  /* bytecode_size */
    "main", /* entry */
    { /* uniform blocks */
      {
        0, /* size */
        { /* uniforms */{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0}, },
      },
      {
        0, /* size */
        { /* uniforms */{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0}, },
      },
      {
        0, /* size */
        { /* uniforms */{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0}, },
      },
      {
        0, /* size */
        { /* uniforms */{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0}, },
      },
    },
    { /* images */ {"mainTexArray",sg.Image_Type.ARRAY},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT},{nil,sg.Image_Type._DEFAULT}, },
  },
  "blit_shader", /* label */
  0, /* _end_canary */
};
} // SOKOL_D3D11
blit_shader_filenames := [?]string {
  "blit.glsl",
  "common.glsl",
};

blit_shader_desc :: proc() -> ^sg.Shader_Desc {
    when SOKOL_D3D11 {
    if sg.query_backend() == sg.Backend.D3D11 {
        return &blit_shader_desc_hlsl5;
    }
    } /* SOKOL_D3D11 */
    return nil; /* can't happen */
}
