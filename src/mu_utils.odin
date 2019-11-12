package main

import sapp "sokol:sokol_app"
import sg "sokol:sokol_gfx"
import sgl "sokol:sokol_gl"
import mu "../lib/microui"
import mu_atlas "../lib/microui/atlas"
import "core:strings"
import "core:intrinsics"
import "core:fmt"
import "core:mem"
using import "core:runtime"
using import "core:math/linalg"

DEFAULT_BUFFER_SIZE :: 200;

key_map: = [512]u8 {
    sapp.Key_Code.LEFT_SHIFT       = cast(u8)mu.Key.Shift,
    sapp.Key_Code.RIGHT_SHIFT      = cast(u8)mu.Key.Shift,
    sapp.Key_Code.LEFT_CONTROL     = cast(u8)mu.Key.Ctrl,
    sapp.Key_Code.RIGHT_CONTROL    = cast(u8)mu.Key.Ctrl,
    sapp.Key_Code.LEFT_ALT         = cast(u8)mu.Key.Alt,
    sapp.Key_Code.RIGHT_ALT        = cast(u8)mu.Key.Alt,
    sapp.Key_Code.ENTER            = cast(u8)mu.Key.Return,
    sapp.Key_Code.BACKSPACE        = cast(u8)mu.Key.Backspace,
};

// TODO: @Speed just make strings with null bytes on the end and cast the pointer!!!
tcstring :: proc(s: string) -> cstring do return strings.clone_to_cstring(s, context.temp_allocator);
tprint :: fmt.tprint;

r_get_text_width :: proc(text: []u8) -> i32 {
    using mu_atlas;

    res:i32 = 0;
    for ch in text {
        res += atlas[ATLAS_FONT + cast(mu.Icon)ch].w;
    }
    return res;
}

mu_label :: proc(ctx: ^mu.Context, s: string) {
    c_str := strings.clone_to_cstring(s, context.temp_allocator);
    mu.label(ctx, c_str);
}

mu_vector :: proc(ctx: ^mu.Context, v: ^$V/[$N]f32, min_val, max_val: f32) -> mu.Res
    where intrinsics.type_is_integer(type_of(N)) && N > 0
{
    mu.layout_begin_column(ctx);
    mu_layout_row(ctx, { 20, -1 }, 0);
    defer mu.layout_end_column(ctx);

    res: mu.Res;
    when N <= 4 {
        when N > 0 do mu.label(ctx, "x:"); res |= mu.slider(ctx, &v[0], min_val, max_val);
        when N > 1 do mu.label(ctx, "y:"); res |= mu.slider(ctx, &v[1], min_val, max_val);
        when N > 2 do mu.label(ctx, "z:"); res |= mu.slider(ctx, &v[2], min_val, max_val);
        when N > 3 do mu.label(ctx, "w:"); res |= mu.slider(ctx, &v[3], min_val, max_val);
    } else {
        inline for j in 0..<N {
            mu.label(ctx, fmt.tprintf("[%d]:", j));
            res |= mu.slider(ctx, &v[j], min_val, max_val);
        }
    }

    return res;
}

r_get_text_height :: proc() -> i32 {
    return 18;
}

mu_checkbox_cstring :: proc(ctx: ^mu.Context, val: ^bool, label: cstring = "") {
    mu.push_id_ptr(ctx, val);
    defer mu.pop_id(ctx);

    checkbox_val:i32 = val^ ? 1 : 0;
    mu.checkbox(ctx, &checkbox_val, label);
    val^ = checkbox_val != 0 ? true : false;
}

mu_checkbox :: proc { mu_checkbox_cstring };

mu_label_printf :: proc(ctx: ^mu.Context, fmt_str: string, args: ..any) {
    mu.label(ctx, tcstring(fmt.tprintf(fmt_str, ..args)));
}

mu_layout_row :: inline proc(ctx: ^mu.Context, widths: []i32, height: i32) {
    mu.layout_row(ctx, cast(i32)len(widths), &widths[0], height);
}

r_init :: proc() {
    mu_atlas.init();

    // atlas image data is in atlas.inl file, this only contains alpha 
    // values, need to expand this to RGBA8
    rgba8_size:u32 = mu_atlas.WIDTH * mu_atlas.HEIGHT * 4;
    rgba8_pixels := make([]u32, rgba8_size);
    defer delete(rgba8_pixels);

    for y in 0..<mu_atlas.HEIGHT {
        for x in 0..<mu_atlas.WIDTH {
            index := y*mu_atlas.WIDTH + x;
            val := index < len(mu_atlas.texture) ? mu_atlas.texture[index] : 0;
            rgba8_pixels[index] = 0x00FFFFFF | (cast(u32)val<<24);
        }
    }

    img_desc := sg.Image_Desc {
        width = mu_atlas.WIDTH,
        height = mu_atlas.HEIGHT,
        // LINEAR would be better for text quality in HighDPI, but the
        // atlas texture is "leaking" from neighbouring pixels unfortunately
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    };

    img_desc.content.subimage[0][0] = {
        ptr = &rgba8_pixels[0],
        size = cast(i32)rgba8_size,
    };

    state.mu_atlas_img = sg.make_image(img_desc);

    state.mu_pip = sgl.make_pipeline({
        blend = {
            enabled = true,
            src_factor_rgb = .SRC_ALPHA,
            dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
        },
    });
}


r_begin :: inline proc(w, h: int) {
    sgl.defaults();
    sgl.push_pipeline();
    sgl.load_pipeline(state.mu_pip);
    sgl.enable_texture();
    sgl.texture(state.mu_atlas_img);
    sgl.matrix_mode_projection();
    sgl.push_matrix();
    sgl.ortho(0.0, cast(f32)w, cast(f32)h, 0.0, -1.0, +1.0);
    sgl.begin_quads();
}

r_end :: inline proc() {
    sgl.end();
    sgl.pop_matrix();
    sgl.pop_pipeline();
}

r_draw :: proc() {
    sgl.draw();
}

r_draw_text :: proc(str: []u8, pos: mu.Vec2, color: mu.Color) {
    dst := mu.Rect { pos.x, pos.y, 0, 0 };
    for ch in str {
        src := mu_atlas.atlas[mu_atlas.ATLAS_FONT + cast(mu.Icon)ch];
        dst.w = src.w;
        dst.h = src.h;
        r_push_quad(dst, src, color);
        dst.x += dst.w;
    }
}

r_draw_rect :: proc(rect: mu.Rect, color: mu.Color) {
    r_push_quad(rect, mu_atlas.atlas[mu_atlas.ATLAS_WHITE], color);
}

r_draw_icon :: proc(icon_id: i32, rect: mu.Rect, color: mu.Color) {
    src := mu_atlas.atlas[icon_id];
    x := rect.x + (rect.w - src.w) / 2;
    y := rect.y + (rect.h - src.h) / 2;
    r_push_quad(mu.Rect{x, y, src.w, src.h}, src, color);
}

r_set_clip_rect :: proc(rect: mu.Rect) {
    sgl.end();
    
    // @Bug nothing draws with this line in. Why?
    //sgl.scissor_rect(rect.x, rect.y, rect.w, rect.h, true);

    sgl.begin_quads();
}

r_push_quad :: proc(dst: mu.Rect, src: mu.Rect, color: mu.Color) {
    u0 := cast(f32) src.x / cast(f32) mu_atlas.WIDTH;
    v0 := cast(f32) src.y / cast(f32) mu_atlas.HEIGHT;
    u1 := cast(f32) (src.x + src.w) / cast(f32) mu_atlas.WIDTH;
    v1 := cast(f32) (src.y + src.h) / cast(f32) mu_atlas.HEIGHT;

    x0 := cast(f32) dst.x;
    y0 := cast(f32) dst.y;
    x1 := cast(f32) (dst.x + dst.w);
    y1 := cast(f32) (dst.y + dst.h);

    sgl.c4b(color.r, color.g, color.b, color.a);
    sgl.v2f_t2f(x0, y0, u0, v0);
    sgl.v2f_t2f(x1, y0, u1, v0);
    sgl.v2f_t2f(x1, y1, u1, v1);
    sgl.v2f_t2f(x0, y1, u0, v1);
}

r_draw_callback :: proc(dst: mu.Rect, callback: rawptr) {
    callback_proc := cast(proc(rect:mu.Rect))callback;
    if callback_proc != nil {
        callback_proc(dst);
    } else {
        // push a purple quad if the callback was nil
        r_push_quad(dst, mu_atlas.atlas[mu_atlas.ATLAS_WHITE], mu.Color { 255, 0, 255, 255 });
    }
}

mu_render :: proc(width, height: int) {
    // microui rendering
    r_begin(width, height);
    defer r_end();

    cmd:^mu.Command = nil;
    for  {
        if !mu.next_command(&mu_ctx, &cmd) do break;
        using cmd;
        switch type {
            case .Text: r_draw_text(cstring_ptr_to_slice(cast(^u8)&text.str[0]), text.pos, text.color);
            case .Rect: r_draw_rect(rect.rect, rect.color);
            case .Icon: r_draw_icon(icon.id, icon.rect, icon.color);
            case .Clip: r_set_clip_rect(clip.rect);
            case .DrawCallback: r_draw_callback(draw_callback.rect, draw_callback.callback);
        }
    }
}

mu_struct_window :: inline proc(ctx: ^mu.Context, value: ^$T) {
    //imgui.push_font(imgui_font_mono);
    //defer imgui.pop_font();

    //imgui.begin(tprint(type_info_of(T)));
    //defer imgui.end();

    mu_struct_ti("", value, type_info_of(T));
}

mu_struct :: inline proc(ctx: ^mu.Context, value: ^$T, name: string, do_header := true) {
    //imgui.push_font(imgui_font_mono);
    //defer imgui.pop_font();

    mu_struct_ti(ctx, name, value, type_info_of(T), "", do_header);
}

mu_indent :: proc() {
    // TODO
}

mu_unindent :: proc() {
    // TODO
}

_mu_struct_block_field_start :: proc(ctx: ^mu.Context, name: string, typename: string) -> bool {
    // if name != "" {
        header := name != "" ? tprint(name, ": ", typename) : tprint(typename);
        TODO_STATE: i32 = 1;
        if mu.header(ctx, &TODO_STATE, tcstring(header)) {
            mu_indent();
            return true;
        }
        return false;
    // }
    // return true;
}
_mu_struct_block_field_end :: proc(ctx: ^mu.Context, name: string) {
    // if name != "" {
        mu_unindent();
    // }
}

push_id_str :: proc(ctx: ^mu.Context, s: string) {
    mu.push_id(ctx, &s[0], cast(i32)len(s));
}

@(deferred_out=_pop_column)
COLUMN :: proc(ctx: ^mu.Context, widths: []i32, height: i32 = 0) -> ^mu.Context {
    mu.layout_begin_column(ctx);
    mu_layout_row(ctx, widths, height);
    return ctx;
}

_pop_column :: proc(ctx: ^mu.Context) {
    mu.layout_end_column(ctx);
}

mu_struct_ti :: proc(ctx: ^mu.Context, name: string, data: rawptr, ti: ^Type_Info, tags: string = "", do_header := true, type_name: string = "") {
    push_id_str(ctx, name);
    defer mu.pop_id(ctx);

    if strings.contains(tags, "imgui_readonly") {
        mu_label(ctx, name); // TODO: same line as below
        mu_label(ctx, tprint(any{data, ti.id}));
        return;
    }

    if strings.contains(tags, "imgui_hidden") {
        return;
    }

    has_range_constraint: bool;
    range_min: f32;
    range_max: f32;
    if strings.contains(tags, "imgui_range") {
        has_range_constraint = true;
        range_idx := strings.index(tags, "imgui_range");
        assert(range_idx >= 0);
        //range_str := tags[range_idx:];
        range_min = -42;
        range_max = 42;
        /*
        range_lexer := laas.make_lexer(range_str);
        laas.get_next_token(&range_lexer, nil);
        laas.expect_symbol(&range_lexer, '=');
        range_min = laas.expect_f32(&range_lexer);
        laas.expect_symbol(&range_lexer, ':');
        range_max = laas.expect_f32(&range_lexer);
        */
    }

    input_int :: proc(ctx: ^mu.Context, name: string, val: ^i32) -> mu.Res {
        s := "TODO:input_int";
        res:mu.Res;
        // TODO:name
        mu.textbox(ctx, &s[0], cast(i32)len(s));
        //TODO: res
        return res;
    }

    switch kind in &ti.variant {
        case Type_Info_Integer: {
            if kind.signed {
                switch ti.size {
                    case 8: new_data := cast(i32)(cast(^i64)data)^; input_int(ctx, name, &new_data); (cast(^i64)data)^ = cast(i64)new_data;
                    case 4: new_data := cast(i32)(cast(^i32)data)^; input_int(ctx, name, &new_data); (cast(^i32)data)^ = cast(i32)new_data;
                    case 2: new_data := cast(i32)(cast(^i16)data)^; input_int(ctx, name, &new_data); (cast(^i16)data)^ = cast(i16)new_data;
                    case 1: new_data := cast(i32)(cast(^i8 )data)^; input_int(ctx, name, &new_data); (cast(^i8 )data)^ = cast(i8 )new_data;
                    case: assert(false, tprint(ti.size));
                }
            }
            else {
                switch ti.size {
                    case 8: new_data := cast(i32)(cast(^u64)data)^; input_int(ctx, name, &new_data); (cast(^u64)data)^ = cast(u64)new_data;
                    case 4: new_data := cast(i32)(cast(^u32)data)^; input_int(ctx, name, &new_data); (cast(^u32)data)^ = cast(u32)new_data;
                    case 2: new_data := cast(i32)(cast(^u16)data)^; input_int(ctx, name, &new_data); (cast(^u16)data)^ = cast(u16)new_data;
                    case 1: new_data := cast(i32)(cast(^u8 )data)^; input_int(ctx, name, &new_data); (cast(^u8 )data)^ = cast(u8 )new_data;
                    case: assert(false, tprint(ti.size));
                }
            }
        }
        case Type_Info_Float: {
            switch ti.size {
                case 8: {
                    assert(false, "need to handle ids in this case");
                    new_data := cast(f32)(cast(^f64)data)^;
                    if has_range_constraint {
                        mu_label(ctx, name);
                        mu.slider(ctx, &new_data, range_min, range_max);
                    }
                    else {
                        mu_label(ctx, name);
                        mu.number(ctx, &new_data, 0.1);
                    }
                    (cast(^f64)data)^ = cast(f64)new_data;
                }
                case 4: {
                    mu_label(ctx, name); // TODO
                    if has_range_constraint {
                        mu.slider(ctx, cast(^f32)data, range_min, range_max);
                    }
                    else {
                        mu.number(ctx, cast(^f32)data, 0.1);
                    }
                }
                case: assert(false, tprint(ti.size));
            }
        }
        case Type_Info_String: {
            assert(ti.size == size_of(string));
            // todo(josh): arbitrary string length, right now there is a max length
            // https://github.com/ocornut/imgui/issues/1008

            text_edit_buffer: [256]u8;
            fmt.bprint(text_edit_buffer[:], (cast(^string)data)^);

            // name
            if mu.textbox(ctx, &text_edit_buffer[0], len(text_edit_buffer)) {
                // TODO ^^^ make a mu_input_text that actually works.
                result := text_edit_buffer[:];
                for b, i in text_edit_buffer {
                    if b == '\x00' {
                        result = text_edit_buffer[:i];
                        break;
                    }
                }
                str := strings.clone(cast(string)result);
                (cast(^string)data)^ = str; // @Leak
            }
        }
        case Type_Info_Boolean: {
            assert(ti.size == size_of(bool));
            mu_checkbox(ctx, cast(^bool)data, tcstring(name));
        }
        case Type_Info_Pointer: {
            mu.text(ctx, tcstring(tprint(name, " = ", "\"", data, "\"")));
        }
        case Type_Info_Named: {
            // distinct type, just follow through .base
            mu_struct_ti(ctx, name, data, kind.base, "", do_header, kind.name);
        }
        case Type_Info_Struct: {
            if !do_header || _mu_struct_block_field_start(ctx, name, type_name) {
                defer if do_header do _mu_struct_block_field_end(ctx, name);

                for field_name, i in kind.names {
                    t := kind.types[i];
                    offset := kind.offsets[i];
                    data := mem.ptr_offset(cast(^byte)data, cast(int)offset);
                    tag := kind.tags[i];
                    mu_struct_ti(ctx, field_name, data, t, tag);
                }
            }
        }
        /*
        case Type_Info_Enum: {
            if len(kind.values) > 0 {
                current_item_index : i32 = -1;
                #complete
                switch _ in kind.values[0] {
                    case u8:        for v, idx in kind.values { if (cast(^u8     )data)^ == v.(u8)      { current_item_index = cast(i32)idx; break; } }
                    case u16:       for v, idx in kind.values { if (cast(^u16    )data)^ == v.(u16)     { current_item_index = cast(i32)idx; break; } }
                    case u32:       for v, idx in kind.values { if (cast(^u32    )data)^ == v.(u32)     { current_item_index = cast(i32)idx; break; } }
                    case u64:       for v, idx in kind.values { if (cast(^u64    )data)^ == v.(u64)     { current_item_index = cast(i32)idx; break; } }
                    case uint:      for v, idx in kind.values { if (cast(^uint   )data)^ == v.(uint)    { current_item_index = cast(i32)idx; break; } }
                    case i8:        for v, idx in kind.values { if (cast(^i8     )data)^ == v.(i8)      { current_item_index = cast(i32)idx; break; } }
                    case i16:       for v, idx in kind.values { if (cast(^i16    )data)^ == v.(i16)     { current_item_index = cast(i32)idx; break; } }
                    case i32:       for v, idx in kind.values { if (cast(^i32    )data)^ == v.(i32)     { current_item_index = cast(i32)idx; break; } }
                    case i64:       for v, idx in kind.values { if (cast(^i64    )data)^ == v.(i64)     { current_item_index = cast(i32)idx; break; } }
                    case int:       for v, idx in kind.values { if (cast(^int    )data)^ == v.(int)     { current_item_index = cast(i32)idx; break; } }
                    case rune:      for v, idx in kind.values { if (cast(^rune   )data)^ == v.(rune)    { current_item_index = cast(i32)idx; break; } }
                    case uintptr:   for v, idx in kind.values { if (cast(^uintptr)data)^ == v.(uintptr) { current_item_index = cast(i32)idx; break; } }
                    case: panic(fmt.tprint(kind.values[0]));
                }

                item := current_item_index;
                imgui.combo(name, &item, kind.names, cast(i32)min(5, len(kind.names)));
                if item != current_item_index {
                    switch value in kind.values[item] {
                        case u8:        (cast(^u8     )data)^ = value;
                        case u16:       (cast(^u16    )data)^ = value;
                        case u32:       (cast(^u32    )data)^ = value;
                        case u64:       (cast(^u64    )data)^ = value;
                        case uint:      (cast(^uint   )data)^ = value;
                        case i8:        (cast(^i8     )data)^ = value;
                        case i16:       (cast(^i16    )data)^ = value;
                        case i32:       (cast(^i32    )data)^ = value;
                        case i64:       (cast(^i64    )data)^ = value;
                        case int:       (cast(^int    )data)^ = value;
                        case rune:      (cast(^rune   )data)^ = value;
                        case uintptr:   (cast(^uintptr)data)^ = value;
                        case: panic(fmt.tprint(value));
                    }
                }
            }
        }
        */
        case Type_Info_Slice: {
            if !do_header || _mu_struct_block_field_start(ctx, name, fmt.tprint("[]", kind.elem)) {
                defer if do_header do _mu_struct_block_field_end(ctx, name);

                slice := (cast(^mem.Raw_Slice)data)^;
                for i in 0..<slice.len {
                    push_id_str(ctx, fmt.tprint(i));
                    defer mu.pop_id(ctx);
                    mu_struct_ti(ctx, fmt.tprint("[", i, "]"), mem.ptr_offset(cast(^byte)slice.data, i * kind.elem_size), kind.elem);
                }
            }
        }
        case Type_Info_Array: {
            if !do_header || _mu_struct_block_field_start(ctx, name, fmt.tprint("[", kind.count, "]", kind.elem)) {
                defer if do_header do _mu_struct_block_field_end(ctx, name);

                W :: 50;
                switch (kind.count) {
                    case 2:
                        COLUMN(ctx, {25, W, 25, W});
                        mu_struct_ti(ctx, "x", mem.ptr_offset(cast(^u8)data, 0 * kind.elem_size), kind.elem);
                        mu_struct_ti(ctx, "y", mem.ptr_offset(cast(^u8)data, 1 * kind.elem_size), kind.elem);
                    case 3:
                        COLUMN(ctx, {25, W, 25, W, 25, W});
                        mu_struct_ti(ctx, "x", mem.ptr_offset(cast(^u8)data, 0 * kind.elem_size), kind.elem);
                        mu_struct_ti(ctx, "y", mem.ptr_offset(cast(^u8)data, 1 * kind.elem_size), kind.elem);
                        mu_struct_ti(ctx, "z", mem.ptr_offset(cast(^u8)data, 2 * kind.elem_size), kind.elem);
                    case 4:
                        COLUMN(ctx, {25, W, 25, W, 25, W, 25, W});
                        mu_struct_ti(ctx, "x", mem.ptr_offset(cast(^u8)data, 0 * kind.elem_size), kind.elem);
                        mu_struct_ti(ctx, "y", mem.ptr_offset(cast(^u8)data, 1 * kind.elem_size), kind.elem);
                        mu_struct_ti(ctx, "z", mem.ptr_offset(cast(^u8)data, 2 * kind.elem_size), kind.elem);
                        mu_struct_ti(ctx, "w", mem.ptr_offset(cast(^u8)data, 3 * kind.elem_size), kind.elem);
                    case:
                    for i in 0..<kind.count {
                        COLUMN(ctx, {25, -1});
                        sub_name := tprint("[", i, "]");
                        mu_struct_ti(ctx, sub_name, mem.ptr_offset(cast(^u8)data, i * kind.elem_size), kind.elem);
                    }
                }
            }
        }
        case Type_Info_Dynamic_Array: {
            if !do_header || _mu_struct_block_field_start(ctx, name, fmt.tprint("[dynamic]", kind.elem)) {
                defer if do_header do _mu_struct_block_field_end(ctx, name);

                array := (cast(^mem.Raw_Dynamic_Array)data)^;
                for i in 0..<array.len {
                    push_id_str(ctx, fmt.tprint(i));
                    defer mu.pop_id(ctx);
                    mu_struct_ti(ctx, fmt.tprint("[", i, "]"), mem.ptr_offset(cast(^byte)array.data, i * kind.elem_size), kind.elem);
                }
            }
        }
        case Type_Info_Any: {
            a := cast(^any)data;
            if a.data == nil do return;
            mu_struct_ti(ctx, name, a.data, type_info_of(a.id));
        }
        case Type_Info_Union: {
            /*
            tag_ptr := uintptr(data) + kind.tag_offset;
            tag_any := any{rawptr(tag_ptr), kind.tag_type.id};

            current_tag: i32 = -1;
            switch i in tag_any {
                case u8:   current_tag = i32(i);
                case u16:  current_tag = i32(i);
                case u32:  current_tag = i32(i);
                case u64:  current_tag = i32(i);
                case i8:   current_tag = i32(i);
                case i16:  current_tag = i32(i);
                case i32:  current_tag = i32(i);
                case i64:  current_tag = i32(i);
                case: panic(fmt.tprint("Invalid union tag type: ", i));
            }

            item := cast(i32)current_tag;
            variant_names: [dynamic]string;
            append(&variant_names, "<none>");
            for v in kind.variants {
                append(&variant_names, fmt.tprint(v));
            }
            mu.combo("tag", &item, variant_names[:], cast(i32)min(5, len(variant_names)));

            if item != current_tag {
                current_tag = item;
                // todo(josh): is zeroing a good idea here?
                mem.zero(data, ti.size);
                switch i in tag_any {
                    case u8:   (cast(^u8 )tag_ptr)^ = u8 (item);
                    case u16:  (cast(^u16)tag_ptr)^ = u16(item);
                    case u32:  (cast(^u32)tag_ptr)^ = u32(item);
                    case u64:  (cast(^u64)tag_ptr)^ = u64(item);
                    case i8:   (cast(^i8 )tag_ptr)^ = i8 (item);
                    case i16:  (cast(^i16)tag_ptr)^ = i16(item);
                    case i32:  (cast(^i32)tag_ptr)^ = i32(item);
                    case i64:  (cast(^i64)tag_ptr)^ = i64(item);
                    case: panic(fmt.tprint("Invalid union tag type: ", i));
                }
            }

            if current_tag > 0 {
                data_ti := kind.variants[current_tag-1];
                mu_struct_ti(name, data, data_ti, "", true, type_name);
            }
            */
        }
        case: mu_label(ctx, fmt.tprint("UNHANDLED TYPE: ", kind));
    }
}
