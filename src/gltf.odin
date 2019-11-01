package main;

import "core:fmt"
using import "core:math/linalg"
import "core:math/bits"
import "core:mem"
import "core:strings"
import sg "sokol:sokol_gfx"
import sfetch "sokol:sokol_fetch"
import "../lib/cgltf"
import "../lib/basisu"
import "./shader_meta"

VERBOSE :: false;

GLTF_Buffer_Fetch_Userdata :: struct { buffer_index: int };
GLTF_Image_Fetch_Userdata :: struct { image_index: int }

MSAA_SAMPLE_COUNT :: 4;

// pipeline cache helper struct to avoid duplicate pipeline-state-objects
Pipeline_Cache_Params :: struct {
    layout: sg.Layout_Desc,
    prim_type: sg.Primitive_Type,
    index_type: sg.Index_Type,
    alpha: bool,
};

SCENE_INVALID_INDEX :: -1;
SCENE_MAX_PIPELINES :: 16;

safe_cast_i16 :: inline proc(n: $T) -> i16 {
    assert(n < bits.I16_MAX);
    return cast(i16)n;
}

gltf_parse :: proc(bytes: []u8) {
    options := cgltf.Options{};
    gltf:^cgltf.Data;

    result := cgltf.parse(&options, &bytes[0], len(bytes), &gltf);
    if result != cgltf.Result.SUCCESS {
        fmt.eprintln("error parsing gltf");
        return;
    }

    defer cgltf.free(gltf);

    //all := fmt.tprint("%s", gltf);
    //os.write_entire_file("test.data", mem.slice_ptr(&all[0], len(all)));

    //
    // parse buffers
    //
    // parse the buffer-view attributes
    {
        buffer_views := mem.slice_ptr(gltf.buffer_views, gltf.buffer_views_count);
        for _, i in buffer_views {
            using buf_view := &buffer_views[i];
            append(&state.creation_params.buffers, Buffer_Creation_Params{
                gltf_buffer_index = mem.ptr_sub(buffer, gltf.buffers),
                offset = cast(i32)offset,
                size = cast(i32)size,
                type = type == .INDICES ? .INDEXBUFFER : .VERTEXBUFFER,
            });
            append(&state.scene.buffers, sg.alloc_buffer());
        }

        // start loading all the buffers
        buffers := mem.slice_ptr(gltf.buffers, gltf.buffers_count);
        for _, i in buffers {
            gltf_buf := &buffers[i];
            user_data := GLTF_Buffer_Fetch_Userdata { buffer_index = i };
            full_uri := fmt.tprintf("%s%s", state.gltf_path_root, gltf_buf.uri);
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
            user_data := GLTF_Image_Fetch_Userdata { image_index = i };

            full_uri := fmt.tprintf("%s%s", state.gltf_path_root, uri);
            when VERBOSE do fmt.println("loading", full_uri);
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
                base_color = safe_cast_i16(mem.ptr_sub(base_color_texture.texture, gltf.textures)),
                metallic_roughness = safe_cast_i16(mem.ptr_sub(metallic_roughness_texture.texture, gltf.textures)),
                normal = safe_cast_i16(mem.ptr_sub(mat.normal_texture.texture, gltf.textures)),
                occlusion = safe_cast_i16(mem.ptr_sub(mat.occlusion_texture.texture, gltf.textures)),
                emissive = safe_cast_i16(mem.ptr_sub(mat.emissive_texture.texture, gltf.textures)),
            };
            append(&state.scene.materials, scene_mat);
        }
    }

    //
    // parse meshes
    //
    {
        meshes := mem.slice_ptr(gltf.meshes, gltf.meshes_count);
        for _, i in meshes {
            gltf_mesh := &meshes[i];
            append(&state.scene.meshes, Mesh {});
            mesh := &state.scene.meshes[len(state.scene.meshes) - 1];
            mesh.first_primitive = cast(i16)len(state.scene.sub_meshes);
            mesh.num_primitives = cast(i16)gltf_mesh.primitives_count;
            primitives := mem.slice_ptr(gltf_mesh.primitives, gltf_mesh.primitives_count);
            for _, prim_index in primitives {
                gltf_prim := &primitives[prim_index];
                append(&state.scene.sub_meshes, Sub_Mesh {});

                using sub_mesh := &state.scene.sub_meshes[len(&state.scene.sub_meshes) - 1];
                vertex_buffers = create_vertex_buffer_mapping_for_gltf_primitive(gltf, gltf_prim);
                pipeline = cast(i16)create_sg_pipeline_for_gltf_primitive(gltf, gltf_prim, &vertex_buffers);
                material = cast(i16)mem.ptr_sub(gltf_prim.material, gltf.materials);
                if gltf_prim.indices != nil {
                    index_buffer = safe_cast_i16(mem.ptr_sub(gltf_prim.indices.buffer_view, gltf.buffer_views));
                    assert(state.creation_params.buffers[index_buffer].type == sg.Buffer_Type.INDEXBUFFER);
                    assert(gltf_prim.indices.stride != 0);
                    base_element = 0;
                    num_elements = cast(i32) gltf_prim.indices.count;
                } else {
                    // hmm... looking up the number of elements to render from
                    // a random vertex component accessor looks a bit shady
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
            append(&state.scene.nodes, Node {});
            node := &state.scene.nodes[len(state.scene.nodes) - 1];
            node.mesh = safe_cast_i16(mem.ptr_sub(gltf_node.mesh, gltf.meshes));
            node.transform = build_transform_for_gltf_node(gltf, gltf_node);
        }
    }
}

build_transform_for_gltf_node :: proc(gltf: ^cgltf.Data, node: ^cgltf.Node) -> Matrix4 {
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
            //r = rotate_matrix4(node.
            fmt.println("TODO: implement rotation nodes");
        }
        if node.has_scale != 0 {
            s = scale_matrix4(identity(Matrix4), Vector3{node.scale[0], node.scale[1], node.scale[2]});
        }
        tform = mul(parent_tform, mul(mul(s, r), t));
    }

    return tform;
}

// creates a vertex buffer bind slot mapping for a specific GLTF primitive
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

create_sg_layout_for_gltf_primitive :: proc(gltf: ^cgltf.Data, prim: ^cgltf.Primitive, vbuf_map: ^Vertex_Buffer_Mapping) -> sg.Layout_Desc {
    assert(prim.attributes_count <= sg.MAX_VERTEX_ATTRIBUTES);
    layout: sg.Layout_Desc = { };
    attributes := mem.slice_ptr(prim.attributes, prim.attributes_count);
    for _, attr_index in attributes {
        attr := &attributes[attr_index];
        attr_slot := gltf_attr_type_to_vs_input_slot(attr.type);
        if (attr_slot != SCENE_INVALID_INDEX) {
            layout.attrs[attr_slot].format = gltf_to_vertex_format(attr.data);
        } else {
            fmt.eprintln("error: attr_slot was SCENE_INVALID_INDEX");
        }
        buffer_view_index := mem.ptr_sub(attr.data.buffer_view, gltf.buffer_views);
        for vb_slot :i32= 0; vb_slot < vbuf_map.num; vb_slot+=1 {
            if vbuf_map.buffer[vb_slot] == cast(i32)buffer_view_index {
                layout.attrs[attr_slot].buffer_index = vb_slot;
            }
        }
    }

    return layout;
}

// Create a unique sokol-gfx pipeline object for GLTF primitive (aka submesh),
// maintains a cache of shared, unique pipeline objects. Returns an index
// into state.scene.pipelines
create_sg_pipeline_for_gltf_primitive :: proc(gltf: ^cgltf.Data, prim: ^cgltf.Primitive, vbuf_map: ^Vertex_Buffer_Mapping) -> i32 {
    pip_params := Pipeline_Cache_Params {
        layout = create_sg_layout_for_gltf_primitive(gltf, prim, vbuf_map),
        prim_type = gltf_to_prim_type(prim.type),
        index_type = gltf_to_index_type(prim),
        alpha = prim.material.alpha_mode != cgltf.Alpha_Mode.OPAQUE
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
        is_metallic:bool = prim.material.has_pbr_metallic_roughness != 0 ? true : false;
        assert(is_metallic, "exptecting metallic for now");
        append(&state.scene.pipelines, sg.make_pipeline({
            layout = pip_params.layout,
            shader = state.shaders.metallic, // TODO is_metallic ? state.shaders.metallic : state.shaders.specular,
            primitive_type = pip_params.prim_type,
            index_type = pip_params.index_type,
            depth_stencil = {
                depth_write_enabled = !pip_params.alpha,
                depth_compare_func = sg.Compare_Func.LESS_EQUAL,
            },
            blend = {
                enabled = pip_params.alpha,
                src_factor_rgb = pip_params.alpha ? sg.Blend_Factor.SRC_ALPHA : sg.Blend_Factor._DEFAULT,
                dst_factor_rgb = pip_params.alpha ? sg.Blend_Factor.ONE_MINUS_SRC_ALPHA : sg.Blend_Factor._DEFAULT,
                color_write_mask = pip_params.alpha ? sg.COLOR_MASK_RGB : sg.COLOR_MASK__DEFAULT,
            },
            rasterizer = {
                cull_mode = sg.Cull_Mode.BACK,
                face_winding = sg.Face_Winding.CCW,
                sample_count = MSAA_SAMPLE_COUNT,
            }
        }));
    }

    assert(len(state.scene.pipelines) <= SCENE_MAX_PIPELINES);
    return cast(i32)i;
}


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

gltf_image_fetch_callback :: proc "c" (response: ^sfetch.Response) {
    if response.dispatched {
        sfetch.bind_buffer(response.handle, sfetch_buffers[response.channel][response.lane][:]);
    } else if response.fetched {
        user_data := cast(^GLTF_Image_Fetch_Userdata)response.user_data;
        gltf_image_index := cast(int)user_data.image_index;
        create_sg_images_for_gltf_image(
            gltf_image_index,
            mem.slice_ptr(cast(^u8)response.buffer_ptr, cast(int)response.fetched_size));
    }
    if response.finished && response.failed {
        state.failed = true;
    }
}

create_sg_buffers_for_gltf_buffer :: proc(gltf_buffer_index: int, bytes: []u8) {
    for buf, i in state.scene.buffers {
        p := &state.creation_params.buffers[i];
        if p.gltf_buffer_index == gltf_buffer_index {
            msg := fmt.tprint("assertion failed", p, len(bytes));
            assert(cast(int)(p.offset + p.size) <= len(bytes), msg);
            sg.init_buffer(buf, {
                type = p.type,
                size = p.size,
                content = mem.ptr_offset(&bytes[0], cast(int)p.offset)
            });
        }
    }
}

create_sg_images_for_gltf_image :: proc(gltf_image_index: int, bytes: []u8) {
    for _, i in state.scene.images {
        p := &state.creation_params.images[i];
        if p.gltf_image_index == gltf_image_index {
            img_desc := basisu.transcode(bytes);
            state.scene.images[i] = sg.make_image(img_desc);
            basisu.free(&img_desc);
        }
    }
}


@(private)
gltf_to_sg_filter :: proc(gltf_filter: i32) -> sg.Filter {
    // https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#samplerminfilter

    switch gltf_filter {
        case 9728: return sg.Filter.NEAREST;
        case 9729: return sg.Filter.LINEAR;
        case 9984: return sg.Filter.NEAREST_MIPMAP_NEAREST;
        case 9985: return sg.Filter.LINEAR_MIPMAP_NEAREST;
        case 9986: return sg.Filter.NEAREST_MIPMAP_LINEAR;
        case 9987: return sg.Filter.LINEAR_MIPMAP_LINEAR;
        case:      return sg.Filter.LINEAR;
    }
}

gltf_to_sg_wrap :: proc(gltf_wrap: i32) -> sg.Wrap {
    // https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#samplerwraps

    switch gltf_wrap {
        case 33071: return sg.Wrap.CLAMP_TO_EDGE;
        case 33648: return sg.Wrap.MIRRORED_REPEAT;
        case 10497: return sg.Wrap.REPEAT;
        case:       return sg.Wrap.REPEAT;
    }
}

gltf_attr_type_to_vs_input_slot :: proc(attr_type: cgltf.Attribute_Type) -> i32 {
    switch attr_type {
        case cgltf.Attribute_Type.POSITION: return shader_meta.ATTR_vs_cgltf_position;
        case cgltf.Attribute_Type.NORMAL: return shader_meta.ATTR_vs_normal;
        case cgltf.Attribute_Type.TEXCOORD: return shader_meta.ATTR_vs_texcoord;
        case: return SCENE_INVALID_INDEX;
    }
}

@(private)
gltf_to_prim_type :: proc(prim_type: cgltf.Primitive_Type) -> sg.Primitive_Type {
    switch prim_type {
        case cgltf.Primitive_Type.POINTS: return sg.Primitive_Type.POINTS;
        case cgltf.Primitive_Type.LINES: return sg.Primitive_Type.LINES;
        case cgltf.Primitive_Type.LINE_STRIP: return sg.Primitive_Type.LINE_STRIP;
        case cgltf.Primitive_Type.TRIANGLES: return sg.Primitive_Type.TRIANGLES;
        case cgltf.Primitive_Type.TRIANGLE_STRIP: return sg.Primitive_Type.TRIANGLE_STRIP;
        case: return sg.Primitive_Type._DEFAULT;
    }
}

@(private)
gltf_to_index_type :: proc(prim: ^cgltf.Primitive) -> sg.Index_Type {
    if prim.indices == nil do return sg.Index_Type.NONE;

    if prim.indices.component_type == cgltf.Component_Type.R_16U {
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
    switch acc.component_type {
        case cgltf.Component_Type.R_8:
            if acc.type == cgltf.Type.VEC4 {
                return acc.normalized != 0 ? sg.Vertex_Format.BYTE4N : sg.Vertex_Format.BYTE4;
            }
        case cgltf.Component_Type.R_8U:
            if acc.type == cgltf.Type.VEC4 {
                return acc.normalized != 0 ? sg.Vertex_Format.UBYTE4N : sg.Vertex_Format.UBYTE4;
            }
        case cgltf.Component_Type.R_16:
            switch acc.type {
                case cgltf.Type.VEC2: return acc.normalized != 0 ? sg.Vertex_Format.SHORT2N : sg.Vertex_Format.SHORT2;
                case cgltf.Type.VEC4: return acc.normalized != 0 ? sg.Vertex_Format.SHORT4N : sg.Vertex_Format.SHORT4;
            }
        case cgltf.Component_Type.R_32F:
            switch acc.type {
                case cgltf.Type.SCALAR: return sg.Vertex_Format.FLOAT;
                case cgltf.Type.VEC2: return sg.Vertex_Format.FLOAT2;
                case cgltf.Type.VEC3: return sg.Vertex_Format.FLOAT3;
                case cgltf.Type.VEC4: return sg.Vertex_Format.FLOAT4;
            }
    }

    fmt.eprintln("error: don't know how to handle gltf.Accessor", acc);
    return sg.Vertex_Format.INVALID;
}


