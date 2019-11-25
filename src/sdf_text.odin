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
    tex_elems: [dynamic]f32,
};

_load_count := 0;
_did_load := false;

Text_Vertex :: struct #packed {
    pos: [2]f32,
    uv: [2]f32,
};

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

    using text;

    size:f32 = 95.0;
    create_text("hello", size);
}

create_text :: proc(str: string, size: f32) {
    using text;

    pen := Vector3 {0, 100, 0};

    buf := strings.make_builder();
    defer strings.destroy_builder(&buf);
    for r in str {
        strings.reset_builder(&buf);
        strings.write_rune(&buf, r);
        r_str := strings.to_string(buf);

        draw_glyph(r_str, &pen, size, &vertex_elems, &tex_elems);
    }

    num_verts := len(vertex_elems) / 2;
    assert(len(vertex_elems) == num_verts * 2);

    verts := make([]Text_Vertex, num_verts);

    for i in 0..<num_verts { // @Speed just use stride/attribute offsets to prevent this copy
        j := i * 2;
        verts[i] = {
            {vertex_elems[j], vertex_elems[j + 1]},
            {tex_elems[j], tex_elems[j + 1]},
        };
    }

    text.bind.vertex_buffers[0] = sg.make_buffer({
        size = cast(i32)(len(verts) * size_of(verts[0])),
        content = &verts[0],
        label = "text-glyph-vertices",
    });

    delete(verts);
}

draw_glyph :: proc(character: string, pen: ^Vector3, size: f32, vertex_elements: ^[dynamic]f32, texture_elements: ^[dynamic]f32) {
    metric, found := text.metrics.chars[character];
    if !found do return;

    metrics := &text.metrics;

    scale := size / cast(f32)metrics.size;
    buffer := cast(f32)metrics.buffer;

    factor:f32 = 1.0;

    width := cast(f32)metric.width;
    height := cast(f32)metric.height;
    horiBearingX := cast(f32)metric.horizontal_bearing_x;
    horiBearingY := cast(f32)metric.horizontal_bearing_y;
    horiAdvance := cast(f32)metric.horizontal_advance;
    posX := cast(f32)metric.pos_x;
    posY := cast(f32)metric.pos_y;

    if width > 0 && height > 0 {
        width += buffer * 2.0;
        height += buffer * 2.0;

        // Add a quad (= two triangles) per glyph.

        y0 := pen.y - (height - horiBearingY) * scale;
        y1 := pen.y + (horiBearingY) * scale;

        append(vertex_elements, 
            (factor * (pen.x + ((horiBearingX - buffer) * scale))), (factor * y0),
            (factor * (pen.x + ((horiBearingX - buffer + width) * scale))), (factor * y0),
            (factor * (pen.x + ((horiBearingX - buffer) * scale))), (factor * y1),

            (factor * (pen.x + ((horiBearingX - buffer + width) * scale))), (factor * y0),
            (factor * (pen.x + ((horiBearingX - buffer) * scale))), (factor * y1),
            (factor * (pen.x + ((horiBearingX - buffer + width) * scale))), (factor * y1)
        );

        append(texture_elements,
            posX, posY + height,
            posX + width, posY + height,
            posX, posY,

            posX + width, posY + height,
            posX, posY,
            posX + width, posY
        );
    }

    // pen.x += Math.ceil(horiAdvance * scale);
    pen.x = pen.x + horiAdvance * scale;
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

    sg.init_image(text.bind.fs_images[shader_meta.SLOT_u_texture], image_desc);
    
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
