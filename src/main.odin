package main

using import "core:runtime"
import "core:strings"
import "core:os"
import "core:mem"
import "core:fmt"
import "core:sys/win32"

using import "math"

import sg "sokol:sokol_gfx"
import sapp "sokol:sokol_app"
import stime "sokol:sokol_time"
import sfetch "sokol:sokol_fetch"
import sgl "sokol:sokol_gl"
import mu "../lib/microui"
import "../lib/basisu"
import "./watcher"

FORCE_2D := false;
OSC :: true;

when OSC {
    import "osc"
    import "core:thread"
}

LKG_ASPECT:f32 = 1;
DEFAULT_CAMERA_FOV:f32 = 14.0;
STACK_TRACES :: true;

when STACK_TRACES {
    import "stacktrace"
}

when EDITOR {
    import "gizmos"
}

EDITOR :: true;

import "./shader_meta";

draw_mesh := true;
draw_quad := false;
draw_grid_lines := false;
draw_gizmos := false;
draw_sdf_text := true;
draw_ui := true;
mesh_rotate_speed:f32 = 12.0;

ANIM_CURVE_WIP :: false;
WINDOW_WIDTH :: 1280;
WINDOW_HEIGHT :: 720;

SFETCH_NUM_CHANNELS :: 1;
SFETCH_NUM_LANES :: 4;
MEGABYTE :: 1024 * 1024;
MAX_FILE_SIZE :: 10 * MEGABYTE;
MSAA_SAMPLE_COUNT :: 1; // anything > 1 causes an assert in sokol_gfx, prob due to my unfinished Render Target Array changes....

sfetch_buffers: [SFETCH_NUM_CHANNELS][SFETCH_NUM_LANES][MAX_FILE_SIZE]u8;

Input_State :: struct {
	right, left, up, down: bool,
	w, a, s, d, q, e, r, t, g, l: bool,
    num_0, num_1, num_2, num_3: bool,
    left_mouse, right_mouse: bool,
    left_ctrl, left_alt, left_shift: bool,
    osc_move: Vector2,
    osc_rotate: Vector3,
}

input_state := Input_State {};

Change :: struct { val, old_val: any };

Undo_Stack :: struct {
    changes: [dynamic]Change,
}

// per-material texture indices into scene.images for metallic material
Metallic_Images :: struct {
    base_color: i16,
    metallic_roughness: i16,
    normal: i16,
    occlusion: i16,
    emissive: i16,
}

Metallic_Material :: struct {
    fs_params: shader_meta.metallic_params,
    images: Metallic_Images,
};

Buffer_Creation_Params :: struct {
    type: sg.Buffer_Type,
    offset: i32,
    size: i32,
    gltf_buffer_index: int,
}

Image_Creation_Params :: struct {
    min_filter: sg.Filter,
    mag_filter: sg.Filter,
    wrap_s: sg.Wrap,
    wrap_t: sg.Wrap,
    gltf_image_index: int,
};

Mesh :: struct {
    first_primitive: i16, // index into scene.sub_meshes
    num_primitives: i16,
};

Vertex_Buffer_Mapping :: struct {
    num: i32,
    buffer: [sg.MAX_SHADERSTAGE_BUFFERS]i32,
}

Sub_Mesh :: struct { // a 'primitive' (aka submesh) contains everything needed to issue a draw call
    // TODO: check that these types make sense
    pipeline: i16,
    material: i16,
    vertex_buffers: Vertex_Buffer_Mapping,
    index_buffer: i16,
    base_element: i32,
    num_elements: i32,
};

Node :: struct {
    mesh: i16, // index into scene.meshes
    transform: Matrix4,
};

Material :: struct {
    pipeline: sg.Pipeline,
    bindings: sg.Bindings,
}

create_fsq_material :: proc(label: cstring, shader: sg.Shader) -> Material {
    using m: Material;

    Vertex :: struct {
        pos: [2]f32,
        uv:  [2]f32,
    };

    C :: 1.0;
    vertices := [?]Vertex {
        {{+C, +C}, {1, 0}}, {{+C, -C}, {0, 1}}, {{-C, -C}, {0, 0}},
        {{-C, -C}, {0, 0}}, {{-C, +C}, {0, 0}}, {{+C, +C}, {1, 0}},
    };

    bindings.vertex_buffers[0] = sg.make_buffer({
        label = label,
        size = len(vertices) * size_of(vertices[0]),
        content = &vertices[0],
    });

    pipeline = sg.make_pipeline({
        shader = shader,
        blend = {
            depth_format = .NONE,
        },
        label = label,
        layout = {
            attrs = {
                0 = {format = .FLOAT2 },
                1 = {format = .FLOAT2 },
            },
        },
    });

    return m;
}

state: struct {
    offscreen: struct {
        pass_desc: sg.Pass_Desc,
        color_img_desc: sg.Image_Desc,
        pass: sg.Pass,
    },
    depth_of_field: struct {
        pass_desc: sg.Pass_Desc,
        color_img_desc: sg.Image_Desc,
        pass: sg.Pass,
    },
    dof_material: Material,
    dof_enabled: bool,

    xform_a: gizmos.Transform,
	pass_action: sg.Pass_Action,
	bind:        sg.Bindings,
	pip:         sg.Pipeline,
    mu_pip:      sg.Pipeline,
    line_rendering_pipeline: sg.Pipeline,
    gizmo_rendering_pipeline: sg.Pipeline,
    mu_atlas_img: sg.Image,

    lenticular_pipeline: sg.Pipeline,
    lenticular_bindings: sg.Bindings,
    
    font_normal_data: [256 * 1024]u8, // TODO: use a smaller buffer and the streaming capability of sokol-fetch

    // mesh
    shaders: struct {
        metallic: sg.Shader,
    },
    scene: struct {
        buffers: [dynamic]sg.Buffer,
        images: [dynamic]sg.Image,
        materials: [dynamic]Metallic_Material,
        meshes: [dynamic]Mesh,
        nodes: [dynamic]Node,
        sub_meshes: [dynamic]Sub_Mesh,
        pipelines: [dynamic]sg.Pipeline,
    },

    camera: Camera,
    view_proj: Matrix4,

    placeholders: struct { white, normal, black: sg.Image },
    pip_cache: [dynamic]Pipeline_Cache_Params,
    point_light: shader_meta.light_params,
    failed: bool,

    creation_params: struct {
        buffers: [dynamic]Buffer_Creation_Params,
        images: [dynamic]Image_Creation_Params,
    },

    auto_rotate: bool,
    mouse: struct { pos: Vector2, }
};

gizmos_ctx: gizmos.Context;

last_ticks: u64 = 0;

frame_count:u32;
fps_counter: struct {
    last_time_secs: f64,
    num_frames: int,

    ms_per_frame: f64,
};

per_frame_stats: struct {
    draw_calls: u64,
    num_elements: u64,
};

bg := [?]f32 { 0.5, 0.7, 1.0 };

test_curve := Bezier_Curve { 1, 0, 0, 1 };

window: mu.Container;
mu_ctx: mu.Context;

/* microui callbacks */
delta := v3(-1.92, -0.07, 1.52);

render_gizmos :: proc(mesh: ^gizmos.Mesh) {
    // @Speed just pass index buffers to a sg_pipeline and be done with it.
    sgl.begin_triangles();
    defer sgl.end();

    for _, t in mesh.triangles {
        tri := &mesh.triangles[t];
        for i in 0..<3 {
            index := tri[i];
            using v := &mesh.vertices[index];
            inline for idx in 0..<3 do assert(!math.is_nan(position[idx]));
            inline for idx in 0..<4 do assert(!math.is_nan(color[idx]));
            sgl.v3f_c4f(position.x, position.y, position.z, color.r, color.g, color.b, color.a);
        }

    }
}

when OSC {
    osc_thread: ^thread.Thread;
    _osc_running := false;

    @private
    osc_thread_func :: proc(thread: ^thread.Thread) {
        osc.init({
            on_vector2 = proc (addr: string, v2: Vector2) { input_state.osc_move = v2; },
            on_vector3 = proc (addr: string, v3: Vector3) { input_state.osc_rotate = v3; }
        });
        for _osc_running {
            osc.update();
        }
        osc.shutdown();
    }

    @private
    stop_osc_thread :: proc() {
        _osc_running = false;
        //thread.join(osc_thread);
        osc_thread = nil;
    }
}

init_callback :: proc "c" () {
    watcher._setup_notification(".");

    state.auto_rotate = true;
    editor_settings = editor_settings_defaults();

    hp_infos:[]Display_Info;
    hp_connected, hp_infos = holoplaycore_init();
    fmt.println("HP_CONNECTED", hp_connected);
    if len(hp_infos) == 0 do hp_connected = false;
    if !hp_connected do FORCE_2D = true;
    if FORCE_2D {
        //fmt.println("FORCE2D is on");
        hp_connected = false;
    }
    if hp_connected {
        hp_info = hp_infos[0];
        LKG_ASPECT = cast(f32)hp_info.width / cast(f32)hp_info.height;
    }

    when OSC {
        _osc_running = true;
        osc_thread = thread.create(osc_thread_func);
        if osc_thread != nil do thread.start(osc_thread);
    }

    if hp_connected {
        move_window(sapp.win32_get_hwnd(), hp_info.xpos, hp_info.ypos, hp_info.width, hp_info.height, true);
    }

    {
        state.xform_a = {
            position = {0, 0, 0},
            orientation = transmute(Vector4)degrees_to_quaternion(v3(180, 0, 0)), // TODO: identity quat?
            scale = {1, 1, 1},
        };
    }

	sg.setup({
		mtl_device                   = sapp.metal_get_device(),
		mtl_renderpass_descriptor_cb = sapp.metal_get_renderpass_descriptor,
		mtl_drawable_cb              = sapp.metal_get_drawable,
		d3d11_device                 = sapp.d3d11_get_device(),
		d3d11_device_context         = sapp.d3d11_get_device_context(),
		d3d11_render_target_view_cb  = sapp.d3d11_get_render_target_view,
		d3d11_depth_stencil_view_cb  = sapp.d3d11_get_depth_stencil_view,
	});

    create_multiview_pass(num_views(), sapp.framebuffer_size());

    sgl.setup({
        max_vertices = 50000,
        max_commands = 300,
        pipeline_pool_size = 5,
    });

    basisu.setup();

    init_camera(&state.camera, true, DEFAULT_CAMERA_FOV, sapp.width(), sapp.height());
    state.camera.position = {0, 0.05, 3.90};

    gizmos_ctx.render = render_gizmos;
    gizmos.init(&gizmos_ctx);

    r_init();
    mu.init(&mu_ctx);
    if !FORCE_2D {
        font_scale = 4.3;
        mu_ctx._style = {
            nil,       /* font */
            { 68, 10 }, /* size */
            25, 20, 40,   /* padding, spacing, indent */
            50,         /* title_height */
            30, 25,      /* scrollbar_size, thumb_size */
            {
                { 230, 230, 230, 255 }, /* MU_COLOR_TEXT */
                { 25,  25,  25,  255 }, /* MU_COLOR_BORDER */
                { 50,  50,  50,  255 }, /* MU_COLOR_WINDOWBG */
                { 25,  25,  25,  255 }, /* MU_COLOR_TITLEBG */
                { 240, 240, 240, 255 }, /* MU_COLOR_TITLETEXT */
                { 0,   0,   0,   0   }, /* MU_COLOR_PANELBG */
                { 75,  75,  75,  255 }, /* MU_COLOR_BUTTON */
                { 95,  95,  95,  255 }, /* MU_COLOR_BUTTONHOVER */
                { 115, 115, 115, 255 }, /* MU_COLOR_BUTTONFOCUS */
                { 30,  30,  30,  255 }, /* MU_COLOR_BASE */
                { 35,  35,  35,  255 }, /* MU_COLOR_BASEHOVER */
                { 40,  40,  40,  255 }, /* MU_COLOR_BASEFOCUS */
                { 43,  43,  43,  255 }, /* MU_COLOR_SCROLLBASE */
                { 30,  30,  30,  255 }  /* MU_COLOR_SCROLLTHUMB */
            }
        };
        mu_ctx.style = &mu_ctx._style;
    }
    mu_ctx.text_width = r_text_width_cb;
    mu_ctx.text_height = r_get_text_height;

	stime.setup();

    sfetch.setup({
        num_channels = 1,
        num_lanes = 4,
    });

    load_sdf_fonts();

    //
    // MESH SETUP
    //

    // create shaders
    state.shaders.metallic = sg.make_shader(shader_meta.cgltf_metallic_shader_desc()^);
    assert(state.shaders.metallic.id != sg.INVALID_ID, "shader didn't compile");

    // create point light
    state.point_light = {
        light_pos = Vector3{10.0, 10.0, 10.0},
        light_range = 100.0,
        light_color = Vector3{1000.0, 1000.0, 1000.0},
        light_intensity = 1.0
    };

    // request the mesh GLTF file
    gltf_path:cstring = "resources/gltf/DamagedHelmet/DamagedHelmet.gltf";

    sfetch.send({
        path = gltf_path,
        callback = proc "c" (response: ^sfetch.Response) {
            if response.dispatched {
                sfetch.bind_buffer(response.handle, sfetch_buffers[response.channel][response.lane][:]);
            } else if response.fetched {
                // file has been loaded, parse as GLTF
                bytes := mem.slice_ptr(cast(^u8)response.buffer_ptr, cast(int)response.fetched_size);
                gltf_parse(bytes, dirname(cast(string)response.path));
            }
            if response.finished && response.failed {
                state.failed = true;
                fmt.eprintln("could not load gltf file");
            }
        }
    });

    make_image :: proc(width, height: i32, pixel_format: sg.Pixel_Format, pixels: []u32) -> sg.Image {
        image_desc := sg.Image_Desc {
            width = width,
            height = height,
            pixel_format = pixel_format
        };
        image_desc.content.subimage[0][0] = {
            ptr = &pixels[0],
            size = cast(i32)len(pixels), // ??????????????????????????
        };
        return sg.make_image(image_desc);
    }

    // create placeholder textures
    pixels: [64]u32;
    for i in 0..<64 do pixels[i] = 0xFFFFFFFF;
    state.placeholders.white = make_image(8, 8, sg.Pixel_Format.RGBA8, pixels[:]);
    for i in 0..<64 do pixels[i] = 0xFF000000;
    state.placeholders.black = make_image(8, 8, sg.Pixel_Format.RGBA8, pixels[:]);
    for i in 0..<64 do pixels[i] = 0xFFFF7FFF;
    state.placeholders.normal = make_image(8, 8, sg.Pixel_Format.RGBA8, pixels[:]);

    //
    // make quad rendering pipeline
    //
    {
        Vertex :: struct {
            pos: [3]f32,
            uv: [2]f32,
        };

        C :: 0.6;
        vertices := [?]Vertex{
            {{+C, +C, +C}, {1.0, 0.0}}, {{+C, -C, +C}, {0.0, 1.0}}, {{-C, -C, +C}, {0.0, 0.0}},
            {{-C, -C, +C}, {0.0, 0.0}}, {{-C, +C, +C}, {0.0, 0.0}}, {{+C, +C, +C}, {1.0, 0.0}},
        };

        state.bind.vertex_buffers[0] = sg.make_buffer({
            label = "shadertoy-vertices",
            size = len(vertices)*size_of(vertices[0]),
            content = &vertices[0],
        });
        state.pip = sg.make_pipeline({
            shader = sg.make_shader(shader_meta.shadertoy_shader_desc()^),
            label = "shadertoy-pipeline",
            layout = {
                attrs = {
                    shader_meta.ATTR_vs_st_position = {format = .FLOAT3},
                    shader_meta.ATTR_vs_st_uv = {format = .FLOAT2},
                },
            },
        });
    }

    // make lenticular rendering pipeline
    {
        C :: 1;
        vertices := [?][2]f32{
            {-C, +C}, {+C, +C}, {-C, -C},
            {-C, -C}, {+C, +C}, {+C, -C},
        };
        state.lenticular_bindings.vertex_buffers[0] = sg.make_buffer({
            label = "lenticular-vertices",
            size = len(vertices)*size_of(vertices[0]),
            content = &vertices[0],
        });
        state.lenticular_pipeline = sg.make_pipeline({
            shader = sg.make_shader(shader_meta.lenticular_shader_desc()^),
            label = "lenticular-pipeline",
            layout = {
                attrs = {
                    shader_meta.ATTR_vs_vertPos_data = {format=.FLOAT2},
                },
            },
        });
    }

    // make depth of field pipeline
    {
        dof_shader := sg.make_shader(shader_meta.dof_coc_shader_desc()^);
        state.dof_material = create_fsq_material("depth of field", dof_shader);
    }

    // make line rendering pipeline
    {
        state.line_rendering_pipeline = sgl.make_pipeline({
            depth_stencil = {
                depth_write_enabled = true,
                depth_compare_func = sg.Compare_Func.LESS_EQUAL,
            },
            rasterizer = {
                sample_count = MSAA_SAMPLE_COUNT,
            },
        });
    }

    // make gizmo rendering pipeline
    {
        state.gizmo_rendering_pipeline = sgl.make_pipeline({
            blend = {
                enabled = true,
                src_factor_rgb = sg.Blend_Factor.SRC_ALPHA,
                dst_factor_rgb = sg.Blend_Factor.ONE_MINUS_SRC_ALPHA,
            },
            /*
            depth_stencil = {
                depth_write_enabled = true,
                depth_compare_func = sg.Compare_Func.LESS_EQUAL,
            },
            */
            rasterizer = {
                sample_count = MSAA_SAMPLE_COUNT,
            },
        });
    }

    //
    // make text rendering pipeline
    //
    sdf_text_init();
}

debug_window :: proc(ctx: ^mu.Context) {
    if window.inited == {} {
        mu.init_window(ctx, &window, {});
        window.rect = FORCE_2D ? 
            mu.rect(20, 20, 250, 450) :
            mu.rect(20, 20, 600, 850);
    }

    window.rect.w = max(window.rect.w, 240);
    window.rect.h = max(window.rect.h, 300);

    if mu.begin_window(ctx, &window, "") {
        defer mu.end_window(ctx);
        when ANIM_CURVE_WIP {
            mu.layout_begin_column(ctx);
            mu_layout_row(ctx, {100,}, 100);
            mu_anim_curve(ctx, &test_curve);
            mu.layout_end_column(ctx);
        }

        @static show_tweaks: i32 = 1;
        if mu.header(ctx, &show_tweaks, "tweaks") {
            when len(all_tweakables) == 0 {
                mu.label(ctx, "no tweaks");
            } else {
                for tweakable in all_tweakables {
                    mu_label(ctx, tweakable.name);
                    any_ptr := tweakable.ptr();
                    mu_struct_ti(ctx, tweakable.name, any_ptr.data, type_info_of(any_ptr.id));
                }
            }
        }

        @static show_info: i32 = 0;
        if mu.header(ctx, &show_info, "debug") {
            mu_layout_row(ctx, {80, -1}, 0);
            mu.label(ctx, "ms per frame:"); mu_label_printf(ctx, "%f", fps_counter.ms_per_frame);
            mu.label(ctx, "num elements:"); mu_label_printf(ctx, "%d", per_frame_stats.num_elements);

            mu.label(ctx, "camera eye pos:");

            mu_vector(ctx, &state.camera.position, -20, 20);

            mu_layout_row(ctx, { 40, -1 }, 0);
            mu.label(ctx, "fov:"); mu.slider(ctx, &state.camera.size, 1, 200);
            mu.label(ctx, "rotate"); mu_checkbox(ctx, &state.auto_rotate, "auto rotate");

            for row_index in 0..<4 {
                row := &state.view_proj[row_index];
                mu_layout_row(ctx, { 300, -1 }, 0);
                mu.label(ctx, strings.clone_to_cstring(
                    fmt.tprintf("%f  %f  %f  %f", row[0], row[1], row[2], row[3]),
                    context.temp_allocator));
            }

            mu_layout_row(ctx, { -78, -1 }, 74);
            /* sliders */
            mu.layout_begin_column(ctx);
            mu_layout_row(ctx, { 46, -1 }, 0);
            mu.label(ctx, "Red:");   mu.slider(ctx, &bg[0], 0, 1.0);
            mu.label(ctx, "Green:"); mu.slider(ctx, &bg[1], 0, 1.0);
            mu.label(ctx, "Blue:");  mu.slider(ctx, &bg[2], 0, 1.0);
            mu.layout_end_column(ctx);
            /* color preview */
            r := mu.layout_next(ctx);

            mu.draw_rect(ctx, r, mu.Color{cast(u8)(bg[0]*255.0), cast(u8)(bg[1]*255.0), cast(u8)(bg[2]*255.0), 255});
            s := fmt.tprintf("#%02X%02X%02X", cast(i32) bg[0], cast(i32) bg[1], cast(i32) bg[2]);
            c_s := strings.clone_to_cstring(s, context.temp_allocator);
            mu.draw_control_text(ctx, c_s, r, cast(i32)mu.Style_Color.Text, {mu.Opt.AlignCenter});

        }
    }
}

frame_callback :: proc "c" () {
	//
	// TIME
	//

    frame_count += 1;
	current_ticks := stime.now();
	now_seconds := stime.sec(current_ticks);
    elapsed_ticks:u64 = last_ticks == 0 ? 0 : stime.diff(current_ticks, last_ticks);
	last_ticks = current_ticks;
	elapsed_seconds := stime.sec(elapsed_ticks);

    {
        using fps_counter;
        num_frames += 1;
        if now_seconds - last_time_secs >= 1.0 {
            ms_per_frame = 1000.0 / cast(f64)num_frames;
            num_frames = 0;
            last_time_secs += 1.0;
        }
    }

	//
	// UPDATE
	//

    if frame_count % 30 == 0 do watcher.handle_changes();

    sfetch.dowork();

    if !_did_load do return;

    dt := cast(f32)elapsed_seconds;

    maybe_recreate_multiview_pass(num_views(), sapp.framebuffer_size());

    when EDITOR {
        mouse_ray := worldspace_ray(&state.camera, state.mouse.pos);
        using state.camera;
        gizmos.update(&gizmos_ctx, {
            mouse_left = input_state.left_mouse,
            hotkey_ctrl = input_state.left_ctrl,
            hotkey_translate = input_state.t,
            hotkey_rotate = input_state.r,
            hotkey_scale = input_state.s,
            hotkey_local = input_state.l,
            ray = mouse_ray,
            cam = {
                yfov = size,
                near_clip = near_plane,
                far_clip = far_plane,
                position = position,
                orientation = transmute(Vector4)rotation,
            }
        });

        using state;
        if gizmos.xform(&gizmos_ctx, "first-example-gizmo", &xform_a) {
            // hovered or changed
        }
    }

    //
    // update scene
    //

    // every other second, scrub through curve, pausing at the end for the other second
    /*
    if do_tween {
        time := cast(f32)(now_seconds * .3);
        int_part, r := math.modf(time);
        if cast(int)int_part % 2 == 0 do r = 1.0 - r;

        vv := evaluate(&test_curve, r);
        state.root_transform = scale_matrix4(state.root_transform, Vector3{ vv.x, vv.y, r });
    }
    */

    // update camera
    state.camera.fov = editor_settings.fov;
    do_camera_movement(&state.camera, input_state, dt, 2.0, 4.0, 1.0);
    input_state.osc_move = v2(0, 0);

    proj := construct_projection_matrix(&state.camera);
    view := construct_view_matrix(&state.camera);
    state.view_proj = mul(proj, view);

    @static x_rotation:f32 = 0;
    if state.auto_rotate do x_rotation += dt * mesh_rotate_speed;

    {
        using input_state;
        xform_a.orientation = transmute(Vector4)degrees_to_quaternion(osc_rotate + v3(180, x_rotation, 0));
    }

    //
    // MICROUI
    //
    {
        mu.begin(&mu_ctx);
        defer mu.end(&mu_ctx);
        debug_window(&mu_ctx);
    }

    per_frame_stats = {};

	//
	// DRAW
	//

    // TODO: write this only when the value changes?
    state.pass_action.colors[0] = {action = .CLEAR, val = {bg[0], bg[1], bg[2], 1}};

    //
    // DRAW MESH
    //
    if draw_mesh {
        sg.begin_pass(state.offscreen.pass, {
            colors = {
                0 = { action = .CLEAR, val = { 0.25, 0.0, 0.0, 1.0 } },
            }
        });
        defer sg.end_pass();

        _num_views := cast(int)num_views();

        using state.scene;
        for _, node_index in nodes {
            node := &nodes[node_index];
            vs_params := shader_meta.vs_params {
                model = mul(gizmos.matrix(state.xform_a), node.transform),
                eye_pos = state.camera.position,
            };

            camera_size:f32 = editor_settings.lkg_camera_size;
            cam_forward := quaternion_forward(state.camera.rotation);
            focal_position := state.camera.position + norm(cam_forward) * camera_size;
            camera_distance := length(state.camera.position - focal_position);

            for view_i:int = 0; view_i < _num_views; view_i += 1 {
                // start at -viewCone * 0.5 and go up to viewCone * 0.5
                offset_angle := _num_views == 1 ? 0 : (cast(f32)view_i / (cast(f32)_num_views - 1) - 0.5) * editor_settings.lkg_view_cone;

                // calculate the offset
                offset := camera_distance * tan(offset_angle);

                view_matrix := view;
                view_matrix[3][0] -= offset;

                // modify the projection matrix, relative to the camera size and aspect ratio
                projection_matrix := proj;
                projection_matrix[2][0] -= offset / (camera_size * LKG_ASPECT);

                vs_params.view_proj_array[view_i] = mul(projection_matrix, view_matrix);
            }

            mesh := &meshes[node.mesh];
            for i in 0..<mesh.num_primitives {
                prim := &sub_meshes[i + mesh.first_primitive];
                sg.apply_pipeline(pipelines[prim.pipeline]);
                bind := sg.Bindings {};
                for vb_slot in 0..<prim.vertex_buffers.num {
                    bind.vertex_buffers[vb_slot] = buffers[prim.vertex_buffers.buffer[vb_slot]];
                }
                if prim.index_buffer != SCENE_INVALID_INDEX {
                    bind.index_buffer = buffers[prim.index_buffer];
                }
                apply_uniforms(.VS, shader_meta.SLOT_vs_params, &vs_params);
                apply_uniforms(.FS, shader_meta.SLOT_light_params, &state.point_light);
                //if mat.is_metallic {
                    {
                        base_color_tex := state.placeholders.white;
                        metallic_roughness_tex := state.placeholders.white;
                        normal_tex := state.placeholders.normal;
                        occlusion_tex := state.placeholders.white;
                        emissive_tex := state.placeholders.black;

                        if prim.material != -1 {
                            metallic := &materials[prim.material];

                            apply_uniforms(sg.Shader_Stage.FS,
                                shader_meta.SLOT_metallic_params,
                                &metallic.fs_params);
                                

                            using metallic.images;
                            if base_color != -1         && images[base_color].id != 0         do base_color_tex = images[base_color];
                            if metallic_roughness != -1 && images[metallic_roughness].id != 0 do metallic_roughness_tex = images[metallic_roughness];
                            if normal != -1             && images[normal].id != 0             do normal_tex = images[normal];
                            if occlusion != -1          && images[occlusion].id != 0          do occlusion_tex = images[occlusion];
                            if emissive != -1           && images[emissive].id != 0           do emissive_tex = images[emissive];
                        }

                        using shader_meta;
                        bind.fs_images[SLOT_base_color_texture] = base_color_tex;
                        bind.fs_images[SLOT_metallic_roughness_texture] = metallic_roughness_tex;
                        bind.fs_images[SLOT_normal_texture] = normal_tex;
                        bind.fs_images[SLOT_occlusion_texture] = occlusion_tex;
                        bind.fs_images[SLOT_emissive_texture] = emissive_tex;
                    }
                //} else {
                    //assert(false, "nonmetallic is unimplemented");
                //}

                sg.apply_bindings(bind);

                assert(prim.num_elements > 0);
                per_frame_stats.num_elements += cast(u64)prim.num_elements;
                sg.draw(cast(int)prim.base_element, cast(int)prim.num_elements, _num_views);
            }
        }
    }

    //
    // DEPTH OF FIELD
    //
    if state.dof_enabled {
        using state.depth_of_field;
        sg.begin_pass(pass, {
            colors = {
                0 = { action = .CLEAR, val = { 0.0, 0.0, 0.0, 0.0 } },
            }
        });
        sg.apply_pipeline(state.dof_material.pipeline);
        sg.apply_bindings(state.dof_material.bindings);

        apply_uniforms(.FS, shader_meta.SLOT_builtins, shader_meta.builtins {
            nearPlane = state.camera.near_plane,  // TODO: do these two values change with the LKG projection matrix stuff? should they become functions on the gl_Layer specific projection matrix?
            farPlane = state.camera.far_plane,
        });

        apply_uniforms(.FS, shader_meta.SLOT_dof_uniforms, shader_meta.dof_uniforms {
            focusDistance = editor_settings.dof_distance,
            focusRange = editor_settings.dof_range,
        });

        sg.draw(0, 6, num_views());
        sg.end_pass();
    }

    sg.begin_default_pass(state.pass_action, sapp.framebuffer_size());

    state.lenticular_bindings.fs_images[shader_meta.SLOT_cocTex] =
        state.depth_of_field.pass_desc.color_attachments[0].image;

    sg.apply_pipeline(state.lenticular_pipeline);
    sg.apply_bindings(state.lenticular_bindings);
    {
        using hp_info;

        // TODO: must match constants in lenticular.glsl. use an @annotation and an enum to just generate them!
        Debug :: enum { Off, Depth, Color, DepthOfField, };

        debug:Debug = .Off;
        {
            using editor_settings;
            // TODO: this should be an enum
            if visualize_depth do debug = .Depth;
            if visualize_color do debug = .Color;
            if visualize_dof   do debug = .DepthOfField;
        }

        apply_uniforms(.FS, shader_meta.SLOT_lkg_fs_uniforms, shader_meta.lkg_fs_uniforms {
            pitch = pitch,
            tilt = tilt,
            center = center,
            subp = subp,
            ri = cast(i32)ri,
            bi = cast(i32)bi,
            invView = invView,
            aspect = cast(f32)width/cast(f32)height,
            debug = i32(debug),
            debugTile = i32(num_views() / 2),
            tile = Vector4 {1, 1, cast(f32)num_views(), 0},
            viewPortion = Vector4{1, 1, 0, 0},
        });
    }
    sg.draw(0, 6, 1);

    // DRAW MOVABLE QUAD
    if draw_quad {
        sg.apply_pipeline(state.pip);
        sg.apply_bindings(state.bind);
        apply_uniforms(.FS, shader_meta.SLOT_st_fs_uniforms, shader_meta.st_fs_uniforms {
            iTime = cast(f32)now_seconds * 3.0,
            iResolution = Vector3 { cast(f32)sapp.width()/2.0, cast(f32)sapp.height()/2.0, 1.0 },
            iTimeDelta = dt,
            iFrame = cast(i32)frame_count,
            iFrameRate = cast(f32)(1.0 / fps_counter.ms_per_frame),
            iSampleRate = 44100,
        });
        sg.draw(0, 6, 1);
    }

    // DRAW GRID LINES
    if draw_grid_lines {
        sgl.defaults();
        sgl.push_pipeline();
        defer sgl.pop_pipeline();
        sgl.load_pipeline(state.line_rendering_pipeline);
        sgl.matrix_mode_modelview();
        sgl.load_matrix(&state.view_proj[0][0]);
        grid_frame_count:u32 = 0;
        //sgl.translate(sin(f32(grid_frame_count) * 0.02) * 16.0, sin(f32(grid_frame_count) * 0.01) * 4.0, 0.0);
        sgl.c3f(0.5, 0.5, 0.5);
        grid(0, grid_frame_count);
        //sgl.draw();
    }

    if draw_ui {
        mu_render(sapp.width(), sapp.height()); // note; this just pushes commands to a queue. r_draw below actually does the draw calls
    }

    // DRAW GIZMOS
    when EDITOR {
        if draw_gizmos {
            using sgl;
            defaults();
            push_pipeline();
            defer pop_pipeline();
            load_pipeline(state.gizmo_rendering_pipeline);
            matrix_mode_modelview();
            load_matrix(&state.view_proj[0][0]);
            gizmos.draw(&gizmos_ctx);
        }
    }

    // DRAW SDF TEXT
    if draw_sdf_text {
        y:f32 = FORCE_2D ? 60 : 80;
        draw_text(fmt.tprintf("%f ms per frame", fps_counter.ms_per_frame), y, v2(f32(10), y));
        text_matrix := ortho3d(0, cast(f32)sapp.width(), 0, cast(f32)sapp.height(), -10.0, 10.0);
        sdf_text_render(text_matrix);
    }

    // DRAW UI
    r_draw();

    sg.end_pass();
	sg.commit();
}

toggle_fullscreen :: proc() {
    is_fullscreen = !is_fullscreen;
    fmt.println("toggling fullscreen", is_fullscreen);

    {
        using win32;
        hwnd := cast(Hwnd)sapp.win32_get_hwnd();

        x, y, w, h: i32;
        win_style: u32;

        if is_fullscreen {
            win_style = WS_POPUP | WS_SYSMENU | WS_VISIBLE;
            if hp_connected {
                using hp_info;
                x, y, w, h = xpos, ypos, width, height;
            } else {
                x, y = 0, 0;
                w, h = get_system_metrics(SM_CXSCREEN), get_system_metrics(SM_CYSCREEN);
            }
        } else {
            x, y = 100, 100;
            w, h = WINDOW_WIDTH, WINDOW_HEIGHT;

            WS_CLIPSIBLINGS :: 0x04000000;
            WS_CLIPCHILDREN :: 0x02000000;
            WS_SIZEBOX      :: 0x00040000;
            win_style = WS_CLIPSIBLINGS | WS_CLIPCHILDREN | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SIZEBOX;
        }
        //set_window_long_ptr_w(hwnd, GWL_STYLE, cast(Long_Ptr)win_style);
        set_window_pos(hwnd, nil, x, y, w, h, SWP_FRAMECHANGED | SWP_NOZORDER);
    }
}

cleanup :: proc "c" () {
    when OSC do stop_osc_thread();
    basisu.shutdown();
    sfetch.shutdown();
    sg.shutdown();
    free_all(context.temp_allocator);
}

event_callback :: proc "c" (event: ^sapp.Event) {
    switch event.type {
        case .RESIZED:
            camera_target_resized(&state.camera, cast(f32)sapp.width(), cast(f32)sapp.height());
        case .MOUSE_DOWN:
            set_capture(sapp.win32_get_hwnd());

            mu.input_mousedown(&mu_ctx, cast(i32)event.mouse_x, cast(i32)event.mouse_y, 1 << cast(u32)event.mouse_button);
            switch event.mouse_button {
                case .LEFT: input_state.left_mouse = true;
                case .RIGHT: input_state.right_mouse = true;
            }
        case .MOUSE_UP:
            release_capture(sapp.win32_get_hwnd());

            mu.input_mouseup(&mu_ctx, cast(i32)event.mouse_x, cast(i32)event.mouse_y, 1 << cast(u32)event.mouse_button);
            switch event.mouse_button {
                case .LEFT: input_state.left_mouse = false;
                case .RIGHT: input_state.right_mouse = false;
            }
        case .MOUSE_MOVE:
            mu.input_mousemove(&mu_ctx, cast(i32)event.mouse_x, cast(i32)event.mouse_y);
            state.mouse.pos = v2(event.mouse_x, event.mouse_y);
        case .KEY_DOWN:
            mu.input_keydown(&mu_ctx, cast(i32)key_map[event.key_code & cast(sapp.Key_Code)511]);
        case .KEY_UP:
            mu.input_keyup(&mu_ctx, cast(i32)key_map[event.key_code & cast(sapp.Key_Code)511]);
        case .CHAR:
            txt := [2]u8 { cast(u8)(event.char_code & 255), 0 };
            mu.input_text(&mu_ctx, cstring(&txt[0]));

    }

	if event.type == .KEY_DOWN && !event.key_repeat {
		using input_state;
		switch event.key_code {
			case .ESCAPE:
				sapp.request_quit();
			case .RIGHT: right = true;
			case .LEFT: left = true;
			case .UP: up = true;
			case .DOWN: down = true;
			case .W: w = true;
			case .S: s = true;
			case .A: a = true;
			case .D: d = true;
            case .Q: q = true;
            case .E: e = true;
            case .R: r = true;
            case .G: g = true;
            case .T: t = true;
            case .L: l = true;
            case .NUM_0: num_0 = true;
            case .NUM_1: num_1 = true;
            case .NUM_2:
                num_2 = true;
                toggle_fullscreen();
            case .NUM_3: num_3 = true;
            case .LEFT_ALT: left_alt = true;
            case .LEFT_CONTROL: left_ctrl = true;
            case .LEFT_SHIFT: left_shift = true;
		}
	}

	if event.type == .KEY_UP {
		using input_state;
		switch event.key_code {
			case .RIGHT: right = false;
			case .LEFT: left = false;
			case .UP: up = false;
			case .DOWN: down = false;
			case .W: w = false;
			case .S: s = false;
			case .A: a = false;
			case .D: d = false;
            case .Q: q = false;
            case .E: e = false;
            case .R: r = false;
            case .G: g = false;
            case .T: t = false;
            case .L: l = false;
            case .NUM_0: num_0 = false;
            case .NUM_1: num_1 = false;
            case .NUM_2: num_2 = false;
            case .NUM_3: num_3 = false;
            case .LEFT_ALT: left_alt = false;
            case .LEFT_CONTROL: left_ctrl = false;
            case .LEFT_SHIFT: left_shift = false;
		}
	}
}

handle_args :: proc() {
    for arg in os.args {
        switch arg {
            case "--2d", "--2D": FORCE_2D = true;
            case "--no-dof": state.dof_enabled = false;
        }
    }
}

main :: proc() {
    state.dof_enabled = true;
    handle_args();

    // install a stacktrace handler for asserts
    when STACK_TRACES do context.assertion_failure_proc = stacktrace.assertion_failure_with_stacktrace_proc;

	os.exit(run_app());
}

is_fullscreen: bool;

run_app :: proc() -> int {
    is_fullscreen = !FORCE_2D;

	return sapp.run({
		init_cb      = init_callback,
		frame_cb     = frame_callback,
		cleanup_cb   = cleanup,
		event_cb     = event_callback,
		width        = WINDOW_WIDTH,
		height       = WINDOW_HEIGHT,
		window_title = "testbed",
        sample_count = MSAA_SAMPLE_COUNT,
        fullscreen   = is_fullscreen,
        //high_dpi     = true,
	});
}

