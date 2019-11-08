package main;

import sgl "sokol:sokol_gl"

grid :: proc(y: f32, frame_count: u32) {
    num :: 64;
    dist:f32: 4.0;
    z_offset := (dist / 8.0) * f32(frame_count & 7);

    sgl.begin_lines();
    defer sgl.end();

    for i in 0..<num {
        x := f32(i) * dist - f32(num) * dist * 0.5;
        sgl.v3f(x, y, -num * dist);
        sgl.v3f(x, y, 0.0);
    }

    for i in 0..<num {
        z := z_offset + f32(i) * f32(dist) - num * dist;
        sgl.v3f(-num * dist * 0.5, y, z);
        sgl.v3f(num * dist * 0.5, y, z);
    }
}
