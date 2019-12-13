package gizmos

using import "../math"

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


// TODO: a lot of these should just go in math, or come from math
// TODO: use Quat from 'math' instead of Vector4 for rotations

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
    inline for i in 0..<len(v) {
        if abs(v[i]) < EPS do v[i] = 0;
    }
}


@private
intersect_ray_plane :: proc(ray: Ray, plane: Vector4, hit_t: ^f32) -> bool {
    denom := dot(v3(plane), ray.direction);
    if abs(denom) == 0 do return false;
    if hit_t != nil do hit_t^ = -dot(plane, v4(ray.origin, 1)) / denom;
    return true;
}

@private
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

// This will calculate a scale constant based on the number of screenspace pixels passed as pixel_scale.
@private
scale_screenspace :: proc(using ctx: ^Context, position: Vector3, pixel_scale: f32) -> f32
{
    dist:f32 = length(position - active_state.cam.position);
    return tan(active_state.cam.yfov) * dist * (pixel_scale / active_state.viewport_size.y);
}

// The only purpose of this is readability: to reduce the total column width of the intersect(...) statements in every gizmo
@private
intersect :: proc(using ctx: ^Context, r: Ray, i: Interact, t: ^f32, best_t: f32) -> bool
{
    if intersect_ray_mesh(r, &mesh_components[i].mesh, t) && t^ < best_t do return true;
    return false;
}

@private
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

@private
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

@private
make_lathed_geometry :: proc(_axis, arm1, arm2: Vector3, slices: int, points: []Vector2, eps:f32 = 0) -> Mesh {
    axis := _axis;

    mesh: Mesh;
    mesh.vertices = make([dynamic]Geo_Vertex, 0, len(points) * slices);
    mesh.triangles = make([dynamic][3]u32, 0, len(points) * slices * 2);

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

@private
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
