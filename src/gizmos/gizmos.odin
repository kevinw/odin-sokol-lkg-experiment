package gizmos;

using import "core:fmt"
using import "core:math"
using import "core:math/linalg"

@private WHITE   := Vector4 {1, 1, 1, 1};
@private RED     := Vector4 {1, 0, 0, 1};
@private V3_ZERO := Vector3 {0, 0, 0};
@private translate_x_arrow, translate_y_arrow:Mesh_Component;

Interact :: enum {
    None,
    Translate_X, Translate_Y, Translate_Z,
    Translate_YZ, Translate_ZX, Translate_XY,
    Translate_XYZ,
    Rotate_X, Rotate_Y, Rotate_Z,
    Scale_X, Scale_Y, Scale_Z,
    Scale_XYZ,
    Last,
};

Interaction_State :: struct {
    active: bool,                  // Flag to indicate if the gizmo is being actively manipulated
    hover: bool,                   // Flag to indicate if the gizmo is being hovered
    original_position: Vector3,    // Original position of an object being manipulated with a gizmo
    original_orientation: Vector4, // Original orientation of an object being manipulated with a gizmo
    original_scale: Vector3,       // Original scale of an object being manipulated with a gizmo
    click_offset: Vector3,         // Offset from position of grabbed object to coordinates of clicked point
    interaction_mode: Interact,    // Currently active component
};

Geo_Vertex :: struct {
    position: Vector3,
    normal: Vector3,
    color: Vector4,
};

@private v_vector4 :: inline proc(position: Vector4) -> Geo_Vertex {
    geo_vertex: Geo_Vertex;
    geo_vertex.position = {position.x, position.y, position.z};
    return geo_vertex;
}

@private v_vector3 :: inline proc(position: Vector3) -> Geo_Vertex {
    geo_vertex: Geo_Vertex;
    geo_vertex.position = position;
    return geo_vertex;
}

v :: proc { v_vector3, v_vector4 };

Mesh :: struct {
    vertices: [dynamic]Geo_Vertex,
    triangles: [dynamic][3]u32,
};

@private clear_mesh :: inline proc(mesh: ^Mesh) {
    clear(&mesh.vertices);
    clear(&mesh.triangles);
}

Mesh_Component :: struct {
    mesh: Mesh,
    base_color: Vector4,
    highlight_color: Vector4,
};

Renderable :: struct {
    mesh: Mesh,
    color: Vector4,
}

Context :: struct {
    draw_list: [dynamic]Renderable,
    render: proc(mesh: ^Mesh),
};

mesh_components: [cast(int)Interact.Last]Mesh_Component;

m3x2 :: inline proc(a, b: Vector3) -> Matrix3x2 {
    return Matrix3x2 {
        { a[0], b[0] },
        { a[1], b[1] },
        { a[2], b[3] }
    };
    //return Matrix2x3 { cast([3]f32)(&a[0])^, cast([3]f32)(&b[0])^, };
}

make_box_geometry :: proc(min_bounds, max_bounds: Vector3) -> Mesh {
    a, b := min_bounds, max_bounds;
    mesh : Mesh;
    mesh.vertices = {
        { { a.x, a.y, a.z }, { -1,0,0 }, WHITE }, { { a.x, a.y, b.z }, { -1,0,0 }, WHITE },
        { { a.x, b.y, b.z }, { -1,0,0 }, WHITE }, { { a.x, b.y, a.z }, { -1,0,0 }, WHITE },
        { { b.x, a.y, a.z }, { +1,0,0 }, WHITE }, { { b.x, b.y, a.z }, { +1,0,0 }, WHITE },
        { { b.x, b.y, b.z }, { +1,0,0 }, WHITE }, { { b.x, a.y, b.z }, { +1,0,0 }, WHITE },
        { { a.x, a.y, a.z }, { 0,-1,0 }, WHITE }, { { b.x, a.y, a.z }, { 0,-1,0 }, WHITE },
        { { b.x, a.y, b.z }, { 0,-1,0 }, WHITE }, { { a.x, a.y, b.z }, { 0,-1,0 }, WHITE },
        { { a.x, b.y, a.z }, { 0,+1,0 }, WHITE }, { { a.x, b.y, b.z }, { 0,+1,0 }, WHITE },
        { { b.x, b.y, b.z }, { 0,+1,0 }, WHITE }, { { b.x, b.y, a.z }, { 0,+1,0 }, WHITE },
        { { a.x, a.y, a.z }, { 0,0,-1 }, WHITE }, { { a.x, b.y, a.z }, { 0,0,-1 }, WHITE },
        { { b.x, b.y, a.z }, { 0,0,-1 }, WHITE }, { { b.x, a.y, a.z }, { 0,0,-1 }, WHITE },
        { { a.x, a.y, b.z }, { 0,0,+1 }, WHITE }, { { b.x, a.y, b.z }, { 0,0,+1 }, WHITE },
        { { b.x, b.y, b.z }, { 0,0,+1 }, WHITE }, { { a.x, b.y, b.z }, { 0,0,+1 }, WHITE },
    };

    mesh.triangles = {
        { 0,1,2 },   { 0,2,3 },   { 4,5,6 },
        { 4,6,7 },   { 8,9,10 },  { 8,10,11 },
        { 12,13,14 },{ 12,14,15 },{ 16,17,18 },
        { 16,18,19 },{ 20,21,22 },{ 20,22,23 }
    };
    return mesh;
}

make_lathed_geometry :: proc(
    verbose: bool,
    _axis, arm1, arm2: Vector3,
    slices: int, points: []Vector2, eps:f32 = 0) -> Mesh
{
    axis := _axis;

    mesh: Mesh;
    for i in 0..cast(u32)slices {
        angle:f32 = (f32(cast(int)i % slices) * TAU / cast(f32)slices) + (TAU/8);
        rot := arm1 * cos(angle) + arm2 * sin(angle);

        mat : Matrix2x3;
        mat[0] = (^[3]f32)(&axis)^;
        mat[1] = (^[3]f32)(&rot)^;

        for p in points {
            append(&mesh.vertices, v(Vector3{
                mat[0].x * p.x + mat[1].x * p.y,
                mat[0].y * p.x + mat[1].y * p.y,
                mat[0].z * p.x + mat[1].z * p.y,
            }));
        }

        if i > 0 {
            num_points := u32(len(points));

            for j in 1..<num_points {
                i0, i1, i2, i3:u32 = (i - 1) * num_points + (j - 1),
                                     (i - 0) * num_points + (j - 1),
                                     (i - 0) * num_points + (j - 0),
                                     (i - 1) * num_points + (j - 0);

                append(&mesh.triangles, [3]u32 { i0, i1, i2 });
                append(&mesh.triangles, [3]u32 { i0, i2, i3 });
            }
        }
    }
    compute_normals(&mesh);
    return mesh;
}

compute_normals :: proc(mesh: ^Mesh) {
    // TODO
}

update :: proc(using ctx: ^Context) {
    clear(&draw_list);

    // TODO

    { m := &mesh_components[Interact.Translate_ZX]; append(&draw_list, Renderable { m.mesh, m.base_color }); }
    { m := &mesh_components[Interact.Translate_XY]; append(&draw_list, Renderable { m.mesh, m.base_color }); }
    { m := &mesh_components[Interact.Translate_YZ]; append(&draw_list, Renderable { m.mesh, m.base_color }); }

    { m := &mesh_components[Interact.Translate_X]; append(&draw_list, Renderable { m.mesh, m.base_color }); }
    { m := &mesh_components[Interact.Translate_Y]; append(&draw_list, Renderable { m.mesh, m.base_color }); }
    { m := &mesh_components[Interact.Translate_Z]; append(&draw_list, Renderable { m.mesh, m.base_color }); }

}

_super_mesh: Mesh;
draw :: proc(using ctx: ^Context) {
    if ctx.render == nil do return;

    //r: ^Mesh = &_super_mesh;
    //clear_mesh(r);

    r:Mesh;

    for _, i in draw_list {
        m := &draw_list[i];

        num_verts := u32(len(r.vertices));
        for _, vert_index in m.mesh.vertices {
            v := m.mesh.vertices[vert_index];
            v.color = m.color;
            append(&r.vertices, v);
        }
        for tri in m.mesh.triangles {
            append(&r.triangles, tri + num_verts);
        }
    }
    ctx.render(&r);

}

init :: proc(ctx: ^Context) {
    arrow_points := [?]Vector2 { { 0.25, 0 }, { 0.25, 0.05 },{ 1, 0.05 },{ 1, 0.10 },{ 1.2, 0 } };
    mace_points  := [?]Vector2 { { 0.25, 0 }, { 0.25, 0.05 },{ 1, 0.05 },{ 1, 0.1 },{ 1.25, 0.1 }, { 1.25, 0 } };
    ring_points  := [?]Vector2 { { +0.025, 1 },{ -0.025, 1 },{ -0.025, 1 },{ -0.025, 1.1 },{ -0.025, 1.1 },{ +0.025, 1.1 },{ +0.025, 1.1 },{ +0.025, 1 } };

    m := &mesh_components;

    using Interact;
    m[Translate_X]   = { make_lathed_geometry(true, { 1,0,0 },{ 0,1,0 },{ 0,0,1 }, 16, arrow_points[:]), { 1,0.5,0.5, 1 }, { 1,0,0, 1 } };
    m[Translate_Y]   = { make_lathed_geometry(false, { 0,1,0 },{ 0,0,1 },{ 1,0,0 }, 16, arrow_points[:]), { 0.5,1,0.5, 1 }, { 0,1,0, 1 } };
    m[Translate_Z]   = { make_lathed_geometry(false, { 0,0,1 },{ 1,0,0 },{ 0,1,0 }, 16, arrow_points[:]), { 0.5,0.5,1, 1 }, { 0,0,1, 1 } };

    m[Translate_YZ]  = { make_box_geometry({ -0.01,0.25,0.25 },{ 0.01,0.75,0.75 }), { 0.5,1,1, 0.5 }, { 0,1,1, 0.6 } };
    m[Translate_ZX]  = { make_box_geometry({ 0.25,-0.01,0.25 },{ 0.75,0.01,0.75 }), { 1,0.5,1, 0.5 }, { 1,0,1, 0.6 } };
    m[Translate_XY]  = { make_box_geometry({ 0.25,0.25,-0.01 },{ 0.75,0.75,0.01 }), { 1,1,0.5, 0.5 }, { 1,1,0, 0.6 } };
    m[Translate_XYZ] = { make_box_geometry({ -0.05,-0.05,-0.05 },{ 0.05,0.05,0.05 }),{ 0.9, 0.9, 0.9, 0.25 },{ 1,1,1, 0.35 } };

    m[Rotate_X]      = { make_lathed_geometry(false, { 1,0,0 },{ 0,1,0 },{ 0,0,1 }, 32, ring_points[:], 0.003), { 1, 0.5, 0.5, 1 }, { 1, 0, 0, 1 } };
    m[Rotate_Y]      = { make_lathed_geometry(false, { 0,1,0 },{ 0,0,1 },{ 1,0,0 }, 32, ring_points[:], -0.003), { 0.5,1,0.5, 1 }, { 0,1,0, 1 } };
    m[Rotate_Z]      = { make_lathed_geometry(false, { 0,0,1 },{ 1,0,0 },{ 0,1,0 }, 32, ring_points[:]), { 0.5,0.5,1, 1 }, { 0,0,1, 1 } };
    m[Scale_X]       = { make_lathed_geometry(false, { 1,0,0 },{ 0,1,0 },{ 0,0,1 }, 16, mace_points[:]),{ 1,0.5,0.5, 1 },{ 1,0,0, 1 } };
    m[Scale_Y]       = { make_lathed_geometry(false, { 0,1,0 },{ 0,0,1 },{ 1,0,0 }, 16, mace_points[:]),{ 0.5,1,0.5, 1 },{ 0,1,0, 1 } };
    m[Scale_Z]       = { make_lathed_geometry(false, { 0,0,1 },{ 1,0,0 },{ 0,1,0 }, 16, mace_points[:]),{ 0.5,0.5,1, 1 },{ 0,0,1, 1 } };
}

