package main

import sgl "sokol:sokol_gl"
using import "core:math/linalg"

Editor_State :: struct {
    grid_offset: Vector3,
};

@tweak editor_state := Editor_State {
    {0, 0, num * 0.5},
};

grid :: proc(y: f32, frame_count: u32) {
    sgl.push_matrix();
    defer sgl.pop_matrix();

    using editor_state;
    sgl.translate(grid_offset.x, grid_offset.y, grid_offset.z);

    dist:f32: 1.0;

    sgl.begin_lines();
    defer sgl.end();

    for i in 0..<num {
        x := f32(i) * dist - f32(num) * dist * 0.5;
        sgl.v3f(x, y, -num * dist);
        sgl.v3f(x, y, 0.0);
    }

    for i in 0..<num {
        z := f32(i) * f32(dist) - num * dist;
        sgl.v3f(-num * dist * 0.5, y, z);
        sgl.v3f(num * dist * 0.5, y, z);
    }
}

num :: 64;

