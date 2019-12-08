package main

import sgl "sokol:sokol_gl"
using import "math"

Editor_Settings :: struct {
    dof_distance, dof_range: f32,
    visualize_depth: bool,
    visualize_color: bool,
    visualize_dof: bool,
    num_views:f32,
    lkg_camera_size:f32, // = 6.0: 
    subview_w: f32,
    lkg_view_cone:f32,   /* = 0.611; // 35deg in radians */
    fov: f32,
    grid_offset: Vector3,
};

@tweak
editor_settings: Editor_Settings;

editor_settings_defaults :: proc() -> Editor_Settings {
    using e := Editor_Settings {};

    lkg_camera_size = 0.80;
    subview_w = 700;
    dof_distance = 2.0;
    dof_range = 0.5;

    lkg_view_cone = 2.51;
    num_views = 45;
    fov = 25.7;
    visualize_dof = true; // @nocheckin

    return e;
}

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

