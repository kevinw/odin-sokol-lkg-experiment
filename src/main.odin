package main

import "core:runtime"
import "core:os"
import "core:mem"
import "core:fmt"
import "core:log"
import "core:sys/win32"

import "./math"

import sg "../lib/odin-sokol/src/sokol_gfx"
import sapp "../lib/odin-sokol/src/sokol_app"
import stime "../lib/odin-sokol/src/sokol_time"
import sfetch "../lib/odin-sokol/src/sokol_fetch"
import sgl "../lib/odin-sokol/src/sokol_gl"
import simgui "../lib/odin-sokol/src/sokol_imgui"
import imgui "../lib/odin-imgui"
import "../lib/wbml"
import "../lib/basisu"
import "./watcher"

Game_Mode :: enum {
    None,
    Snake,
    Tunnel
}

game_mode: Game_Mode = .None;

OSC :: false;
LKG_ASPECT:f32 = 1;
DEFAULT_CAMERA_FOV:f32 = 14.0;
STACK_TRACES :: true;
LEAK_CHECK :: false;


when OSC {
    import "osc"
    import "core:thread"
}

when STACK_TRACES {
    import "stacktrace"
}

when EDITOR {
    import "gizmos"
}

EDITOR :: true;

import "./shader_meta";

osc_enabled := true;

load_assimp_model := false;
draw_mesh := true;
draw_quad := false;
draw_grid_lines := false;
draw_gizmos := false;
draw_sdf_text := true;
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
	w, a, s, d, q, e, r, t, g, l, p: bool,
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

GLTFMesh :: struct {
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

GLTFNode :: struct {
    mesh: i16, // index into scene.meshes
    transform: Matrix4,
};

Material :: struct {
    pipeline: sg.Pipeline,
    bindings: sg.Bindings,
}

apply_material :: proc(using material: ^Material) {
    sg.apply_pipeline(pipeline);
    sg.apply_bindings(bindings);
}

Scene :: struct {
    buffers: [dynamic]sg.Buffer,
    images: [dynamic]sg.Image,
    materials: [dynamic]Metallic_Material,
    meshes: [dynamic]GLTFMesh,
    nodes: [dynamic]GLTFNode,
    sub_meshes: [dynamic]Sub_Mesh,
    pipelines: [dynamic]sg.Pipeline,
};

state: struct {
    assimp_model: Model,
    offscreen: struct {
        pass_desc: sg.Pass_Desc,
        color_img_desc: sg.Image_Desc,
        pass: sg.Pass,
    },
    depth_of_field: struct {
        prefilter_blit: Blitter,
        postfilter_blit: Blitter,
        combine_blit: Blitter,

        half_size_color: sg.Image,
        final_img: sg.Image,

        coc_pass_desc: sg.Pass_Desc,
        coc_pass: sg.Pass,
        coc_img_desc: sg.Image_Desc,
        coc_material: Material,

        bokeh_pass_desc: sg.Pass_Desc,
        bokeh_pass: sg.Pass,
        bokeh_img_desc: sg.Image_Desc,
        bokeh_material: Material,

        enabled: bool,
    },

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

    scene: Scene,
    camera: Camera,
    view_proj: Matrix4,
    view_proj_array: [MAXIMUM_VIEWS]Matrix4,

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

init_callback :: proc() {
    using math;

    watcher._setup_notification(".");

    state.auto_rotate = true;
    editor_settings = editor_settings_defaults();

    hp_infos:[]Display_Info;
    hp_connected, hp_infos = holoplaycore_init();

    if len(hp_infos) == 0 do hp_connected = false;
    hp_info = hp_connected ? hp_infos[0] : STOCK_DISPLAY_INFO;

    LKG_ASPECT = cast(f32)hp_info.width / cast(f32)hp_info.height;

    when OSC {
        if osc_enabled {
            _osc_running = true;
            osc_thread = thread.create(osc_thread_func);
            if osc_thread != nil do thread.start(osc_thread);
        }
    }

    if hp_connected {
        move_window(sapp.win32_get_hwnd(), hp_info.xpos, hp_info.ypos, hp_info.width, hp_info.height, true);
    }

    state.xform_a = {
        position = {0, 0, 0},
        orientation = transmute(Vector4)degrees_to_quaternion(v3(180, 0, 0)), // TODO: identity quat?
        scale = {1, 1, 1},
    };

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

    setup_simgui();

    basisu.setup();

    init_camera(&state.camera, true, DEFAULT_CAMERA_FOV, sapp.width(), sapp.height());

    switch game_mode {
    case .Snake:
        state.camera.position = {-4, .26, 13.7};
        state.camera.rotation = {0, -.12, 0, 0.99};
        {
            using editor_settings;
            {
                using dof;
                bokeh_radius = 3.90;
                distance = 7.40;
                range = 3.80;
            }
            lkg_camera_size = 3.40;
        }
    case .Tunnel:
        state.camera.position = {0, 0.05, 3.90};
    case .None:
        state.camera.position = {0, 0.05, 3.90};
    }

    gizmos_ctx.render = render_gizmos;
    gizmos.init(&gizmos_ctx);

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
    //gltf_path:cstring = "resources/gltf/DamagedHelmet/DamagedHelmet.gltf";
    gltf_path:cstring = "resources/gltf/Duck/Duck.gltf";
    //gltf_path:cstring = "resources/gltf/Drevo/scene.gltf";

    sfetch.send({
        path = gltf_path,
        callback = proc "c" (response: ^sfetch.Response) {
            context.logger = main_thread_logger;

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

    // make depth of field pipelines
    {
        init_dof_pipelines();
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

    draw_gizmos = false;

    log.info("init callback has finished.");

    if load_assimp_model {
        state.assimp_model = load_model_from_file("resources/models/box.obj");
    }
}

setup_context_fn :: proc(cb: proc()) {
    context.logger = main_thread_logger;
    context.assertion_failure_proc = stacktrace.assertion_failure_with_stacktrace_proc;
    cb();
}

setup_context_event :: proc(cb: proc(e: ^sapp.Event), e: ^sapp.Event) {
    context.logger = main_thread_logger;
    context.assertion_failure_proc = stacktrace.assertion_failure_with_stacktrace_proc;
    cb(e);
}

setup_context :: proc { setup_context_fn, setup_context_event };

frame_callback :: proc() {
    using math;

    sfetch.dowork();
    if !_did_load do return;


	//
	// TIME
	//

    frame_count += 1;
	current_ticks := stime.now();
	now_seconds := stime.sec(current_ticks);
    elapsed_ticks:u64 = last_ticks == 0 ? 0 : stime.diff(current_ticks, last_ticks);
	last_ticks = current_ticks;
	elapsed_seconds := stime.sec(elapsed_ticks);
    dt := cast(f32)elapsed_seconds;

    simgui.new_frame(cast(i32)sapp.width(), cast(i32)sapp.height(), elapsed_seconds);

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

    if frame_count % 30 == 0 {
        watcher.handle_changes(on_shader_changed);
    }

    maybe_recreate_multiview_pass(num_views(), sapp.framebuffer_size());

    when EDITOR {
        if draw_gizmos {
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
        state.xform_a.orientation = transmute(Vector4)degrees_to_quaternion(osc_rotate + v3(180, x_rotation, 0));
    }

    //
    // IMGUI
    //
    {
        //imgui.show_demo_window();

        if imgui.begin("Inspector") {
            if imgui.button("Save") {
                s := wbml.serialize(&editor_settings);
                os.write_entire_file("state.wbml", transmute([]u8)s);
            }
            imgui.same_line();
            if imgui.button("Load") {
                bytes, ok := os.read_entire_file("state.wbml");
                if ok {
                    wbml.deserialize(bytes, &editor_settings);
                }
            }
            imgui_struct(&editor_settings, "Editor Settings");

            //for tweakable in all_tweakables {
                //any_ptr := tweakable.ptr();
                //imgui_struct_ti(tweakable.name, any_ptr.data, type_info_of(any_ptr.id), "", true);
            //}
            imgui_struct(&state, "state");
        }
        imgui.end();

        imgui_console();
    }

    per_frame_stats = {};

	//
	// DRAW
	//

    // TODO: write this only when the value changes?
    state.pass_action.colors[0] = {action = .CLEAR, val = {bg[0], bg[1], bg[2], 1}};

    //
    // Compute multiview view_proj matrices
    //
    _num_views := num_views();
    {
        camera_size:f32 = editor_settings.lkg_camera_size;
        cam_forward := quaternion_forward(state.camera.rotation);
        focal_position := state.camera.position + norm(cam_forward) * camera_size;
        camera_distance := length(state.camera.position - focal_position);

        // Looking Glass multiview-each gl_Layer gets a different view-projection matrix,
        // each one offset on a horizontal "rail"
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

            state.view_proj_array[view_i] = mul(projection_matrix, view_matrix);
        }
    }

    // DRAW MESH
    {
        BEGIN_PASS(state.offscreen.pass, { colors = { 0 = { action = .CLEAR, val = { 0.00, 0.0, 0.0, 1.0 } }}});

        if draw_mesh {
            draw(&state.scene, _num_views, now_seconds);
        }

        // draw assimp mesh
        if load_assimp_model {
            scale := v3(1, 1, 1);
            rotation := v4(0, 0, 0, 0);
            position := v3(0, 0, 0);

            @static vert_color: sg.Shader;
            shader := static_shader(&vert_color, shader_meta.vertcolor_shader_desc());
            draw_model(&state.assimp_model, shader, position, rotation, scale);
        }

    } // draw_mesh (offscreen pass)


    //
    // DEPTH OF FIELD
    //

    if state.depth_of_field.enabled {
        using state.depth_of_field;
        {
            // coc (circle of confusion)
            BEGIN_PASS(coc_pass, { colors = { 0 = { action = .CLEAR, val = { 0.0, 0.0, 0.0, 0.0 } }, } });

            apply_material(&coc_material);

            apply_uniforms(.FS, shader_meta.SLOT_builtins, shader_meta.builtins {
                nearPlane = state.camera.near_plane,  // TODO: do these two values change with the LKG projection matrix stuff? should they become functions on the gl_Layer specific projection matrix?
                farPlane = state.camera.far_plane,
            });
            apply_uniforms(.FS, shader_meta.SLOT_dof_uniforms, shader_meta.dof_uniforms {
                focusDistance = editor_settings.dof.distance,
                focusRange = editor_settings.dof.range,
                bokeh_radius = editor_settings.dof.bokeh_radius,
            });

            sg.draw(0, 6, num_views());
        }

        {
            // prefilter (main color and coc -> half size color with coc in alpha)
            prefilter_blit.bindings.fs_images[shader_meta.SLOT_prefilterCoc] = coc_pass_desc.color_attachments[0].image;
            blit(&prefilter_blit, state.offscreen.pass_desc.color_attachments[0].image);
        }

        {
            // bokeh pass (already to half-size texture)
            // TODO: make this another set of 'create_blit'/'blit' calls
            BEGIN_PASS(bokeh_pass, { colors = { 0 = { action = .CLEAR, val = { 0.0, 0.0, 0.0, 0.0 } }, } });
            bokeh_material.bindings.fs_images[shader_meta.SLOT_cameraColorWithCoc] = half_size_color;// offscreen.pass_desc.color_attachments[0].image;
            apply_material(&bokeh_material);
            apply_uniforms(.FS, shader_meta.SLOT_bokeh_uniforms, shader_meta.bokeh_uniforms {
                bokeh_radius = editor_settings.dof.bokeh_radius,
            });

            sg.draw(0, 6, num_views());
        }
        {
            // post filter pass
            blit(&postfilter_blit, bokeh_pass_desc.color_attachments[0].image);
        }

        {
            // combine pass
            combine_blit.bindings.fs_images[shader_meta.SLOT_cocTexArr] = state.depth_of_field.coc_pass_desc.color_attachments[0].image;
            combine_blit.bindings.fs_images[shader_meta.SLOT_dofTex] = half_size_color;
            blit(&combine_blit, state.offscreen.pass_desc.color_attachments[0].image);
        }
    }

    //
    // DRAW WORLD SPACE SDF TEXT
    //
    if draw_sdf_text {
        //y:f32 = is_fullscreen ? 75 : 40;
        y:f32 = 0.08;
        fps := fps_counter.ms_per_frame > 0 ? cast(int)(1000.0 / fps_counter.ms_per_frame) : 0;
        txt := fmt.tprintf("%d fps - %f ms per frame - %d tris - %d views", fps, fps_counter.ms_per_frame, per_frame_stats.num_elements * cast(u64)num_views(), num_views());
        {
            using editor_settings.sdftext;
            actual_num_layers := _num_views > 1 ? int(max(num_layers, 1)) : 1;
            for i in 0..<actual_num_layers { // weird sdf layer effect
                factor := f32(i)/f32(num_layers);
                layer_buf := lerp(buf, lerp(buf, 1.0, buf_falloff), factor);
                z := z_start - factor * z_thickness;
                draw_text(txt, y, v3(f32(0), y, z), gamma, layer_buf);
            }
        }

        color := Vector4{1, 1, 1, 0.35};
        {
            using editor_settings.sdftext;
            //text_matrix := state.view_proj;
            //text_matrix := ortho3d(0, cast(f32)sapp.width(), 0, cast(f32)sapp.height(), -10.0, 10.0);

            {
                BEGIN_PASS(text.pass, text.pass_action);
                model_matrix := mat4_translate(state.camera.position);
                model_matrix = mul(model_matrix, quat_to_mat4(state.camera.rotation));
                model_matrix = mul(model_matrix, mat4_translate(pos));
                sdf_text_render(state.view_proj_array, model_matrix, _num_views, color);
            }
        }
    }

    //
    // DEFAULT FRAMEBUFFER PASS
    //
    sg.begin_default_pass(state.pass_action, sapp.framebuffer_size());

    {
        using state;
        using lenticular_bindings;
        using shader_meta;

        camera_color := offscreen.pass_desc.color_attachments[0].image;

        if state.depth_of_field.enabled {
            fs_images[SLOT_cocTex]    = depth_of_field.coc_pass_desc.color_attachments[0].image;
            fs_images[SLOT_depthTex]  = offscreen.pass_desc.depth_stencil_attachment.image;
            fs_images[SLOT_screenTex] = depth_of_field.final_img;
        } else {
            fs_images[SLOT_cocTex]    = camera_color;
            fs_images[SLOT_depthTex]  = offscreen.pass_desc.depth_stencil_attachment.image;
            fs_images[SLOT_screenTex] = camera_color;
        }
    }


    //
    // Blit the offscreen render target array into a lenticular image
    //
    sg.apply_pipeline(state.lenticular_pipeline);
    sg.apply_bindings(state.lenticular_bindings);
    {
        using hp_info;

        // TODO: must match constants in lenticular.glsl. use an @annotation and an enum to just generate them!
        Debug :: enum { Off, Depth, DOFCoc };

        debug:Debug = .Off;
        {
            using editor_settings;
            if visualize_depth   do debug = .Depth; // TODO: this should be an enum in editor_settings
            if visualize_dof_coc do debug = .DOFCoc;
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
            viewPortion = Vector4{1, 1, 0, 0}, // TODO: not used with render target arrays
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

    // draw word tiles
    {
        sgl.defaults();
        sgl.push_pipeline();
        defer sgl.pop_pipeline();
        draw_level();
    }

    // DRAW UI
    simgui.render();

    sg.end_pass();
	sg.commit();
}

toggle_fullscreen :: proc() {
    is_fullscreen = !is_fullscreen;

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

cleanup :: proc() {
    when OSC {
        if osc_enabled {
            stop_osc_thread();
        }
    }

    simgui.shutdown();
    basisu.shutdown();
    sfetch.shutdown();
    sg.shutdown();
    free_all(context.temp_allocator);
    cleanup_logger();
}

event_callback :: proc(event: ^sapp.Event) {
    want_capture_keyboard := simgui.handle_event(event);

    #partial switch event.type {
        case .RESIZED:
            camera_target_resized(&state.camera, cast(f32)sapp.width(), cast(f32)sapp.height());
        case .MOUSE_DOWN:
            //set_capture(sapp.win32_get_hwnd());
            switch event.mouse_button {
                case .LEFT: input_state.left_mouse = true;
                case .RIGHT: input_state.right_mouse = true;
                case .MIDDLE:
                case .INVALID: 
            }
        case .MOUSE_UP:
            //release_capture(sapp.win32_get_hwnd());
            switch event.mouse_button {
                case .LEFT: input_state.left_mouse = false;
                case .RIGHT: input_state.right_mouse = false;
                case .MIDDLE:
                case .INVALID:
            }
        case .MOUSE_MOVE:
            state.mouse.pos = v2(event.mouse_x, event.mouse_y);
    }

	if event.type == .KEY_DOWN && !event.key_repeat {
		using input_state;
        #partial switch event.key_code {
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
            case .G:
                g = true;
                if !want_capture_keyboard do draw_gizmos = !draw_gizmos;
            case .T: t = true;
            case .L: l = true;
            case .P:
                p = true;
            case .NUM_0: num_0 = true;
            case .NUM_1: num_1 = true;
            case .NUM_2:
                num_2 = true;
                if !want_capture_keyboard do toggle_fullscreen();
            case .NUM_3: num_3 = true;
                num_3 = true;
                if !want_capture_keyboard do toggle_multiview();
            case .LEFT_ALT: left_alt = true;
            case .LEFT_CONTROL: left_ctrl = true;
            case .LEFT_SHIFT: left_shift = true;
		}
	}

	if event.type == .KEY_UP {
		using input_state;
        #partial switch event.key_code {
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
            case .P: p = false;
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

handle_args :: proc(fullscreen: ^bool) {
    for arg in os.args {
        switch arg {
            case "--no-dof": state.depth_of_field.enabled = false;
            case "--no-osc": osc_enabled = false;
            case "--2D", "--2d": force_num_views = 1;
            case "--no-model": draw_mesh = false;
            case "--window": fullscreen^ = false;
        }
    }
}

passthrough_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, flags: u64 = 0, location := #caller_location) -> rawptr {
    fmt.printf("%v   \n  size = %v\n  alignment = %v\n  old_memory = %v\n  old_size = %v\n  flags = %v\n  location = %v\n", mode, size, alignment, old_memory, old_size, flags, location);

    original_allocator := cast(^mem.Allocator)allocator_data;
    return original_allocator.procedure(original_allocator.data, mode, size, alignment, old_memory, old_size, flags, location);
}

passthrough_allocator: mem.Allocator;

main :: proc() {
    // WORDS
    load_word_list();
    init_level();
    force_num_views = 1;

    main_thread_logger = log.create_multi_logger(
        log.create_console_logger(),
        log.Logger { imgui_logger_proc, nil, nil }
    );

    state.depth_of_field.enabled = true; // TODO: have a state init function

    fullscreen := true;
    handle_args(&fullscreen);

    // install a stacktrace handler for asserts
    when STACK_TRACES {
        context.assertion_failure_proc = stacktrace.assertion_failure_with_stacktrace_proc;
    }

    sg.set_assert_func(proc "c" (expr, file: cstring, line: i32) {
        fd := os.stderr;
        os.write_string(fd, "sokol_gfx assert failed: '");
        os.write_string(fd, string(expr));
        os.write_string(fd, "' in ");
        os.write_string(fd, string(file));
        os.write_string(fd, ":");
        os.write_string(fd, fmt.aprint(line));
        os.write_string(fd, "\n");
        stacktrace.print_stack_trace(1);
        runtime.debug_trap();
    });


    when LEAK_CHECK {
        // TODO: this won't really work with all the proc "c"s around. I think we need to have a module-level
        // allocator, like the main_thread_logger, and then assign it in setup_context, which is getting
        // called in our proc "c" callbacks.
        original_allocator := context.allocator;
        passthrough_allocator = {
            procedure = passthrough_allocator_proc,
            data = &original_allocator,
        };
        context.allocator = passthrough_allocator;
    }

	os.exit(run_app(fullscreen));
}

is_fullscreen: bool;

main_thread_logger: log.Logger;

cleanup_logger :: proc() {
    multi_logger := main_thread_logger;
    if multi_logger.data != nil {
        data := cast(^log.Multi_Logger_Data)multi_logger.data;
        log.destroy_console_logger(&data.loggers[0]);
        log.destroy_multi_logger(&multi_logger);
    }
}

run_app :: proc(fullscreen: bool) -> int {
    is_fullscreen = fullscreen;

	return sapp.run({
		init_cb      = proc "c" () { setup_context(init_callback); },
		frame_cb     = proc "c" () { setup_context(frame_callback); },
		cleanup_cb   = proc "c" () { setup_context(cleanup); },
		event_cb     = proc "c" (e: ^sapp.Event) { setup_context(event_callback, e); },
		width        = WINDOW_WIDTH,
		height       = WINDOW_HEIGHT,
		window_title = "testbed",
        sample_count = MSAA_SAMPLE_COUNT,
        fullscreen   = is_fullscreen,
        //high_dpi     = true,
	});
}

