package main

using import "math"
import sapp "sokol:sokol_app"
import "core:fmt"

Camera :: struct {
    is_perspective: bool,

    // orthographic -> size in world units from center of screen to top of screen
    // perspective  -> fov
    using _size_fov: struct #raw_union { size, fov: f32 },

    near_plane: f32,
    far_plane:  f32,

    clear_color: Colorf,

    //current_rendermode: Rendermode,

    position: Vec3,
    rotation: Quat,

    pixel_width, pixel_height, aspect: f32,

    //draw_mode: gpu.Draw_Mode,

    //framebuffer: Framebuffer,
}

camera_target_resized :: proc(camera: ^Camera, pixel_width, pixel_height: f32) {
    camera.pixel_width = cast(f32)pixel_width;
    camera.pixel_height = cast(f32)pixel_height;
    camera.aspect = camera.pixel_width / camera.pixel_height;
}

worldspace_ray :: proc(using camera: ^Camera, screen_pt: Vector2) -> Ray {
    // thanks http://antongerdelan.net/opengl/raycasting.html

    ray_nds := v3(2 * screen_pt.x / pixel_width - 1.0,
                  1 - 2 * screen_pt.y / pixel_height,
                  1);

    ray_clip := v4(ray_nds.x, ray_nds.y, -1.0, 1.0);

    // @Speed
    projection_matrix := construct_projection_matrix(camera);
    view_matrix := construct_view_matrix(camera);

    ray_eye := mul(inverse(projection_matrix), ray_clip);
    ray_eye = v4(ray_eye.x, ray_eye.y, -1.0, 0.0);

    ray_wor := v3(mul(inverse(view_matrix), ray_eye));
    // don't forget to normalise the vector at some point
    ray_wor = norm(ray_wor);
    return Ray {origin=position, direction=ray_wor};
}

construct_view_matrix :: proc(camera: ^Camera) -> Mat4 {
	view_matrix := translate(identity(Mat4), -camera.position);

	rotation := camera.rotation;
    rotation_matrix := quat_to_mat4(inverse(rotation));
    view_matrix = mul(rotation_matrix, view_matrix);
    return view_matrix;
}

construct_projection_matrix :: proc(using camera: ^Camera) -> Mat4 {
    if is_perspective {
        return perspective(to_radians(size), aspect, near_plane, far_plane);
    } else {
        top    : f32 =  1 * size;
        bottom : f32 = -1 * size;
        left   : f32 = -1 * aspect * size;
        right  : f32 =  1 * aspect * size;
        return ortho3d(left, right, bottom, top, camera.near_plane, camera.far_plane);
    }
}

init_camera :: proc(camera: ^Camera, is_perspective: bool, size: f32, pixel_width, pixel_height: int) {
    camera.is_perspective = is_perspective;
    camera.size = size;
    camera.near_plane = 0.01;
    camera.far_plane = 100;
    camera.position = Vec3{};
    camera.rotation = Quat{0, 0, 0, 1};
    camera.clear_color = {1, 0, 1, 1};
    camera.pixel_width = cast(f32)pixel_width;
    camera.pixel_height = cast(f32)pixel_height;
    camera.aspect = camera.pixel_width / camera.pixel_height;
}

delete_camera :: proc(camera: Camera) {
}

orbit :: proc(camera: ^Camera, input_state: Input_State, dt: f32, distance: f32) {
}

do_camera_movement :: proc(camera: ^Camera, input_state: Input_State, dt: f32, normal_speed: f32, fast_speed: f32, slow_speed: f32) {
	speed := normal_speed;

	if input_state.left_shift {
		speed = fast_speed;
	} else if input_state.left_alt {
		speed = slow_speed;
	}

    up      := quaternion_up(camera.rotation);
    forward := quaternion_forward(camera.rotation);
	right   := quaternion_right(camera.rotation);

    down := -up;
    back := -forward;
    left := -right;

	if input_state.e { camera.position += up      * speed * dt; }
	if input_state.q { camera.position += down    * speed * dt; }
	if input_state.w { camera.position += forward * speed * dt; }
	if input_state.s { camera.position += back    * speed * dt; }
	if input_state.a { camera.position += left    * speed * dt; }
	if input_state.d { camera.position += right   * speed * dt; }

    if input_state.osc_move.x > 0 || input_state.osc_move.y > 0 {
        fmt.println(input_state.osc_move);
        OSC_SPEED :: 1;
        camera.position += right * OSC_SPEED * speed * dt * (input_state.osc_move.x - 0.5);
        camera.position += up *    OSC_SPEED * speed * dt * (input_state.osc_move.y - 0.5);
    }

	if input_state.right_mouse {
		SENSITIVITY :: 0.17;

        move_x, move_y: i32 = 0, 0;
        sapp.get_relative_mouse(&move_x, &move_y);
        delta := v2(move_x, -move_y);

		delta *= SENSITIVITY;
		degrees := Vec3{delta.y, -delta.x, 0};
		camera.rotation = rotate_quat_by_degrees(camera.rotation, degrees);
	}
}

rotate_quat_by_degrees :: proc(q: Quat, degrees: Vec3) -> Quat {
	x := axis_angle(Vec3{1, 0, 0}, to_radians(degrees.x));
	y := axis_angle(Vec3{0, 1, 0}, to_radians(degrees.y));
	z := axis_angle(Vec3{0, 0, 1}, to_radians(degrees.z));
	result := mul(y, q);
	result  = mul(result, x);
	result  = mul(result, z);
	return quat_norm(result);
}
