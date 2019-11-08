package main

using import "core:math/linalg"
using import "core:math"
import sapp "sokol:sokol_app"

FPS_Camera :: struct {
    position: Vector3,
    angle: Vector2,
    fov: f32,

    view: Matrix4,
    proj: Matrix4,
}

speed :: 3.0;
mouse_speed :: 0.005;

last_mouse:Vector2;
first := true;

near_clip :: 0.1;
far_clip :: 1000.0;

init :: proc(using Camera: ^FPS_Camera) {
    fov = 60;
}

update :: proc(using camera: ^FPS_Camera, dt: f32, key_state: Key_State) {
    if first {
        first = false;
    } else {
        delta := (last_mouse - state.mouse.pos) * mouse_speed;
        angle += delta;

        // Spherical to Cartesian
        direction := v3(
            cos(angle.y) * sin(angle.x), 
            sin(angle.y),
            cos(angle.y) * cos(angle.x));
        
        right_v := v3(
            sin(angle.x - PI/2.0), 
            0,
            cos(angle.x - PI/2.0));
        
        up_v := cross(right_v, direction);

        {
            using key_state;
            if w || up do    position += direction * dt * speed;
            if s || down do  position -= direction * dt * speed;
            if d || right do position += right_v   * dt * speed;
            if a || left do  position -= right_v   * dt * speed;
        }

        aspect := cast(f32)sapp.width() / cast(f32)sapp.height();

        proj = perspective(deg2rad(fov), aspect, near_clip, far_clip);
        view = look_at(position, normalize(position + direction), up_v); 
    }

    last_mouse = state.mouse.pos;
}
/*

quaternion_from_euler_vector :: proc(euler: Vector3) -> Quaternion {
    return quaternion_from_euler_angles(euler.x, euler.y, euler.z);
}

quaternion_from_euler_angles :: proc(yaw, pitch, roll: f32) -> Quaternion {
    cy := cos(yaw * 0.5);
    sy := sin(yaw * 0.5);
    cp := cos(pitch * 0.5);
    sp := sin(pitch * 0.5);
    cr := cos(roll * 0.5);
    sr := sin(roll * 0.5);

    return quaternion(
        cy * cp * sr - sy * sp * cr,
        sy * cp * sr + cy * sp * cr,
        sy * cp * cr - cy * sp * sr,
        cy * cp * cr + sy * sp * sr);
}

quaternion_from_euler :: proc {
    quaternion_from_euler_vector,
    quaternion_from_euler_angles
};

*/
