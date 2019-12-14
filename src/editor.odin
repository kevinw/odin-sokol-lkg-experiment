package main

import sgl "../lib/odin-sokol/src/sokol_gl"
using import "math"

Editor_Settings :: struct {
    sdftext: struct {
        gamma: f32,
        buf: f32,

        num_layers: f32,
        buf_falloff: f32,
        z_thickness: f32,
        z_start: f32,

        pos: Vector3,
    },
    subview_w: f32,
    num_views:f32,
    lkg_camera_size:f32, // = 6.0: 
    lkg_view_cone:f32,   /* = 0.611; // 35deg in radians */
    dof: struct {
        distance, range, bokeh_radius: f32,
    },
    visualize_depth: bool,
    visualize_dof_coc: bool,
    fov: f32,
    grid_offset: Vector3,
    ui_mousewheel_scroll_speed: f32, // = 5.0
};

@tweak
editor_settings: Editor_Settings;

editor_settings_defaults :: proc() -> Editor_Settings {
    using e := Editor_Settings {};

    {
        using sdftext;
        gamma = 0.12;
        buf_falloff = 0.9;
        buf = 0.75; // cast(f32)(192.0 / 256.0);
        num_layers = 10;
        z_thickness = 0.15;
        pos = v3(-1.2, -0.81, -3.3);
    }

    lkg_camera_size = 0.80;
    subview_w = 700;
    {
        using dof;
        distance = 1.9;
        range = 0.9;
        bokeh_radius = 4;
    }
    lkg_view_cone = 2.51;
    num_views = 45;
    fov = 25.7;

    ui_mousewheel_scroll_speed = -16;


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

