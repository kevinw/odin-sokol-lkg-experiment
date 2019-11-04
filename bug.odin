package main

import "core:fmt"
using import "core:math/linalg"

Camera :: struct {
    eye_pos: Vector3,
    view_proj: Matrix4,
};

state: struct {
    camera: Camera,
};

main :: proc() {
    delta := Vector3 {3, 4, 5};

    state.camera.eye_pos = delta;
    target := Vector3 {};

    one, two: Matrix4;
    one = look_at(state.camera.eye_pos, target, Vector3 { 0, 1, 0 });

    // IF YOU COMMENT OUT THIS PRINTLN, THE ASSERTION DOES NOT TRIGGER
    fmt.println(target);

    two = look_at(state.camera.eye_pos, target, Vector3 { 0, 1, 0 });


    assert(one == two, fmt.tprintf("\none: %#v\ntwo: %#v\n", one, two));
}
