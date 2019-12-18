package main

import sg "../lib/odin-sokol/src/sokol_gfx"
import ai "../lib/assimp"
using import "core:fmt"
using import "core:strings"
using import "core:runtime"
using import "./math"
import "core:mem"
import "core:log"
import "./stacktrace"

import "./shader_meta"

Mat4 :: math.Matrix4;
Vec3 :: math.Vector3;
BONES_PER_VERTEX :: 4;


load_model_from_file :: proc(path: string) -> Model {
	path_c := strings.clone_to_cstring(path);
	defer delete(path_c);

	scene := ai.import_file(path_c,
		// cast(u32) ai.Post_Process_Steps.Calc_Tangent_Space |
		cast(u32) ai.Post_Process_Steps.Triangulate |
		// cast(u32) ai.Post_Process_Steps.Join_Identical_Vertices |
		// cast(u32) ai.Post_Process_Steps.Sort_By_PType |
		// cast(u32) ai.Post_Process_Steps.Find_Invalid_Data |
		// cast(u32) ai.Post_Process_Steps.Gen_UV_Coords |
		// cast(u32) ai.Post_Process_Steps.Find_Degenerates |
		// cast(u32) ai.Post_Process_Steps.Transform_UV_Coords |
		// cast(u32) ai.Post_Process_Steps.Pre_Transform_Vertices |
		cast(u32) ai.Post_Process_Steps.Gen_Smooth_Normals |
		// cast(u32) ai.Post_Process_Steps.Flip_Winding_Order |
		cast(u32) ai.Post_Process_Steps.Flip_UVs
		);
	assert(scene != nil, tprint(ai.get_error_string()));
	defer ai.release_import(scene);

	model := _load_model_internal(scene);
	return model;
}

Model :: struct {
	name: string,
    meshes: [dynamic]Mesh,
}

Mesh :: struct {
    vertex_buffer: sg.Buffer,
    index_buffer: sg.Buffer,
    //vao: VAO,
    //vbo: VBO,
    //ibo: EBO,
    vertex_type: ^Type_Info,

    index_count:  int,
    vertex_count: int,

	skin: Skinned_Mesh,
}

Skinned_Mesh :: struct {
	bones: []Bone,
    nodes: [dynamic]Node,
	name_mapping: map[string]int,
	global_inverse: Mat4,

    parent_node: ^Node, // points into array above
}

Bone :: struct {
	offset: Mat4,
	name: string,
}


Node :: struct {
    name: string,
    local_transform: Mat4,

    parent: ^Node,
    children: [dynamic]^Node,
}

ai_to_wb :: proc (m : ai.Matrix4x4) -> Mat4 {
	return Mat4{
		{m.a1, m.b1, m.c1, m.d1},
		{m.a2, m.b2, m.c2, m.d2},
		{m.a3, m.b3, m.c3, m.d3},
		{m.a4, m.b4, m.c4, m.d4},
	};
}

Vertex3D :: struct {
	position: Vec3,
	tex_coord: Vec3, // todo(josh): should this be a Vec2?
	color: Colorf,
	normal: Vec3,

	bone_indicies: [BONES_PER_VERTEX]u32,
	bone_weights: [BONES_PER_VERTEX]f32,
}

get_mesh_transform :: proc(node: ^ai.Node, mesh_name: string) -> Mat4 {
	ret := math.identity(Mat4);

	children := mem.slice_ptr(node.children, cast(int)node.num_children);
	for _, i in children {
		child := children[i];

		child_name := strings.string_from_ptr(&child.name.data[0], cast(int)child.name.length);
		if child_name == mesh_name {
			return ai_to_wb(child.transformation);
		}

		ret = get_mesh_transform(child, mesh_name);
	}

	return ret;
}


_load_model_internal :: proc(scene: ^ai.Scene, loc := #caller_location) -> Model {
	mesh_count := cast(int) scene.num_meshes;
	model: Model;
	model.meshes = make([dynamic]Mesh, 0, mesh_count, context.allocator, loc);
	base_vert := 0;

    log.info("TODO: load_animations");
	//anim.load_animations_from_ai_scene(scene);

	meshes := mem.slice_ptr(scene^.meshes, cast(int) scene.num_meshes);
	for _, i in meshes {

		mesh := meshes[i];
		mesh_name := strings.string_from_ptr(&mesh.name.data[0], cast(int)mesh.name.length);
		verts := mem.slice_ptr(mesh.vertices, cast(int) mesh.num_vertices);

		mesh_transform := get_mesh_transform(scene.root_node, mesh_name);

		normals: []ai.Vector3D;
		if ai.has_normals(mesh) {
			assert(mesh.normals != nil);
			normals = mem.slice_ptr(mesh.normals, cast(int) mesh.num_vertices);
		}

		colors : []ai.Color4D;
		if ai.has_vertex_colors(mesh, 0) {
			assert(mesh.colors != nil);
			colors = mem.slice_ptr(mesh.colors[0], cast(int) mesh.num_vertices);
		}

		texture_coords : []ai.Vector3D;
		if ai.has_texture_coords(mesh, 0) {
			assert(mesh.texture_coords != nil);
			texture_coords = mem.slice_ptr(mesh.texture_coords[0], cast(int) mesh.num_vertices);
		}

		processed_verts := make([dynamic]Vertex3D, 0, mesh.num_vertices);
		defer delete(processed_verts);

		defer base_vert += int(mesh.num_vertices);

		// process vertices into Vertex3D struct
		for i in 0..mesh.num_vertices-1 {
			position := verts[i];

			normal := ai.Vector3D{0, 0, 0};
			if normals != nil {
				normal = normals[i];
			}

			color := Colorf{1, 1, 1, 1};
			if colors != nil {
				color = transmute(Colorf)colors[i];
			}

			texture_coord := Vec3{0, 0, 0};
			if texture_coords != nil {
				texture_coord = Vec3{texture_coords[i].x, texture_coords[i].y, texture_coords[i].z};
			}

			pos := mul(mesh_transform, Vec4{position.x, position.y, position.z, 1});
			vert := Vertex3D{
				Vec3{pos.x, pos.y, pos.z},
				texture_coord,
				color,
				Vec3{normal.x, normal.y, normal.z}, {}, {}};

			append(&processed_verts, vert);
		}

		indices := make([dynamic]u32, 0, mesh.num_vertices);
		defer delete(indices);

		faces := mem.slice_ptr(mesh.faces, cast(int)mesh.num_faces);
		for face in faces {
			face_indices := mem.slice_ptr(face.indices, cast(int) face.num_indices);
			for face_index in face_indices {
				append(&indices, face_index);
			}
		}

		skin : Skinned_Mesh;
		if mesh.num_bones > 0 {

			// @alloc needs to be freed when the mesh is destroyed
			bone_mapping := make(map[string]int, cast(int)mesh.num_bones);
			bone_info := make([dynamic]Bone, 0, cast(int)mesh.num_bones);

			num_bones := 0;
			bones := mem.slice_ptr(mesh.bones, cast(int)mesh.num_bones);
			for bone in bones {
				bone_name := strings.clone(strings.string_from_ptr(&bone.name.data[0], cast(int)bone.name.length));

				bone_index := 0;
				if bone_name in bone_mapping {
					bone_index = bone_mapping[bone_name];
				} else {
					bone_index = num_bones;
					bone_mapping[bone_name] = bone_index;
					num_bones += 1;
				}

				offset := ai_to_wb(bone.offset_matrix);
				append(&bone_info, Bone{ offset, bone_name });

				if bone.num_weights == 0 do continue;

				weights := mem.slice_ptr(bone.weights, cast(int)bone.num_weights);
				for weight in weights {
					vertex_id := base_vert + int(weight.vertex_id);
					vert := processed_verts[vertex_id];
					for j := 0; j < BONES_PER_VERTEX; j += 1 {
						if vert.bone_weights[j] == 0 {
							vert.bone_weights[j] = weight.weight;
							vert.bone_indicies[j] = u32(bone_index);

							processed_verts[vertex_id] = vert;
							break;
						}
					}
				} // end weights
			} // end bones loop

			skin = Skinned_Mesh{
				bone_info[:],
				make([dynamic]Node, 0, 50),
				bone_mapping,
				inverse(ai_to_wb(scene.root_node.transformation)),
				nil,
			};

		} // end bone if
		// create mesh
		idx := add_mesh_to_model(&model,
			processed_verts[:],
			indices[:],
			skin
		);

		read_node_hierarchy(&model.meshes[idx], scene.root_node, identity(Mat4), nil);
	}

	return model;
}

read_node_hierarchy :: proc(using mesh: ^Mesh, ai_node : ^ai.Node, parent_transform: Mat4, parent_node: ^Node) {
	node_name := strings.clone(strings.string_from_ptr(&ai_node.name.data[0], cast(int)ai_node.name.length));

	node_transform := ai_to_wb(ai_node.transformation);
	global_transform := mul(parent_transform, node_transform);

	node := Node {
				node_name,
				node_transform,
				parent_node,
				make([dynamic]^Node, 0, cast(int)ai_node.num_children)
			};

	append(&skin.nodes, node);
	idx := len(skin.nodes) - 1;

	if skin.parent_node == nil {
		skin.parent_node = &skin.nodes[idx];
	}

	if parent_node != nil {
		append(&parent_node.children, &skin.nodes[idx]);
	}

	children := mem.slice_ptr(ai_node.children, cast(int)ai_node.num_children);
	for _, i in children {
		read_node_hierarchy(mesh, children[i], global_transform, &skin.nodes[idx]);
	}
}


// todo(josh): maybe shouldn't use strings for mesh names, not sure
add_mesh_to_model :: proc(model: ^Model, vertices: []$Vertex_Type, indices: []u32, skin: Skinned_Mesh, loc := #caller_location) -> int {

    vertex_buffer := sg.make_buffer({
        label = "mesh vertices", // TODO: better name
        size = i32(len(vertices) * size_of(Vertex_Type)),
        content = &vertices[0]
    });
    
    fmt.println("Vertices:\n", vertices);

    index_buffer := sg.make_buffer({
        label = "mesh indices",
        type = .INDEXBUFFER,
        size = i32(len(indices) * size_of(u32)),
        content = &indices[0],
    });

    fmt.println("Indices:\n", indices);

	idx := len(model.meshes);
    // fmt.println("adding mesh to model at idx", idx);
	mesh := Mesh{vertex_buffer, index_buffer, type_info_of(Vertex_Type), len(indices), len(vertices), skin};
	append(&model.meshes, mesh, loc);

	update_mesh(model, idx, vertices, indices);

	return idx;
}

remove_mesh_from_model :: proc(model: ^Model, idx: int, loc := #caller_location) {
	assert(idx < len(model.meshes));
	mesh := model.meshes[idx];
	_internal_delete_mesh(mesh, loc);
	unordered_remove(&model.meshes, idx);
}


_internal_delete_mesh :: proc(mesh: Mesh, loc := #caller_location) {
    sg.destroy_buffer(mesh.vertex_buffer);
    sg.destroy_buffer(mesh.index_buffer);
	//gpu.log_errors(#procedure, loc);

	for name in mesh.skin.name_mapping {
		delete(name);
	}

	delete(mesh.skin.name_mapping);
	delete(mesh.skin.bones);
}

get_pipeline_and_bindings :: proc(mesh: ^Mesh, shader: sg.Shader) -> (sg.Pipeline, sg.Bindings) {
    /*
        Vertex3D :: struct {
            position: Vec3,
            tex_coord: Vec3, // todo(josh): should this be a Vec2?
            color: Colorf,
            normal: Vec3,

            bone_indicies: [BONES_PER_VERTEX]u32,
            bone_weights: [BONES_PER_VERTEX]f32,
        }
    */

    @static _pip: sg.Pipeline;
    if _pip.id == 0 {
        desc := sg.Pipeline_Desc {
            label = "assimp mesh pipeline",
            shader = shader,
            index_type = .UINT32,
            layout = sg.Layout_Desc {
                buffers = {
                    0 = {
                        stride = size_of(Vertex3D),
                    }
                },
                attrs = {
                    shader_meta.ATTR_vs_position = {
                        format = .FLOAT3,
                        offset = 0,
                    },
                    shader_meta.ATTR_vs_color0 = {
                        format = .FLOAT3,
                        offset = cast(i32)offset_of(Vertex3D, normal),
                    }
                    /*
                    shader_meta.ATTR_vs_cgltf_position = {
                        format = .FLOAT3,
                        offset = 0,
                    },
                    shader_meta.ATTR_vs_normal = {
                        format = .FLOAT3,
                        offset = cast(i32)offset_of(Vertex3D, normal),
                    },
                    shader_meta.ATTR_vs_texcoord = {
                        format = .FLOAT3,
                        offset = cast(i32)offset_of(Vertex3D, tex_coord),
                    },
                    */
                }
            },
        };
        _pip = sg.make_pipeline(desc);
    }
    pipeline := _pip;

    assert(pipeline.id != sg.INVALID_ID);
    assert(false);

    bindings := sg.Bindings {
        vertex_buffers = {
            0 = mesh.vertex_buffer,
        },
        index_buffer = mesh.index_buffer,
    };

    using shader_meta;
    /*
    bindings.fs_images[SLOT_base_color_texture] = get_placeholder_image(.WHITE);
    bindings.fs_images[SLOT_metallic_roughness_texture] = get_placeholder_image(.WHITE);
    bindings.fs_images[SLOT_normal_texture] = get_placeholder_image(.NORMALS);
    bindings.fs_images[SLOT_occlusion_texture] = get_placeholder_image(.WHITE);
    bindings.fs_images[SLOT_emissive_texture] = get_placeholder_image(.BLACK);
    */

    return pipeline, bindings;
}

draw_model :: proc(model: ^Model, shader: sg.Shader, position: Vector3, rotation: Vector4, scale: Vector3) {
    for _, i in model.meshes {
        mesh := &model.meshes[i];

        num_instances := 1;
        pipeline, bindings := get_pipeline_and_bindings(mesh, shader);
        sg.apply_pipeline(pipeline);
        sg.apply_bindings(bindings);


        /*
        vs_params := shader_meta.vs_params {
            eye_pos = state.camera.position,
            num_instances = cast(i32)num_instances,
        };
        for m in 0..<num_instances {
            vs_params.instance_model_matrices[m] = identity(Matrix4);
        }
        for view_i:int = 0; view_i < num_views(); view_i += 1 {
            vs_params.view_proj_array[view_i] = state.view_proj_array[view_i];
        }

        apply_uniforms(.VS, shader_meta.SLOT_vs_params, &vs_params);
        apply_uniforms(.FS, shader_meta.SLOT_light_params, &state.point_light);
        apply_uniforms(.FS, shader_meta.SLOT_metallic_params, shader_meta.metallic_params {
            base_color_factor = 1,
            emissive_factor = 0,
            metallic_factor = 0.5,
            roughness_factor = 0.5,
        });
        */

        apply_uniforms(.VS, shader_meta.SLOT_vs_uniforms, shader_meta.vs_uniforms {
            mvp = state.view_proj,
        });

        sg.draw(0, mesh.index_count / 3, num_views() * num_instances);
    }
}

update_mesh :: proc(model: ^Model, idx: int, vertices: []$Vertex_Type, indices: []u32) {
	assert(idx < len(model.meshes));
	mesh := &model.meshes[idx];

    /*
	gpu.bind_vao(mesh.vao);

	gpu.bind_vbo(mesh.vbo);
	gpu.buffer_vertices(vertices);

	gpu.bind_ibo(mesh.ibo);
	gpu.buffer_elements(indices);

	gpu.bind_vao(0);
    */

	mesh.vertex_type  = type_info_of(Vertex_Type);
	mesh.index_count  = len(indices);
	mesh.vertex_count = len(vertices);
}

