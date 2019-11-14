package main

using import "math"
import "core:mem"

v2 :: inline proc(w, h: $T) -> Vector2 { return Vector2 { cast(f32)w, cast(f32)h }; }


strlen :: proc(s: ^$T) -> int { // TODO: doesn't this already exist?
    i := 0;
    for {
        val := mem.ptr_offset(s, i);
        if val^ == 0 do break;
        i += 1;
    }
    return i;
}


cstring_ptr_to_slice :: proc(s: ^$T) -> []T { // @Unsafe
    return mem.slice_ptr(s, strlen(s));
}


// COMPAT WITH LINALG
translate_matrix4 :: proc(v: Vec3) -> Mat4 do return translate(identity(Mat4), v);
scale_matrix4 :: mat4_scale;
rotate_matrix4 :: mat4_rotate;

