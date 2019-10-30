package main;
import sg "sokol:sokol_gfx"
import sfetch "sokol:sokol_fetch"
import "../lib/cgltf"
import "core:fmt"
import "core:mem"

SCENE_MAX_BUFFERS :: 16;
SCENE_MAX_IMAGES :: 16;

gltf_parse :: proc(bytes: []u8) {
    options := cgltf.Options{};
    gltf:^cgltf.Data;

    result := cgltf.parse(&options, &bytes[0], len(bytes), &gltf);
    if result != cgltf.Result.SUCCESS {
        fmt.eprintln("error parsing gltf");
        return;
    }

    defer cgltf.free(gltf);

    //
    // parse buffers
    //
    if gltf.buffer_views_count > SCENE_MAX_BUFFERS {
        state.failed = true;
        fmt.eprintln("too many buffers");
        return;
    }

    // parse the buffer-view attributes
    buffer_views := mem.slice_ptr(gltf.buffer_views, gltf.buffer_views_count);
    for buf_view in buffer_views {
        append(&state.creation_params.buffers, Buffer_Creation_Params{
            gltf_buffer_index = mem.ptr_sub(buf_view.buffer, gltf.buffers),
            offset = cast(i32)buf_view.offset,
            size = cast(i32)buf_view.size,
            type = buf_view.type == .INDICES ? .INDEXBUFFER : .VERTEXBUFFER,
        });
        append(&state.scene.buffers, sg.alloc_buffer());
    }

    // start loading all the buffers
    buffers := mem.slice_ptr(gltf.buffers, gltf.buffers_count);
    for gltf_buf, i in buffers {
        user_data := GLTF_Buffer_Fetch_Userdata { buffer_index = i };
        fmt.println("fetching", gltf_buf.uri);
        sfetch.send({
            path = gltf_buf.uri,
            callback = gltf_buffer_fetch_callback,
            user_data_ptr = &user_data,
            user_data_size = size_of(user_data),
        });
    }

    //
    // parse images
    //
    textures := mem.slice_ptr(gltf.textures, gltf.textures_count);
    if len(textures) > SCENE_MAX_IMAGES {
        state.failed = true;
        fmt.eprintln("too many textures");
        return;
    }

    for _, i in textures {
        tex := &textures[i];
        append(&state.creation_params.images, Image_Creation_Params{
            gltf_image_index = mem.ptr_sub(tex.image, gltf.images),
            min_filter = gltf_to_sg_filter(tex.sampler.min_filter),
            mag_filter = gltf_to_sg_filter(tex.sampler.mag_filter),
            wrap_s = gltf_to_sg_wrap(tex.sampler.wrap_s),
            wrap_t = gltf_to_sg_wrap(tex.sampler.wrap_t),
        });
        append(&state.scene.images, sg.Image{id=sg.INVALID_ID});
    }

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

create_sg_buffers_for_gltf_buffer :: proc(gltf_buffer_index: int, bytes: []u8) {
    for buf, i in state.scene.buffers {
        p := &state.creation_params.buffers[i];
        if p.gltf_buffer_index == gltf_buffer_index {
            assert(cast(int)(p.offset + p.size) < len(bytes));
            sg.init_buffer(buf, {
                type = p.type,
                size = p.size,
                content = mem.ptr_offset(&bytes[0], cast(int)p.offset)
            });
        }
    }
}

GLTF_Buffer_Fetch_Userdata :: struct {
    buffer_index: cgltf.Size,
};


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
