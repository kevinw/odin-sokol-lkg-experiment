package main

import "core:intrinsics"
import "core:fmt"
import sg "../lib/odin-sokol/src/sokol_gfx"
import "./watcher"
import "core:log"
import "core:os"
import "core:strings"

apply_uniforms_ptr :: proc(stage: sg.Shader_Stage, slot: int, uniforms: ^$T) {
    sg.apply_uniforms(stage, slot, uniforms, size_of(T));
}

apply_uniforms_struct :: proc(stage: sg.Shader_Stage, slot: int, uniforms: $T)
    where intrinsics.type_is_struct(T)
{
    _uniforms := uniforms;
    sg.apply_uniforms(stage, slot, &_uniforms, size_of(T));
}

apply_uniforms :: proc { apply_uniforms_ptr, apply_uniforms_struct };

// Create a Buffer from a pointer to a constant-sized array
make_buffer :: proc(label: cstring, elements: ^[$N]$T) -> sg.Buffer
    where intrinsics.type_is_struct(T)
{
    return sg.make_buffer({
        label = label,
        size = N * size_of(T),
        content = &elements[0]
    });
}

get_quad_xy_uv_01 :: proc() -> sg.Buffer {
    @static did_init := false;
    @static buf: sg.Buffer;
    
    if !did_init {
        Vertex :: struct { pos: [2]f32, uv: [2]f32, };

        vertices := [?]Vertex {
            {{0, 0}, {0, 0}}, {{1, 0}, {1, 0}}, {{1, 1}, {1, 1}},
            {{0, 0}, {0, 0}}, {{1, 1}, {1, 1}}, {{0, 1}, {0, 1}},
        };

        buf = make_buffer("quad_xy_uv_01", &vertices);

        did_init = true;
    }

    return buf;
}

get_quad_negone_one :: proc() -> sg.Buffer {
    @static did_init := false;
    @static quad_buf: sg.Buffer;
    
    if !did_init {
        Vertex :: struct { pos: [2]f32, uv: [2]f32, };

        vertices := [?]Vertex {
            {{-1, -1}, {0, 1}}, {{1, -1}, {1, 1}}, {{+1, 1}, {1, 0}},
            {{-1, -1}, {0, 1}}, {{1, +1}, {1, 0}}, {{-1, 1}, {0, 0}},
        };

        quad_buf = make_buffer("quad_negone_one buffer", &vertices);

        did_init = true;
    }

    return quad_buf;
}

make_image :: proc(width, height: i32, pixel_format: sg.Pixel_Format, pixels: []u32 = nil) -> sg.Image {
    image_desc := sg.Image_Desc {
        width = width,
        height = height,
        pixel_format = pixel_format
    };
    if pixels != nil {
        image_desc.content.subimage[0][0] = {
            ptr = &pixels[0],
            size = cast(i32)len(pixels), // ??????????????????????????
        };
    }
    return sg.make_image(image_desc);
}

rendertarget_array_desc :: proc(width, height, num_layers: i32, label: cstring) -> sg.Image_Desc {
    offscreen_sample_count := sg.query_features().msaa_render_targets ? MSAA_SAMPLE_COUNT : 1;
    desc := sg.Image_Desc {
        render_target = true,
        type = .ARRAY,
        width = width,
        height = height,
        min_filter = .LINEAR,
        mag_filter = .LINEAR,
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        sample_count = cast(i32)offscreen_sample_count,
        label = "multiview color image"
    };
    desc.layers = num_layers;
    return desc;
}

reinit_image :: inline proc(img: ^sg.Image, desc: sg.Image_Desc) {
    assert(img != nil);

    sg.destroy_image(img^);
    img^ = sg.make_image(desc);
}

reinit_pass :: inline proc(pass: ^sg.Pass, desc: sg.Pass_Desc) {
    assert(pass != nil);

    sg.destroy_pass(pass^);
    pass^ = sg.make_pass(desc);
}

reinit_pipeline :: inline proc(pipeline: ^sg.Pipeline, desc: sg.Pipeline_Desc) {
    assert(pipeline != nil);

    sg.destroy_pipeline(pipeline^);
    pipeline^ = sg.make_pipeline(desc);
}

on_shader_changed :: proc(notification: watcher.Change_Notification) {
    for _, i in reloadable_pipelines {
        p := &reloadable_pipelines[i];

        needs_recompile := false;
        for filename in p.filenames {
            if filename == notification.asset_id {
                needs_recompile = true;
                break;
            }
        }

        if !needs_recompile do continue;

        using notification;

        exe := `C:\src\fips-deploy\sokol-tools\win64-vstudio-release\sokol-shdc.exe`;
        //filename_without_ext := remove_last_extension(asset_id);
        args := fmt.tprintf(`--slang hlsl5 --input %s --format bare --output "temp_shaders/"`, asset_id);
        if !subprocess("%s %s", exe, args) { 
            log.error("error calling sokol-shdc");
            continue;
        }

        program_name := p.label;
        if program_name == "" {
            fmt.println("no label, skipping");
            continue;
        }

        vert_filename := fmt.tprintf("temp_shaders/%s_vs.hlsl", program_name);
        frag_filename := fmt.tprintf("temp_shaders/%s_fs.hlsl", program_name);
        vert, ok1 := os.read_entire_file(vert_filename);
        frag, ok2 := os.read_entire_file(frag_filename);

        if ok1 && ok2 {
            shader_desc := p.shader_desc;
            shader_desc.vs.source = strings.clone_to_cstring(string(vert)); // @Leak
            shader_desc.fs.source = strings.clone_to_cstring(string(frag)); // @Leak
            new_shader := sg.make_shader(shader_desc);
            if new_shader.id == sg.INVALID_ID {
                log.error("could not compile new shader");
            } else {
                p.shader_desc = shader_desc;
                sg.destroy_shader(p.pipeline_desc.shader);
                p.pipeline_desc.shader = new_shader;
                new_pipeline := sg.make_pipeline(p.pipeline_desc);
                if new_pipeline.id == sg.INVALID_ID {
                    log.error("could not compile new pipeline");
                } else {
                    sg.destroy_pipeline(p.pipeline^);
                    log.info("reassigning pipeline %s", p.pipeline_desc.label);
                    p.pipeline^ = new_pipeline;
                }
            }
        } else {
            log.error("couldn't find output shaders %s or %s", frag_filename, vert_filename);
        }
    }
}

Reloadable_Pipeline :: struct {
    label: string, // TODO: this needs to correspond to the @program name in the shader for now
    pipeline: ^sg.Pipeline,
    pipeline_desc: sg.Pipeline_Desc,
    shader_desc: sg.Shader_Desc,
    filenames: []string,
};

reloadable_pipelines: [dynamic]Reloadable_Pipeline;

reloadable_pipeline :: proc(pipeline: ^sg.Pipeline, filenames: []string, shader_desc: sg.Shader_Desc, pipeline_desc_: sg.Pipeline_Desc) {
    found := false;
    for _, i in reloadable_pipelines {
        p := &reloadable_pipelines[i];
        if p.pipeline == pipeline {
            found = true;
            break;
        }
    }

    pipeline_desc := pipeline_desc_;

    assert(pipeline_desc.shader.id == 0, "expected to make our own shader here");
    shader := sg.make_shader(shader_desc);
    pipeline_desc.shader = shader;

    assert(pipeline != nil);
    sg.destroy_pipeline(pipeline^);
    pipeline^ = sg.make_pipeline(pipeline_desc);

    if !found {
        append(&reloadable_pipelines, Reloadable_Pipeline {
            label = string(pipeline_desc.label),
            pipeline = pipeline,
            shader_desc = shader_desc,
            filenames = filenames,
            pipeline_desc = pipeline_desc,
        });
    }
}

static_shader :: inline proc(s: ^sg.Shader, desc: ^sg.Shader_Desc) -> sg.Shader {
    if s.id == 0 {
        s^ = sg.make_shader(desc^);
    }

    return s^;
}

Placeholder_Texture :: enum {
    WHITE,
    BLACK,
    NORMALS,
}


get_placeholder_image :: proc(type: Placeholder_Texture) -> sg.Image {
    @static did_init_placeholders := false;
    @static white, black, normals: sg.Image;
    if !did_init_placeholders {
        pixels: [64]u32;
        for i in 0..<64 do pixels[i] = 0xFFFFFFFF;
        white = make_image(8, 8, sg.Pixel_Format.RGBA8, pixels[:]);
        for i in 0..<64 do pixels[i] = 0xFF000000;
        black = make_image(8, 8, sg.Pixel_Format.RGBA8, pixels[:]);
        for i in 0..<64 do pixels[i] = 0xFFFF7FFF;
        normals = make_image(8, 8, sg.Pixel_Format.RGBA8, pixels[:]);

        did_init_placeholders = true;
    }

    switch type {
        case .WHITE: return white;
        case .BLACK: return black;
        case .NORMALS: return normals;
    }

    return sg.Image {};
}

@(deferred_out=sg.end_pass)
BEGIN_PASS :: proc(pass: sg.Pass, pass_action: sg.Pass_Action) {
    sg.begin_pass(pass, pass_action);
}

