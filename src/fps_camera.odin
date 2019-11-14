package main

using import "math"
import sapp "sokol:sokol_app"

FPS_Camera :: struct {
    position: Vector3,
    angle: Vector2,
    fov: f32,

    up: Vector3,
    right: Vector3,
    forward: Vector3,

    near, far: f32,

    view: Matrix4,
    proj: Matrix4,
}

speed :: 3.0;
mouse_speed :: 0.6;

init :: proc(using Camera: ^FPS_Camera) {
    fov = 75;
    position = v3(0, 1, -2);
    near = 0.1;
    far = 1000.0;
}

Ray :: struct { origin, direction: Vector3 }

screen_to_world_ray :: proc(using cam: ^FPS_Camera, pixel: Vector2) -> Ray {
    viewport_x0:f32= 0; // TODO
    viewport_y0:f32= 0; // TODO
    viewport_width := cast(f32)sapp.width();
    viewport_height := cast(f32)sapp.height();

    x := 2 * (pixel.x - viewport_x0) / viewport_width - 1;
    y := 1 - 2 * (pixel.y - viewport_y0) / viewport_height;

    view_proj := mul(proj, view); // TODO: don't do this more than once a frame

    inv_view_proj:Matrix4 = inverse(view_proj);
    p0:Vector4 = mul(inv_view_proj, Vector4{x, y, -1, 1});
    p1:Vector4 = mul(inv_view_proj, Vector4{x, y, +1, 1});

    return { position, v3(p1) * p0.w - v3(p0) * p1.w };
}

update :: proc(using camera: ^FPS_Camera, dt: f32, input_state: Input_State, aspect: f32) {
    if input_state.right_mouse || input_state.r {
        move_x, move_y: i32 = 0, 0;
        sapp.get_relative_mouse(&move_x, &move_y);
        angle += Vector2{cast(f32)move_x, cast(f32)move_y} * mouse_speed;
    }

    proj = perspective(deg2rad(fov), aspect, near, far);
    view = rotate_matrix(Vector3{angle.y, angle.x, 0});

    right   = v3(view[0][0], view[1][0], view[2][0]);
    up      = v3(view[0][1], view[1][1], view[2][1]);
    forward = v3(view[0][2], view[1][2], view[2][2]);

    {
        if input_state.w || input_state.up    do position += forward * dt * speed;
        if input_state.s || input_state.down  do position -= forward * dt * speed;
        if input_state.d || input_state.right do position -= right   * dt * speed;
        if input_state.a || input_state.left  do position += right   * dt * speed;
        if input_state.e                      do position -= up * dt * speed;
        if input_state.q                      do position += up * dt * speed;
    }

    view = mul(view, translate_matrix4(position));
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

inverse :: proc(m: Matrix4) -> Matrix4 {
	o: Matrix4;

	sf00 := m[2][2] * m[3][3] - m[3][2] * m[2][3];
	sf01 := m[2][1] * m[3][3] - m[3][1] * m[2][3];
	sf02 := m[2][1] * m[3][2] - m[3][1] * m[2][2];
	sf03 := m[2][0] * m[3][3] - m[3][0] * m[2][3];
	sf04 := m[2][0] * m[3][2] - m[3][0] * m[2][2];
	sf05 := m[2][0] * m[3][1] - m[3][0] * m[2][1];
	sf06 := m[1][2] * m[3][3] - m[3][2] * m[1][3];
	sf07 := m[1][1] * m[3][3] - m[3][1] * m[1][3];
	sf08 := m[1][1] * m[3][2] - m[3][1] * m[1][2];
	sf09 := m[1][0] * m[3][3] - m[3][0] * m[1][3];
	sf10 := m[1][0] * m[3][2] - m[3][0] * m[1][2];
	sf11 := m[1][1] * m[3][3] - m[3][1] * m[1][3];
	sf12 := m[1][0] * m[3][1] - m[3][0] * m[1][1];
	sf13 := m[1][2] * m[2][3] - m[2][2] * m[1][3];
	sf14 := m[1][1] * m[2][3] - m[2][1] * m[1][3];
	sf15 := m[1][1] * m[2][2] - m[2][1] * m[1][2];
	sf16 := m[1][0] * m[2][3] - m[2][0] * m[1][3];
	sf17 := m[1][0] * m[2][2] - m[2][0] * m[1][2];
	sf18 := m[1][0] * m[2][1] - m[2][0] * m[1][1];


	o[0][0] = +(m[1][1] * sf00 - m[1][2] * sf01 + m[1][3] * sf02);
	o[0][1] = -(m[0][1] * sf00 - m[0][2] * sf01 + m[0][3] * sf02);
	o[0][2] = +(m[0][1] * sf06 - m[0][2] * sf07 + m[0][3] * sf08);
	o[0][3] = -(m[0][1] * sf13 - m[0][2] * sf14 + m[0][3] * sf15);

	o[1][0] = -(m[1][0] * sf00 - m[1][2] * sf03 + m[1][3] * sf04);
	o[1][1] = +(m[0][0] * sf00 - m[0][2] * sf03 + m[0][3] * sf04);
	o[1][2] = -(m[0][0] * sf06 - m[0][2] * sf09 + m[0][3] * sf10);
	o[1][3] = +(m[0][0] * sf13 - m[0][2] * sf16 + m[0][3] * sf17);

	o[2][0] = +(m[1][0] * sf01 - m[1][1] * sf03 + m[1][3] * sf05);
	o[2][1] = -(m[0][0] * sf01 - m[0][1] * sf03 + m[0][3] * sf05);
	o[2][2] = +(m[0][0] * sf11 - m[0][1] * sf09 + m[0][3] * sf12);
	o[2][3] = -(m[0][0] * sf14 - m[0][1] * sf16 + m[0][3] * sf18);

	o[3][0] = -(m[1][0] * sf02 - m[1][1] * sf04 + m[1][2] * sf05);
	o[3][1] = +(m[0][0] * sf02 - m[0][1] * sf04 + m[0][2] * sf05);
	o[3][2] = -(m[0][0] * sf08 - m[0][1] * sf10 + m[0][2] * sf12);
	o[3][3] = +(m[0][0] * sf15 - m[0][1] * sf17 + m[0][2] * sf18);


	ood := 1.0 / (m[0][0] * o[0][0] +
	              m[0][1] * o[1][0] +
	              m[0][2] * o[2][0] +
	              m[0][3] * o[3][0]);

	o[0][0] *= ood;
	o[0][1] *= ood;
	o[0][2] *= ood;
	o[0][3] *= ood;
	o[1][0] *= ood;
	o[1][1] *= ood;
	o[1][2] *= ood;
	o[1][3] *= ood;
	o[2][0] *= ood;
	o[2][1] *= ood;
	o[2][2] *= ood;
	o[2][3] *= ood;
	o[3][0] *= ood;
	o[3][1] *= ood;
	o[3][2] *= ood;
	o[3][3] *= ood;

	return o;
}



