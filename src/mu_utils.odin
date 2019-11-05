package main

import sg "sokol:sokol_gfx"
import sgl "sokol:sokol_gl"
import mu "../lib/microui"
import mu_atlas "../lib/microui/atlas"
import "core:strings"
import "core:fmt"

DEFAULT_BUFFER_SIZE :: 200;


r_get_text_width :: proc(text: []u8) -> i32 {
    res:i32 = 0;
    for _ in text {
        res += 10; // TODO
    }
    return res;
    /*
    res:i32 = 0;
    for p = &text[0]; p^ != nil && len--; p++ {
        res += atlas[ATLAS_FONT + (unsigned char)*p].w;
    }
    return res;
    */
}

r_get_text_height :: proc() -> i32 {
    return 18;
}

mu_checkbox :: proc(ctx: ^mu.Context, val: ^bool, label: cstring) {
    bool_val:i32 = val^ ? 1 : 0;
    mu.checkbox(ctx, &bool_val, label);
    val^ = bool_val == 1 ? true : false;
}

mu_label_printf :: proc(ctx: ^mu.Context, fmt_str: string, args: ..any) {
	data: [DEFAULT_BUFFER_SIZE]byte;
	buf := strings.builder_from_slice(data[:]);
	res := fmt.sbprintf(&buf, fmt_str, ..args);

    // @Speed: don't clone
    c_str := strings.clone_to_cstring(res);
    defer delete(c_str);

    mu.label(ctx, c_str);
}

mu_layout_row :: proc(ctx: ^mu.Context, items: i32, widths: []i32, height: i32) {
    widths_ptr := &widths[0];
    mu.layout_row(ctx, items, widths_ptr, height);
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

