package main

import "core:fmt"
import sg "sokol:sokol_gfx"
import "./shader_meta";

MAXIMUM_VIEWS :: 45; // match shader value

hp_info: Display_Info;
hp_connected: bool;

force_num_views: int = -1;

num_views :: proc() -> int {
    if force_num_views != -1 do return force_num_views;

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

DOF_COC_IMAGE_FORMAT: sg.Pixel_Format = .R32F;

init_dof_pipelines :: proc() {
    quad_buf := get_quad_negone_one();

    {
        using state.depth_of_field.coc_material;
        bindings.vertex_buffers[0] = quad_buf;
        pipeline = sg.make_pipeline({
            label = "dof coc pipeline",
            shader = sg.make_shader(shader_meta.dof_coc_shader_desc()^),
            blend = {
                color_format = DOF_COC_IMAGE_FORMAT,
                depth_format = .NONE,
            },
            layout = {
                attrs = {
                    0 = {format = .FLOAT2 },
                    1 = {format = .FLOAT2 },
                },
            },
        });
    }
    {
        using state.depth_of_field.bokeh_material;
        bindings.vertex_buffers[0] = quad_buf;
        pipeline = sg.make_pipeline({
            label = "dof bokeh pipeline",
            shader = sg.make_shader(shader_meta.dof_bokeh_shader_desc()^),
            blend = {
                depth_format = .NONE,
            },
            layout = {
                attrs = {
                    0 = {format = .FLOAT2 },
                    1 = {format = .FLOAT2 },
                },
            },
        });
    }
}

Blitter :: struct {
    pass: sg.Pass,
    pipeline: sg.Pipeline,
    bindings: sg.Bindings,
};

recreate_blit :: proc(using b: ^Blitter, label: cstring, target_rt: sg.Image, shader_: sg.Shader = {}) {

    // @Leak 
    shader := shader_;
    if shader.id == 0 {
        @static blit_shader: sg.Shader;
        if blit_shader.id == 0 {
            blit_shader = sg.make_shader(shader_meta.blit_shader_desc()^);
        }
        shader = blit_shader;
    }

    reinit_pipeline(&pipeline, {
        label = label,
        shader = shader,
        blend = {
            depth_format = .NONE,
        },
        layout = {
            attrs = {
                0 = {format = .FLOAT2},
                1 = {format = .FLOAT2},
            }
        }
    });
    assert(pipeline.id != sg.INVALID_ID);

    reinit_pass(&pass, {
        label = label,
        color_attachments = { 0 = { image = target_rt } }
    });
    assert(pass.id != sg.INVALID_ID);

    bindings.vertex_buffers[0] = get_quad_negone_one();
}

blit :: proc(using b: ^Blitter, source_rt: sg.Image, source_slot: int = 0) {
    sg.begin_pass(pass, { colors = { 0 = { action = .LOAD }}});
    defer sg.end_pass();

    assert(pipeline.id != sg.INVALID_ID, fmt.tprintf("blit pipeline is invalid for blit at %p", b));

    sg.apply_pipeline(pipeline);
    bindings.fs_images[source_slot] = source_rt;
    sg.apply_bindings(bindings);
    sg.draw(0, 6, num_views());
}

create_multiview_pass :: proc(num_views, framebuffer_width, framebuffer_height: int) {
    width, height := calc_lkg_subquilt_size(framebuffer_width, framebuffer_height);

    assert(width > 0 && height > 0);
    //fmt.printf("creating offscreen multiview pass (%dx%d) with %d views\n", width, height, num_views);

    {
        using state.offscreen;

        /* destroy previous resource (can be called for invalid id) */
        sg.destroy_image(pass_desc.color_attachments[0].image);
        sg.destroy_image(pass_desc.depth_stencil_attachment.image);

        /* create offscreen rendertarget images and pass */
        color_img_desc = rendertarget_array_desc(width, height, cast(i32)num_views, "multiview color image");

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

        reinit_pass(&pass, pass_desc);
    }

    //
    // depth of field
    //
    {
        using state.depth_of_field;

        {
            sg.destroy_image(coc_pass_desc.color_attachments[0].image);
            sg.destroy_image(coc_pass_desc.depth_stencil_attachment.image);

            coc_img_desc = rendertarget_array_desc(width, height, cast(i32)num_views, "depth of field coc image");
            coc_img_desc.pixel_format = DOF_COC_IMAGE_FORMAT;

            coc_pass_desc = {
                color_attachments = {
                    0 = { image = sg.make_image(coc_img_desc) },
                },
                label = "depth of field coc pass",
            };

            sg.destroy_pass(coc_pass);
            coc_pass = sg.make_pass(coc_pass_desc);

            // set "cameraDepth" uniform texture
            coc_material.bindings.fs_images[shader_meta.SLOT_cameraDepth] =
                state.offscreen.pass_desc.depth_stencil_attachment.image;
        }

        bokeh_width, bokeh_height := width / 2, height / 2;
        {
            sg.destroy_image(bokeh_pass_desc.color_attachments[0].image);

            bokeh_img_desc = rendertarget_array_desc(bokeh_width, bokeh_height, cast(i32)num_views, "depth of field bokeh image");
            bokeh_pass_desc = {
                label = "depth of field bokeh pass",
                color_attachments = {
                    0 = { image = sg.make_image(bokeh_img_desc) },
                },
            };

            reinit_pass(&bokeh_pass, bokeh_pass_desc);
        }

        cam_tex := &state.offscreen.color_img_desc;

        half_w, half_h := cam_tex.width / 2, cam_tex.height / 2;

        reinit_image(&half_size_color, rendertarget_array_desc(half_w, half_h, cast(i32)num_views, "half_size_color"));

        @static prefilter_shader, postfilter_shader, combine_shader: sg.Shader;
        recreate_blit(&prefilter_blit, "prefilter", half_size_color, static_shader(&prefilter_shader, shader_meta.dof_prefilter_shader_desc()));
        recreate_blit(&postfilter_blit, "postfilter", half_size_color, static_shader(&postfilter_shader, shader_meta.dof_postfilter_shader_desc()));
        reinit_image(&final_img, rendertarget_array_desc(width, height, cast(i32)num_views, "full size dof final"));
        recreate_blit(&combine_blit, "dof_combine", final_img, static_shader(&combine_shader, shader_meta.dof_combine_shader_desc()));
    }
}

