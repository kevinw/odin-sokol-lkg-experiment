package main

Input_State :: struct {
	right, left, up, down: bool,
	w, a, s, d, q, e, r, t, g, l, p: bool,
    num_0, num_1, num_2, num_3: bool,
    left_mouse, right_mouse: bool,
    left_ctrl, left_alt, left_shift: bool,
    osc_move: Vector2,
    osc_rotate: Vector3,
}

input_state := Input_State {};
_last_input_state := Input_State {};

input_2d_pressed :: proc(delta: ^[2]i16) {
    using input_state;
    last := &_last_input_state;

    if (!last.d && d) || (!last.right && right) do delta.x += 1;
    if (!last.a && a) || (!last.left && left) do delta.x -= 1;
    if (!last.w && w) || (!last.up && up) do delta.y -= 1;
    if (!last.s && s) || (!last.down && down) do delta.y += 1;
}

