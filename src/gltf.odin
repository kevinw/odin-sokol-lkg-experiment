package main;

import "core:fmt"
import "core:mem"
import "core:math/bits"
import "core:strings"
import sg "../lib/odin-sokol/src/sokol_gfx"
import sfetch "../lib/odin-sokol/src/sokol_fetch"
import "../lib/cgltf"
import "../lib/basisu"
import "./shader_meta"
import "shared:odin-stb/stbi"
import "math"

import "gizmos"

VERBOSE :: false;

Image_Type :: enum {
    Unknown,
    Basis,
    PNG,
    JPEG,
}

check_cast_i32 :: proc(n: $T) -> i32 {
    return cast(i32)n; // TODO
}

image_type_for_ext :: proc(ext: string) -> Image_Type {
    switch ext {
        case "png": return .PNG;
        case "jpeg", "jpg": return .JPEG;
        case "basis": return .Basis;
    }
    return .Unknown;
}

GLTF_Buffer_Fetch_Userdata :: struct { buffer_index: int };
GLTF_Image_Fetch_Userdata :: struct { image_index: int, image_type: Image_Type, full_uri: string }

// pipeline cache helper struct to avoid duplicate pipeline-state-objects
Pipeline_Cache_Params :: struct {
    layout: sg.Layout_Desc,
    prim_type: sg.Primitive_Type,
    index_type: sg.Index_Type,
    alpha: bool,
};

SCENE_INVALID_INDEX :: -1;
SCENE_MAX_PIPELINES :: 16;

draw :: proc(using scene: ^Scene, _num_views: int, now_seconds: f64) {
    using math;

    num_instances: int;
    switch game_mode {
        case .None: num_instances = 1;
        case .Snake: num_instances = 35;
        case .Tunnel: num_instances = 50;
    }

    for _, node_index in nodes {
        node := &nodes[node_index];
        vs_params := shader_meta.vs_params {
            //model = mul(gizmos.matrix(state.xform_a), node.transform),
            eye_pos = state.camera.position,
            num_instances = cast(i32)num_instances,
        };

        root_m := mul(gizmos.matrix(state.xform_a), node.transform);

        switch game_mode {
            case .Snake:
                now := cast(f32)now_seconds * 0.3;
                for m in 0..<num_instances {
                    f := f32(m) / f32(num_instances);
                    factor := f * TAU;
                    pos := v3(sin(factor + cast(f32)now_seconds * 1.0), cos(factor) * sin(factor), cos(factor)) * factor;
                    FREQ :: 1.0;
                    DEPTH :: 3;
                    pos += v3(perlin2d(factor, now, FREQ, DEPTH), perlin2d(now, factor, FREQ, DEPTH), perlin2d(now * factor, now, FREQ, DEPTH));
                    rot := mat4_rotate(norm(pos), cast(f32)now_seconds * 0.5 * f);
                    vs_params.instance_model_matrices[m] = mul(mul(root_m, mat4_translate(pos)), rot);
                }
            case .Tunnel:
            case .None:
                for m in 0..<num_instances {
                    vs_params.instance_model_matrices[m] = root_m;
                }
        }

        for view_i:int = 0; view_i < _num_views; view_i += 1 {
            vs_params.view_proj_array[view_i] = state.view_proj_array[view_i];
        }

        white, black, normal := get_placeholder_image(.WHITE), get_placeholder_image(.BLACK), get_placeholder_image(.NORMALS);

        mesh := &meshes[node.mesh];
        for i in 0..<mesh.num_primitives {
            prim := &sub_meshes[i + mesh.first_primitive];
            sg.apply_pipeline(pipelines[prim.pipeline]);
            bind := sg.Bindings {};
            for vb_slot in 0..<prim.vertex_buffers.num {
                bind.vertex_buffers[vb_slot] = buffers[prim.vertex_buffers.buffer[vb_slot]];
            }
            if prim.index_buffer != SCENE_INVALID_INDEX {
                bind.index_buffer = buffers[prim.index_buffer];
            }
            //bind.vertex_buffers[shader_meta.ATTR_vs_instance_model] = instance_model;

            apply_uniforms(.VS, shader_meta.SLOT_vs_params, &vs_params);
            apply_uniforms(.FS, shader_meta.SLOT_light_params, &state.point_light);
            //if mat.is_metallic {
                {
                    base_color_tex := white;
                    metallic_roughness_tex := white;
                    normal_tex := normal;
                    occlusion_tex := white;
                    emissive_tex := black;

                    // TODO: can we just make the asset loader put the
                    // placeholders there, and then overwrite them when
                    // they arrive/are decoded? we shouldn't be "looking
                    // them up" every frame.

                    if prim.material != -1 {
                        metallic := &materials[prim.material];

                        apply_uniforms(sg.Shader_Stage.FS,
                            shader_meta.SLOT_metallic_params,
                            &metallic.fs_params);
                            

                        using metallic.images;
                        if base_color != -1         && images[base_color].id != 0         do base_color_tex = images[base_color];
                        if metallic_roughness != -1 && images[metallic_roughness].id != 0 do metallic_roughness_tex = images[metallic_roughness];
                        if normal != -1             && images[normal].id != 0             do normal_tex = images[normal];
                        if occlusion != -1          && images[occlusion].id != 0          do occlusion_tex = images[occlusion];
                        if emissive != -1           && images[emissive].id != 0           do emissive_tex = images[emissive];
                    }

                    using shader_meta;
                    bind.fs_images[SLOT_base_color_texture] = base_color_tex;
                    bind.fs_images[SLOT_metallic_roughness_texture] = metallic_roughness_tex;
                    bind.fs_images[SLOT_normal_texture] = normal_tex;
                    bind.fs_images[SLOT_occlusion_texture] = occlusion_tex;
                    bind.fs_images[SLOT_emissive_texture] = emissive_tex;
                }
            //} else {
                //assert(false, "nonmetallic is unimplemented");
            //}

            sg.apply_bindings(bind);

            assert(prim.num_elements > 0);
            per_frame_stats.num_elements += cast(u64)prim.num_elements;
            sg.draw(cast(int)prim.base_element, cast(int)prim.num_elements, _num_views * num_instances);
        }
    }
}

@private
safe_cast_i16 :: inline proc(n: $T) -> i16 {
    assert(n < bits.I16_MAX);
    return cast(i16)n;
}

@private
optional_i16_offset :: proc(ptr: ^$T, base: ^T) -> i16 {
    if ptr == nil do return -1; // TODO: not sure keeping an index here is the right thing to do
    return safe_cast_i16(mem.ptr_sub(ptr, base));
}

@private
gltf_parse :: proc(bytes: []u8, path_root: string) {
    options := cgltf.Options{};
    gltf:^cgltf.Data;

    result := cgltf.parse(&options, &bytes[0], len(bytes), &gltf);
    if result != .SUCCESS {
        fmt.eprintln("error parsing gltf");
        return;
    }
    defer cgltf.free(gltf);

    //
    // check for index buffer usage
    //
    used_as_index := make([]bool, gltf.buffer_views_count, context.temp_allocator);

    meshes := mem.slice_ptr(gltf.meshes, gltf.meshes_count);
    for _, i in meshes {
        gltf_mesh := &meshes[i];
        primitives := mem.slice_ptr(gltf_mesh.primitives, gltf_mesh.primitives_count);
        for _, prim_index in primitives {
            indices := primitives[prim_index].indices;
            if indices != nil {
                buffer_index := safe_cast_i16(mem.ptr_sub(indices.buffer_view, gltf.buffer_views));
                used_as_index[buffer_index] = true;
            }
        }
    }

    //
    // parse buffers
    //
    // parse the buffer-view attributes
    {
        buffer_views := mem.slice_ptr(gltf.buffer_views, gltf.buffer_views_count);
        for _, i in buffer_views {
            using buf_view := &buffer_views[i];
            buffer_index := mem.ptr_sub(buffer, gltf.buffers);
            append(&state.creation_params.buffers, Buffer_Creation_Params{
                gltf_buffer_index = buffer_index,
                offset = cast(i32)offset,
                size = cast(i32)size,
                type = type == .INDICES || used_as_index[i] ? .INDEXBUFFER : .VERTEXBUFFER,
            });
            append(&state.scene.buffers, sg.alloc_buffer());
        }

        // start loading all the buffers
        buffers := mem.slice_ptr(gltf.buffers, gltf.buffers_count);
        for _, i in buffers {
            gltf_buf := &buffers[i];
            user_data := GLTF_Buffer_Fetch_Userdata { buffer_index = i };
            full_uri := fmt.tprintf("%s%s", path_root, gltf_buf.uri);
            when VERBOSE do fmt.println("<-", full_uri);
            sfetch.send({
                path = strings.clone_to_cstring(full_uri, context.temp_allocator), // @Speed
                callback = gltf_buffer_fetch_callback,
                user_data_ptr = &user_data,
                user_data_size = size_of(user_data),
            });
        }
    }

    //
    // parse images
    //
    {
        textures := mem.slice_ptr(gltf.textures, gltf.textures_count);
        for _, i in textures {
            using tex := &textures[i];
            append(&state.creation_params.images, Image_Creation_Params{
                gltf_image_index = mem.ptr_sub(image, gltf.images),
                min_filter = gltf_to_sg_filter(sampler.min_filter),
                mag_filter = gltf_to_sg_filter(sampler.mag_filter),
                wrap_s = gltf_to_sg_wrap(sampler.wrap_s),
                wrap_t = gltf_to_sg_wrap(sampler.wrap_t),
            });
            append(&state.scene.images, sg.Image{id=sg.INVALID_ID});
        }

        images := mem.slice_ptr(gltf.images, gltf.images_count);
        for _, i in images {
            using img := &images[i];

            full_uri := fmt.aprintf("%s%s", path_root, uri);
            user_data := GLTF_Image_Fetch_Userdata {
                image_index = i,
                full_uri = full_uri,
            };
            // TODO: leak
            when VERBOSE do fmt.println("loading", full_uri);

            last_dot := strings.last_index(full_uri, ".");
            if last_dot != -1 && last_dot + 1 < len(full_uri) {
                ext := full_uri[last_dot + 1:];
                user_data.image_type = image_type_for_ext(ext);
            }

            sfetch.send({
                path = strings.clone_to_cstring(full_uri, context.temp_allocator),
                callback = gltf_image_fetch_callback,
                user_data_ptr = &user_data,
                user_data_size = size_of(user_data),
            });
        }
    }

    //
    // parse materials
    //
    {
        materials := mem.slice_ptr(gltf.materials, gltf.materials_count);
        for _, i in materials {
            mat := &materials[i];
            assert(mat.has_pbr_metallic_roughness == 1); // TODO: setup different materials for specular
            using mat.pbr_metallic_roughness;
            scene_mat := Metallic_Material {};
            for d in 0..<4 do scene_mat.fs_params.base_color_factor[d] = base_color_factor[d];
            for d in 0..<3 do scene_mat.fs_params.emissive_factor[d] = mat.emissive_factor[d];
            scene_mat.fs_params.metallic_factor = metallic_factor;
            scene_mat.fs_params.roughness_factor = roughness_factor;

            scene_mat.images = {
                base_color = optional_i16_offset(base_color_texture.texture, gltf.textures),
                metallic_roughness = optional_i16_offset(metallic_roughness_texture.texture, gltf.textures),
                normal = optional_i16_offset(mat.normal_texture.texture, gltf.textures),
                occlusion = optional_i16_offset(mat.occlusion_texture.texture, gltf.textures),
                emissive = optional_i16_offset(mat.emissive_texture.texture, gltf.textures),
            };

            append(&state.scene.materials, scene_mat);
        }
    }

    //
    // parse meshes
    //
    {
        for _, i in meshes {
            gltf_mesh := &meshes[i];
            append(&state.scene.meshes, GLTFMesh {});
            mesh := &state.scene.meshes[len(state.scene.meshes) - 1];
            mesh.first_primitive = safe_cast_i16(len(state.scene.sub_meshes));
            mesh.num_primitives = safe_cast_i16(gltf_mesh.primitives_count);
            primitives := mem.slice_ptr(gltf_mesh.primitives, gltf_mesh.primitives_count);
            for _, prim_index in primitives {
                gltf_prim := &primitives[prim_index];
                append(&state.scene.sub_meshes, Sub_Mesh {});

                using sub_mesh := &state.scene.sub_meshes[len(&state.scene.sub_meshes) - 1];
                vertex_buffers = create_vertex_buffer_mapping_for_gltf_primitive(gltf, gltf_prim);
                pipeline = safe_cast_i16(create_sg_pipeline_for_gltf_primitive(gltf, gltf_prim, &vertex_buffers));
                material = optional_i16_offset(gltf_prim.material, gltf.materials);
                if gltf_prim.indices != nil {
                    index_buffer = safe_cast_i16(mem.ptr_sub(gltf_prim.indices.buffer_view, gltf.buffer_views));
                    //assert(state.creation_params.buffers[index_buffer].type == .INDEXBUFFER, fmt.tprint("expected .INDEXBUFFER, found ", state.creation_params.buffers[index_buffer].type));
                    assert(gltf_prim.indices.stride != 0);
                    base_element = 0;
                    num_elements = cast(i32) gltf_prim.indices.count;
                } else {
                    // hmm... looking up the number of elements to render from
                    // a random vertex component accessor looks a bit shady
                    fmt.print("SCENE_INVALID_INDEX");
                    index_buffer = SCENE_INVALID_INDEX;
                    base_element = 0;
                    num_elements = cast(i32) gltf_prim.attributes.data.count;
                }
            }
        }
    }

    //
    // parse nodes
    //
    nodes := mem.slice_ptr(gltf.nodes, gltf.nodes_count);
    for _, i in nodes {
        gltf_node := &nodes[i];
        // ignore nodes without mesh, those are not relevant since we
        // bake the transform hierarchy into per-node world space transforms
        if gltf_node.mesh != nil {
            append(&state.scene.nodes, GLTFNode {});
            node := &state.scene.nodes[len(state.scene.nodes) - 1];
            node.mesh = safe_cast_i16(mem.ptr_sub(gltf_node.mesh, gltf.meshes));
            node.transform = build_transform_for_gltf_node(gltf, gltf_node);
        }
    }
}

@private
build_transform_for_gltf_node :: proc(gltf: ^cgltf.Data, node: ^cgltf.Node) -> Matrix4 {
    using math;

    parent_tform := identity(Matrix4);
    if node.parent != nil {
        parent_tform = build_transform_for_gltf_node(gltf, node.parent);
    }
    tform := identity(Matrix4);
    if node.has_matrix != 0 {
        tform = (cast(^Matrix4)&node.matrix[0])^;
    } else {
        t := identity(Matrix4);
        r := identity(Matrix4);
        s := identity(Matrix4);
        if node.has_translation != 0 {
            t = translate_matrix4(Vector3{node.translation[0], node.translation[1], node.translation[2]});
        }
        if node.has_rotation != 0 {
            r = rotate_matrix4x4_quat(node.rotation[0], node.rotation[1], node.rotation[2], node.rotation[3]);
        }
        if node.has_scale != 0 {
            s = scale_matrix4(identity(Matrix4), Vector3{node.scale[0], node.scale[1], node.scale[2]});
        }
        tform = mul(parent_tform, mul(mul(s, r), t));
    }

    return tform;
}

@private
rotate_matrix4x4_quat :: proc(q_x, q_y, q_z, q_w: f32) -> math.Matrix4x4 {
    using math;

    // thanks Unity decompiled

    // Precalculate coordinate products
    x := q_x * 2.0;
    y := q_y * 2.0;
    z := q_z * 2.0;
    xx := q_x * x;
    yy := q_y * y;
    zz := q_z * z;
    xy := q_x * y;
    xz := q_x * z;
    yz := q_y * z;
    wx := q_w * x;
    wy := q_w * y;
    wz := q_w * z;

    // Calculate 3x3 matrix from orthonormal basis
    m: Matrix4;
    m[0][0] = 1.0 - (yy + zz); m[1][0] = xy + wz; m[2][0] = xz - wy; m[3][0] = 0.0;
    m[0][1] = xy - wz; m[1][1] = 1.0 - (xx + zz); m[2][1] = yz + wx; m[3][1] = 0.0;
    m[0][2] = xz + wy; m[1][2] = yz - wx; m[2][2] = 1.0 - (xx + yy); m[3][2] = 0.0;
    m[0][3] = 0.0; m[1][3] = 0.0; m[2][3] = 0.0; m[3][3] = 1.0;
    return m;
}

// creates a vertex buffer bind slot mapping for a specific GLTF primitive
@private
create_vertex_buffer_mapping_for_gltf_primitive :: proc(gltf: ^cgltf.Data, prim: ^cgltf.Primitive) -> Vertex_Buffer_Mapping {
    buf_map: Vertex_Buffer_Mapping;
    for i in 0..<sg.MAX_SHADERSTAGE_BUFFERS {
        buf_map.buffer[i] = SCENE_INVALID_INDEX;
    }

    attributes := mem.slice_ptr(prim.attributes, prim.attributes_count);
    for _, attr_index in attributes {
        attr := &attributes[attr_index];
        acc := attr.data;

        buffer_view_index := mem.ptr_sub(acc.buffer_view, gltf.buffer_views);
        i : i32;
        for i = 0; i < buf_map.num; i += 1 {
            if buf_map.buffer[i] == cast(i32)buffer_view_index do break;
        }
        if (i == buf_map.num) && (buf_map.num < sg.MAX_SHADERSTAGE_BUFFERS) {
            buf_map.buffer[buf_map.num] = cast(i32)buffer_view_index;
            buf_map.num += 1;
        }
        assert(buf_map.num <= sg.MAX_SHADERSTAGE_BUFFERS);
    }

    return buf_map;
}

@private
create_sg_layout_for_gltf_primitive :: proc(gltf: ^cgltf.Data, prim: ^cgltf.Primitive, vbuf_map: ^Vertex_Buffer_Mapping) -> sg.Layout_Desc {
    assert(prim.attributes_count <= sg.MAX_VERTEX_ATTRIBUTES);
    layout: sg.Layout_Desc;
    attributes := mem.slice_ptr(prim.attributes, prim.attributes_count);
    highest_slot: i32 = -1;
    for _, attr_index in attributes {
        attr := &attributes[attr_index];
        attr_slot := gltf_attr_type_to_vs_input_slot(attr.type);
        if (attr_slot != SCENE_INVALID_INDEX) {
            layout.attrs[attr_slot].format = gltf_to_vertex_format(attr.data);

            buffer_view_index := mem.ptr_sub(attr.data.buffer_view, gltf.buffer_views);
            for vb_slot :i32= 0; vb_slot < vbuf_map.num; vb_slot+=1 {
                if vbuf_map.buffer[vb_slot] == cast(i32)buffer_view_index {
                    layout.attrs[attr_slot].buffer_index = vb_slot;
                    highest_slot = max(attr_slot, highest_slot);
                }
            }
        } else {
            fmt.eprintln("error: attr_slot was SCENE_INVALID_INDEX");
        }
    }

    // TODO: per instance data
    //instance_model_slot := highest_slot + 1;
    //layout.attrs[shader_meta.ATTR_vs_instance_model].buffer_index = instance_model_slot;
    //layout.attrs[shader_meta.ATTR_vs_instance_model].

    return layout;
}

// Create a unique sokol-gfx pipeline object for GLTF primitive (aka submesh),
// maintains a cache of shared, unique pipeline objects. Returns an index
// into state.scene.pipelines
@private
create_sg_pipeline_for_gltf_primitive :: proc(gltf: ^cgltf.Data, prim: ^cgltf.Primitive, vbuf_map: ^Vertex_Buffer_Mapping) -> i32 {
    assert(gltf != nil, "gtlf data cannot be nil");
    assert(prim != nil, "prim cannot be null");

    pip_params := Pipeline_Cache_Params {
        layout = create_sg_layout_for_gltf_primitive(gltf, prim, vbuf_map),
        prim_type = gltf_to_prim_type(prim.type),
        index_type = gltf_to_index_type(prim),
        alpha = prim.material != nil && prim.material.alpha_mode != .OPAQUE
    };

    i := 0;
    for _, p in state.scene.pipelines {
        if p >= len(state.pip_cache) do break;
        if pipelines_equal(&state.pip_cache[p], &pip_params) {
            // an identical pipeline already exists, reuse this
            assert(state.scene.pipelines[p].id != sg.INVALID_ID);
            return cast(i32)p;
        }
    }

    if i == len(state.scene.pipelines) && len(state.scene.pipelines) < SCENE_MAX_PIPELINES {
        append(&state.pip_cache, pip_params);
        is_metallic:bool = prim.material == nil || prim.material.has_pbr_metallic_roughness != 0 ? true : false;
        assert(is_metallic, "exptecting metallic for now");

        using pip_params;

        append(&state.scene.pipelines, sg.Pipeline {});
        p := &state.scene.pipelines[len(state.scene.pipelines) - 1];

        reinit_pipeline(p, {
            label = "cgltf_metallic",
            layout = layout,
            shader = state.shaders.metallic, // TODO is_metallic ? state.shaders.metallic : state.shaders.specular,
            primitive_type = prim_type,
            index_type = index_type,
            depth_stencil = {
                depth_write_enabled = !alpha,
                depth_compare_func = .LESS_EQUAL,
            },
            blend = {
                enabled = alpha,
                src_factor_rgb = alpha ? .SRC_ALPHA : ._DEFAULT,
                dst_factor_rgb = alpha ? .ONE_MINUS_SRC_ALPHA : ._DEFAULT,
                color_write_mask = alpha ? sg.COLOR_MASK_RGB : sg.COLOR_MASK__DEFAULT,
            },
            rasterizer = {
                cull_mode = .BACK,
                face_winding = .CCW,
                sample_count = MSAA_SAMPLE_COUNT,
            }
        });
    }

    assert(len(state.scene.pipelines) <= SCENE_MAX_PIPELINES);
    return cast(i32)i;
}


@private
gltf_buffer_fetch_callback :: proc "c" (response: ^sfetch.Response) {
    if response.dispatched {
        sfetch.bind_buffer(response.handle, sfetch_buffers[response.channel][response.lane][:]);
    } else if response.fetched {
        user_data := cast(^GLTF_Buffer_Fetch_Userdata)response.user_data;
        gltf_buffer_index := cast(int)user_data.buffer_index;
        bytes := mem.slice_ptr(cast(^u8)response.buffer_ptr, cast(int)response.fetched_size);
        create_sg_buffers_for_gltf_buffer(gltf_buffer_index, bytes);
    }

    if response.finished && response.failed {
        fmt.eprintln("error fetching buffer");
        state.failed = true;
    }
}

@private
gltf_image_fetch_callback :: proc "c" (response: ^sfetch.Response) {
    user_data := cast(^GLTF_Image_Fetch_Userdata)response.user_data;
    if response.dispatched {
        sfetch.bind_buffer(response.handle, sfetch_buffers[response.channel][response.lane][:]);
    } else if response.fetched {
        gltf_image_index := cast(int)user_data.image_index;
        create_sg_images_for_gltf_image(
            gltf_image_index,
            user_data.image_type,
            mem.slice_ptr(cast(^u8)response.buffer_ptr, cast(int)response.fetched_size));
    }
    if response.finished && response.failed {
        fmt.eprintln("error fetching image:", user_data.full_uri);
        state.failed = true;
    }

    //free(user_data.full_uri); // TODO: crashes, because no context in proc "C" ? maybe?
}

@private
create_sg_buffers_for_gltf_buffer :: proc(gltf_buffer_index: int, bytes: []u8) {
    for buf, i in state.scene.buffers {
        p := &state.creation_params.buffers[i];
        if p.gltf_buffer_index == gltf_buffer_index {
            assert(cast(int)(p.offset + p.size) <= len(bytes));
            sg.init_buffer(buf, {
                type = p.type,
                size = p.size,
                content = mem.ptr_offset(&bytes[0], cast(int)p.offset)
            });
        }
    }
}

@private
create_sg_images_for_gltf_image :: proc(gltf_image_index: int, image_type: Image_Type, bytes: []u8) {
    for _, i in state.scene.images {
        p := &state.creation_params.images[i];
        if p.gltf_image_index != gltf_image_index do continue;
        // @Speed should we make a new sg.Image for each one?
        #partial switch image_type {
            case .JPEG, .PNG:
                desired_channels :: 4;
                x, y, channels_in_file: i32;
                res := stbi.load_from_memory(&bytes[0], check_cast_i32(len(bytes)), &x, &y, &channels_in_file, desired_channels);
                assert(res != nil, "stbi could load image from memory");
                defer stbi.image_free(res);

                assert(x > 0 && y > 0);
                img_desc := sg.Image_Desc {
                    width = x,
                    height = y,
                    pixel_format = .RGBA8,
                    min_filter = .LINEAR,
                    mag_filter = .LINEAR,
                };
                img_desc.content.subimage[0][0] = { ptr = res, size = x * y * desired_channels };
                state.scene.images[i] = sg.make_image(img_desc);
            case .Basis:
                img_desc := basisu.transcode(bytes);
                state.scene.images[i] = sg.make_image(img_desc);
                basisu.free(&img_desc);
            case:
                assert(false, "unhandled image type");
        }
    }
}

@(private)
gltf_to_sg_filter :: proc(gltf_filter: i32) -> sg.Filter {
    // https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#samplerminfilter

    switch gltf_filter {
        case 9728: return .NEAREST;
        case 9729: return .LINEAR;
        case 9984: return .NEAREST_MIPMAP_NEAREST;
        case 9985: return .LINEAR_MIPMAP_NEAREST;
        case 9986: return .NEAREST_MIPMAP_LINEAR;
        case 9987: return .LINEAR_MIPMAP_LINEAR;
        case:      return .LINEAR;
    }
}

gltf_to_sg_wrap :: proc(gltf_wrap: i32) -> sg.Wrap {
    // https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#samplerwraps

    switch gltf_wrap {
        case 33071: return .CLAMP_TO_EDGE;
        case 33648: return .MIRRORED_REPEAT;
        case 10497: return .REPEAT;
        case:       return .REPEAT;
    }
}

gltf_attr_type_to_vs_input_slot :: proc(attr_type: cgltf.Attribute_Type) -> i32 {
    #partial switch attr_type {
        case .POSITION: return shader_meta.ATTR_vs_cgltf_position;
        case .NORMAL: return shader_meta.ATTR_vs_normal;
        case .TEXCOORD: return shader_meta.ATTR_vs_texcoord;
        //case .TANGENT: return shader_meta.ATTR_vs_tangent;
        case:
            fmt.eprintln("unhandled Attribute_Type", attr_type);
            return SCENE_INVALID_INDEX;
    }
}

@(private)
gltf_to_prim_type :: proc(prim_type: cgltf.Primitive_Type) -> sg.Primitive_Type {
    #partial switch prim_type {
        case .POINTS: return .POINTS;
        case .LINES: return .LINES;
        case .LINE_STRIP: return .LINE_STRIP;
        case .TRIANGLES: return .TRIANGLES;
        case .TRIANGLE_STRIP: return .TRIANGLE_STRIP;
        case: return ._DEFAULT;
    }
}

@(private)
gltf_to_index_type :: proc(prim: ^cgltf.Primitive) -> sg.Index_Type {
    if prim.indices == nil do return sg.Index_Type.NONE;

    if prim.indices.component_type == .R_16U {
        return sg.Index_Type.UINT16;
    } else {
        return sg.Index_Type.UINT32;
    }
}

// helper to compare to pipeline-cache items
@(private)
pipelines_equal :: proc(p0: ^Pipeline_Cache_Params, p1: ^Pipeline_Cache_Params) -> bool {
    if p0.prim_type != p1.prim_type do return false;
    if p0.alpha != p1.alpha do return false;
    if p0.index_type != p1.index_type do return false;

    for i := 0; i < sg.MAX_VERTEX_ATTRIBUTES; i += 1 {
        a0 := p0.layout.attrs[i];
        a1 := p1.layout.attrs[i];
        if (a0.buffer_index != a1.buffer_index) ||
            (a0.offset != a1.offset) ||
            (a0.format != a1.format) {
            return false;
        }
    }

    return true;
}


@(private)
gltf_to_vertex_format :: proc(acc: ^cgltf.Accessor) -> sg.Vertex_Format {
    #partial switch acc.component_type {
        case .R_8:
            if acc.type == .VEC4 {
                return acc.normalized != 0 ? .BYTE4N : .BYTE4;
            }
        case .R_8U:
            if acc.type == .VEC4 {
                return acc.normalized != 0 ? .UBYTE4N : .UBYTE4;
            }
        case .R_16:
            #partial switch acc.type {
                case .VEC2: return acc.normalized != 0 ? .SHORT2N : .SHORT2;
                case .VEC4: return acc.normalized != 0 ? .SHORT4N : .SHORT4;
            }
        case .R_32F:
            #partial switch acc.type {
                case .SCALAR: return .FLOAT;
                case .VEC2: return .FLOAT2;
                case .VEC3: return .FLOAT3;
                case .VEC4: return .FLOAT4;
            }
    }

    fmt.eprintln("error: don't know how to handle gltf.Accessor", acc);
    return .INVALID;
}


