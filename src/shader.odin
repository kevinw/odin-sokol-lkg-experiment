package main

import sg "../lib/odin-sokol/src/sokol_gfx"
import "core:encoding/json"
import "core:log"
import "core:os"
import "core:fmt"

json_to_shader_desc :: proc(json_filename: string) -> sg.Shader_Desc {
    desc: sg.Shader_Desc;

    bytes, ok := os.read_entire_file(json_filename);
    if !ok {
        log.error("could not read file '%s'", json_filename);
        return desc;
    }

    if val, err := json.parse(bytes); err != .None {
        log.error("could not parse JSON in '%s'", json_filename);
    } else {
        using json;

        obj := val.value.(Object);
        profile_version := obj["profile_version"].value.(i64);
        fmt.println("profile_version", profile_version);

        vs_obj, has_vs := obj["vs"];
        if has_vs {
            vs := vs_obj.value.(Object);
            filename := vs["file"].value.(string);
            fmt.println("vs filename", filename);

            inputs := vs["inputs"].value.(Array);
            for inp_obj in inputs {
                inp := inp_obj.value.(Object);
                id := inp["id"].value.(i64);
                name := inp["name"].value.(string);
                location := inp["location"].value.(i64);

                fmt.println(id, name, location);


            }
        }
        

        //language := obj["langauge"].value.(string);
        //assert(language == "hlsl");
    }

    return desc;
}
