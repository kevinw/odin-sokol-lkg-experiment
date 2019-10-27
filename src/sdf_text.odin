package main

import "core:fmt"
import "core:encoding/json"

SDF_Text_Metrics :: struct {
    name: string,
    style: string,
    buffer: int,
    size: int,
    chars: map[string]SDF_Text_Chars,
}

SDF_Text_Chars : struct {
    width: u16,
    height: u16,
    horizontal_bearing_x: u16,
    horizontal_bearing_y: u16,
    horizontal_advance: u16,
    pos_x: u16,
    pos_y: u16,
};

from_json :: proc(json_text: []byte) -> SDF_Text_Metrics {
    if val, err := parse(json_text); err {
        panic("could not parse json");
    }

    obj := value.(Object);

    fmt.println("{}", obj);
}
