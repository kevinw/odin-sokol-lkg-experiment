package main

import sg "sokol:sokol_gfx"
import sapp "sokol:sokol_app"
import stime "sokol:sokol_time"
import sfetch "sokol:sokol_fetch"
import sgl "sokol:sokol_gl"
import "shared:odin-stb/stbi"
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
MAX_FILE_SIZE :: 1024*1024;

sfetch_buffers: [SFETCH_NUM_CHANNELS][SFETCH_NUM_LANES][MAX_FILE_SIZE]u8;

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

state: struct {
	pass_action: sg.Pass_Action,
	bind:        sg.Bindings,
	pip:         sg.Pipeline,

    mu_pip:      sg.Pipeline,
    mu_atlas_img: sg.Image,

    font_normal_data: [256 * 1024]u8, // TODO: use a smaller buffer and the streaming capability of sokol-fetch

    // mesh
    gltf_path_root: string,
    shaders: struct {
        metallic: sg.Shader,
    },
    scene: struct {
        buffers: [dynamic]sg.Buffer,
        images: [dynamic]sg.Image,
        materials: [dynamic]Metallic_Material,
        meshes: [dynamic]Mesh,
        sub_meshes: [dynamic]Sub_Mesh,
        pipelines: [dynamic]sg.Pipeline,
    },
    pip_cache: [dynamic]Pipeline_Cache_Params,
    point_light: shader_meta.light_params,
    failed: bool,

    creation_params: struct {
        buffers: [dynamic]Buffer_Creation_Params,
        images: [dynamic]Image_Creation_Params,
    },
};

mu_ctx: mu.Context;

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

did_load :: proc() {
    _load_count += 1;
    if _load_count != 2 do return;

    _did_load = true;

    using text;

    size:f32 = 95.0;
    create_text("sdf text", size);
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
            pixel_format = sg.Pixel_Format.R8;
        case 3:
            panic("unimplemented");
        case 4:
            pixel_format = sg.Pixel_Format.RGBA8;
        case:
            panic("unexpected number of channels");
    }

    image_desc := sg.Image_Desc {
        width = width,
        height = height,
        pixel_format = pixel_format,
        min_filter = sg.Filter.LINEAR,
        mag_filter = sg.Filter.LINEAR,
    };

    image_desc.content.subimage[0][0] = {
        ptr = pixel_data,
        size = width * height * channels,
    };

    sg.init_image(text.bind.fs_images[shader_meta.SLOT_u_texture], image_desc);
    
    did_load();

}

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


init_callback :: proc "c" () {
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
        max_commands = 500,
        pipeline_pool_size = 5,
    });

    basisu.setup();

    r_init();
    mu.init(&mu_ctx);
    mu_ctx.text_width = text_width_cb;
    mu_ctx.text_height = text_height_cb;

	stime.setup();

    sfetch.setup({
        num_channels = 1,
        num_lanes = 4,
    });

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

    //
    // MESH SETUP
    //

    // create shaders
    state.shaders.metallic = sg.make_shader(shader_meta.cgltf_metallic_shader_desc()^);
    fmt.println("\n~~~~~~~~~\nmetallic\n", state.shaders.metallic,"\n");

    // create point light
    state.point_light = {
        light_pos = Vector3{10.0, 10.0, 10.0},
        light_range = 100.0,
        light_color = Vector3{1000.0, 1000.0, 1000.0},
        light_intensity = 1.0
    };

    // request the mesh GLTF file
    state.gltf_path_root = "resources/gltf/DamagedHelmet/";
    sfetch.send({
        path = "resources/gltf/DamagedHelmet/DamagedHelmet.gltf",
        callback = proc "c" (response: ^sfetch.Response) {
            if response.dispatched {
                sfetch.bind_buffer(response.handle, sfetch_buffers[response.channel][response.lane][:]);
            } else if response.fetched {
                // file has been loaded, parse as GLTF
                gltf_parse(mem.slice_ptr(cast(^u8)response.buffer_ptr, cast(int)response.fetched_size));
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
            col: [4]f32,
        };

        vertices := [?]Vertex{
            {{+0.5, +0.5, +0.5}, {1.0, 0.0, 0.0, 1.0}},
            {{+0.5, -0.5, +0.5}, {0.0, 1.0, 0.0, 1.0}},
            {{-0.5, -0.5, +0.5}, {0.0, 0.0, 1.0, 1.0}},
            {{-0.5, -0.5, +0.5}, {0.0, 0.0, 1.0, 1.0}},
            {{-0.5, +0.5, +0.5}, {0.0, 0.0, 1.0, 1.0}},
            {{+0.5, +0.5, +0.5}, {1.0, 0.0, 0.0, 1.0}},
        };

        state.bind.vertex_buffers[0] = sg.make_buffer({
            label = "triangle-vertices",
            size = len(vertices)*size_of(vertices[0]),
            content = &vertices[0],
        });
        state.pip = sg.make_pipeline({
            shader = sg.make_shader(shader_meta.vertcolor_shader_desc()^),
            label = "triangle-pipeline",
            primitive_type = .TRIANGLES,
            layout = {
                attrs = {
                    shader_meta.ATTR_vs_position = {format = .FLOAT3},
                    shader_meta.ATTR_vs_color0 = {format = .FLOAT4},
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

position := Vector3 {};
last_ticks: u64 = 0;

bg := [?]f32 { 0.5, 0.7, 1.0 };


window: mu.Container;
test_window :: proc(ctx: ^mu.Context) {
    if window.inited == {} {
        mu.init_window(ctx, &window, {});
        window.rect = mu.rect(40, 40, 300, 450);
    }

    window.rect.w = max(window.rect.w, 240);
    window.rect.h = max(window.rect.h, 300);

    if mu.begin_window(ctx, &window, "micro ui window") {
        defer mu.end_window(ctx);

        @static show_info: i32 = 1;
        if mu.header(ctx, &show_info, "Window Info") {

            row_info := [?]i32 { 54, -1 };
            mu.layout_row(ctx, 2, &row_info[0], 0);

            mu.label(ctx, "Position:");
            mu_label_printf(ctx, "%d, %d", window.rect.x, window.rect.y);
            mu.label(ctx, "Size:");
            mu_label_printf(ctx, "%d, %d", window.rect.w, window.rect.h);
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

	if v.x != 0 do position.x += v.x * cast(f32)elapsed_seconds;
	if v.y != 0 do position.y += v.y * cast(f32)elapsed_seconds;

	mvp := translate_matrix4(position);

    //
    // MICROUI
    //
    {
        // microui definition
        mu.begin(&mu_ctx);
        test_window(&mu_ctx);
        defer mu.end(&mu_ctx);
    }
    {
        // microui rendering
        r_begin(sapp.width(), sapp.height());
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
            }
        }
    }

	//
	// DRAW
	//

    // TODO: write this only when the value changes?
    state.pass_action.colors[0] = {action = .CLEAR, val = {bg[0], bg[1], bg[2], 1}};

    sg.begin_default_pass(state.pass_action, sapp.framebuffer_size());

    {
        sg.apply_pipeline(state.pip);
        sg.apply_bindings(state.bind);

        vs_uniforms := shader_meta.vs_uniforms {
            mvp = mvp,
        };
        global_params_values := shader_meta.global_params {
            time = cast(f32)now_seconds * 3.0
        };
        sg.apply_uniforms(sg.Shader_Stage.FS, shader_meta.SLOT_global_params, &global_params_values, size_of(shader_meta.global_params));
        sg.apply_uniforms(sg.Shader_Stage.VS, shader_meta.SLOT_vs_uniforms, &vs_uniforms, size_of(shader_meta.vs_uniforms));
        sg.draw(0, 6, 1);
    }

    {
        u_matrix := ortho3d(0, WINDOW_WIDTH, 0, WINDOW_HEIGHT, -10.0, 10.0);

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
	err := sapp.run({
		init_cb      = init_callback,
		frame_cb     = frame_callback,
		cleanup_cb   = cleanup,
		event_cb     = event_callback,
		width        = WINDOW_WIDTH,
		height       = WINDOW_HEIGHT,
		window_title = "testbed",
	});
	os.exit(int(err));
}

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

event_callback :: proc "c" (event: ^sapp.Event) {
    switch event.type {
        case .MOUSE_DOWN:
            mu.input_mousedown(&mu_ctx, cast(i32)event.mouse_x, cast(i32)event.mouse_y, 1 << cast(u32)event.mouse_button);
        case .MOUSE_UP:
            mu.input_mouseup(&mu_ctx, cast(i32)event.mouse_x, cast(i32)event.mouse_y, 1 << cast(u32)event.mouse_button);
        case .MOUSE_MOVE:
            mu.input_mousemove(&mu_ctx, cast(i32)event.mouse_x, cast(i32)event.mouse_y);
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
