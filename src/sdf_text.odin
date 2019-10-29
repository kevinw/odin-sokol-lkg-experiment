package main

import "core:encoding/json"

SDF_Text_Metrics :: struct {
    family: string,
    style: string,
    buffer: int,
    size: int,
    chars: map[string]SDF_Text_Chars,
}

SDF_Text_Chars :: struct {
    width: u16,
    height: u16,
    horizontal_bearing_x: u16,
    horizontal_bearing_y: u16,
    horizontal_advance: u16,
    pos_x: u16,
    pos_y: u16,
};

metrics_from_json :: proc(json_text: []byte) -> SDF_Text_Metrics {
    if val, err := json.parse(json_text); err != .None {
        panic("could not parse json");
        return SDF_Text_Metrics {};
    } else {
        using json;

        obj := val.value.(Object);

        text_chars := SDF_Text_Metrics {
            family = obj["family"].value.(String),
            style = obj["style"].value.(String),
            buffer = cast(int)obj["buffer"].value.(Integer),
            size = cast(int)obj["size"].value.(Integer),
        };

        text_chars.chars = make(map[string]SDF_Text_Chars);

        for char, char_values in obj["chars"].value.(Object) {
            arr := char_values.value.(Array);

            get_u16 :: proc(arr: Array, index: int) -> u16 {
                if index < len(arr) {
                    return cast(u16)arr[index].value.(Integer);
                } else {
                    return 0;
                }
            }

            text_chars.chars[char] = SDF_Text_Chars {
                width = get_u16(arr, 0),
                height = get_u16(arr, 1),
                horizontal_bearing_x = get_u16(arr, 2),
                horizontal_bearing_y = get_u16(arr, 3),
                horizontal_advance = get_u16(arr, 4),
                pos_x = get_u16(arr, 5),
                pos_y = get_u16(arr, 6),
            };
        }


        return text_chars;
    }
}
