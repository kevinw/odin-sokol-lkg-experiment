package sgs

import "core:fmt"
import "core:os"
import "core:strings"
import sg "../../lib/odin-sokol/src/sokol_gfx"

CHUNK_ROOT :=      makefourcc('S', 'G', 'S', ' ');
CHUNK_STAG :=      makefourcc('S', 'T', 'A', 'G');
CHUNK_REFL :=      makefourcc('R', 'E', 'F', 'L');
CHUNK_CODE :=      makefourcc('C', 'O', 'D', 'E');
CHUNK_DATA :=      makefourcc('D', 'A', 'T', 'A');

SGS_LANG_GLES := makefourcc('G', 'L', 'E', 'S');
SGS_LANG_HLSL := makefourcc('H', 'L', 'S', 'L');
SGS_LANG_GLSL := makefourcc('G', 'L', 'S', 'L');
SGS_LANG_MSL  := makefourcc('M', 'S', 'L', ' ');

SGS_VERTEXFORMAT_FLOAT :=      makefourcc('F', 'L', 'T', '1');
SGS_VERTEXFORMAT_FLOAT2 :=     makefourcc('F', 'L', 'T', '2');
SGS_VERTEXFORMAT_FLOAT3 :=     makefourcc('F', 'L', 'T', '3');
SGS_VERTEXFORMAT_FLOAT4 :=     makefourcc('F', 'L', 'T', '4');
SGS_VERTEXFORMAT_INT :=        makefourcc('I', 'N', 'T', '1');
SGS_VERTEXFORMAT_INT2 :=       makefourcc('I', 'N', 'T', '2');
SGS_VERTEXFORMAT_INT3 :=       makefourcc('I', 'N', 'T', '3');
SGS_VERTEXFORMAT_INT4 :=       makefourcc('I', 'N', 'T', '4');

makefourcc :: proc(a, b, c, d: u8) -> u32 {
    return cast(u32)(a) | (cast(u32)(b) << 8) | (cast(u32)(c) << 16) | (cast(u32)(d) << 24);
}

Stage :: enum u32 {
    VERTEX = 1414677846,//makefourcc('V', 'E', 'R', 'T'),
    FRAGMENT = 1195463238,//makefourcc('F', 'R', 'A', 'G'),
    COMPUTE = 1347243843,//makefourcc('C', 'O', 'M', 'P'),
};

SGS_IMAGEDIM_1D :=            makefourcc('1', 'D', ' ', ' ');
SGS_IMAGEDIM_2D :=            makefourcc('2', 'D', ' ', ' ');
SGS_IMAGEDIM_3D :=            makefourcc('3', 'D', ' ', ' ');
SGS_IMAGEDIM_CUBE :=          makefourcc('C', 'U', 'B', 'E');
SGS_IMAGEDIM_RECT :=          makefourcc('R', 'E', 'C', 'T');
SGS_IMAGEDIM_BUFFER :=        makefourcc('B', 'U', 'F', 'F');
SGS_IMAGEDIM_SUBPASS :=       makefourcc('S', 'U', 'B', 'P');

// SGS chunk
Chunk :: struct #packed {
    lang: u32,          // sgs_shader_lang
    profile_ver: u32,   // 
};

// REFL
Chunk_Refl :: struct #packed {
    name: [32]u8,
    num_inputs: u32,
    num_textures: u32,
    num_uniform_buffers: u32,
    num_storage_images: u32,
    num_storage_buffers: u32,
    flatten_ubos: u16,
    debug_info: u16,

    // inputs: sgs_refl_input[num_inputs]
    // uniform-buffers: sgs_refl_uniformbuffer[num_uniform_buffers]
    // textures: sgs_refl_texture[num_textures]
    // storage_images: sgs_refl_texture[num_storage_images]
    // storage_buffers: sgs_refl_buffer[num_storage_buffers]
};

Chunk_Refl_to_string :: proc(using chunk_refl: ^Chunk_Refl) -> string {
    return fmt.tprint(
        "Chunk_Refl{",
        "name=", cstring(&name[0]),
        ", num_inputs=", num_inputs,
        ", num_textures=", num_textures,
        ", num_uniform_buffers=", num_uniform_buffers,
        ", num_storage_images=", num_storage_images,
        ", num_storage_buffers=", num_storage_buffers,
        ", flatten_ubos=", flatten_ubos,
        ", debug_info=", debug_info,
    "}");
}


Refl_Input :: struct #packed {
    name: [32]u8,
    loc: i32,
    semantic: [32]u8,
    semantic_index: u32,
    format: u32,
};

Refl_Input_to_string :: proc(using refl_input: ^Refl_Input) -> string {
    return fmt.tprint(
        "Refl_Input{name=", cstring(&name[0]),
        ", loc=", loc,
        ", semantic=", cstring(&semantic[0]),
        ", semantic_index= ", semantic_index,
        ", format=", format,
    "}");
}

Refl_Texture :: struct #packed {
    name: [32]u8,
    binding: i32,
    image_dim: u32,
    multisample: u8,
    is_array: u8,
};

Refl_Buffer :: struct #packed {
    name: [32]u8,
    binding: i32,
    size_bytes: u32,
    array_stride: u32,
}; 

Refl_Buffer_to_string :: proc(using refl_buffer: ^Refl_Buffer) -> string {
    return fmt.tprint("Refl_Buffer{",
        "name=", cstring(&name[0]),
        ", binding=", binding,
        ", size_bytes=", size_bytes,
        ", array_stride=", array_stride,
    "}");
}

Refl_Uniformbuffer :: struct #packed {
    name: [32]u8,
    binding: i32,
    size_bytes: u32,
    array_size: u16,
};

Refl_Uniformbuffer_to_string :: proc(using refl_ubuffer: ^Refl_Uniformbuffer) -> string {
    return fmt.tprint("Refl_Uniformbuffer{",
        "name=", cstring(&name[0]),
        ", binding=", binding,
        ", size_bytes=", size_bytes,
        ", array_size=", array_size,
    "}");
}


Reader :: struct {
    bytes: []byte,
    offset: int,
};

read :: proc(using reader: ^Reader, $T: typeid) -> T {
    N :: size_of(T);
    current_offset := offset;
    offset += N;

    return (cast(^T)(&bytes[current_offset:current_offset + N][0]))^;
}

read_string :: proc(using reader: ^Reader, num_bytes: int) -> string {
    assert(num_bytes > 0);
    assert(offset + num_bytes <= len(bytes));

    current_offset := offset;
    offset += num_bytes;

    return string(bytes[current_offset:current_offset + num_bytes]);
}

bytes_remaining :: proc(using reader: ^Reader) -> int {
    assert(offset <= len(bytes));
    return len(bytes) - offset;
}

Info :: struct {
    foo: u32,
};

parse_sgs_file :: proc(filename: string) -> (sg.Shader_Desc, bool) {
    shader_desc := sg.Shader_Desc {};

    bytes, ok := os.read_entire_file(filename);
    if !ok {
        fmt.eprintln("could not read", filename);
        return shader_desc, false;
    }

    reader := Reader { bytes, 0 };
    if read(&reader, u32) != CHUNK_ROOT {
        return shader_desc, false;
    }
    read(&reader, u32); // size

    lang := read(&reader, u32);
    fmt.println("lang", lang);

    profile_version := read(&reader, u32);
    fmt.println("profile_version", profile_version);

    shader_type: Stage;
    current_desc_stage: ^sg.Shader_Stage_Desc;

    for bytes_remaining(&reader) > 0 {
        chunk_type := read(&reader, u32);
        switch chunk_type {
            case CHUNK_STAG:
                stage_size := read(&reader, u32); // size
                fmt.println("stage_size", stage_size);
            case cast(u32)Stage.VERTEX, cast(u32)Stage.FRAGMENT, cast(u32)Stage.COMPUTE:
                shader_type = cast(Stage)chunk_type;
                fmt.println("------------");
                #complete switch shader_type {
                    case .VERTEX:   current_desc_stage = &shader_desc.vs;
                    case .FRAGMENT: current_desc_stage = &shader_desc.fs;
                    case .COMPUTE:  assert(false); // TODO
                }
            case CHUNK_CODE:
                code_len := read(&reader, u32);
                fmt.println("code_len", code_len);
                shader_code := read_string(&reader, cast(int)code_len);
                fmt.println("shader_code\n", shader_code[:len(shader_code)-1]);
                assert(shader_code[len(shader_code) - 1] == '\x00');

                assert(current_desc_stage != nil);
                current_desc_stage.source = strings.clone_to_cstring(shader_code[:len(shader_code) - 2]); // take the null byte off, since clone_to_cstring will put one back on :x
                current_desc_stage.entry = "main";
            case CHUNK_DATA:
                assert(false); // TODO: unhandled - shader bytecode
            case CHUNK_REFL:
                fmt.println("REFL chunk");
                chunk_len := read(&reader, u32);
                future_offset := reader.offset + cast(int)chunk_len;
                refl := read(&reader, Chunk_Refl);
                fmt.println("read REFL chunk:", Chunk_Refl_to_string(&refl));
                for _ in 0..<refl.num_inputs {
                    input := read(&reader, Refl_Input);
                    fmt.println("input", Refl_Input_to_string(&input));
                }
                for _ in 0..<refl.num_uniform_buffers {
                    uniform_buffer := read(&reader, Refl_Uniformbuffer);
                    fmt.println("uniform buffer", Refl_Uniformbuffer_to_string(&uniform_buffer));
                }
                for _ in 0..<refl.num_textures {
                    texture := read(&reader, Refl_Texture);
                    fmt.println("texture", texture);
                }
                for _ in 0..<refl.num_storage_images {
                    storage_image := read(&reader, Refl_Texture);
                    fmt.println("storage image", storage_image);
                }
                for _ in 0..<refl.num_storage_buffers {
                    storage_buffer := read(&reader, Refl_Buffer);
                    fmt.println("storage buffer:", Refl_Buffer_to_string(&storage_buffer));
                }
                //assert(reader.offset == future_offset, fmt.tprint("expected reader offset to be", future_offset, "but it was", reader.offset));
                reader.offset = future_offset;
            case:
                fmt.println("unhandled chunk", chunk_type);
                assert(false);
                chunk_len := read(&reader, u32);
                _ = read_string(&reader, cast(int)chunk_len);
        }
    }

    fmt.println("DONE");

    return shader_desc, true;
}

main :: proc() {
    info, ok := parse_sgs_file("vertcolor.sgs");
    assert(ok);
}
