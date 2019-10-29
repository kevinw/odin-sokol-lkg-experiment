package main

using import "core:math/linalg"

v2 :: inline proc(w, h: $T) -> Vector2 { return Vector2 { cast(f32)w, cast(f32)h }; }

