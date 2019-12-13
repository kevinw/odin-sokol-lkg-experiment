// thanks to https://github.com/JoshuaManton/workbench/ for this imgui / type info code

package main
import simgui "../lib/odin-sokol/src/sokol_imgui"
import imgui "../lib/odin-imgui"
import sapp "sokol:sokol_app"
import sg "sokol:sokol_gfx"

using import "core:runtime"
import "core:strings"
import "core:mem"
using import "core:fmt"

@(deferred_out=_END)
BEGIN :: proc(name: string) -> bool {
    return imgui.begin(name);
}

@private _END :: proc(did_open: bool) { imgui.end(); }

imgui_struct_window :: inline proc(value: ^$T) {
    //imgui.push_font(imgui_font_mono); // TODO
    //defer imgui.pop_font();

    imgui.begin(tprint(type_info_of(T)));
    defer imgui.end();

    imgui_struct_ti("", value, type_info_of(T));
}

imgui_struct :: inline proc(value: ^$T, name: string, do_header := true) {
    //imgui.push_font(imgui_font_mono); // TODO
    //defer imgui.pop_font();

    imgui_struct_ti(name, value, type_info_of(T), "", do_header);
}

_imgui_struct_block_field_start :: proc(name: string, typename: string) -> bool {
    // if name != "" {
        header: string;
        if name != "" {
            header = tprint(name, ": ", typename);
        }
        else {
            header = tprint(typename);
        }
        if imgui.collapsing_header(header) {
            imgui.indent();
            return true;
        }
        return false;
    // }
    // return true;
}
_imgui_struct_block_field_end :: proc(name: string) {
    // if name != "" {
        imgui.unindent();
    // }
}

_readonly: bool;
imgui_struct_ti :: proc(name: string, data: rawptr, ti: ^Type_Info, tags: string = "", do_header := true, type_name: string = "") {
    imgui.push_id(name);
    defer imgui.pop_id();

    if strings.contains(tags, "imgui_readonly") {
        imgui.label_text(name, tprint(any{data, ti.id}));
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
        range_str := tags[range_idx:];
        /*
        range_lexer := laas.make_lexer(range_str);
        laas.get_next_token(&range_lexer, nil);
        laas.expect_symbol(&range_lexer, '=');
        range_min_str := laas.expect_string(&range_lexer);
        laas.expect_symbol(&range_lexer, ':');
        range_max_str := laas.expect_string(&range_lexer);

        range_min = parse_f32(range_min_str);
        range_max = parse_f32(range_max_str);
        */
        fmt.println("TODO: laas.make_lexer");

        range_min = 0;
        range_min = 1;
    }

    switch kind in &ti.variant {
        case Type_Info_Integer: {
            if kind.signed {
                switch ti.size {
                    case 8: new_data := cast(i32)(cast(^i64)data)^; imgui.input_int(name, &new_data); (cast(^i64)data)^ = cast(i64)new_data;
                    case 4: new_data := cast(i32)(cast(^i32)data)^; imgui.input_int(name, &new_data); (cast(^i32)data)^ = cast(i32)new_data;
                    case 2: new_data := cast(i32)(cast(^i16)data)^; imgui.input_int(name, &new_data); (cast(^i16)data)^ = cast(i16)new_data;
                    case 1: new_data := cast(i32)(cast(^i8 )data)^; imgui.input_int(name, &new_data); (cast(^i8 )data)^ = cast(i8 )new_data;
                    case: assert(false, tprint(ti.size));
                }
            }
            else {
                switch ti.size {
                    case 8: new_data := cast(i32)(cast(^u64)data)^; imgui.input_int(name, &new_data); (cast(^u64)data)^ = cast(u64)new_data;
                    case 4: new_data := cast(i32)(cast(^u32)data)^; imgui.input_int(name, &new_data); (cast(^u32)data)^ = cast(u32)new_data;
                    case 2: new_data := cast(i32)(cast(^u16)data)^; imgui.input_int(name, &new_data); (cast(^u16)data)^ = cast(u16)new_data;
                    case 1: new_data := cast(i32)(cast(^u8 )data)^; imgui.input_int(name, &new_data); (cast(^u8 )data)^ = cast(u8 )new_data;
                    case: assert(false, tprint(ti.size));
                }
            }
        }
        case Type_Info_Float: {
            switch ti.size {
                case 8: {
                    new_data := cast(f32)(cast(^f64)data)^;
                    imgui.push_item_width(100);
                    imgui.input_float(tprint(name, "##non_range"), &new_data);
                    imgui.pop_item_width();
                    if has_range_constraint {
                        imgui.same_line();
                        imgui.push_item_width(200);
                        imgui.slider_float(name, &new_data, range_min, range_max);
                        imgui.pop_item_width();
                    }
                    (cast(^f64)data)^ = cast(f64)new_data;
                }
                case 4: {
                    new_data := cast(f32)(cast(^f32)data)^;
                    imgui.push_item_width(100);
                    imgui.input_float(tprint(name, "##non_range"), &new_data);
                    imgui.pop_item_width();
                    if has_range_constraint {
                        imgui.same_line();
                        imgui.push_item_width(200);
                        imgui.slider_float(name, &new_data, range_min, range_max);
                        imgui.pop_item_width();
                    }
                    (cast(^f32)data)^ = cast(f32)new_data;
                }
                case: assert(false, tprint(ti.size));
            }
        }
        case Type_Info_String: {
            assert(ti.size == size_of(string));
            // todo(josh): arbitrary string length, right now there is a max length
            // https://github.com/ocornut/imgui/issues/1008
            text_edit_buffer: [256]u8;
            bprint(text_edit_buffer[:], (cast(^string)data)^);

            if imgui.input_text(name, text_edit_buffer[:], .EnterReturnsTrue) {
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
            imgui.checkbox(name, cast(^bool)data);
        }
        case Type_Info_Pointer: {
            result := tprint(name, " = ", "\"", data, "\"");
            imgui.text(result);
        }
        case Type_Info_Named: {
            imgui_struct_ti(name, data, kind.base, "", do_header, kind.name);
        }
        case Type_Info_Struct: {
            if !do_header || _imgui_struct_block_field_start(name, type_name) {
                defer if do_header do _imgui_struct_block_field_end(name);

                // if kind == &type_info_of(Quat).variant.(Type_Info_Named).base.variant.(Type_Info_Struct) {
                //     q := cast(^Quat)data;
                //     dir := quaternion_to_euler(q^);
                //     if imgui.input_float("##782783", &dir.x, 0, 0, -1, imgui.Input_Text_Flags.EnterReturnsTrue) {
                //         q^ = euler_angles(expand_to_tuple(dir));
                //     }
                //     if imgui.input_float("##42424", &dir.y, 0, 0, -1, imgui.Input_Text_Flags.EnterReturnsTrue) {
                //         q^ = euler_angles(expand_to_tuple(dir));
                //     }
                //     if imgui.input_float("##54512", &dir.z, 0, 0, -1, imgui.Input_Text_Flags.EnterReturnsTrue) {
                //         q^ = euler_angles(expand_to_tuple(dir));
                //     }
                // }

                for field_name, i in kind.names {
                    t := kind.types[i];
                    offset := kind.offsets[i];
                    data := mem.ptr_offset(cast(^byte)data, cast(int)offset);
                    tag := kind.tags[i];
                    imgui_struct_ti(field_name, data, t, tag);
                }
            }
        }
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
                    case: panic(tprint(kind.values[0]));
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
                        case: panic(tprint(value));
                    }
                }
            }
        }
        case Type_Info_Slice: {
            if !do_header || _imgui_struct_block_field_start(name, tprint("[]", kind.elem)) {
                defer if do_header do _imgui_struct_block_field_end(name);

                slice := (cast(^mem.Raw_Slice)data)^;
                for i in 0..slice.len-1 {
                    imgui.push_id(tprint(i));
                    defer imgui.pop_id();
                    imgui_struct_ti(tprint("[", i, "]"), mem.ptr_offset(cast(^byte)slice.data, i * kind.elem_size), kind.elem);
                }
            }
        }
        case Type_Info_Array: {
            if !do_header || _imgui_struct_block_field_start(name, tprint("[", kind.count, "]", kind.elem)) {
                defer if do_header do _imgui_struct_block_field_end(name);

                for i in 0..kind.count-1 {
                    imgui.push_id(tprint(i));
                    defer imgui.pop_id();
                    imgui_struct_ti(tprint("[", i, "]"), mem.ptr_offset(cast(^byte)data, i * kind.elem_size), kind.elem);
                }
            }
        }
        case Type_Info_Dynamic_Array: {
            if !do_header || _imgui_struct_block_field_start(name, tprint("[dynamic]", kind.elem)) {
                defer if do_header do _imgui_struct_block_field_end(name);

                array := (cast(^mem.Raw_Dynamic_Array)data)^;
                for i in 0..array.len-1 {
                    imgui.push_id(tprint(i));
                    defer imgui.pop_id();
                    imgui_struct_ti(tprint("[", i, "]"), mem.ptr_offset(cast(^byte)array.data, i * kind.elem_size), kind.elem);
                }
            }
        }
        case Type_Info_Any: {
            a := cast(^any)data;
            if a.data == nil do return;
            imgui_struct_ti(name, a.data, type_info_of(a.id));
        }
        case Type_Info_Union: {
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
            v := kind.variants;
            variant_names: [dynamic]string;
            append(&variant_names, "<none>");
            for v in kind.variants {
                append(&variant_names, tprint(v));
            }
            imgui.combo("tag", &item, variant_names[:], cast(i32)min(5, len(variant_names)));

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
                imgui_struct_ti(name, data, data_ti, "", true, type_name);
            }
        }
        case: imgui.text(tprint("UNHANDLED TYPE: ", kind));
    }
}


setup_simgui :: proc() {
    simgui.setup({
        //no_default_font = true,
        dpi_scale = sapp.dpi_scale(),
    });

    /*
    // TODO: this stuff is waiting on an odin bug to be fixed
    io := imgui.get_io();

    // configure Dear ImGui with our own embedded font
    font_cfg : imgui.FontConfig;
    imgui.font_config_default_constructor(&font_cfg);
    font_cfg.font_data_owned_by_atlas = false;
    font_cfg.oversample_h = 2;
    font_cfg.oversample_v = 2;
    font_cfg.rasterizer_multiply = 1.5;

    imgui.font_atlas_add_font_from_memory_ttf(io.fonts, &dump_font[0], size_of(dump_font), 16, &font_cfg);

    // create font texture for the custom font
    font_pixels: ^u8;
    font_width, font_height: i32;

    imgui.font_atlas_get_text_data_as_rgba32(io.fonts, &font_pixels, &font_width, &font_height);

    img_desc := sg.Image_Desc {
        width = font_width,
        height = font_height,
        pixel_format = .RGBA8,
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        min_filter = .LINEAR,
        mag_filter = .LINEAR,
    };

    img_desc.content.subimage[0][0].ptr = font_pixels;
    img_desc.content.subimage[0][0].size = font_width * font_height * 4;

    io.fonts.tex_id = cast(imgui.TextureID)cast(uintptr)sg.make_image(img_desc).id;
    */
}
