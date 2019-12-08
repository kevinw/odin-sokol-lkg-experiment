package main

import sg "sokol:sokol_gfx"

apply_uniforms :: proc(stage: sg.Shader_Stage, slot: int, uniforms: ^$T) {
    sg.apply_uniforms(stage, slot, uniforms, size_of(T));
}
