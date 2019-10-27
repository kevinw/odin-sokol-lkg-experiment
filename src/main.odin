package main

import sg "sokol:sokol_gfx"
import sapp "sokol:sokol_app"
import stime "sokol:sokol_time"
import sfetch "sokol:sokol_fetch"

import "core:os"
import "core:fmt"
using import "core:math"

import shader_meta "./shader_meta";

state: struct {
	pass_action: sg.Pass_Action,
	bind:        sg.Bindings,
	pip:         sg.Pipeline,

    font_normal_data: [256 * 1024]u8,
    font_normal: i32,
};

font_normal_loaded :: proc "c" (response: ^sfetch.Response) {
    if response.fetched {
        font_normal = fonsAddFontMem(state.fons, "sans", response.buffer_ptr, response.fetched_size, false);
    } else {
        fmt.eprintln("error fetching normal font");
    }
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
        path = "resources/DroidSerif-Regular.ttf",
        callback = font_normal_loaded,
        buffer_ptr = &state.font_normal_data[0],
        buffer_size = size_of(state.font_normal_data),
    });

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

	shader := sg.make_shader(shader_meta.vertcolor_shader_desc()^);

	state.pip = sg.make_pipeline({
		shader = shader,
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

position := Vec3 {};
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

	v := Vec3 {};
	if key_state.d || key_state.right do v.x -= 1.0;
	if key_state.a || key_state.left do v.x += 1.0;
	if key_state.w || key_state.up do v.y -= 1.0;
	if key_state.s || key_state.down do v.y += 1.0;

	if v.x != 0 do position.x += v.x * cast(f32)elapsed_seconds;
	if v.y != 0 do position.y += v.y * cast(f32)elapsed_seconds;

	mvp := mat4_translate(position);

	//
	// DRAW
	//
	sg.begin_default_pass(state.pass_action, sapp.framebuffer_size());
	sg.apply_pipeline(state.pip);
	sg.apply_bindings(state.bind);

	vs_uniforms := shader_meta.vs_uniforms {
		mvp = (cast(^[16]f32)&mvp)^,
	};
	global_params_values := shader_meta.global_params {
		time = cast(f32)now_seconds
	};
	sg.apply_uniforms(sg.Shader_Stage.FS, shader_meta.SLOT_global_params, &global_params_values, size_of(shader_meta.global_params));
	sg.apply_uniforms(sg.Shader_Stage.VS, shader_meta.SLOT_vs_uniforms, &vs_uniforms, size_of(shader_meta.vs_uniforms));
	sg.draw(0, 6, 1);
	sg.end_pass();
	sg.commit();
}

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
		width        = 400,
		height       = 300,
		window_title = "SOKOL Quad",
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
				if .CTRL in event.modifiers {
					sapp.request_quit();
				}
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
