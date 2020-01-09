package main

import sg "../lib/odin-sokol/src/sokol_gfx"
import sfetch "../lib/odin-sokol/src/sokol_fetch"
import "core:strings"
import "core:fmt"
import "core:mem"
import "shared:odin-stb/stbi"
import shader_meta "./shader_meta"
import "core:encoding/json"

SDF_Text_Vert_Attrib :: struct #packed {
    gamma: f32,
    buf: f32,
    unused0: f32,
    unused1: f32,
}

SDF_Text_Vert :: struct #packed {
    pos: Vector3,
    uv: Vector2,
    attribs: SDF_Text_Vert_Attrib,
};

// TODO: generate this with the above struct, using anotations, at compile-time
// or, even better, generate this, AND the above struct, via the shader compiler...hmm...
@private _layout := sg.Layout_Desc { 
    attrs = {
        shader_meta.ATTR_vs_a_pos = {format = .FLOAT3},
        shader_meta.ATTR_vs_a_texcoord = {format = .FLOAT2},
        shader_meta.ATTR_vs_a_attribs = {format = .FLOAT4},
    },
};

SDF_Text_Metrics :: struct {
    family: string,
    style: string,
    buffer: int,
    size: int,
    chars: map[string]SDF_Text_Chars,
}

SDF_Text_Chars :: struct {
    width: u16,
    height: u16,
    horizontal_bearing_x: u16,
    horizontal_bearing_y: u16,
    horizontal_advance: u16,
    pos_x: u16,
    pos_y: u16,
};

text: struct {
    pass: sg.Pass,
    pass_action: sg.Pass_Action,
    bind: sg.Bindings,
    pipeline: sg.Pipeline,

    texture_size: Vector2,
    json_data: [256 * 1024]u8,
    metrics: SDF_Text_Metrics,

    vertex_elems: [dynamic]SDF_Text_Vert,
    needs_update: bool,
};

_load_count := 0;
_did_load := false;

load_sdf_fonts :: proc() {
    sfetch.send({
        path = "resources/OpenSans-Regular.png",
        callback = font_normal_loaded,
        buffer_ptr = &state.font_normal_data[0],
        buffer_size = size_of(state.font_normal_data),
    });

    sfetch.send({
        path = "resources/OpenSans-Regular.json",
        callback = font_json_loaded,
        buffer_ptr = &text.json_data[0],
        buffer_size = size_of(text.json_data),
    });
}

did_load :: proc() {
    _load_count += 1;
    if _load_count != 2 do return;
    _did_load = true;
}

sdf_text_init :: proc() {
    using text;
    bind.fs_images[shader_meta.SLOT_font_atlas] = sg.alloc_image();
    pipeline = sg.make_pipeline({
        label = "sdf-text-pipeline",
        shader = sg.make_shader(shader_meta.sdf_text_shader_desc()^),
        primitive_type = .TRIANGLES,
        blend = {
            enabled = true,
            src_factor_rgb = .SRC_ALPHA,
            dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
        },
        layout = _layout,
    });
    pass_action.colors[0] = {action = .LOAD, val = {1.0, 0.0, 1.0, 1.0}};
}

sdf_text_render :: proc(view_proj_array: [MAXIMUM_VIEWS]Matrix4, model_matrix: Matrix4, num_views: int, color: Vector4) {
    vs_uniforms := shader_meta.sdf_vs_uniforms {
        view_proj_array = view_proj_array,
        model_matrix = model_matrix,
        texsize = text.texture_size,
    };

    fs_uniforms := shader_meta.sdf_fs_uniforms {
        color = color,
        debug = 0.0,
    };

    using text;

    if needs_update {
        if text.bind.vertex_buffers[0].id == 0 {
            text.bind.vertex_buffers[0] = sg.make_buffer({
                size = cast(i32)(15000 * size_of(vertex_elems[0])),
                usage = .DYNAMIC,
                label = "text-glyph-vertices",
            });
        }

        sg.update_buffer(bind.vertex_buffers[0], &vertex_elems[0], len(vertex_elems) * size_of(vertex_elems[0]));
    }
    defer if needs_update {
        clear(&text.vertex_elems); // must happen after the draw call? is the update_buffer not immediate?
        needs_update = false;
    }

    sg.apply_pipeline(pipeline);
    sg.apply_bindings(bind);
    apply_uniforms(.VS, shader_meta.SLOT_sdf_vs_uniforms, &vs_uniforms);
    apply_uniforms(.FS, shader_meta.SLOT_sdf_fs_uniforms, &fs_uniforms);
    sg.draw(0, len(vertex_elems), num_views);
}

draw_text :: proc(flip_y: bool, str: string, size: f32, pos: Vector3, gamma, buf: f32) {
    using text;

    needs_update = true;
    pen := pos;
    string_buf := strings.make_builder();
    defer strings.destroy_builder(&string_buf);

    for r in str {
        // @Speed -- isn't there a faster way to iterate the runes than writing
        // them into a buffer?
        strings.reset_builder(&string_buf);
        strings.write_rune(&string_buf, r);
        r_str := strings.to_string(string_buf);
        draw_glyph(flip_y, r_str, &pen, size, &vertex_elems, gamma, buf);
    }

}

draw_glyph :: proc(flip_y: bool, character: string, pen: ^Vector3, size: f32, vertex_elements: ^[dynamic]SDF_Text_Vert, gamma, buf: f32) {
    metric, found := text.metrics.chars[character];
    if !found do return;

    metrics := &text.metrics;

    scale := size / cast(f32)metrics.size;
    buffer := cast(f32)metrics.buffer;

    factor:f32 = 1.0;

    width := cast(f32)metric.width;
    height := cast(f32)metric.height;
    h_bearing_x := cast(f32)metric.horizontal_bearing_x;
    h_bearing_y := cast(f32)metric.horizontal_bearing_y;
    h_advance := cast(f32)metric.horizontal_advance;
    pos_x := cast(f32)metric.pos_x;
    pos_y := cast(f32)metric.pos_y;

    pos_y_0 := pos_y;
    pos_y_1 := pos_y + height;

    if flip_y {
        pos_y_1 = pos_y;
        pos_y_0 = pos_y + height;
    }

    if width > 0 && height > 0 {
        width += buffer * 2.0;
        height += buffer * 2.0;

        y0 := pen.y - (height - h_bearing_y) * scale;
        y1 := pen.y + (h_bearing_y) * scale;
        z:f32 = pen.z;

        attribs := SDF_Text_Vert_Attrib {
            gamma = gamma,
            buf = buf,
        };

        // two tris per glyph
        V :: SDF_Text_Vert;
        append(vertex_elements, 
            V{ { (factor * (pen.x + ((h_bearing_x - buffer) * scale))), (factor * y0), z }, 
               { pos_x, pos_y_1, }, attribs },
            V{ { (factor * (pen.x + ((h_bearing_x - buffer + width) * scale))), (factor * y0), z },
               { pos_x + width, pos_y_1 }, attribs },
            V{ { (factor * (pen.x + ((h_bearing_x - buffer) * scale))), (factor * y1), z },
                { pos_x, pos_y_0 }, attribs },

            V{ { (factor * (pen.x + ((h_bearing_x - buffer + width) * scale))), (factor * y0), z },
               { pos_x + width, pos_y_1 }, attribs },
            V{ { (factor * (pen.x + ((h_bearing_x - buffer) * scale))), (factor * y1), z },
               { pos_x, pos_y_0 }, attribs },
            V{ { (factor * (pen.x + ((h_bearing_x - buffer + width) * scale))), (factor * y1), z },
               { pos_x + width, pos_y_0 }, attribs },
        );
    }

    // pen.x += Math.ceil(h_advance * scale);
    pen.x = pen.x + h_advance * scale;
}


font_json_loaded :: proc "c" (response: ^sfetch.Response) {
    if !response.fetched {
        fmt.eprintln("error fetching font json", response);
        return;
    }

    json_text := mem.slice_ptr(cast(^u8)response.buffer_ptr, cast(int)response.fetched_size);
    text.metrics = metrics_from_json(json_text);

    did_load();
}

font_normal_loaded :: proc "c" (response: ^sfetch.Response) {
    if !response.fetched {
        fmt.eprintln("error fetching normal font", response);
        return;
    }

    width, height, channels:i32 = ---, ---, ---;

    ptr := cast(^u8)response.buffer_ptr;
    size := cast(i32)response.fetched_size;
    
    pixel_data := stbi.load_from_memory(ptr, size, &width, &height, &channels, 0);
    
    if pixel_data == nil {
        fmt.println("could not load image");
        return;
    }

    defer stbi.image_free(pixel_data);

    text.texture_size = v2(width, height);

    pixel_format: sg.Pixel_Format;
    switch channels {
        case 1:
            pixel_format = .R8;
        case 3:
            panic("unimplemented");
        case 4:
            pixel_format = .RGBA8;
        case:
            panic("unexpected number of channels");
    }

    image_desc := sg.Image_Desc {
        width = width,
        height = height,
        pixel_format = pixel_format,
        min_filter = .LINEAR,
        mag_filter = .LINEAR,
    };

    image_desc.content.subimage[0][0] = {
        ptr = pixel_data,
        size = width * height * channels,
    };

    sg.init_image(text.bind.fs_images[shader_meta.SLOT_font_atlas], image_desc);
    
    did_load();
}

// TODO: use asset catalog system or something here
metrics_from_json :: proc(json_text: []byte) -> SDF_Text_Metrics {
    if val, err := json.parse(json_text); err != .None {
        panic("could not parse json");
        return SDF_Text_Metrics {};
    } else {
        using json;

        obj := val.value.(Object);

        text_chars := SDF_Text_Metrics {
            family = obj["family"].value.(String),
            style = obj["style"].value.(String),
            buffer = cast(int)obj["buffer"].value.(Integer),
            size = cast(int)obj["size"].value.(Integer),
        };

        text_chars.chars = make(map[string]SDF_Text_Chars);

        for char, char_values in obj["chars"].value.(Object) {
            arr := char_values.value.(Array);

            get_u16 :: proc(arr: Array, index: int) -> u16 {
                if index < len(arr) {
                    return cast(u16)arr[index].value.(Integer);
                } else {
                    return 0;
                }
            }

            text_chars.chars[char] = SDF_Text_Chars {
                width = get_u16(arr, 0),
                height = get_u16(arr, 1),
                horizontal_bearing_x = get_u16(arr, 2),
                horizontal_bearing_y = get_u16(arr, 3),
                horizontal_advance = get_u16(arr, 4),
                pos_x = get_u16(arr, 5),
                pos_y = get_u16(arr, 6),
            };
        }


        return text_chars;
    }
}
