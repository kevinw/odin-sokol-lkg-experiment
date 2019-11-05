package main

import sg "sokol:sokol_gfx"
import sgl "sokol:sokol_gl"
import mu "../lib/microui"
using import "core:math/linalg"

Bezier_Curve :: struct {
    p0, p1, p2, p3: Vector2,
};

edit_curve :: proc(curve: ^Bezier_Curve) {

}
