package main

import "core:intrinsics"
import sg "sokol:sokol_gfx"

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

static_shader :: inline proc(s: ^sg.Shader, desc: ^sg.Shader_Desc) -> sg.Shader {
    if s.id == 0 {
        s^ = sg.make_shader(desc^);
    }

    return s^;
}
