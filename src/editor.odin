package main

import sgl "sokol:sokol_gl"
using import "math"

@tweak
editor_settings : struct {
    lkg_view_cone:f32,   // = 0.611; // 35deg in radians
    lkg_camera_size:f32, // = 6.0: 
    subview_w: f32,
    num_views:f32,
    fov: f32,
    grid_offset: Vector3,
};


grid :: proc(y: f32, frame_count: u32) {
    using editor_settings;

    sgl.push_matrix();
    defer sgl.pop_matrix();

    sgl.translate(grid_offset.x, grid_offset.y, grid_offset.z);

    dist:f32: 1.0;
    half_dist := dist * 0.5;

    sgl.begin_lines();
    defer sgl.end();

    for i in 0..<num {
        x := f32(i) * dist - f32(num) * half_dist;
        sgl.v3f(x, y, -num * dist);
        sgl.v3f(x, y, 0.0);
    }

    for i in 0..<num {
        z := f32(i) * f32(dist) - num * dist;
        sgl.v3f(-num * half_dist, y, z);
        sgl.v3f(+num * half_dist, y, z);
    }
}

num :: 64;

