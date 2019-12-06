package main

import sg "sokol:sokol_gfx"
import "./shader_meta";

MAXIMUM_VIEWS :: 45; // match shader value

hp_info: Display_Info;
hp_connected: bool;

num_views :: proc() -> int {
    if FORCE_2D do return 1;

    return min(MAXIMUM_VIEWS, max(1, cast(int)editor_settings.num_views));
}

maybe_recreate_multiview_pass :: proc(num_views, framebuffer_width, framebuffer_height: int) {
    using state.offscreen;

    width, height := calc_lkg_subquilt_size(framebuffer_width, framebuffer_height);

    if cast(i32)num_views == color_img_desc.layers &&
        color_img_desc.width == width &&
        color_img_desc.height == height {
        return;
    }

    create_multiview_pass(num_views, framebuffer_width, framebuffer_height);
}

calc_lkg_subquilt_size :: proc(framebuffer_width, framebuffer_height: int) -> (i32, i32) {
    aspect := cast(f32)framebuffer_width / cast(f32)framebuffer_height;
    width := max(10, cast(int)editor_settings.subview_w);
    height := cast(int)(cast(f32)width / aspect);
    return cast(i32)width, cast(i32)height;
}

create_multiview_pass :: proc(num_views, framebuffer_width, framebuffer_height: int) {
    width, height := calc_lkg_subquilt_size(framebuffer_width, framebuffer_height);

    assert(width > 0 && height > 0);
    //fmt.printf("creating offscreen multiview pass (%dx%d) with %d views\n", width, height, num_views);

    using state.offscreen;

    /* destroy previous resource (can be called for invalid id) */
    sg.destroy_pass(pass);
    sg.destroy_image(pass_desc.color_attachments[0].image);
    sg.destroy_image(pass_desc.depth_stencil_attachment.image);

    /* create offscreen rendertarget images and pass */
    offscreen_sample_count := sg.query_features().msaa_render_targets ? MSAA_SAMPLE_COUNT : 1;
    color_img_desc = sg.Image_Desc {
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
    color_img_desc.layers = cast(i32)num_views;

    depth_img_desc := color_img_desc; // copy values from color Image_Desc
    depth_img_desc.pixel_format = .DEPTH_STENCIL;
    depth_img_desc.label = "multiview depth image";

    pass_desc = {
        color_attachments = {
            0 = { image = sg.make_image(color_img_desc) },
        },
        depth_stencil_attachment = {
            image = sg.make_image(depth_img_desc),
        },
        label = "multiview offscreen pass"
    };

    pass = sg.make_pass(pass_desc);

    /* also need to update the fullscreen-quad texture bindings */
    state.lenticular_bindings.fs_images[shader_meta.SLOT_screenTex] = pass_desc.color_attachments[0].image;
    state.lenticular_bindings.fs_images[shader_meta.SLOT_depthTex] = pass_desc.depth_stencil_attachment.image;
}

