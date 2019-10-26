package shader_meta;

import sg "sokol:sokol_gfx"

SOKOL_D3D11 :: true;
/*
    #version:1# (machine generated, don't edit!)

    Generated by sokol-shdc (https://github.com/floooh/sokol-tools)

    Overview:

        Shader program 'vertcolor':
            Get shader desc: vertcolor_shader_desc()
            Vertex shader: vs
                Attribute slots:
                    ATTR_vs_position = 0
                    ATTR_vs_color0 = 1
                Uniform block 'vs_uniforms':
                    C struct: vs_uniforms_t
                    Bind slot: SLOT_vs_uniforms = 0
            Fragment shader: fs
                Uniform block 'global_params':
                    C struct: global_params_t
                    Bind slot: SLOT_global_params = 0


    Shader descriptor structs:

        sg_shader vertcolor = sg_make_shader(vertcolor_shader_desc());

    Vertex attribute locations for vertex shader 'vs':

        sg_pipeline pip = sg_make_pipeline(&(sg_pipeline_desc){
            .layout = {
                .attrs = {
                    [ATTR_vs_position] = { ... },
                    [ATTR_vs_color0] = { ... },
                },
            },
            ...});

    Image bind slots, use as index in sg_bindings.vs_images[] or .fs_images[]


    Bind slot and C-struct for uniform block 'vs_uniforms':

        vs_uniforms_t vs_uniforms = {
            .mvp = ...;
        };
        sg_apply_uniforms(sg.SHADERSTAGE_[VS|FS], SLOT_vs_uniforms, &vs_uniforms, sizeof(vs_uniforms));

    Bind slot and C-struct for uniform block 'global_params':

        global_params_t global_params = {
            .time = ...;
        };
        sg_apply_uniforms(sg.SHADERSTAGE_[VS|FS], SLOT_global_params, &global_params, sizeof(global_params));

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
ATTR_vs_position :: 0;
ATTR_vs_color0 :: 1;
SLOT_vs_uniforms :: 0;
vs_uniforms :: struct #align 16 {
    mvp: [16]f32,
};
SLOT_global_params :: 0;
global_params :: struct #align 16 {
    time: f32,
    _pad_4: [12]u8,
};
when SOKOL_D3D11 {
/*
    cbuffer vs_uniforms : register(b0)
    {
        row_major float4x4 _20_mvp : packoffset(c0);
    };
    
    
    static float4 gl_Position;
    static float4 position;
    static float4 color;
    static float4 color0;
    
    struct SPIRV_Cross_Input
    {
        float4 position : TEXCOORD0;
        float4 color0 : TEXCOORD1;
    };
    
    struct SPIRV_Cross_Output
    {
        float4 color : TEXCOORD0;
        float4 gl_Position : SV_Position;
    };
    
    #line 14 ""
    void vert_main()
    {
    #line 14 ""
        gl_Position = mul(position, _20_mvp);
    #line 15 ""
        color = color0;
    }
    
    SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
    {
        position = stage_input.position;
        color0 = stage_input.color0;
        vert_main();
        SPIRV_Cross_Output stage_output;
        stage_output.gl_Position = gl_Position;
        stage_output.color = color;
        return stage_output;
    }
*/
@(private)
vs_source_hlsl5 := [?]u8 {
    0x63,0x62,0x75,0x66,0x66,0x65,0x72,0x20,0x76,0x73,0x5f,0x75,0x6e,0x69,0x66,0x6f,
    0x72,0x6d,0x73,0x20,0x3a,0x20,0x72,0x65,0x67,0x69,0x73,0x74,0x65,0x72,0x28,0x62,
    0x30,0x29,0x0a,0x7b,0x0a,0x20,0x20,0x20,0x20,0x72,0x6f,0x77,0x5f,0x6d,0x61,0x6a,
    0x6f,0x72,0x20,0x66,0x6c,0x6f,0x61,0x74,0x34,0x78,0x34,0x20,0x5f,0x32,0x30,0x5f,
    0x6d,0x76,0x70,0x20,0x3a,0x20,0x70,0x61,0x63,0x6b,0x6f,0x66,0x66,0x73,0x65,0x74,
    0x28,0x63,0x30,0x29,0x3b,0x0a,0x7d,0x3b,0x0a,0x0a,0x0a,0x73,0x74,0x61,0x74,0x69,
    0x63,0x20,0x66,0x6c,0x6f,0x61,0x74,0x34,0x20,0x67,0x6c,0x5f,0x50,0x6f,0x73,0x69,
    0x74,0x69,0x6f,0x6e,0x3b,0x0a,0x73,0x74,0x61,0x74,0x69,0x63,0x20,0x66,0x6c,0x6f,
    0x61,0x74,0x34,0x20,0x70,0x6f,0x73,0x69,0x74,0x69,0x6f,0x6e,0x3b,0x0a,0x73,0x74,
    0x61,0x74,0x69,0x63,0x20,0x66,0x6c,0x6f,0x61,0x74,0x34,0x20,0x63,0x6f,0x6c,0x6f,
    0x72,0x3b,0x0a,0x73,0x74,0x61,0x74,0x69,0x63,0x20,0x66,0x6c,0x6f,0x61,0x74,0x34,
    0x20,0x63,0x6f,0x6c,0x6f,0x72,0x30,0x3b,0x0a,0x0a,0x73,0x74,0x72,0x75,0x63,0x74,
    0x20,0x53,0x50,0x49,0x52,0x56,0x5f,0x43,0x72,0x6f,0x73,0x73,0x5f,0x49,0x6e,0x70,
    0x75,0x74,0x0a,0x7b,0x0a,0x20,0x20,0x20,0x20,0x66,0x6c,0x6f,0x61,0x74,0x34,0x20,
    0x70,0x6f,0x73,0x69,0x74,0x69,0x6f,0x6e,0x20,0x3a,0x20,0x54,0x45,0x58,0x43,0x4f,
    0x4f,0x52,0x44,0x30,0x3b,0x0a,0x20,0x20,0x20,0x20,0x66,0x6c,0x6f,0x61,0x74,0x34,
    0x20,0x63,0x6f,0x6c,0x6f,0x72,0x30,0x20,0x3a,0x20,0x54,0x45,0x58,0x43,0x4f,0x4f,
    0x52,0x44,0x31,0x3b,0x0a,0x7d,0x3b,0x0a,0x0a,0x73,0x74,0x72,0x75,0x63,0x74,0x20,
    0x53,0x50,0x49,0x52,0x56,0x5f,0x43,0x72,0x6f,0x73,0x73,0x5f,0x4f,0x75,0x74,0x70,
    0x75,0x74,0x0a,0x7b,0x0a,0x20,0x20,0x20,0x20,0x66,0x6c,0x6f,0x61,0x74,0x34,0x20,
    0x63,0x6f,0x6c,0x6f,0x72,0x20,0x3a,0x20,0x54,0x45,0x58,0x43,0x4f,0x4f,0x52,0x44,
    0x30,0x3b,0x0a,0x20,0x20,0x20,0x20,0x66,0x6c,0x6f,0x61,0x74,0x34,0x20,0x67,0x6c,
    0x5f,0x50,0x6f,0x73,0x69,0x74,0x69,0x6f,0x6e,0x20,0x3a,0x20,0x53,0x56,0x5f,0x50,
    0x6f,0x73,0x69,0x74,0x69,0x6f,0x6e,0x3b,0x0a,0x7d,0x3b,0x0a,0x0a,0x23,0x6c,0x69,
    0x6e,0x65,0x20,0x31,0x34,0x20,0x22,0x22,0x0a,0x76,0x6f,0x69,0x64,0x20,0x76,0x65,
    0x72,0x74,0x5f,0x6d,0x61,0x69,0x6e,0x28,0x29,0x0a,0x7b,0x0a,0x23,0x6c,0x69,0x6e,
    0x65,0x20,0x31,0x34,0x20,0x22,0x22,0x0a,0x20,0x20,0x20,0x20,0x67,0x6c,0x5f,0x50,
    0x6f,0x73,0x69,0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,0x6d,0x75,0x6c,0x28,0x70,0x6f,
    0x73,0x69,0x74,0x69,0x6f,0x6e,0x2c,0x20,0x5f,0x32,0x30,0x5f,0x6d,0x76,0x70,0x29,
    0x3b,0x0a,0x23,0x6c,0x69,0x6e,0x65,0x20,0x31,0x35,0x20,0x22,0x22,0x0a,0x20,0x20,
    0x20,0x20,0x63,0x6f,0x6c,0x6f,0x72,0x20,0x3d,0x20,0x63,0x6f,0x6c,0x6f,0x72,0x30,
    0x3b,0x0a,0x7d,0x0a,0x0a,0x53,0x50,0x49,0x52,0x56,0x5f,0x43,0x72,0x6f,0x73,0x73,
    0x5f,0x4f,0x75,0x74,0x70,0x75,0x74,0x20,0x6d,0x61,0x69,0x6e,0x28,0x53,0x50,0x49,
    0x52,0x56,0x5f,0x43,0x72,0x6f,0x73,0x73,0x5f,0x49,0x6e,0x70,0x75,0x74,0x20,0x73,
    0x74,0x61,0x67,0x65,0x5f,0x69,0x6e,0x70,0x75,0x74,0x29,0x0a,0x7b,0x0a,0x20,0x20,
    0x20,0x20,0x70,0x6f,0x73,0x69,0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,0x73,0x74,0x61,
    0x67,0x65,0x5f,0x69,0x6e,0x70,0x75,0x74,0x2e,0x70,0x6f,0x73,0x69,0x74,0x69,0x6f,
    0x6e,0x3b,0x0a,0x20,0x20,0x20,0x20,0x63,0x6f,0x6c,0x6f,0x72,0x30,0x20,0x3d,0x20,
    0x73,0x74,0x61,0x67,0x65,0x5f,0x69,0x6e,0x70,0x75,0x74,0x2e,0x63,0x6f,0x6c,0x6f,
    0x72,0x30,0x3b,0x0a,0x20,0x20,0x20,0x20,0x76,0x65,0x72,0x74,0x5f,0x6d,0x61,0x69,
    0x6e,0x28,0x29,0x3b,0x0a,0x20,0x20,0x20,0x20,0x53,0x50,0x49,0x52,0x56,0x5f,0x43,
    0x72,0x6f,0x73,0x73,0x5f,0x4f,0x75,0x74,0x70,0x75,0x74,0x20,0x73,0x74,0x61,0x67,
    0x65,0x5f,0x6f,0x75,0x74,0x70,0x75,0x74,0x3b,0x0a,0x20,0x20,0x20,0x20,0x73,0x74,
    0x61,0x67,0x65,0x5f,0x6f,0x75,0x74,0x70,0x75,0x74,0x2e,0x67,0x6c,0x5f,0x50,0x6f,
    0x73,0x69,0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,0x67,0x6c,0x5f,0x50,0x6f,0x73,0x69,
    0x74,0x69,0x6f,0x6e,0x3b,0x0a,0x20,0x20,0x20,0x20,0x73,0x74,0x61,0x67,0x65,0x5f,
    0x6f,0x75,0x74,0x70,0x75,0x74,0x2e,0x63,0x6f,0x6c,0x6f,0x72,0x20,0x3d,0x20,0x63,
    0x6f,0x6c,0x6f,0x72,0x3b,0x0a,0x20,0x20,0x20,0x20,0x72,0x65,0x74,0x75,0x72,0x6e,
    0x20,0x73,0x74,0x61,0x67,0x65,0x5f,0x6f,0x75,0x74,0x70,0x75,0x74,0x3b,0x0a,0x7d,
    0x0a,0x00,
};
/*
    cbuffer global_params : register(b0)
    {
        float _19_time : packoffset(c0);
    };
    
    
    static float4 frag_color;
    static float4 color;
    
    struct SPIRV_Cross_Input
    {
        float4 color : TEXCOORD0;
    };
    
    struct SPIRV_Cross_Output
    {
        float4 frag_color : SV_Target0;
    };
    
    #line 14 ""
    void frag_main()
    {
    #line 14 ""
        frag_color = lerp(color, float4(1.0f, 0.0f, 1.0f, 1.0f), ((sin(_19_time) + 1.0f) * 0.5f).xxxx);
    }
    
    SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
    {
        color = stage_input.color;
        frag_main();
        SPIRV_Cross_Output stage_output;
        stage_output.frag_color = frag_color;
        return stage_output;
    }
*/
@(private)
fs_source_hlsl5 := [?]u8 {
    0x63,0x62,0x75,0x66,0x66,0x65,0x72,0x20,0x67,0x6c,0x6f,0x62,0x61,0x6c,0x5f,0x70,
    0x61,0x72,0x61,0x6d,0x73,0x20,0x3a,0x20,0x72,0x65,0x67,0x69,0x73,0x74,0x65,0x72,
    0x28,0x62,0x30,0x29,0x0a,0x7b,0x0a,0x20,0x20,0x20,0x20,0x66,0x6c,0x6f,0x61,0x74,
    0x20,0x5f,0x31,0x39,0x5f,0x74,0x69,0x6d,0x65,0x20,0x3a,0x20,0x70,0x61,0x63,0x6b,
    0x6f,0x66,0x66,0x73,0x65,0x74,0x28,0x63,0x30,0x29,0x3b,0x0a,0x7d,0x3b,0x0a,0x0a,
    0x0a,0x73,0x74,0x61,0x74,0x69,0x63,0x20,0x66,0x6c,0x6f,0x61,0x74,0x34,0x20,0x66,
    0x72,0x61,0x67,0x5f,0x63,0x6f,0x6c,0x6f,0x72,0x3b,0x0a,0x73,0x74,0x61,0x74,0x69,
    0x63,0x20,0x66,0x6c,0x6f,0x61,0x74,0x34,0x20,0x63,0x6f,0x6c,0x6f,0x72,0x3b,0x0a,
    0x0a,0x73,0x74,0x72,0x75,0x63,0x74,0x20,0x53,0x50,0x49,0x52,0x56,0x5f,0x43,0x72,
    0x6f,0x73,0x73,0x5f,0x49,0x6e,0x70,0x75,0x74,0x0a,0x7b,0x0a,0x20,0x20,0x20,0x20,
    0x66,0x6c,0x6f,0x61,0x74,0x34,0x20,0x63,0x6f,0x6c,0x6f,0x72,0x20,0x3a,0x20,0x54,
    0x45,0x58,0x43,0x4f,0x4f,0x52,0x44,0x30,0x3b,0x0a,0x7d,0x3b,0x0a,0x0a,0x73,0x74,
    0x72,0x75,0x63,0x74,0x20,0x53,0x50,0x49,0x52,0x56,0x5f,0x43,0x72,0x6f,0x73,0x73,
    0x5f,0x4f,0x75,0x74,0x70,0x75,0x74,0x0a,0x7b,0x0a,0x20,0x20,0x20,0x20,0x66,0x6c,
    0x6f,0x61,0x74,0x34,0x20,0x66,0x72,0x61,0x67,0x5f,0x63,0x6f,0x6c,0x6f,0x72,0x20,
    0x3a,0x20,0x53,0x56,0x5f,0x54,0x61,0x72,0x67,0x65,0x74,0x30,0x3b,0x0a,0x7d,0x3b,
    0x0a,0x0a,0x23,0x6c,0x69,0x6e,0x65,0x20,0x31,0x34,0x20,0x22,0x22,0x0a,0x76,0x6f,
    0x69,0x64,0x20,0x66,0x72,0x61,0x67,0x5f,0x6d,0x61,0x69,0x6e,0x28,0x29,0x0a,0x7b,
    0x0a,0x23,0x6c,0x69,0x6e,0x65,0x20,0x31,0x34,0x20,0x22,0x22,0x0a,0x20,0x20,0x20,
    0x20,0x66,0x72,0x61,0x67,0x5f,0x63,0x6f,0x6c,0x6f,0x72,0x20,0x3d,0x20,0x6c,0x65,
    0x72,0x70,0x28,0x63,0x6f,0x6c,0x6f,0x72,0x2c,0x20,0x66,0x6c,0x6f,0x61,0x74,0x34,
    0x28,0x31,0x2e,0x30,0x66,0x2c,0x20,0x30,0x2e,0x30,0x66,0x2c,0x20,0x31,0x2e,0x30,
    0x66,0x2c,0x20,0x31,0x2e,0x30,0x66,0x29,0x2c,0x20,0x28,0x28,0x73,0x69,0x6e,0x28,
    0x5f,0x31,0x39,0x5f,0x74,0x69,0x6d,0x65,0x29,0x20,0x2b,0x20,0x31,0x2e,0x30,0x66,
    0x29,0x20,0x2a,0x20,0x30,0x2e,0x35,0x66,0x29,0x2e,0x78,0x78,0x78,0x78,0x29,0x3b,
    0x0a,0x7d,0x0a,0x0a,0x53,0x50,0x49,0x52,0x56,0x5f,0x43,0x72,0x6f,0x73,0x73,0x5f,
    0x4f,0x75,0x74,0x70,0x75,0x74,0x20,0x6d,0x61,0x69,0x6e,0x28,0x53,0x50,0x49,0x52,
    0x56,0x5f,0x43,0x72,0x6f,0x73,0x73,0x5f,0x49,0x6e,0x70,0x75,0x74,0x20,0x73,0x74,
    0x61,0x67,0x65,0x5f,0x69,0x6e,0x70,0x75,0x74,0x29,0x0a,0x7b,0x0a,0x20,0x20,0x20,
    0x20,0x63,0x6f,0x6c,0x6f,0x72,0x20,0x3d,0x20,0x73,0x74,0x61,0x67,0x65,0x5f,0x69,
    0x6e,0x70,0x75,0x74,0x2e,0x63,0x6f,0x6c,0x6f,0x72,0x3b,0x0a,0x20,0x20,0x20,0x20,
    0x66,0x72,0x61,0x67,0x5f,0x6d,0x61,0x69,0x6e,0x28,0x29,0x3b,0x0a,0x20,0x20,0x20,
    0x20,0x53,0x50,0x49,0x52,0x56,0x5f,0x43,0x72,0x6f,0x73,0x73,0x5f,0x4f,0x75,0x74,
    0x70,0x75,0x74,0x20,0x73,0x74,0x61,0x67,0x65,0x5f,0x6f,0x75,0x74,0x70,0x75,0x74,
    0x3b,0x0a,0x20,0x20,0x20,0x20,0x73,0x74,0x61,0x67,0x65,0x5f,0x6f,0x75,0x74,0x70,
    0x75,0x74,0x2e,0x66,0x72,0x61,0x67,0x5f,0x63,0x6f,0x6c,0x6f,0x72,0x20,0x3d,0x20,
    0x66,0x72,0x61,0x67,0x5f,0x63,0x6f,0x6c,0x6f,0x72,0x3b,0x0a,0x20,0x20,0x20,0x20,
    0x72,0x65,0x74,0x75,0x72,0x6e,0x20,0x73,0x74,0x61,0x67,0x65,0x5f,0x6f,0x75,0x74,
    0x70,0x75,0x74,0x3b,0x0a,0x7d,0x0a,0x00,
};
@(private)
vertcolor_shader_desc_hlsl5 := sg.Shader_Desc {
  0, /* _start_canary */
  { /*attrs*/{"position","TEXCOORD",0},{"color0","TEXCOORD",1},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0},{nil,nil,0}, },
  { /* vs */
    cstring(&vs_source_hlsl5[0]), /* source */
    nil,  /* bytecode */
    0,  /* bytecode_size */
    "main", /* entry */
    { /* uniform blocks */
      {
        64, /* size */
        { /* uniforms */{"vs_uniforms",sg.Uniform_Type.FLOAT4,4},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0}, },
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
    cstring(&fs_source_hlsl5[0]), /* source */
    nil,  /* bytecode */
    0,  /* bytecode_size */
    "main", /* entry */
    { /* uniform blocks */
      {
        16, /* size */
        { /* uniforms */{"global_params",sg.Uniform_Type.FLOAT4,1},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0},{nil,sg.Uniform_Type.INVALID,0}, },
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
  "vertcolor_shader", /* label */
  0, /* _end_canary */
};
} // SOKOL_D3D11
// #if !defined(SOKOL_GFX_INCLUDED)
//  #error "Please include sokol_gfx.h before vertcolor.odin"
// #endif
vertcolor_shader_desc :: proc() -> ^sg.Shader_Desc {
    when SOKOL_D3D11 {
    if sg.query_backend() == sg.Backend.D3D11 {
        return &vertcolor_shader_desc_hlsl5;
    }
    } /* SOKOL_D3D11 */
    return nil; /* can't happen */
}
