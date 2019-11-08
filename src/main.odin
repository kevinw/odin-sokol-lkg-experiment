package main

import sg "sokol:sokol_gfx"
import sapp "sokol:sokol_app"
import stime "sokol:sokol_time"
import sfetch "sokol:sokol_fetch"
import sgl "sokol:sokol_gl"
import mu "../lib/microui"
import "../lib/basisu"

import "core:os"
import "core:strings"
import "core:mem"
import "core:fmt"
import "core:math/bits"
using import "core:math"
using import "core:math/linalg"

import shader_meta "./shader_meta";

WINDOW_WIDTH :: 1280;
WINDOW_HEIGHT :: 720;

SFETCH_NUM_CHANNELS :: 1;
SFETCH_NUM_LANES :: 4;
MAX_FILE_SIZE :: 10*1024*1024;
MSAA_SAMPLE_COUNT :: 4;

sfetch_buffers: [SFETCH_NUM_CHANNELS][SFETCH_NUM_LANES][MAX_FILE_SIZE]u8;

Key_State :: struct {
	right: bool,
	left: bool,
	up: bool,
	down: bool,

	w: bool,
	a: bool,
	s: bool,
	d: bool,
}

key_state := Key_State {};

Mouse_State :: struct {
    pos: Vector2,
}


Camera :: struct {
    eye_pos: Vector3,
    view_proj: Matrix4,
    fov: f32,
};

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

state: struct {
	pass_action: sg.Pass_Action,
	bind:        sg.Bindings,
	pip:         sg.Pipeline,

    mu_pip:      sg.Pipeline,
    mu_atlas_img: sg.Image,

    font_normal_data: [256 * 1024]u8, // TODO: use a smaller buffer and the streaming capability of sokol-fetch

    // mesh
    shaders: struct {
        metallic: sg.Shader,
    },
    root_transform: Matrix4,
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
    fps_camera: FPS_Camera,
    placeholders: struct { white, normal, black: sg.Image },
    pip_cache: [dynamic]Pipeline_Cache_Params,
    point_light: shader_meta.light_params,
    failed: bool,

    creation_params: struct {
        buffers: [dynamic]Buffer_Creation_Params,
        images: [dynamic]Image_Creation_Params,
    },

    auto_rotate: bool,
    mouse: Mouse_State,


};

position := Vector3 {};
last_ticks: u64 = 0;

do_print :i32 = 0;
do_tween:= false;

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
text_width_cb :: proc "c" (font: mu.Font, _text: cstring, _byte_len: i32) -> i32 {
    text := _text;
    byte_len := _byte_len;

    if byte_len == -1 {
        byte_len = cast(i32)len(text);
    }

    text_slice:[]u8 = mem.slice_ptr(cast(^u8)&text, cast(int)byte_len);

    return r_get_text_width(text_slice);
}

text_height_cb :: proc "c" (font: mu.Font) -> i32 {
    return r_get_text_height();
}

v3_any :: proc(x: $A, y: $B, z: $C) -> Vector3 { return Vector3 { cast(f32)x, cast(f32)y, cast(f32)z }; }
v3_empty :: proc() -> Vector3 { return Vector3 {}; }
v3 :: proc { v3_any, v3_empty };
sub :: proc(v1, v2: Vector3) -> Vector3 {
    return Vector3 { v1.x - v2.x, v1.y - v2.y, v1.z - v2.z };
}

DEG_TO_RAD :: PI / 180.0;
deg2rad :: inline proc(f: $T) -> T { return f * DEG_TO_RAD; }

delta := v3(-1.92, -0.07, 1.52);

init_callback :: proc "c" () {
    state.camera.eye_pos = delta;
    state.camera.fov = 60;

    text.vertex_elems = make([dynamic]f32);
    text.tex_elems = make([dynamic]f32);

	sg.setup({
		mtl_device                   = sapp.metal_get_device(),
		mtl_renderpass_descriptor_cb = sapp.metal_get_renderpass_descriptor,
		mtl_drawable_cb              = sapp.metal_get_drawable,
		d3d11_device                 = sapp.d3d11_get_device(),
		d3d11_device_context         = sapp.d3d11_get_device_context(),
		d3d11_render_target_view_cb  = sapp.d3d11_get_render_target_view,
		d3d11_depth_stencil_view_cb  = sapp.d3d11_get_depth_stencil_view,
	});

    sgl.setup({
        max_vertices = 5000,
        max_commands = 50,
        pipeline_pool_size = 5,
    });

    basisu.setup();

    init(&state.fps_camera);

    r_init();
    mu.init(&mu_ctx);
    mu_ctx.text_width = text_width_cb;
    mu_ctx.text_height = text_height_cb;

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
            {{+C, +C, +C}, {1.0, 0.0}},
            {{+C, -C, +C}, {0.0, 1.0}},
            {{-C, -C, +C}, {0.0, 0.0}},
            {{-C, -C, +C}, {0.0, 0.0}},
            {{-C, +C, +C}, {0.0, 0.0}},
            {{+C, +C, +C}, {1.0, 0.0}},
        };

        state.bind.vertex_buffers[0] = sg.make_buffer({
            label = "shadertoy-vertices",
            size = len(vertices)*size_of(vertices[0]),
            content = &vertices[0],
        });
        state.pip = sg.make_pipeline({
            shader = sg.make_shader(shader_meta.shadertoy_shader_desc()^),
            label = "shadertoy-pipeline",
            primitive_type = .TRIANGLES,
            layout = {
                attrs = {
                    shader_meta.ATTR_vs_st_position = {format = .FLOAT3},
                    shader_meta.ATTR_vs_st_uv = {format = .FLOAT2},
                },
            },
        });

    }

    //
    // make text rendering pipeline
    //
    {
        UV_0 :: 0;
        UV_1 :: 32767;
        assert(UV_1 == bits.I16_MAX);

        vertices := [?]Text_Vertex {
            {{+0.5, +0.5}, {1.0, 1.0}},
            {{+0.5, -0.5}, {1.0, 0.0}},
            {{-0.5, -0.5}, {0.0, 0.0}},
            {{-0.5, -0.5}, {0.0, 0.0}},
            {{-0.5, +0.5}, {0.0, 1.0}},
            {{+0.5, +0.5}, {1.0, 1.0}},
        };

        text.bind.vertex_buffers[0] = sg.make_buffer({
            size = len(vertices) * size_of(vertices[0]),
            content = &vertices[0],
            label = "text-vertices",
        });

        text.bind.fs_images[shader_meta.SLOT_u_texture] = sg.alloc_image();
        text.pipeline = sg.make_pipeline({
            label = "sdf-text-pipeline",
            shader = sg.make_shader(shader_meta.sdf_text_shader_desc()^),
            primitive_type = .TRIANGLES,
            blend = {
                enabled = true,
                src_factor_rgb = sg.Blend_Factor.SRC_ALPHA,
                dst_factor_rgb = sg.Blend_Factor.ONE_MINUS_SRC_ALPHA,
            },
            layout = {
                attrs = {
                    shader_meta.ATTR_vs_a_pos = {format = .FLOAT2},
                    shader_meta.ATTR_vs_a_texcoord = {format = .FLOAT2},
                },
            },
        });
        text.pass_action.colors[0] = {action = .LOAD, val = {1.0, 0.0, 1.0, 1.0}};
    }
}

test_window :: proc(ctx: ^mu.Context) {
    if window.inited == {} {
        mu.init_window(ctx, &window, {});
        window.rect = mu.rect(40, 40, 300, 450);
    }

    window.rect.w = max(window.rect.w, 240);
    window.rect.h = max(window.rect.h, 300);

    if mu.begin_window(ctx, &window, "") {
        defer mu.end_window(ctx);

        mu.layout_begin_column(ctx);
        mu_layout_row(ctx, 1, {100,}, 100);
        mu_anim_curve(ctx, &test_curve);
        mu.layout_end_column(ctx);

        @static show_info: i32 = 1;
        if mu.header(ctx, &show_info, "debug") {
            mu_layout_row(ctx, 2,{80, -1}, 0);
            mu.label(ctx, "ms per frame:"); mu_label_printf(ctx, "%f", fps_counter.ms_per_frame);
            mu.label(ctx, "num elements:"); mu_label_printf(ctx, "%d", per_frame_stats.num_elements);

            mu.label(ctx, "camera eye pos:");

            mu.layout_begin_column(ctx);
            mu_layout_row(ctx, 2, { 20, -1 }, 0);
            mu_vector3(ctx, &state.camera.eye_pos, -6, 6);
            mu.layout_end_column(ctx);

            mu_layout_row(ctx, 2, { 40, -1 }, 0);
            mu.label(ctx, "fov:"); mu.slider(ctx, &state.camera.fov, 1, 200);

            mu.label(ctx, "print"); mu.checkbox(ctx, &do_print, "");
            mu.label(ctx, "tween"); mu_checkbox(ctx, &do_tween, "");
            mu.label(ctx, "rotate"); mu_checkbox(ctx, &state.auto_rotate, "");

            for row_index in 0..<4 {
                row := &state.camera.view_proj[row_index];
                mu_layout_row(ctx, 1, { 300, -1 }, 0);
                mu.label(ctx, strings.clone_to_cstring(
                    fmt.tprintf("%f  %f  %f  %f", row[0], row[1], row[2], row[3]),
                    context.temp_allocator));
            }

        }

        /* background color sliders */
        @static show_sliders:i32 = 1;
        if (mu.header(ctx, &show_sliders, "Background Color")) {
            mu_layout_row(ctx, 2, { -78, -1 }, 74);
            /* sliders */
            mu.layout_begin_column(ctx);
            mu_layout_row(ctx, 2, { 46, -1 }, 0);
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
    free_all(context.temp_allocator);

	//
	// TIME
	//

    frame_count += 1;
	current_ticks := stime.now();
	now_seconds := stime.sec(current_ticks);
	elapsed_ticks: u64 = ---;
	if last_ticks == 0 {
		elapsed_ticks = 0;
	} else {
		elapsed_ticks = stime.diff(current_ticks, last_ticks);
	}
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

    sfetch.dowork();

    if !_did_load do return;

	v := Vector3 {};
    {
        using key_state;
        if d || right do v.x -= 1.0;
        if a || left do v.x += 1.0;
        if w || up do v.y -= 1.0;
        if s || down do v.y += 1.0;
    }

    dt := cast(f32)elapsed_seconds;

	if v.x != 0 do position.x += v.x * dt;
	if v.y != 0 do position.y += v.y * dt;

    //
    // update scene
    //
    state.root_transform = state.auto_rotate ? rotate_matrix4(Vector3{0, 1, 0}, cast(f32)now_seconds) : identity(Matrix4);

    // every other second, scrub through curve, pausing at the end for the other second
    if do_tween {
        time := cast(f32)(now_seconds * .3);
        int_part, r := math.modf(time);
        if cast(int)int_part % 2 == 0 do r = 1.0 - r;

        vv := evaluate(&test_curve, r);
        state.root_transform = scale_matrix4(state.root_transform, Vector3{ vv.x, vv.y, r });
    }

    // update camera
    aspect:f32 = cast(f32)sapp.width() / cast(f32)sapp.height();
    {
        using state.camera;
        {
            using key_state;
            /*
            if w do eye_pos.z += dt;
            if a do eye_pos.x -= dt;
            if s do eye_pos.z -= dt;
            if d do eye_pos.x += dt;
            */
        }

        proj := perspective(deg2rad(fov), aspect, 0.01, 100.0);
        view := look_at(eye_pos, Vector3{0, 0, 0}, Vector3 { 0, 1, 0 });
        view_proj = mul(proj, view);
    }

    update(&state.fps_camera, dt, key_state);

    state.camera.view_proj = mul(state.fps_camera.proj, state.fps_camera.view);
    state.camera.eye_pos = state.fps_camera.position;


    //
    // MICROUI
    //
    { // definition
        mu.begin(&mu_ctx);
        defer mu.end(&mu_ctx);
        test_window(&mu_ctx);
    }
    mu_render(sapp.width(), sapp.height()); // note; this just pushes commands to a queue. r_draw below actually does the draw calls

    per_frame_stats = {};

	//
	// DRAW
	//

    // TODO: write this only when the value changes?
    state.pass_action.colors[0] = {action = .CLEAR, val = {bg[0], bg[1], bg[2], 1}};

    sg.begin_default_pass(state.pass_action, sapp.framebuffer_size());

    draw_quad := true;

    // DRAW MOVABLE QUAD
    if draw_quad {
        sg.apply_pipeline(state.pip);
        sg.apply_bindings(state.bind);
        global_params_values := shader_meta.st_fs_uniforms {
            iTime = cast(f32)now_seconds * 3.0,
            iResolution = Vector3 { cast(f32)sapp.width()/2.0, cast(f32)sapp.height()/2.0, 1.0 },
            iTimeDelta = dt,
            iFrame = cast(i32)frame_count,
            iFrameRate = cast(f32)(1.0 / fps_counter.ms_per_frame),
            iSampleRate = 44100,
        };
        // shadertoy uniforms
        sg.apply_uniforms(.FS, shader_meta.SLOT_st_fs_uniforms, &global_params_values, size_of(shader_meta.st_fs_uniforms));
        sg.draw(0, 6, 1);
    }

    // DRAW GRID LINES
    {
        sgl.defaults();
        sgl.matrix_mode_projection();
        sgl.matrix_mode_modelview();
        sgl.load_matrix(&state.camera.view_proj[0][0]);
        grid_frame_count :u32 = 0;
        sgl.translate(sin(f32(grid_frame_count) * 0.02) * 16.0, sin(f32(grid_frame_count) * 0.01) * 4.0, 0.0);
        sgl.c3f(1.0, 0.0, 1.0);

        grid(-7.0, grid_frame_count);
        grid(+7.0, grid_frame_count);
    }

    // DRAW MESH
    {
        using state.scene;
        for _, node_index in nodes {
            node := &nodes[node_index];
            vs_params := shader_meta.vs_params {
                model = mul(state.root_transform, node.transform),
                view_proj = state.camera.view_proj,
                eye_pos = state.camera.eye_pos,
            };
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
                sg.apply_uniforms(.VS, shader_meta.SLOT_vs_params, &vs_params, size_of(vs_params));
                sg.apply_uniforms(.FS, shader_meta.SLOT_light_params, &state.point_light, size_of(state.point_light));
                //if mat.is_metallic {

                    {
                        base_color_tex := state.placeholders.white;
                        metallic_roughness_tex := state.placeholders.white;
                        normal_tex := state.placeholders.normal;
                        occlusion_tex := state.placeholders.white;
                        emissive_tex := state.placeholders.black;

                        if prim.material != -1 {
                            metallic := &materials[prim.material];

                            sg.apply_uniforms(sg.Shader_Stage.FS,
                                shader_meta.SLOT_metallic_params,
                                &metallic.fs_params,
                                size_of(shader_meta.metallic_params));

                            using metallic.images;
                            if base_color != -1 && images[base_color].id != 0 do base_color_tex = images[base_color];
                            if metallic_roughness != -1 && images[metallic_roughness].id != 0 do metallic_roughness_tex = images[metallic_roughness];
                            if normal != -1 && images[normal].id != 0 do normal_tex = images[normal];
                            if occlusion != -1 && images[occlusion].id != 0 do occlusion_tex = images[occlusion];
                            if emissive != -1 && images[emissive].id != 0 do emissive_tex = images[emissive];
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
                sg.draw(cast(int)prim.base_element, cast(int)prim.num_elements, 1);
            }
        }
    }

    // DRAW SDF TEXT
    {
        u_matrix := ortho3d(0, cast(f32)sapp.width(), 0, cast(f32)sapp.height(), -10.0, 10.0);

        vs_uniforms := shader_meta.sdf_vs_uniforms {
            u_matrix = u_matrix,
            u_texsize = text.texture_size,
        };

        fs_uniforms := shader_meta.sdf_fs_uniforms {
            u_color = Vector4{1, 1, 1, 1},
            u_debug = 0.0,
            u_gamma = 0.02,
            u_buffer = cast(f32)(192.0 / 256.0),
        };

        sg.apply_pipeline(text.pipeline);
        sg.apply_bindings(text.bind);

        sg.apply_uniforms(sg.Shader_Stage.VS, shader_meta.SLOT_sdf_vs_uniforms, &vs_uniforms, size_of(shader_meta.sdf_vs_uniforms));
        sg.apply_uniforms(sg.Shader_Stage.FS, shader_meta.SLOT_sdf_fs_uniforms, &fs_uniforms, size_of(shader_meta.sdf_fs_uniforms));

        num_verts := len(text.vertex_elems) / 2;
        sg.draw(0, num_verts, 1);
    }

    // DRAW UI
    r_draw();

    sg.end_pass();
	sg.commit();
}

cleanup :: proc "c" () {
    basisu.shutdown();
    sfetch.shutdown();
    sg.shutdown();
}

main :: proc() {
    //fmt.println("--------odin sizes:");
    //cgltf.print_sizes();
    //fmt.println("--------c sizes:");
    //cgltf.print_struct_sizes();

    run_app();
}

run_app :: proc() {
	err := sapp.run({
		init_cb      = init_callback,
		frame_cb     = frame_callback,
		cleanup_cb   = cleanup,
		event_cb     = event_callback,
		width        = WINDOW_WIDTH,
		height       = WINDOW_HEIGHT,
		window_title = "testbed",
        sample_count = MSAA_SAMPLE_COUNT,
	});
	os.exit(int(err));
}

event_callback :: proc "c" (event: ^sapp.Event) {
    switch event.type {
        case .MOUSE_DOWN:
            mu.input_mousedown(&mu_ctx, cast(i32)event.mouse_x, cast(i32)event.mouse_y, 1 << cast(u32)event.mouse_button);
        case .MOUSE_UP:
            mu.input_mouseup(&mu_ctx, cast(i32)event.mouse_x, cast(i32)event.mouse_y, 1 << cast(u32)event.mouse_button);
        case .MOUSE_MOVE:
            mu.input_mousemove(&mu_ctx, cast(i32)event.mouse_x, cast(i32)event.mouse_y);
            state.mouse.pos = v2(event.mouse_x, event.mouse_y);
    }

	if event.type == .KEY_DOWN && !event.key_repeat {
		using key_state;
		switch event.key_code {
			case .ESCAPE:
				sapp.request_quit();
			case .Q:
				//if .CTRL in event.modifiers {
					sapp.request_quit();
				//}
			case .RIGHT: right = true;
			case .LEFT: left = true;
			case .UP: up = true;
			case .DOWN: down = true;
			case .W: w = true;
			case .S: s = true;
			case .A: a = true;
			case .D: d = true;
		}
	}

	if event.type == .KEY_UP {
		using key_state;
		switch event.key_code {
			case .RIGHT: right = false;
			case .LEFT: left = false;
			case .UP: up = false;
			case .DOWN: down = false;
			case .W: w = false;
			case .S: s = false;
			case .A: a = false;
			case .D: d = false;
		}
	}
}
