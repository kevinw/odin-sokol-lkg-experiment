package main

import sg "sokol:sokol_gfx"
import sfetch "sokol:sokol_fetch"
import "core:strings"
import "core:fmt"
import "core:mem"
import "shared:odin-stb/stbi"
import shader_meta "./shader_meta"
import "core:encoding/json"
using import "math"

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
    pass_action: sg.Pass_Action,
    bind: sg.Bindings,
    pipeline: sg.Pipeline,

    texture_size: Vector2,
    json_data: [256 * 1024]u8,
    metrics: SDF_Text_Metrics,

    vertex_elems: [dynamic]f32,
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
        layout = {
            attrs = {
                shader_meta.ATTR_vs_a_pos = {format = .FLOAT2},
                shader_meta.ATTR_vs_a_texcoord = {format = .FLOAT2},
            },
        },
    });
    pass_action.colors[0] = {action = .LOAD, val = {1.0, 0.0, 1.0, 1.0}};
}

sdf_text_render :: proc(matrix: Matrix4, color: Vector4, gamma, buf: f32) {
    vs_uniforms := shader_meta.sdf_vs_uniforms {
        matrix = matrix,
        texsize = text.texture_size,
    };

    fs_uniforms := shader_meta.sdf_fs_uniforms {
        color = color,
        debug = 0.0,
        gamma = gamma,
        buf = buf,
    };

    using text;

    if needs_update {
        sg.update_buffer(bind.vertex_buffers[0], &vertex_elems[0], len(vertex_elems) * size_of(vertex_elems[0]));
    }

    sg.apply_pipeline(pipeline);
    sg.apply_bindings(bind);
    sg.apply_uniforms(.VS, shader_meta.SLOT_sdf_vs_uniforms, &vs_uniforms, size_of(shader_meta.sdf_vs_uniforms));
    sg.apply_uniforms(.FS, shader_meta.SLOT_sdf_fs_uniforms, &fs_uniforms, size_of(shader_meta.sdf_fs_uniforms));
    sg.draw(0, len(vertex_elems) / 4, 1);

    if needs_update {
        clear(&text.vertex_elems); // must happen after the draw call? is the update_buffer not immediate?
        needs_update = false;
    }
}

draw_text :: proc(str: string, size: f32, pos: Vector2) {
    using text;

    needs_update = true;

    pen := Vector3 {pos.x, pos.y, 0};

    buf := strings.make_builder();
    defer strings.destroy_builder(&buf);

    for r in str {
        strings.reset_builder(&buf);
        strings.write_rune(&buf, r);
        r_str := strings.to_string(buf);
        draw_glyph(r_str, &pen, size, &vertex_elems);
    }

    if text.bind.vertex_buffers[0].id == 0 {
        text.bind.vertex_buffers[0] = sg.make_buffer({
            size = cast(i32)(5000 * size_of(vertex_elems[0])),
            usage = .DYNAMIC,
            label = "text-glyph-vertices",
        });
    }
}

draw_glyph :: proc(character: string, pen: ^Vector3, size: f32, vertex_elements: ^[dynamic]f32) {
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

    if width > 0 && height > 0 {
        width += buffer * 2.0;
        height += buffer * 2.0;

        y0 := pen.y - (height - h_bearing_y) * scale;
        y1 := pen.y + (h_bearing_y) * scale;

        append(vertex_elements, 
            (factor * (pen.x + ((h_bearing_x - buffer) * scale))), (factor * y0),
            pos_x, pos_y + height,
            (factor * (pen.x + ((h_bearing_x - buffer + width) * scale))), (factor * y0),
            pos_x + width, pos_y + height,
            (factor * (pen.x + ((h_bearing_x - buffer) * scale))), (factor * y1),
            pos_x, pos_y,

            (factor * (pen.x + ((h_bearing_x - buffer + width) * scale))), (factor * y0),
            pos_x + width, pos_y + height,
            (factor * (pen.x + ((h_bearing_x - buffer) * scale))), (factor * y1),
            pos_x, pos_y,
            (factor * (pen.x + ((h_bearing_x - buffer + width) * scale))), (factor * y1),
            pos_x + width, pos_y
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
