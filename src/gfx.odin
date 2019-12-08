package main

import "core:intrinsics"
import sg "sokol:sokol_gfx"

apply_uniforms_ptr :: proc(stage: sg.Shader_Stage, slot: int, uniforms: ^$T) {
    sg.apply_uniforms(stage, slot, uniforms, size_of(T));
}

apply_uniforms_struct :: proc(stage: sg.Shader_Stage, slot: int, uniforms: $T)
    where intrinsics.type_is_struct(T)
{
    _uniforms := uniforms;
    sg.apply_uniforms(stage, slot, &_uniforms, size_of(T));
}

apply_uniforms :: proc { apply_uniforms_ptr, apply_uniforms_struct };
