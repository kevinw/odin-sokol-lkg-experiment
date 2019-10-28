package main

import sg "sokol:sokol_gfx"
import sapp "sokol:sokol_app"
import stime "sokol:sokol_time"
import sfetch "sokol:sokol_fetch"
import "shared:odin-stb/stbi"

import "core:os"
import "core:mem"
import "core:fmt"
import "core:math/bits"
using import "core:math"
using import "core:math/linalg"

import shader_meta "./shader_meta";

state: struct {
	pass_action: sg.Pass_Action,
	bind:        sg.Bindings,
	pip:         sg.Pipeline,

    font_normal_data: [256 * 1024]u8,
};

text: struct {
    pass_action: sg.Pass_Action,
    bind: sg.Bindings,
    pipeline: sg.Pipeline,

    texture_size: Vector2,
    json_data: [256 * 1024]u8,
    metrics: SDF_Text_Metrics,
};

v2 :: inline proc(w, h: $T) -> Vector2 {
    return Vector2 { cast(f32)w, cast(f32)h };
}


_load_count := 0;
did_load :: proc() {
    _load_count += 1;
    if _load_count == 2 {
        fmt.println("loaded everything!");
    }
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
    fmt.printf("loaded image %dx%d with %d channels\n", width, height, channels);

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

    text.texture_size = v2(width, height);

    sg.init_image(text.bind.fs_images[shader_meta.SLOT_u_texture], image_desc);
    
    did_load();

}

init_callback :: proc "c" () {
	sg.setup({
		mtl_device                   = sapp.metal_get_device(),
		mtl_renderpass_descriptor_cb = sapp.metal_get_renderpass_descriptor,
		mtl_drawable_cb              = sapp.metal_get_drawable,
		d3d11_device                 = sapp.d3d11_get_device(),
		d3d11_device_context         = sapp.d3d11_get_device_context(),
		d3d11_render_target_view_cb  = sapp.d3d11_get_render_target_view,
		d3d11_depth_stencil_view_cb  = sapp.d3d11_get_depth_stencil_view,
	});

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
            size = len(vertices)*size_of(vertices[0]),
            content = &vertices[0],
            label = "triangle-vertices",
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

        state.pass_action.colors[0] = {action = .CLEAR, val = {0.5, 0.7, 1.0, 1}};
    }

    //
    // make text rendering pipeline
    //

    {
        Vertex :: struct #packed {
            pos: [2]f32,
            uv: [2]f32,
        };

        UV_0 :: 0;
        UV_1 :: 32767;
        assert(UV_1 == bits.I16_MAX);

        vertices := [?]Vertex {
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
            shader = sg.make_shader(shader_meta.sdf_text_shader_desc()^),
            label = "sdf-text-pipeline",
            primitive_type = .TRIANGLES,
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

frame_callback :: proc "c" () {
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
	// DRAW
	//

    if draw_quad {
        sg.begin_default_pass(state.pass_action, sapp.framebuffer_size());
        defer sg.end_pass();

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

    if draw_text {
        sg.begin_default_pass(text.pass_action, sapp.framebuffer_size());
        defer sg.end_pass();

        vs_uniforms := shader_meta.sdf_vs_uniforms {
            u_matrix = identity(Matrix4),
            u_texsize = Vector2{1,1}, // TODO
        };

        fs_uniforms := shader_meta.sdf_fs_uniforms {
            u_color = Vector4{1, 0, 0, 1},
            u_debug = 1.0,
            u_gamma = 0.0, // TODO
            u_buffer = 0.0, // TODO
        };

        sg.apply_pipeline(text.pipeline);
        sg.apply_bindings(text.bind);

        sg.apply_uniforms(sg.Shader_Stage.VS, shader_meta.SLOT_sdf_vs_uniforms, &vs_uniforms, size_of(shader_meta.sdf_vs_uniforms));
        sg.apply_uniforms(sg.Shader_Stage.FS, shader_meta.SLOT_sdf_fs_uniforms, &fs_uniforms, size_of(shader_meta.sdf_fs_uniforms));

        sg.draw(0, 6, 1);
    }

	sg.commit();
}

@(private) draw_quad := true;
@(private) draw_text := true;

cleanup :: proc "c" () {
    sfetch.shutdown();
    sg.shutdown();
}

main :: proc() {
	err := sapp.run({
		init_cb      = init_callback,
		frame_cb     = frame_callback,
		cleanup_cb   = cleanup,
		event_cb     = event_callback,
		width        = 1280,
		height       = 720,
		window_title = "game",
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
