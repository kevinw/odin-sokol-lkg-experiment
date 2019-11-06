package main

import sg "sokol:sokol_gfx"
import sapp "sokol:sokol_app"
import sgl "sokol:sokol_gl"
import mu "../lib/microui"
using import "core:math/linalg"
import "core:fmt"

bezier_interp :: inline proc(t: f32, start, control_1, control_2, end: Vector2) -> Vector2 {
    omt := 1.0 - t;
    omt2 := omt * omt;
    omt3 := omt2 * omt;
    t2 := t * t;
    t3 := t2 * t;

	return start * omt3 + control_1 * omt2 * t * 3.0 + control_2 * omt * t2 * 3.0 + end * t3;
}

evaluate :: inline proc(using curve: ^Bezier_Curve, t: f32) -> Vector2 {
    return bezier_interp(t, p0, p1, p2, p3);
}

Bezier_Curve :: struct {
    p0, p1, p2, p3: Vector2,
};

_base := Vector2 {};
_curve : Bezier_Curve;

mu_anim_curve :: proc(ctx: ^mu.Context, curve: ^Bezier_Curve) -> i32 {
    //id := mu.get_id(ctx, &curve, size_of(curve));
    rect := mu.layout_next(ctx);

    _curve = curve^;

    cb:rawptr = cast(rawptr)proc(rect: mu.Rect) {
        r_end(); // @Cleanup: is r_end/r_begin really necessary here?
        w, h := sapp.width(), sapp.height();
        defer r_begin(w, h);

        sgl.defaults();
        sgl.viewport(0, 0, cast(i32)w, cast(i32)h, true);
        sgl.begin_lines();
        defer sgl.end();

        sgl.push_matrix();
        defer sgl.pop_matrix();
        sgl.matrix_mode_projection();
        sgl.ortho(0.0, cast(f32)w, cast(f32)h, 0.0, -1.0, +1.0);
        sgl.matrix_mode_modelview();
        sgl.load_identity();
        sgl.translate(cast(f32)rect.x, cast(f32)rect.y, 0);

        _base = v2(rect.x, rect.y);
        line :: proc(x0: $A, y0: $B, x1: $C, y1: $D) {
            sgl.v2f(_base.x + cast(f32)x0, _base.y + cast(f32)y0);
            sgl.v2f(_base.x + cast(f32)x1, _base.y + cast(f32)y1);
        }


        N :: 100;
        for i in 0..N {
            t0 := cast(f32)i / cast(f32)N;
            p0 := evaluate(&_curve, t0);

            t1 := cast(f32)(i + 1) / cast(f32)N;
            p1 := evaluate(&_curve, t1);

            line(p0.x * cast(f32)rect.w, p0.y * cast(f32)rect.h,
                p1.x * cast(f32)rect.w, p1.y * cast(f32)rect.h);
        }

        sgl.c3f(1.0, 1.0, 1.0);
        line(0, 0, rect.w, rect.h);

        assert(sgl.error() == .NO_ERROR, fmt.tprint("got error", sgl.error()));
    };

    mu.draw_callback(ctx, rect, cb);
    return 0;
}

