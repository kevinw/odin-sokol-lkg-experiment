package main

MSAA_SAMPLES :: 1;

NUM_VIEWS :: 16;

import "core:os"
import "core:fmt"
using import "math"
using import "shader_meta"

import sg "sokol:sokol_gfx"
import sapp "sokol:sokol_app"

offscreen_pass_desc: sg.Pass_Desc;
offscreen_pass: sg.Pass;
offscreen_pip: sg.Pipeline;
offscreen_bind: sg.Bindings;

fsq_pip: sg.Pipeline;
fsq_bind: sg.Bindings;
dbg_pip: sg.Pipeline;
dbg_bind: sg.Bindings;

/* pass action to clear the MRT render target */
@private offscreen_pass_action := sg.Pass_Action {
    colors = {
        0 = { action = .CLEAR, val = { 0.25, 0.0, 0.0, 1.0 } },
    }
};

/* default pass action, no clear needed, since whole screen is overwritten */
default_pass_action:= sg.Pass_Action {
    colors = { 0 = { action = .DONTCARE }, },
    depth = { action = .DONTCARE },
    stencil = { action = .DONTCARE }
};

@private rx, ry: f32;

vertex_t :: struct { x, y, z, b: f32 };

/* called initially and when window size changes */
create_offscreen_pass :: proc(width, height: i32) {
    /* destroy previous resource (can be called for invalid id) */
    sg.destroy_pass(offscreen_pass);
    sg.destroy_image(offscreen_pass_desc.color_attachments[0].image);
    sg.destroy_image(offscreen_pass_desc.depth_stencil_attachment.image);

    /* create offscreen rendertarget images and pass */
    offscreen_sample_count := sg.query_features().msaa_render_targets ? MSAA_SAMPLES : 1;
    color_img_desc := sg.Image_Desc {
        render_target = true,
        type = .ARRAY,
        width = width,
        height = height,
        min_filter = .LINEAR,
        mag_filter = .LINEAR,
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        sample_count = cast(i32)offscreen_sample_count,
        label = "color image"
    };
    color_img_desc.layers = NUM_VIEWS;

    depth_img_desc := color_img_desc; // copy values from color Image_Desc
    depth_img_desc.pixel_format = .DEPTH;
    depth_img_desc.label = "depth image";

    offscreen_pass_desc = {
        color_attachments = {
            0 = { image = sg.make_image(color_img_desc) },
        },
        depth_stencil_attachment = {
            image = sg.make_image(depth_img_desc),
        },
        label = "offscreen pass"
    };

    offscreen_pass = sg.make_pass(offscreen_pass_desc);

    /* also need to update the fullscreen-quad texture bindings */
    fsq_bind.fs_images[SLOT_tex0] = offscreen_pass_desc.color_attachments[0].image;
}

/* listen for window-resize events and recreate offscreen rendertargets */
mrt_event :: proc "c" (e: ^sapp.Event) {
    if e.type == .RESIZED {
        create_offscreen_pass(e.framebuffer_width, e.framebuffer_height);
    }
}

mrt_init :: proc "c" () {
    sg.setup(sg.Desc {
        gl_force_gles2 = sapp.gles2(),
        mtl_device = sapp.metal_get_device(),
        mtl_renderpass_descriptor_cb = sapp.metal_get_renderpass_descriptor,
        mtl_drawable_cb = sapp.metal_get_drawable,
        d3d11_device = sapp.d3d11_get_device(),
        d3d11_device_context = sapp.d3d11_get_device_context(),
        d3d11_render_target_view_cb = sapp.d3d11_get_render_target_view,
        d3d11_depth_stencil_view_cb = sapp.d3d11_get_depth_stencil_view
    });

    /* a render pass with 3 color attachment images, and a depth attachment image */
    create_offscreen_pass(cast(i32)sapp.width(), cast(i32)sapp.height());

    /* cube vertex buffer */
    cube_vertices := [?]vertex_t {
        /* pos + brightness */
        { -1.0, -1.0, -1.0,   1.0 },
        {  1.0, -1.0, -1.0,   1.0 },
        {  1.0,  1.0, -1.0,   1.0 },
        { -1.0,  1.0, -1.0,   1.0 },

        { -1.0, -1.0,  1.0,   0.8 },
        {  1.0, -1.0,  1.0,   0.8 },
        {  1.0,  1.0,  1.0,   0.8 },
        { -1.0,  1.0,  1.0,   0.8 },

        { -1.0, -1.0, -1.0,   0.6 },
        { -1.0,  1.0, -1.0,   0.6 },
        { -1.0,  1.0,  1.0,   0.6 },
        { -1.0, -1.0,  1.0,   0.6 },

        { 1.0, -1.0, -1.0,    0.4 },
        { 1.0,  1.0, -1.0,    0.4 },
        { 1.0,  1.0,  1.0,    0.4 },
        { 1.0, -1.0,  1.0,    0.4 },

        { -1.0, -1.0, -1.0,   0.5 },
        { -1.0, -1.0,  1.0,   0.5 },
        {  1.0, -1.0,  1.0,   0.5 },
        {  1.0, -1.0, -1.0,   0.5 },

        { -1.0,  1.0, -1.0,   0.7 },
        { -1.0,  1.0,  1.0,   0.7 },
        {  1.0,  1.0,  1.0,   0.7 },
        {  1.0,  1.0, -1.0,   0.7 },
    };

    cube_vbuf := sg.make_buffer({
        size = size_of(cube_vertices),
        content = &cube_vertices[0],
        label = "cube vertices"
    });

    /* index buffer for the cube */
    cube_indices := [?]u16 {
        0, 1, 2,  0, 2, 3,
        6, 5, 4,  7, 6, 4,
        8, 9, 10,  8, 10, 11,
        14, 13, 12,  15, 14, 12,
        16, 17, 18,  16, 18, 19,
        22, 21, 20,  23, 22, 20
    };

    cube_ibuf := sg.make_buffer({
        type = sg.Buffer_Type.INDEXBUFFER,
        size = size_of(cube_indices),
        content = &cube_indices[0],
        label = "cube indices"
    });

    /* a shader to render the cube into offscreen MRT render targest */
    offscreen_shd := sg.make_shader(offscreen_shader_desc()^);

    /* pipeline object for the offscreen-rendered cube */
    offscreen_pip = sg.make_pipeline({
        layout = {
            buffers = {
                0 = {
                    stride = size_of(vertex_t),
                }
            },
            attrs = {
                ATTR_vs_offscreen_pos     = { offset=cast(i32)offset_of(vertex_t,x), format=.FLOAT3 },
                ATTR_vs_offscreen_bright0 = { offset=cast(i32)offset_of(vertex_t,b), format=.FLOAT },
            }
        },
        shader = offscreen_shd,
        index_type = .UINT16,
        depth_stencil = {
            depth_compare_func = .LESS_EQUAL,
            depth_write_enabled = true
        },
        blend = {
            color_attachment_count = 1,
            depth_format = .DEPTH
        },
        rasterizer = {
            cull_mode = .BACK,
            sample_count = MSAA_SAMPLES
        },
        label = "offscreen pipeline"
    });

    /* resource bindings for offscreen rendering */
    offscreen_bind = {
        vertex_buffers = {
            0 = cube_vbuf,
        },
        index_buffer = cube_ibuf,
    };

    /* a vertex buffer to render a fullscreen rectangle */
    quad_vertices := [?]f32  { 0.0, 0.0,  1.0, 0.0,  0.0, 1.0,  1.0, 1.0 };
    quad_vbuf := sg.make_buffer({
        size = size_of(quad_vertices),
        content = &quad_vertices[0],
        label = "quad vertices"
    });

    /* a shader to render a fullscreen rectangle by adding the 3 offscreen-rendered images */
    fsq_shd := sg.make_shader(fsq_shader_desc()^);

    /* the pipeline object to render the fullscreen quad */
    fsq_pip = sg.make_pipeline({
        layout = {
            attrs = {
                ATTR_vs_fsq_pos = { format = .FLOAT2 }
            }
        },
        shader = fsq_shd,
        primitive_type = .TRIANGLE_STRIP,
        rasterizer = { sample_count = MSAA_SAMPLES },
        label = "fullscreen quad pipeline"
    });

    /* resource bindings to render a fullscreen quad */
    fsq_bind = sg.Bindings {
        vertex_buffers = { 0 = quad_vbuf },
        fs_images = { SLOT_tex0 = offscreen_pass_desc.color_attachments[0].image }
    };

    /* pipeline and resource bindings to render debug-visualization quads */
    dbg_pip = sg.make_pipeline({
        layout = { attrs = { ATTR_vs_dbg_pos = { format= .FLOAT2 } } },
        primitive_type = .TRIANGLE_STRIP,
        shader = sg.make_shader(dbg_shader_desc()^),
        rasterizer = { sample_count = MSAA_SAMPLES },
        label = "dbgvis quad pipeline"
    });

    dbg_bind = sg.Bindings {
        vertex_buffers = { 0 = quad_vbuf }
        /* images will be filled right before rendering */
    };
}

mrt_frame :: proc "c" () {
    /* view-projection matrix */
    proj := perspective(deg2rad(f32(60)), cast(f32)sapp.width()/cast(f32)sapp.height(), 0.01, 10);
    view := look_at(Vector3{0.0, 1.5, 6.0}, Vector3{0.0, 0.0, 0.0}, Vector3{0.0, 1.0, 0.0});
    view_proj := mul(proj, view);

    /* shader parameters */
    rx += 1.0; ry += 2.0;
    rxm := rotate_matrix4(Vector3{1, 0, 0}, deg2rad(rx));
    rym := rotate_matrix4(Vector3{0, 1, 0}, deg2rad(ry));

    model := mul(rxm, rym);

    mvps := [NUM_VIEWS]Mat4 {};
    for i in 0..<NUM_VIEWS {
        angle := cast(f32)i / cast(f32)NUM_VIEWS * 180;
        mvps[i] = mul(mul(view_proj, model), rotate_matrix4(Vector3{0, 1, 1}, deg2rad(angle)));
    }

    offscreen_params := Offscreen_Params { mvps = mvps };

    fsq_params := FSQ_Params {
        offset = Vector2 { sin(deg2rad(rx)*0.01)*0.9, sin(deg2rad(ry)*0.01)*0.9 }
    };

    /* render cube into MRT offscreen render targets */
    {
        sg.begin_pass(offscreen_pass, offscreen_pass_action);
        defer sg.end_pass();

        sg.apply_pipeline(offscreen_pip);
        sg.apply_bindings(offscreen_bind);
        sg.apply_uniforms(.VS, SLOT_Offscreen_Params, &offscreen_params, size_of(offscreen_params));
        sg.draw(0, 36, NUM_VIEWS);
    }

    /* render fullscreen quad with the 'composed image', plus 3 small debug-view quads */
   {
        sg.begin_default_pass(default_pass_action, sapp.width(), sapp.height());
        sg.apply_pipeline(fsq_pip);
        sg.apply_bindings(fsq_bind);
        sg.apply_uniforms(.VS, SLOT_FSQ_Params, &fsq_params, size_of(fsq_params));
        sg.draw(0, 4, 1);
        sg.apply_pipeline(dbg_pip);
        for i in 0..<NUM_VIEWS {
            S :: 50;
            sg.apply_viewport(i * S, 0, S, S, false);
            debug_uniforms := DebugUniforms { tex_slice = cast(f32)i };
            sg.apply_uniforms(.FS, SLOT_DebugUniforms, &debug_uniforms, size_of(debug_uniforms));
            dbg_bind.fs_images[SLOT_tex] = offscreen_pass_desc.color_attachments[0].image;
            sg.apply_bindings(dbg_bind);
            sg.draw(0, 4, 1);
        }
        sg.apply_viewport(0, 0, sapp.width(), sapp.height(), false);
        sg.end_pass();
        sg.commit();
    }
}

mrt_cleanup :: proc "c" () {
    sg.shutdown();
}

main_mrt :: proc() {
    os.exit(sapp.run({
        init_cb = mrt_init,
        frame_cb = mrt_frame,
        cleanup_cb = mrt_cleanup,
        event_cb = mrt_event,
        width = 800,
        height = 600,
        sample_count = MSAA_SAMPLES,
        window_title = "Render Target Array Slice Rendering",
    }));
}

