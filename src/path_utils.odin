package main

import "core:strings"

dirname :: proc(path: string, allocator := context.allocator) -> string {
    assert(strings.index(path, "\\") == -1,
        "need to handle backslashes on windows");

    // if there's no slash, return ./
    last_index := strings.last_index(path, "/");
    if last_index == -1 do return strings.clone("./", allocator);

    // if it's already a dir
    if last_index == len(path) - 1 do return strings.clone(path, allocator);

    // otherwise, return the dir part, including the slash
    return strings.clone(path[0:last_index + 1], allocator);
}
