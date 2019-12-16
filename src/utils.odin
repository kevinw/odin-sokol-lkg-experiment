package main

using import "math"
import "core:mem"

v2 :: inline proc(w, h: $T) -> Vector2 { return Vector2 { cast(f32)w, cast(f32)h }; }

remove_last_extension :: proc(str : string) -> string {
    last_dot := -1;
    for r, i in str {
        if r == '.' do last_dot = i;
    }
    
    return last_dot != -1 ? str[:last_dot] : str;
}


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

Colorf :: struct {
	r: f32 "imgui_range=0:1",
	g: f32 "imgui_range=0:1",
	b: f32 "imgui_range=0:1",
	a: f32 "imgui_range=0:1",
}

Colori :: struct {
	r, g, b, a: u8,
}

color_lerp :: proc(c1, c2: $T, t: f32) -> T where T == Colorf || T == Colori {
	return T {
		r = lerp(c1.r, c2.r, t),
		g = lerp(c1.g, c2.g, t),
		b = lerp(c1.b, c2.b, t),
		a = lerp(c1.a, c2.a, t),
	};
}

COLOR_WHITE  := Colorf{1, 1, 1, 1};
COLOR_RED    := Colorf{1, 0, 0, 1};
COLOR_GREEN  := Colorf{0, 1, 0, 1};
COLOR_BLUE   := Colorf{0, 0, 1, 1};
COLOR_BLACK  := Colorf{0, 0, 0, 1};
COLOR_YELLOW := Colorf{1, 1, 0, 1};

Maybe :: union(T: typeid) {
	T,
}

getval :: inline proc(m: Maybe($T)) -> (T, bool) {
	return m.(T);
}

v3_any :: proc(x: $A, y: $B, z: $C) -> Vector3 { return Vector3 { cast(f32)x, cast(f32)y, cast(f32)z }; }
v4_any :: proc(x: $A, y: $B, z: $C, w: $D) -> Vector4 { return Vector4 { cast(f32)x, cast(f32)y, cast(f32)z, cast(f32)w }; }
v3_empty :: proc() -> Vector3 { return Vector3 {}; }
v4_empty :: proc() -> Vector4 { return Vector4 {}; }
v3_slice :: proc(slice: []f32) -> Vector3 {
    assert(len(slice) >= 3);
    return Vector3 { slice[0], slice[1], slice[2] };
}
v3_from_v4 :: proc(v4: Vector4) -> Vector3 do return { v4.x, v4.y, v4.z };

v3 :: proc { v3_any, v3_empty, v3_slice, v3_from_v4 };
v4 :: proc { v4_any, v4_empty };
sub :: proc(v1, v2: Vector3) -> Vector3 {
    return Vector3 { v1.x - v2.x, v1.y - v2.y, v1.z - v2.z };
}

DEG_TO_RAD :: PI / 180.0;
deg2rad :: inline proc(f: $T) -> T { return f * DEG_TO_RAD; }

