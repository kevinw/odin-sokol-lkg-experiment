package gizmos;

using import "core:fmt"
using import "../math"

@private INF:f32: 99999999999999;

@private V3_ONE  := Vector3 {1, 1, 1};
@private WHITE   := Vector4 {1, 1, 1, 1};
@private RED     := Vector4 {1, 0, 0, 1};
@private GREEN   := Vec4 { 0, 1, 0, 1 };
@private BLUE    := Vec4 { 0, 0, 1, 1 };
@private V3_ZERO := Vector3 {0, 0, 0};
@private translate_x_arrow, translate_y_arrow:Mesh_Component;

Ray :: struct { origin, direction: Vector3 }

Context :: struct {
    draw_list: [dynamic]Renderable,
    render: proc(mesh: ^Mesh),
    mode: Transform_Mode,
    gizmos: map[u32]Interaction_State,
    local_toggle: bool,
    has_clicked, has_released: bool, // left mouse button
    active_state, last_state: Application_State,
};

Transform_Mode :: enum { Translate, Rotate, Scale };

Transform :: struct {
    position: Vector3,
    orientation: Vector4,
    scale: Vector3,
}

transform_coord :: proc(transform: Matrix4, coord: Vector3) -> Vector3 {
    r := mul(transform, v4(coord, 1));
    return v3(r) / r.w;
}

transform_ray :: proc(using p: Transform, r: Ray) -> Ray do return { transform_point(p, r.origin), transform_vector(p, r.direction) };
detransform_ray :: proc(using p: Transform, r: Ray) -> Ray do return { detransform_point(p, r.origin), detransform_vector(p, r.direction) };
detransform_scale_ray:: proc(scale: f32, r: ^Ray) { r.origin /= scale; r.direction /= scale; }
transform_scale_ray :: proc(scale: f32, r: ^Ray) { r.origin *= scale; r.direction *= scale; }

transform :: proc { transform_ray, transform_scale_ray };
detransform :: proc { detransform_ray, detransform_scale_ray };

transform_vector_transform :: proc(using t: Transform, vec: Vector3) -> Vector3 do return qrot(orientation, vec * scale);
transform_point :: proc(using t: Transform, p: Vector3) -> Vector3 do return position + transform_vector(t, p);
detransform_point :: proc(using t: Transform, p: Vector3) -> Vector3 do return detransform_vector(t, p - position);
detransform_vector :: proc(using t: Transform, vec: Vector3) -> Vector3 do return qrot(qinv(orientation), vec) / scale;

transform_vector_matrix :: proc(transform_matrix: Matrix4, vector: Vector3) -> Vector3 do return v3(mul(transform_matrix, v4(vector, 0)));

transform_vector :: proc { transform_vector_transform, transform_vector_matrix };

length2 :: inline proc(a: Vector4) -> f32 do return dot(a, a);
qconj :: inline proc(q: Vector4) -> Vector4 do return {-q.x,-q.y,-q.z,q.w};
qinv :: inline proc(q: Vector4) -> Vector4 do return qconj(q)/length2(q);
qxdir :: inline proc(q: Vector4) -> Vector3 do return {q.w*q.w+q.x*q.x-q.y*q.y-q.z*q.z, (q.x*q.y+q.z*q.w)*2, (q.z*q.x-q.y*q.w)*2};
qydir :: inline proc(q: Vector4) -> Vector3 do return {(q.x*q.y-q.z*q.w)*2, q.w*q.w-q.x*q.x+q.y*q.y-q.z*q.z, (q.y*q.z+q.x*q.w)*2};
qzdir :: inline proc(q: Vector4) -> Vector3 do return {(q.z*q.x+q.y*q.w)*2, (q.y*q.z-q.x*q.w)*2, q.w*q.w-q.x*q.x-q.y*q.y+q.z*q.z};
qrot :: inline proc(q: Vector4, v: Vector3) -> Vector3 do return qxdir(q)*v.x + qydir(q)*v.y + qzdir(q)*v.z;
qmul :: inline proc(a, b: Vector4) -> Vector4 do return {a.x*b.w+a.w*b.x+a.y*b.z-a.z*b.y, a.y*b.w+a.w*b.y+a.z*b.x-a.x*b.z, a.z*b.w+a.w*b.z+a.x*b.y-a.y*b.x, a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z};

v4 :: inline proc(v: Vector3, w: f32) -> Vector4 do return Vector4 { v.x, v.y, v.z, w };
v3_scalar :: inline proc(scalar: f32) -> Vector3 do return Vector3 { scalar, scalar, scalar };
v3_v4 :: inline proc(v: Vector4) -> Vector3 do return Vector3 { v.x, v.y, v.z };
v3 :: proc { v3_scalar, v3_v4 };

matrix :: proc(using t: Transform) -> Matrix4 {
    return {
        auto_cast v4(qxdir(orientation) * scale.x, 0),
        auto_cast v4(qydir(orientation) * scale.y, 0),
        auto_cast v4(qzdir(orientation) * scale.z, 0),
        auto_cast v4(position, 1)
    };
}

flush_to_zero :: proc(v: ^Vector3) {
    EPS :: 0.02;
    inline for i in 0..len(v) {
        if abs(v[i]) < EPS do v[i] = 0;
    }
}

Camera_Parameters :: struct {
    yfov, near_clip, far_clip: f32,
    position: Vector3,
    orientation: Vector4,
};

Application_State :: struct {
    mouse_left, hotkey_translate, hotkey_rotate, hotkey_scale, hotkey_local, hotkey_ctrl: bool,
    screenspace_scale, snap_translation, snap_scale, snap_rotation: f32,
    viewport_size: Vector2,
    ray_origin, ray_direction: Vector3,
    cam: Camera_Parameters,
};

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

clone :: proc(m: ^Mesh) -> Mesh {
    new_mesh := Mesh {
        vertices = make(type_of(m.vertices), len(m.vertices)),
        triangles = make(type_of(m.triangles), len(m.triangles)),
    };

    copy(new_mesh.vertices[:], m.vertices[:]);
    copy(new_mesh.triangles[:], m.triangles[:]);

    return new_mesh;
}

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

mesh_components: [cast(int)Interact.Last]Mesh_Component;

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

make_lathed_geometry :: proc(_axis, arm1, arm2: Vector3, slices: int, points: []Vector2, eps:f32 = 0) -> Mesh {
    axis := _axis;

    mesh: Mesh;
    for i in 0..cast(u32)slices {
        angle:f32 = (f32(cast(int)i % slices) * TAU / cast(f32)slices) + (TAU/8);
        rot := arm1 * cos(angle) + arm2 * sin(angle);

        mat : [2][3]f32;
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

update :: proc(using ctx: ^Context, state: Application_State) {
    active_state = state;
    local_toggle = (!last_state.hotkey_local && active_state.hotkey_local && active_state.hotkey_ctrl) ? !local_toggle : local_toggle;
    has_clicked = !last_state.mouse_left && active_state.mouse_left;
    has_released = last_state.mouse_left && !active_state.mouse_left;
    clear(&draw_list);
}

min_vec :: proc (a, b: Vec3) -> Vec3 do return {min(a.x, b.x), min(a.y, b.y), min(a.z, b.z)};
max_vec :: proc (a, b: Vec3) -> Vec3 do return {max(a.x, b.x), max(a.y, b.y), max(a.z, b.z)};

_super_mesh: Mesh;
draw :: proc(using ctx: ^Context) {
    if ctx.render == nil do return;

    //r:Mesh;
    r: ^Mesh = &_super_mesh;
    clear_mesh(r);

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
    ctx.render(r);

    last_state = active_state;
}

@private _create_geo :: proc() {
    @static did_create:bool;
    if did_create do return;
    did_create = true;

    arrow_points := [?]Vector2 { { 0.25, 0 }, { 0.25, 0.05 },{ 1, 0.05 },{ 1, 0.10 },{ 1.2, 0 } };
    mace_points  := [?]Vector2 { { 0.25, 0 }, { 0.25, 0.05 },{ 1, 0.05 },{ 1, 0.1 },{ 1.25, 0.1 }, { 1.25, 0 } };
    ring_points  := [?]Vector2 { { +0.025, 1 },{ -0.025, 1 },{ -0.025, 1 },{ -0.025, 1.1 },{ -0.025, 1.1 },{ +0.025, 1.1 },{ +0.025, 1.1 },{ +0.025, 1 } };

    m := &mesh_components;

    using Interact;
    m[Translate_X]   = { make_lathed_geometry({ 1,0,0 },{ 0,1,0 },{ 0,0,1 }, 16, arrow_points[:]), { 1,0.5,0.5, 1 }, RED };
    m[Translate_Y]   = { make_lathed_geometry({ 0,1,0 },{ 0,0,1 },{ 1,0,0 }, 16, arrow_points[:]), { 0.5,1,0.5, 1 }, GREEN };
    m[Translate_Z]   = { make_lathed_geometry({ 0,0,1 },{ 1,0,0 },{ 0,1,0 }, 16, arrow_points[:]), { 0.5,0.5,1, 1 }, BLUE };

    m[Translate_YZ]  = { make_box_geometry({ -0.01,0.25,0.25 },{ 0.01,0.75,0.75 }), { 0.5,1,1, 0.5 }, { 0,1,1, 0.6 } };
    m[Translate_ZX]  = { make_box_geometry({ 0.25,-0.01,0.25 },{ 0.75,0.01,0.75 }), { 1,0.5,1, 0.5 }, { 1,0,1, 0.6 } };
    m[Translate_XY]  = { make_box_geometry({ 0.25,0.25,-0.01 },{ 0.75,0.75,0.01 }), { 1,1,0.5, 0.5 }, { 1,1,0, 0.6 } };
    m[Translate_XYZ] = { make_box_geometry({ -0.05,-0.05,-0.05 },{ 0.05,0.05,0.05 }),{ 0.9, 0.9, 0.9, 0.25 },{ 1,1,1, 0.35 } };

    m[Rotate_X]      = { make_lathed_geometry({ 1,0,0 },{ 0,1,0 },{ 0,0,1 }, 32, ring_points[:], 0.003), { 1, 0.5, 0.5, 1 }, RED };
    m[Rotate_Y]      = { make_lathed_geometry({ 0,1,0 },{ 0,0,1 },{ 1,0,0 }, 32, ring_points[:], -0.003), { 0.5,1,0.5, 1 }, GREEN };
    m[Rotate_Z]      = { make_lathed_geometry({ 0,0,1 },{ 1,0,0 },{ 0,1,0 }, 32, ring_points[:]), { 0.5,0.5,1, 1 }, BLUE };
    m[Scale_X]       = { make_lathed_geometry({ 1,0,0 },{ 0,1,0 },{ 0,0,1 }, 16, mace_points[:]),{ 1,0.5,0.5, 1 }, RED };
    m[Scale_Y]       = { make_lathed_geometry({ 0,1,0 },{ 0,0,1 },{ 1,0,0 }, 16, mace_points[:]),{ 0.5,1,0.5, 1 }, GREEN };
    m[Scale_Z]       = { make_lathed_geometry({ 0,0,1 },{ 1,0,0 },{ 0,1,0 }, 16, mace_points[:]),{ 0.5,0.5,1, 1 } ,BLUE };
}

init :: proc(using ctx: ^Context) {
    _create_geo();
    local_toggle = true;
}

hash_fnv1a :: proc(str: string) -> u32 {
    fnv1aBase32:u32: 0x811C9DC5;
    fnv1aPrime32:u32: 0x01000193;

    result:u32 = fnv1aBase32;
    for c in str {
        result ~= cast(u32)c;
        result *= fnv1aPrime32;
    }

    return result;
}

xform :: proc(using ctx: ^Context, name: string, t: ^Transform) -> bool {
    activated := false;

    if active_state.hotkey_ctrl {
        if !last_state.hotkey_translate && active_state.hotkey_translate do mode = .Translate;
        else if !last_state.hotkey_rotate && active_state.hotkey_rotate do mode = .Rotate;
        else if !last_state.hotkey_scale && active_state.hotkey_scale do mode = .Scale;
    }

    switch mode {
        case .Translate: position_gizmo(ctx, name, t.orientation, &t.position);
        case .Rotate: orientation_gizmo(ctx, name, t.position, &t.orientation);
        case .Scale: scale_gizmo(ctx, name, t.orientation, t.position, &t.scale);
    }

    s := ctx.gizmos[hash_fnv1a(name)];
    activated |= s.hover || s.active;

    return activated;
}

orientation_gizmo :: proc(using ctx: ^Context, name: string, center: Vector3, orientation: ^Vector4)
{
    assert(length2(orientation^) > f32(1e-6));

    p := Transform { center, local_toggle ? orientation^ : Vector4 {0, 0, 0, 1}, Vector3{1,1,1}}; // Orientation is local by default
    draw_scale := active_state.screenspace_scale > 0 ? scale_screenspace(ctx, p.position, active_state.screenspace_scale) : 1;
    id := hash_fnv1a(name);

    // interaction_mode will only change on clicked
    gizmo := gizmos[id];
    defer gizmos[id] = gizmo;

    if has_clicked do gizmo.interaction_mode = .None;

    {
        updated_state := Interact.None;

        ray := detransform(p, Ray{ active_state.ray_origin, active_state.ray_direction });
        detransform(draw_scale, &ray);
        best_t := INF;
        t:f32;

        if intersect(ctx, ray, .Rotate_X, &t, best_t) { updated_state = .Rotate_X; best_t = t; }
        if intersect(ctx, ray, .Rotate_Y, &t, best_t) { updated_state = .Rotate_Y; best_t = t; }
        if intersect(ctx, ray, .Rotate_Z, &t, best_t) { updated_state = .Rotate_Z; best_t = t; }

        if has_clicked {
            gizmo.interaction_mode = updated_state;
            if gizmo.interaction_mode != .None {
                transform(draw_scale, &ray);
                gizmo.original_position = center;
                gizmo.original_orientation = orientation^;
                gizmo.click_offset = transform_point(p, ray.origin + ray.direction * t);
                gizmo.active = true;
            } else {
                gizmo.active = false;
            }
        }
    }

    activeAxis: Vector3;
    if gizmo.active {
        starting_orientation := local_toggle ? gizmo.original_orientation : Vector4{0, 0, 0, 1};
        switch gizmo.interaction_mode {
            case .Rotate_X: axis_rotation_dragger(ctx, &gizmo, { 1, 0, 0 }, center, starting_orientation, &p.orientation); activeAxis = { 1, 0, 0 };
            case .Rotate_Y: axis_rotation_dragger(ctx, &gizmo, { 0, 1, 0 }, center, starting_orientation, &p.orientation); activeAxis = { 0, 1, 0 };
            case .Rotate_Z: axis_rotation_dragger(ctx, &gizmo, { 0, 0, 1 }, center, starting_orientation, &p.orientation); activeAxis = { 0, 0, 1 };
        }
    }

    if has_released {
        gizmo.interaction_mode = .None;
        gizmo.active = false;
    }

    model_matrix := matrix(p);
    scaleMatrix := mat4_scale(identity(Mat4), v3(draw_scale));
    model_matrix = mul(model_matrix, scaleMatrix);

    one := [?]Interact { gizmo.interaction_mode };
    all := [?]Interact { .Rotate_X, .Rotate_Y, .Rotate_Z };

    draw_interactions: []Interact = local_toggle && gizmo.interaction_mode != .None ? one[:] : all[:];

    for c in draw_interactions {
        r := Renderable {
            mesh = clone(&mesh_components[c].mesh), // @Leak
            color = c == gizmo.interaction_mode ? mesh_components[c].base_color : mesh_components[c].highlight_color
        };

        for _, index in r.mesh.vertices {
            v := &r.mesh.vertices[index];
            v.position = transform_coord(model_matrix, v.position); // transform local coordinates into worldspace
            v.normal = transform_vector(model_matrix, v.normal);
        }

        append(&draw_list, r);
    }

    // For non-local transformations, we only present one rotation ring 
    // and draw an arrow from the center of the gizmo to indicate the degree of rotation
    if local_toggle == false && gizmo.interaction_mode != .None {
        // Create orthonormal basis for drawing the arrow
        a := qrot(p.orientation, gizmo.click_offset - gizmo.original_position);

        zDir := norm(activeAxis);
        xDir := norm(cross(a, zDir));
        yDir := cross(zDir, xDir);

        // Ad-hoc geometry
        arrow_points := [?]Vector2 { { 0.0, 0. },{ 0.0, 0.05 },{ 0.8, 0.05 },{ 0.9, 0.10 },{ 1.0, 0 } };
        geo := make_lathed_geometry(yDir, xDir, zDir, 32, arrow_points[:]);

        r := Renderable {
            mesh = geo,
            color = Vector4{1, 1, 1, 1},
        };

        for _, index in r.mesh.vertices {
            v := &r.mesh.vertices[index];
            v.position = transform_coord(model_matrix, v.position);
            v.normal = transform_vector(model_matrix, v.normal);
        }

        append(&draw_list, r);

        orientation^ = qmul(p.orientation, gizmo.original_orientation);
    } else if local_toggle == true && gizmo.interaction_mode != .None {
        orientation^ = p.orientation;
    }

}

scale_gizmo :: proc(using ctx: ^Context, name: string, orientation: Vector4, center: Vector3, scale: ^Vector3)
{
}

// This will calculate a scale constant based on the number of screenspace pixels passed as pixel_scale.
scale_screenspace :: proc(using ctx: ^Context, position: Vector3, pixel_scale: f32) -> f32
{
    dist:f32 = length(position - active_state.cam.position);
    return tan(active_state.cam.yfov) * dist * (pixel_scale / active_state.viewport_size.y);
}

// The only purpose of this is readability: to reduce the total column width of the intersect(...) statements in every gizmo
intersect :: proc(using ctx: ^Context, r: Ray, i: Interact, t: ^f32, best_t: f32) -> bool
{
    if intersect_ray_mesh(r, &mesh_components[i].mesh, t) && t^ < best_t do return true;
    return false;
}

intersect_ray_mesh :: proc(ray: Ray, mesh: ^Mesh, hit_t: ^f32) -> bool {
    best_t := INF;
    t:f32;
    best_tri:i32= -1;
    for tri, tri_index in mesh.triangles {
        if intersect_ray_triangle(ray, mesh.vertices[tri[0]].position, mesh.vertices[tri[1]].position, mesh.vertices[tri[2]].position, &t) && t < best_t {
            best_t = t;
            best_tri = i32(tri_index);
        }
    }
    if best_tri == -1 do return false;
    if hit_t != nil do hit_t^ = best_t;
    return true;
}

intersect_ray_plane :: proc(ray: Ray, plane: Vector4, hit_t: ^f32) -> bool {
    denom := dot(v3(plane), ray.direction);
    if abs(denom) == 0 do return false;
    if hit_t != nil do hit_t^ = -dot(plane, v4(ray.origin, 1)) / denom;
    return true;
}

intersect_ray_triangle :: proc(ray: Ray, v0: Vector3, v1: Vector3, v2: Vector3, hit_t: ^f32) -> bool
{
    e1 := v1 - v0;
    e2 := v2 - v0;
    h := cross(ray.direction, e2);

    a := dot(e1, h);
    if abs(a) == 0 do return false;

    f:f32 = 1.0 / a;
    s := ray.origin - v0;
    u := f * dot(s, h);
    if u < 0 || u > 1 do return false;

    q := cross(s, e1);
    v := f * dot(ray.direction, q);
    if v < 0 || u + v > 1 do return false;

    t := f * dot(e2, q);
    if t < 0 do return false;

    if hit_t != nil do hit_t^ = t;

    return true;
}

position_gizmo :: proc(using ctx: ^Context, name: string, orientation: Vector4, position: ^Vector3) {
    p := Transform{position^, local_toggle ? orientation : Vector4{0, 0, 0, 1}, V3_ONE};
    draw_scale:f32 = active_state.screenspace_scale > 0 ? scale_screenspace(ctx, p.position, active_state.screenspace_scale) : 1;
    id := hash_fnv1a(name);

    gizmo := gizmos[id];
    defer gizmos[id] = gizmo;

    // interaction_mode will only change on clicked
    if has_clicked {
        gizmo.interaction_mode = .None;
    }

    {
        updated_state := Interact.None;
        ray := detransform(p, Ray{ active_state.ray_origin, active_state.ray_direction });
        detransform(draw_scale, &ray);

        best_t:f32 = INF; // TODO: odin's infinity?
        t: f32;

        if intersect(ctx, ray, .Translate_X, &t, best_t)   { updated_state = .Translate_X;   best_t = t; }
        if intersect(ctx, ray, .Translate_Y, &t, best_t)   { updated_state = .Translate_Y;   best_t = t; }
        if intersect(ctx, ray, .Translate_Z, &t, best_t)   { updated_state = .Translate_Z;   best_t = t; }
        if intersect(ctx, ray, .Translate_YZ, &t, best_t)  { updated_state = .Translate_YZ;  best_t = t; }
        if intersect(ctx, ray, .Translate_ZX, &t, best_t)  { updated_state = .Translate_ZX;  best_t = t; }
        if intersect(ctx, ray, .Translate_XY, &t, best_t)  { updated_state = .Translate_XY;  best_t = t; }
        if intersect(ctx, ray, .Translate_XYZ, &t, best_t) { updated_state = .Translate_XYZ; best_t = t; }

        if has_clicked {
            gizmo.interaction_mode = updated_state;
            if gizmo.interaction_mode != .None {
                transform(draw_scale, &ray);
                gizmo.click_offset = local_toggle ? transform_vector(p, ray.origin + ray.direction*t) : ray.origin + ray.direction * t;
                gizmo.active = true;
            } else {
                gizmo.active = false;
            }
        }

        gizmo.hover = best_t == INF ? false : true;
    }
 
    axes: [3]Vector3;
    if local_toggle do axes = { qxdir(p.orientation), qydir(p.orientation), qzdir(p.orientation) };
    else do axes = { { 1, 0, 0 },{ 0, 1, 0 },{ 0, 0, 1 } };

    if gizmo.active {
        position^ += gizmo.click_offset;
        defer position^ -= gizmo.click_offset;
        switch gizmo.interaction_mode {
            case .Translate_X:   axis_translation_dragger( ctx, &gizmo, axes[0], position);
            case .Translate_Y:   axis_translation_dragger( ctx, &gizmo, axes[1], position);
            case .Translate_Z:   axis_translation_dragger( ctx, &gizmo, axes[2], position);
            case .Translate_YZ:  plane_translation_dragger(ctx, &gizmo, axes[0], position);
            case .Translate_ZX:  plane_translation_dragger(ctx, &gizmo, axes[1], position);
            case .Translate_XY:  plane_translation_dragger(ctx, &gizmo, axes[2], position);
            case .Translate_XYZ: plane_translation_dragger(ctx, &gizmo, -qzdir(active_state.cam.orientation), position);
        }
    }

    if has_released {
        gizmo.interaction_mode = .None;
        gizmo.active = false;
    }

    draw_interactions := [?]Interact {
        .Translate_X, .Translate_Y, .Translate_Z,
        .Translate_YZ, .Translate_ZX, .Translate_XY,
        .Translate_XYZ
    };

    model_matrix := mul(matrix(p), mat4_scale(identity(Matrix4), v3(draw_scale)));

    for c in draw_interactions {
        r := Renderable {
            mesh = clone(&mesh_components[c].mesh),
            color = c == gizmo.interaction_mode ? mesh_components[c].base_color : mesh_components[c].highlight_color
        };

        for _, index in r.mesh.vertices {
            v := &r.mesh.vertices[index];
            v.position = transform_coord(model_matrix, v.position); // transform local coordinates into worldspace
            v.normal = transform_vector(model_matrix, v.normal);
        }

        append(&draw_list, r);
    }
}

@private
axis_translation_dragger :: proc(using ctx: ^Context, interaction: ^Interaction_State, axis: Vector3, point: ^Vector3) {
    if !active_state.mouse_left do return;

    // First apply a plane translation dragger with a plane that contains the desired axis and is oriented to face the camera
    plane_tangent := cross(axis, point^ - active_state.cam.position);
    plane_normal := cross(axis, plane_tangent);
    plane_translation_dragger(ctx, interaction, plane_normal, point);

    point^ = interaction.original_position + axis * dot(point^ - interaction.original_position, axis);
}


@private
plane_translation_dragger :: proc(using ctx: ^Context, interaction: ^Interaction_State, plane_normal: Vector3, point: ^Vector3) {
    // Mouse clicked
    if has_clicked do interaction.original_position = point^;

    if !active_state.mouse_left do return;

    // Define the plane to contain the original position of the object
    plane_point := interaction.original_position;
    r := Ray { active_state.ray_origin, active_state.ray_direction };

    // If an intersection exists between the ray and the plane, place the object at that point
    denom := dot(r.direction, plane_normal);
    if abs(denom) == 0 do return;

    t := dot(plane_point - r.origin, plane_normal) / denom;
    if t < 0 do return;

    point^ = r.origin + r.direction * t;

    if active_state.snap_translation > 0 do point^ = snap(point^, active_state.snap_translation);
}

@private
axis_rotation_dragger :: proc(using ctx: ^Context, gizmo: ^Interaction_State, axis, center: Vector3, start_orientation: Vector4, orientation: ^Vector4) {
    if !active_state.mouse_left do return;

    original_pose := Transform { gizmo.original_position, start_orientation, Vector3{1,1,1} };
    the_axis := transform_vector(original_pose, axis);
    the_plane := v4(the_axis, -dot(the_axis, gizmo.click_offset));
    r := Ray { active_state.ray_origin, active_state.ray_direction };

    t: f32;
    if !intersect_ray_plane(r, the_plane, &t) do return;

    center_of_rotation := gizmo.original_position + the_axis * dot(the_axis, gizmo.click_offset - gizmo.original_position);
    arm1 := norm(gizmo.click_offset - center_of_rotation);
    arm2 := norm(r.origin + r.direction * t - center_of_rotation);

    d := dot(arm1, arm2);
    if d > 0.999 { orientation^ = start_orientation; return; }

    angle := acos(d);
    if angle < 0.001 { orientation^ = start_orientation; return; }

    if active_state.snap_rotation != 0 {
        snapped := make_rotation_quat_between_vectors_snapped(arm1, arm2, active_state.snap_rotation);
        orientation^ = qmul(snapped, start_orientation);
    } else {
        a := norm(cross(arm1, arm2));
        orientation^ = qmul(rotation_quat(a, angle), start_orientation);
    }
}

rotation_quat :: proc(axis: Vector3, angle: f32) -> Vector4 do return v4(axis*sin(angle/2), cos(angle/2));
make_rotation_quat_axis_angle :: proc(axis: Vector3, angle: f32) -> Vector4 do return v4(axis * sin(angle / 2), cos(angle / 2));

make_rotation_quat_between_vectors_snapped :: proc (from, to: Vector3, angle: f32) -> Vector4 {
    a := norm(from);
    b := norm(to);
    snappedAcos := floor(acos(dot(a, b)) / angle) * angle;
    return make_rotation_quat_axis_angle(norm(cross(a, b)), snappedAcos);
}

snap :: proc(value: Vector3, snap: f32) -> Vector3
{
    if snap > 0 {
        return Vector3 { floor(value.x / snap), floor(value.y / snap), floor(value.z / snap) } * snap;
    }
    return value;
}
