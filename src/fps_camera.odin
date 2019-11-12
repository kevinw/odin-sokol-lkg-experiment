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
mouse_speed :: 0.6;

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

    proj = perspective(deg2rad(fov), aspect, near_clip, far_clip);
    view = rotate_matrix(Vector3{angle.y, angle.x, 0});

    right   = v3(view[0][0], view[1][0], view[2][0]);
    up      = v3(view[0][1], view[1][1], view[1][2]);
    forward = v3(view[0][2], view[1][2], view[2][2]);

    view = mul(view, translate_matrix4(position));

    //forward = normalize(v3(cos(angle.y) * sin(angle.x), sin(angle.y), cos(angle.y) * cos(angle.x)));
    //right = normalize(v3(sin(angle.x - PI/2.0), 0, cos(angle.x - PI/2.0)));
    //up = normalize(cross(right, forward));

    {
        if input_state.w || input_state.up    do position += forward * dt * speed;
        if input_state.s || input_state.down  do position -= forward * dt * speed;
        if input_state.d || input_state.right do position -= right   * dt * speed;
        if input_state.a || input_state.left  do position += right   * dt * speed;
        if input_state.e                      do position -= up * dt * speed;
        if input_state.q                      do position += up * dt * speed;
    }

    //view = look_at(position, normalize(position + forward), normalize(up)); 
}

rotate_matrix :: proc(rotation: Vector3) -> Matrix4 {
    cosX := cos(deg2rad(rotation.x));
    cosY := cos(deg2rad(rotation.y));
    cosZ := cos(deg2rad(rotation.z));

    sinX := sin(deg2rad(rotation.x));
    sinY := sin(deg2rad(rotation.y));
    sinZ := sin(deg2rad(rotation.z));

    m := identity(Matrix4);

    m[0][0] = cosY * cosZ;
    m[0][1] = (sinX * sinY * cosZ) + (cosX * sinZ);
    m[0][2] = -(cosX * sinY * cosZ) + (sinX * sinZ);

    m[1][0] = -(cosY * sinZ);
    m[1][1] = -(sinX * sinY * sinZ) + (cosX * cosZ);
    m[1][2] = (cosX * sinY * sinZ) + (sinX * cosZ);

    m[2][0] = sinY;
    m[2][1] = -(sinX * cosY);
    m[2][2] = (cosX * cosY);

    return m;
}
