
SDF_Text_Vert :: struct #packed {
    pos: Vector3 `position`, 
    uv: Vector2 `uv`,
}

could generate at compile time: 

layout = {
    attrs = {
        shader_meta.ATTR_vs_a_pos = {format = SDF_Text_Vertex_Format},
        shader_meta.ATTR_vs_a_texcoord = {format = .FLOAT2},
    },
},
