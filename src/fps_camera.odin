package main

using import "core:math/linalg"
using import "core:math"
import sapp "sokol:sokol_app"

FPS_Camera :: struct {
    position: Vector3,
    angle: Vector2,
    fov: f32,

    up: Vector3,
    right: Vector3,
    forward: Vector3,

    view: Matrix4,
    proj: Matrix4,
}

speed :: 3.0;
mouse_speed :: 0.006;

near_clip :: 0.1;
far_clip :: 1000.0;

init :: proc(using Camera: ^FPS_Camera) {
    fov = 75;
    position = v3(0, 1, -2);
}

update :: proc(using camera: ^FPS_Camera, dt: f32, input_state: Input_State, aspect: f32) {
    if input_state.right_mouse {
        move_x, move_y: i32 = 0, 0;
        sapp.get_relative_mouse(&move_x, &move_y);
        angle += v2(move_x, move_y) * mouse_speed;
    }

    forward = normalize(v3(cos(angle.y) * sin(angle.x), sin(angle.y), cos(angle.y) * cos(angle.x)));
    right = normalize(v3(sin(angle.x - PI/2.0), 0, cos(angle.x - PI/2.0)));
    up = normalize(cross(right, forward));

    {
        if input_state.w || input_state.up    do position += forward * dt * speed;
        if input_state.s || input_state.down  do position -= forward * dt * speed;
        if input_state.d || input_state.right do position -= right   * dt * speed;
        if input_state.a || input_state.left  do position += right   * dt * speed;
        if input_state.e                      do position -= up * dt * speed;
        if input_state.q                      do position += up * dt * speed;
    }

    proj = perspective(deg2rad(fov), aspect, near_clip, far_clip);
    view = look_at(position, position + forward, up); 
}
